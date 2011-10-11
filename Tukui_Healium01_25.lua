-- TESTED
-- buff (must implement move tukui raid frame to test) -> OK
-- debuff -> OK
-- cd -> OK
-- button -> OK
-- cure + dispel -> OK
-- incoming heal ==> C["unitframes"].healcomm = true -> OK
-- disable tukui raid debuff/buff/hots   see \Tukui_Raid_Healing\oUF_hTukz_Raid01_15.lua:139   frame.Debuffs = nil  -> OK
-- mana ==> included in oUF  -> OK
-- special spells (swiftmend allowed only if rejuv or regrowth on member) (see settings) -> OK
-- change alpha when dead/ghost or disconnected -> OK
-- HealiumEnabled -> OK
-- avoid using _G[] to get raid frame, use a local list -> OK
-- pets: could Share be used to create pets ? -> OK
-- spell/buff/debuff size/spacing -> OK
-- sound when a dispellable spell is found -> OK
-- spell/buff/debuff tooltip -> OK
-- buff/debuff are not shown when connecting  this is because unit is not yet set when Shared is called (unit = raid instead of player1) -> OK
-- rebirth not shown when dead while in combat. Forgot to add rez=true =) -> OK
-- settings: highlightCure, playSoundOnDispel, showBuffDebuffTooltip, showButtonTooltip, showPercentage, frame width/height -> OK
-- sometimes buff/debuff doesn't disappear -> stupid copy/paste
-- doesn't work if no settings found for current spec on priest. Respec works but connecting with a spec without settings doesn't work -> OK
-- Use this module only if Healium is enabled and at least a settings for current class is found, else, use classic module
--	if grid -> raid, party
--	else,
--		create normal grid -> custom [@raid26,exists] show;hide
--		if healium, create healium -> custom [@raid26,exists] hide;show + pets
--		else, create normal custom [@raid26,exists] hide;show

-- TO TEST
-- delayed healium buttons creation while in combat (call Healium_CreateFrameButtons when out of combat) -> DOESNT WORK
-- aggro ==> C["unitframes"].aggro = true

-- TODO:
-- settings: showDebuffs, showNoMana
-- why raid frame moves automatically?
-- if not enough mana or reactive conditions not met, change heal button color, see http://www.wowwiki.com/API_IsUsableSpell
--	-> conflict if button is colored for a dispel and nomana ==> set flag on button to determine which color set (settings showNoMana)
-- range by spell: Tukui\Tukui\modules\unitframes\core\oUF\elements\range.lua
-- spell must be learned to appear in a button (question-mark if not learned) check Healium_IsSpellLearned(spellID)
-- REDO settings: global settings, per character settings and spec settings
--	on ENTERING_WORLD or TALENT_UPDATE, build settings from HealiumSettings (concat global, per character and spec settings)
--	and use a global variable to store current settings
-- Flash frames: hide flash frame when debuff is dispelled (settings flashCure)
-- multirow: 2 rows of spell/buff/debuff (looks ugly :p)

local ADDON_NAME, ns = ...
local oUF = oUFTukui or oUF
assert(oUF, "Tukui was unable to locate oUF install.")

ns._Objects = {}
ns._Headers = {}

local T, C, L = unpack(Tukui) -- Import: T - functions, constants, variables; C - config; L - locales
if not C["unitframes"].enable == true or C["unitframes"].gridonly == true then return end
if not HealiumSettings or not HealiumSettings.enabled or not HealiumSettings[T.myclass] then return end

-------------------------------------------------------
-- Constants
-------------------------------------------------------
local Healium_Debug = true
local Healium_MaxButtonCount = 10
local Healium_MaxDebuffCount = 8
local Healium_MaxBuffCount = 6

-------------------------------------------------------
-- Variables
-------------------------------------------------------
local Healium_DelayedButtonsCreation = {}
local Healium_Frames = {}
local Healium_LastDebuffSoundTime = GetTime()

-------------------------------------------------------
-- Helpers
-------------------------------------------------------
local function Healium_ERROR(line)
	print("|CFFFF0000TH|r:"..line)
end

local function Healium_WARNING(line)
	print("|CFF00FFFFTH|r:"..line)
end

local function Healium_DEBUG(line)
	if not Healium_Debug or Healium_Debug == false then return end
	print("|CFF00FF00TH|r:"..line)
end

local function Getter(value, default)
	return value == nil and default or value
end

local ShortValueNegative = function(v)
	if v <= 999 then return v end
	if v >= 1000000 then
		local value = string.format("%.1fm", v/1000000)
		return value
	elseif v >= 1000 then
		local value = string.format("%.1fk", v/1000)
		return value
	end
end

-- Return settings for current spec
local function Healium_GetSettings()
	Healium_DEBUG("Healium_GetSettings")
	local ptt = GetPrimaryTalentTree()
	if not ptt then return end
	return HealiumSettings[T.myclass][ptt]
end

-- Get frame from unit
local function Healium_GetFrameFromUnit(unit)
	Healium_DEBUG("Healium_GetFrameFromUnit")
	if not Healium_Frames then return end
	for _, frame in ipairs(Healium_Frames) do
		--Healium_DEBUG("Healium_GetFrameFromUnit:"..frame:GetName().."  "..(frame.unit or 'nil').."  "..(frame:IsShown() and 'shown' or 'hidden'))
		if frame and frame:IsShown() and frame.unit == unit then return frame end
	end
	return
end

-- Loop among every members in party/raid and call a function
local function Healium_ForEachMember(fct, ...)
	Healium_DEBUG("Healium_ForEachMember")
	if not Healium_Frames then return end
	for _, frame in ipairs(Healium_Frames) do
		--Healium_DEBUG("Healium_ForEachMember:"..frame:GetName().."  "..(frame.unit or 'nil').."  "..(frame:IsShown() and 'shown' or 'hidden'))
		if frame and frame:IsShown() then
			fct(frame, ...)
		end
	end
end

-- Get book spell id from spell name
local function Healium_GetSpellBookID(spellName)
	Healium_DEBUG("Healium_GetSpellBookID")
	for i = 1, 300, 1 do
		local spellBookName = GetSpellBookItemName(i, SpellBookFrame.bookType)
		if (not spellBookName) then break end
		if (spellName == spellBookName) then
			local slotType = GetSpellBookItemInfo(i, SpellBookFrame.bookType)
			if (slotType == "FUTURESPELL") then break end
			return i
		end
	end            
	return nil
end

-- Is spell learned
local function Healium_IsSpellLearned(spellID)
	Healium_DEBUG("Healium_IsSpellLearned")
	local spellName = GetSpellInfo(spellID)
	if not spellName then return end
	local skillType, globalSpellID = GetSpellBookItemInfo(spellName)
	-- skill type: "SPELL", "PETACTION", "FUTURESPELL", "FLYOUT"
	if skillType == "SPELL" and globalSpellID == spellID then return skillType end
	return
end

-- Play a sound
local function Healium_PlayDebuffSound()
	Healium_DEBUG("Healium_PlayDebuffSound")
	PlaySoundFile("Sound\\Doodad\\BellTollHorde.wav")
end

-- Create flash frame on a frame
local function Healium_CreateFlashFrame(frame)
	Healium_DEBUG("Healium_CreateFlashFrame")
	if not HealiumSettings.flashCure then return end
	if frame.healiumFlashFrame then return end

	frame.healiumFlashFrame = CreateFrame("Frame", nil, frame)
	frame.healiumFlashFrame:Hide()
	frame.healiumFlashFrame:SetAllPoints(frame)
	frame.healiumFlashFrame.texture = frame.healiumFlashFrame:CreateTexture(nil, "OVERLAY")
	frame.healiumFlashFrame.texture:SetTexture("Interface\\Cooldown\\star4")
	frame.healiumFlashFrame.texture:SetPoint("CENTER", frame.healiumFlashFrame, "CENTER")
	frame.healiumFlashFrame.texture:SetBlendMode("ADD")
	frame.healiumFlashFrame:SetAlpha(1)
	frame.healiumFlashFrame.UpdateInterval = 0.02
	frame.healiumFlashFrame.timeSinceLastUpdate = 0
	frame.healiumFlashFrame:SetScript("OnUpdate", function (self, elapsed)
		if not self:IsShown() then return end
		self.timeSinceLastUpdate = self.timeSinceLastUpdate + elapsed
		if self.timeSinceLastUpdate >= self.UpdateInterval then
			self.modifier = self.flashModifier
			self.flashModifier = self.modifier - self.modifier * self.timeSinceLastUpdate
			self.timeSinceLastUpdate = 0
			self.alpha = self.flashModifier * self.flashBrightness
			if self.modifier < 0.1 or self.alpha <= 0 then
				self:Hide()
			else
				self.texture:SetHeight(self.modifier * self:GetHeight() * self.flashSize)
				self.texture:SetWidth(self.modifier * self:GetWidth() * self.flashSize)
				self.texture:SetAlpha(self.alpha)
			end
		end
	end)
end

-- Show flash frame
local function Healium_ShowFlashFrame(frame, color, size, brightness)
	Healium_DEBUG("Healium_ShowFlashFrame")
	--if not frame.healiumFlashFrame then return end
	if not healiumFlashFrame then
		-- Create flash frame on-the-fly
		Healium_CreateFlashFrame(frame)
	end

	-- Show flash frame
	frame.healiumFlashFrame.flashModifier = 1
	frame.healiumFlashFrame.flashSize = (size or 240) / 100
	frame.healiumFlashFrame.flashBrightness = (brightness or 100) / 100
	frame.healiumFlashFrame.texture:SetAlpha(1 * frame.healiumFlashFrame.flashBrightness)
	frame.healiumFlashFrame.texture:SetHeight(frame.healiumFlashFrame:GetHeight() * frame.healiumFlashFrame.flashSize)
	frame.healiumFlashFrame.texture:SetWidth(frame.healiumFlashFrame:GetWidth() * frame.healiumFlashFrame.flashSize)
	if type(color) == "table" then
		frame.healiumFlashFrame.texture:SetVertexColor(color.r or 1, color.g or 1, color.b or 1)
	elseif type(color) == "string" then
		local color = COLORTABLE[color:lower()]
		if color then
			frame.healiumFlashFrame.texture:SetVertexColor(color.r or 1, color.g or 1, color.b or 1)
		else
			frame.healiumFlashFrame.texture:SetVertexColor(1, 1, 1)
		end
	else
		frame.healiumFlashFrame.texture:SetVertexColor(1, 1, 1)
	end
	frame.healiumFlashFrame:Show()
end

-- Hide flash frame
local function Healium_HideFlashFrame(frame, color, size, brightness)
	Healium_DEBUG("Healium_HideFlashFrame")
	if not frame.healiumFlashFrame then return end

	frame.healiumFlashFrame:Hide()
end

-------------------------------------------------------
-- Healium specific functions
-------------------------------------------------------
-- Update healium button cooldown
local function Healium_UpdateFrameCooldown(frame, index, start, duration, enabled)
	Healium_DEBUG("Healium_UpdateFrameCooldown")
	if not frame.healiumButtons then return end
	--Healium_DEBUG("frame:"..(frame and frame:GetName() or "nil").." index:"..(index or "nil").." start:"..(start or "nil").." duration:"..(duration or "nil").." enabled:"..(enabled or "nil"))
	local button = frame.healiumButtons[index]
	--Healium_DEBUG("button:"..(button and button:GetName() or "nil").." cooldown:"..(button.cooldown and "ok" or "nil"))
	CooldownFrame_SetTimer(button.cooldown, start, duration, enabled)
end

-- Update healium button color
local function Healium_UpdateFrameColor(frame, index, color)
	Healium_DEBUG("Healium_UpdateFrameColor")
	if not frame.healiumButtons then return end
	local button = frame.healiumButtons[index]
	button.texture:SetVertexColor(color[1], color[2], color[3])
end

-- Update healium frame debuff position
local function Healium_UpdateFrameDebuffsPosition(frame)
	Healium_DEBUG("Healium_UpdateFrameDebuffsPosition")
	--Healium_DEBUG("Update debuff position for "..frame:GetName())
	if not frame.healiumDebuffs or not frame.healiumButtons then return end
	local settings = Healium_GetSettings()
	if not settings then return end
	local lastButton = frame.healiumButtons[#settings.spells]
	local firstDebuff = frame.healiumDebuffs[1]
	--Healium_DEBUG("lastButton: "..lastButton:GetName().."  firstDebuff: "..firstDebuff:GetName())
	local debuffSpacing = settings and settings.debuffSpacing or 2
	firstDebuff:ClearAllPoints()
	firstDebuff:Point("TOPLEFT", lastButton, "TOPRIGHT", debuffSpacing, 0)
end

-- Update healium frame buff/debuff and special spells
local function Healium_UpdateFrameBuffsDebuffsSpecialSpells(frame)
	local settings = Healium_GetSettings()
	local unit = frame.unit

	Healium_DEBUG("Healium_UpdateFrameBuffsDebuffsSpecialSpells: frame: "..frame:GetName().." unit: "..(unit or "nil"))
	
	if not unit then return end

	-- buff and buttons are not modified if unit is disabled (dead, ghost or disconnected)
	-- debuff are modified if unit is disabled

	-- reset vertex, border and backdrop color
	if frame.healiumButtons and not frame.healiumDisabled then
		Healium_DEBUG("---- reset vertex, border and backdrop color")
		for index, button in ipairs(frame.healiumButtons) do
			button.texture:SetVertexColor(1, 1, 1)
			button:SetBackdropColor(0.6, 0.6, 0.6)
			button:SetBackdropBorderColor(0.1, 0.1, 0.1)
			--Healium_HideFlashFrame(button)
		end
	end
	-- TODO: hide every buff and debuffs instead of hiding remainder ones

	-- buff
	local buffs = {}
	if frame.healiumBuffs and not frame.healiumDisabled then
		local buffIndex = 1
		if settings then
			for i = 1, 40, 1 do
				-- get buff
				name, _, icon, count, _, duration, expirationTime, _, _, _, spellID = UnitAura(unit, i, "PLAYER|HELPFUL")
				if not name then break end
				tinsert(buffs, spellID) -- we display buff castable by player but we keep the whole list of buff to check prereq
				-- is buff casted by player and in spell list?
				local found = false
				for index, spellSetting in ipairs(settings.spells) do
					if spellSetting.spellID and spellSetting.spellID == spellID then
						found = true
					elseif spellSetting.macroName then
						local macroID = GetMacroIndexByName(spellSetting.macroName)
						if macroID > 0 then
							local spellName = GetMacroSpell(macroID)
							if spellName == name then
								found = true
							end
						end
					end
				end
				if found then
					-- buff casted by player and in spell list
					local buff = frame.healiumBuffs[buffIndex]
					-- id, unit and texture
					buff:SetID(i) -- used by tooltip
					buff.unit = unit
					buff.icon:SetTexture(icon)
					-- count
					if count > 1 then
						buff.count:SetText(count)
						buff.count:Show()
					else
						buff.count:Hide()
					end
					-- cooldown
					if duration and duration > 0 then
						local startTime = expirationTime - duration
						buff.cooldown:SetCooldown(startTime, duration)
					else
						buff.cooldown:Hide()
					end
					-- show
					buff:Show()
					-- next buff
					buffIndex = buffIndex + 1
					-- too many buff?
					if buffIndex > Healium_MaxBuffCount then
						Healium_WARNING("Too many buff for "..frame:GetName().." "..unit)
						break
					end
				end
			end
		end
		for i = buffIndex, Healium_MaxBuffCount, 1 do
			-- hide remainder buff
			local buff = frame.healiumBuffs[i]
			buff:Hide()
		end
	end

	-- debuff
	local debuffs = {}
	if frame.healiumDebuffs then
		local debuffIndex = 1
		if settings then
			for i = 1, 40, 1 do
				-- get debuff
				local name, _, icon, count, debuffType, duration, expirationTime, _, _, _, spellID = UnitDebuff(unit, i) 
				if not name then break end
				tinsert(debuffs, { spellID, debuffType } ) -- we display only non-blacklisted debuff but we keep the whole debuff list to check prereq
				-- is debuff blacklisted?
				local filtered = false
				if HealiumSettings.debuffBlacklist then
					for _, debuffBlackListSpellID in ipairs(HealiumSettings.debuffBlacklist) do
						if debuffBlackListSpellID == spellID then
							filtered = true
							break
						end
					end
				end
				if not filtered then
					-- debuff not blacklisted
					local debuff = frame.healiumDebuffs[debuffIndex]
					-- id, unit and texture
					debuff:SetID(i) -- used by tooltip
					debuff.unit = unit
					debuff.icon:SetTexture(icon)
					-- count
					if count > 1 then
						debuff.count:SetText(count)
						debuff.count:Show()
					else
						debuff.count:Hide()
					end
					-- cooldown
					if duration and duration > 0 then
						local startTime = expirationTime - duration
						debuff.cooldown:SetCooldown(startTime, duration)
						debuff.cooldown:Show()
					else
						debuff.cooldown:Hide()
					end
					-- debuff color
					local debuffColor = debuffType and DebuffTypeColor[debuffType] or DebuffTypeColor["none"]
					--Healium_DEBUG("debuffType: "..(debuffType or 'nil').."  debuffColor: "..(debuffColor and debuffColor.r or 'nil')..","..(debuffColor and debuffColor.g or 'nil')..","..(debuffColor and debuffColor.b or 'nil'))
					debuff:SetBackdropBorderColor(debuffColor.r, debuffColor.g, debuffColor.b)
					-- show
					debuff:Show()
					-- next debuff
					debuffIndex = debuffIndex + 1
					--- too many debuff?
					if debuffIndex > Healium_MaxDebuffCount then
						Healium_WARNING("Too many debuff for "..frame:GetName().." "..unit)
						break
					end
				end
			end
		end
		for i = debuffIndex, Healium_MaxDebuffCount, 1 do
			-- hide remainder debuff
			local debuff = frame.healiumDebuffs[i]
			debuff:Hide()
		end
	end

	-- color dispel button if dispellable debuff and special spells (is buff or debuff a prereq to enable/disable a spell)
	if settings and frame.healiumButtons and not frame.healiumDisabled then
		local debuffDispellableFound = false
		local highlightCure = Getter(HealiumSettings.highlightCure, true)
		local playSound = Getter(HealiumSettings.playSoundOnDispel, true)
		local flashCure = Getter(HealiumSettings.flashCure, true)
		for index, spellSetting in ipairs(settings.spells) do
			local button = frame.healiumButtons[index]
			-- buff prereq: if not present, spell is inactive
			if spellSetting.buffs then
				--Healium_DEBUG("searching buff prereq for "..spellSetting.spellID)
				local prereqBuffFound = false
				for _, prereqBuffSpellID in ipairs(spellSetting.buffs) do
					--Healium_DEBUG("buff prereq for "..spellSetting.spellID.." "..prereqBuffSpellID)
					for _, buffSpellID in pairs(buffs) do
						--Healium_DEBUG("buff on unit "..buffSpellID)
						if buffSpellID == prereqBuffSpellID then
							--Healium_DEBUG("PREREQ: "..prereqBuffSpellID.." is a buff prereq for "..spellSetting.spellID.." "..button:GetName())
							prereqBuffFound = true
							break
						end
					end
					if prereqBuffFound then break end
				end
				if not prereqBuffFound then
					--Healium_DEBUG("PREREQ: BUFF for "..spellSetting.spellID.." NOT FOUND")
					button.texture:SetVertexColor(0.4, 0.4, 0.4)
				end
			end
			-- debuff prereq: if present, spell is inactive
			if spellSetting.debuffs then
				--Healium_DEBUG("searching buff prereq for "..spellSetting.spellID)
				local prereqDebuffFound = false
				for _, prereqDebuffSpellID in ipairs(spellSetting.debuffs) do
					--Healium_DEBUG("buff prereq for "..spellSetting.spellID.." "..prereqDebuffSpellID)
					for _, debuff in ipairs(debuffs) do
						local debuffSpellID = debuff[1]
						--Healium_DEBUG("debuff on unit "..debuffSpellID)
						if debuffSpellID == prereqDebuffSpellID then
							--Healium_DEBUG("PREREQ: "..prereqDebuffSpellID.." is a debuff prereq for "..spellSetting.spellID.." "..button:GetName())
							prereqDebuffFound = true
							break
						end
					end
					if prereqDebuffFound then break end
				end
				if prereqDebuffFound then
					--Healium_DEBUG("PREREQ: DEBUFF for "..spellSetting.spellID.." FOUND")
					button.texture:SetVertexColor(0.4, 0.4, 0.4)
				end
			end
			-- color dispel button if affected by a debuff curable by a player spell
			if spellSetting.cures and (highlightCure or playSound) then
				for _, debuff in ipairs(debuffs) do
					local debuffType = debuff[2]
					debuffType = "Curse" -- DEBUG purpose :)
					if debuffType then
						--Healium_DEBUG("type: "..type(spellSetting.cures[debuffType]))
						local canCure = type(spellSetting.cures[debuffType]) == "function" and spellSetting.cures[debuffType]() or spellSetting.cures[debuffType]
						if canCure then
							--print("DEBUFF dispellable")
							local debuffColor = DebuffTypeColor[debuffType] or DebuffTypeColor["none"]
							-- Highlight heal button
							if highlightCure then
								--Healium_DEBUG("debuff "..debuff[1].." dispellable by "..(spellSetting.spellID or spellSetting.macroName).." on button "..button:GetName())
								button:SetBackdropColor(debuffColor.r, debuffColor.g, debuffColor.b)
								--button:SetBackdropBorderColor(debuffColor.r, debuffColor.g, debuffColor.b)
								button.texture:SetVertexColor(debuffColor.r, debuffColor.g, debuffColor.b)
							end
							-- flash heal button
							if flashCure then
								Healium_ShowFlashFrame(button, debuffColor, 100, 100)
							end
							debuffDispellableFound = true
							break -- a debuff dispellable is enough
						end
					end
				end
			end
		end
		if debuffDispellableFound then
			-- Play sound?
			if playSound then
				if UnitInRange(unit) then
					local now = GetTime()
					--print("DEBUFF in range: "..now.."  "..Healium_LastDebuffSoundTime)
					if now > (Healium_LastDebuffSoundTime + 7) then -- no more than once every 7 seconds
						--print("DEBUFF in time")
						Healium_PlayDebuffSound()
						Healium_LastDebuffSoundTime = now
					end
				end
			end
		end
	end
end

-- Update healium frame buttons, set texture, extra attributes and show/hide.
local function Healium_UpdateFrameButtons(frame)
	Healium_DEBUG("Update frame buttons for "..frame:GetName())
	if not frame.healiumButtons then return end
	local settings = Healium_GetSettings()
	for i, button in ipairs(frame.healiumButtons) do
		if settings and i <= #settings.spells then
			Healium_DEBUG("show button "..i.." "..frame:GetName())
			local spellSetting = settings.spells[i]
			local icon, name, kind
			if spellSetting.spellID then
				if Healium_IsSpellLearned(spellSetting.spellID) then
					kind = "spell"
					name, _, icon = GetSpellInfo(spellSetting.spellID)
					button.healiumSpellBookID = Healium_GetSpellBookID(name)
					button.healiumMacroName = nil
				end
			elseif spellSetting.macroName then
				if GetMacroIndexByName(spellSetting.macroName) > 0 then
					kind = "macro"
					icon = select(2,GetMacroInfo(spellSetting.macroName))
					name = spellSetting.macroName
					button.healiumSpellBookID = nil
					button.healiumMacroName = name
				end
			end
			-- if spellSetting.cures then
				-- Healium_CreateFlashFrame(button)
			-- end
			if kind and name and icon then
				button.texture:SetTexture(icon)
				button:SetAttribute("type",kind)
				button:SetAttribute(kind, name)
			else
				button.texture:SetTexture("Interface/Icons/INV_Misc_QuestionMark")
				button:SetAttribute("type","target") -- simply target if spell is not valid
			end
			button:Show()
		else
			Healium_DEBUG("hide button "..i.." "..frame:GetName())
			button.texture:SetTexture("Interface/Icons/INV_Misc_QuestionMark")
			button:Hide()
		end
	end
end

-- For each spell, get cooldown then loop among Healium Frames and set cooldown
local function Healium_UpdateCooldowns()
	Healium_DEBUG("Healium_UpdateCooldowns")
	local settings = Healium_GetSettings()
	if not settings then return end
	for index, spellSetting in ipairs(settings.spells) do
		local start, duration, enabled
		if spellSetting.spellID then
			start, duration, enabled = GetSpellCooldown(spellSetting.spellID)
		elseif spellSetting.macroName then
			local name = GetMacroSpell(spellSetting.macroName)
			if name then 
				start, duration, enabled = GetSpellCooldown(name)
			else
				enabled = false
			end
		end
		if start > 0 then
			Healium_ForEachMember(Healium_UpdateFrameCooldown, index, start, duration, enabled)
		end
	end
end

-- Color spell in blue if OOM
local function Healium_UpdateUsableSpells()
	Healium_DEBUG("Healium_UpdateUsableSpells")
	if not HealiumSettings.showNoMana then return end
	local settings = Healium_GetSettings()
	if not settings then return end
	for index, spellSetting in ipairs(settings.spells) do
		local noMana = false
		if spellSetting.spellID then 
			noMana = select(2, IsUsableSpell(spellSetting.spellID))
		elseif spellSetting.macroName then
			local macroID = GetMacroIndexByName(spellSetting.macroName)
			if macroID > 0 then
				local spellName = GetMacroSpell(macroID)
				noMana = select(2, IsUsableSpell(spellName))
			end
		end
		if noMana then
			Healium_ForEachMember(Healium_UpdateFrameColor, index, {0.5, 0.5, 1.0})
		end
	end
end

-- Change player's name's color if it has aggro or not
local function Healium_UpdateThread(self, event, unit)
	Healium_DEBUG("Healium_UpdateThread")
	if (self.unit ~= unit) or (unit == "target" or unit == "pet" or unit == "focus" or unit == "focustarget" or unit == "targettarget") then return end
	local threat = UnitThreatSituation(self.unit)
	if (threat and threat > 1) then
		--self.Name:SetTextColor(1,0.1,0.1)
		local r, g, b = GetThreatStatusColor(status)
		self.Name:SetTextColor(r, g, b)
	else
		self.Name:SetTextColor(1,1,1)
	end 
end

-- PostUpdateHealth, called after health bar has been updated
local function Healium_PostUpdateHeal(health, unit, min, max)
	Healium_DEBUG("Healium_PostUpdateHeal: "..(unit or "nil"))
	-- call normal raid post update heal
	T.PostUpdateHealthRaid(health, unit, min, max)

	local frame = health:GetParent()
	--local unit = frame.unit
	local settings = Healium_GetSettings()

	--Healium_DEBUG("Healium_PostUpdateHeal: "..frame:GetName().."  "..(unit or 'nil'))
	if not UnitIsConnected(unit) or UnitIsDead(unit) or UnitIsGhost(unit) then
		--Healium_DEBUG("->DISABLE")
		frame.healiumDisabled = true
		-- change healium buttons texture and reset buff/debuff
		if settings and frame.healiumButtons then
			--Healium_DEBUG("disable healium buttons")
			for index, spellSetting in ipairs(settings.spells) do
				local button = frame.healiumButtons[index]
				if ((UnitIsDead(unit) or UnitIsGhost(unit)) and (not spellSetting.rez or spellSetting.rez == false)) or not UnitIsConnected(unit) then
					--Healium_DEBUG("disable button "..button:GetName())
					-- --button.texture:SetVertexColor(1, 0.1, 0.1)
					-- --button:SetBackdropColor(1,0.1,0.1)
					-- --button:SetBackdropBorderColor(1,0.1,0.1)
					button.texture:SetVertexColor(1,0.1,0.1)
				end
			end
		end
		-- hide buff
		if frame.healiumBuffs then
			--Healium_DEBUG("disable healium buffs")
			for _, buff in ipairs(frame.healiumBuffs) do
				buff:Hide()
			end
		end
		-- if frame.healiumDebuffs then
			-- Healium_DEBUG("disable healium debuffs")
			-- for _, debuff in ipairs(frame.healiumDebuffs) do
				-- debuff:Hide()
			-- end
		-- end
	elseif frame.healiumDisabled then
		--Healium_DEBUG("DISABLED")
		if frame.healiumButtons then
			--Healium_DEBUG("enable healium buttons")
			for index, button in ipairs(frame.healiumButtons) do
				--Healium_DEBUG("enable button:"..button:GetName())
				button.texture:SetVertexColor(1,1,1)
			end
		end
		frame.healiumDisabled = false
	end
	local showPercentage = Getter(HealiumSettings.showPercentage, false)
	if showPercentage and min ~= max and UnitIsConnected(unit) and not UnitIsDead(unit) and not UnitIsGhost(unit) then
		local r, g, b = oUF.ColorGradient(min/max, 0.69, 0.31, 0.31, 0.65, 0.63, 0.35, 0.33, 0.59, 0.33)
		--health.value:SetText("|cff559655-"..ShortValueNegative(max-min).."|r")
		--health.value:SetFormattedText("|cff%02x%02x%02x-"..ShortValueNegative(max-min).."|r", r * 255, g * 255, b * 255)
		--health.value:SetFormattedText("|cffAF5050%d|r |cffD7BEA5-|r |cff%02x%02x%02x%d%%|r", min, r * 255, g * 255, b * 255, floor(min / max * 100))
		--health.value:SetFormattedText("|cff559655%d%%|r", floor(min / max * 100))
		health.value:SetFormattedText("|cff%02x%02x%02x%d%%|r", r * 255, g * 255, b * 255, floor(min / max * 100))
	end
end

-- Heal buttons tooltip
local function Healium_ButtonOnEnter(self)
	-- Heal tooltips are anchored to tukui tooltip
	local TukuiTooltipAnchor = _G["TukuiTooltipAnchor"]
	GameTooltip:SetOwner(TukuiTooltipAnchor, "ANCHOR_NONE")
	if self.healiumSpellBookID then
		GameTooltip:SetSpellBookItem(self.healiumSpellBookID, SpellBookFrame.bookType)
	elseif self.healiumMacroName then
		GameTooltip:AddLine("Macro: "..self.healiumMacroName)
	end
	local unit = SecureButton_GetUnit(self)
	if not UnitExists(unit) then return end
	local unitName = UnitName(unit)
	if (not unitName) then unitName = "-" end
	GameTooltip:AddLine("Target: |cFF00FF00"..unitName,1,1,1)
	GameTooltip:Show()
end

-- Debuff tooltip
local function Healium_DebuffOnEnter(self)
	--http://wow.go-hero.net/framexml/13164/TargetFrame.xml
	if ( self:GetCenter() > GetScreenWidth()/2 ) then
		GameTooltip:SetOwner(self, "ANCHOR_LEFT")
	else
		GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
	end
	GameTooltip:SetUnitDebuff(self.unit, self:GetID())
end

-- Buff tooltip
local function Healium_BuffOnEnter(self)
	--http://wow.go-hero.net/framexml/13164/TargetFrame.xml
	if ( self:GetCenter() > GetScreenWidth()/2 ) then
		GameTooltip:SetOwner(self, "ANCHOR_LEFT")
	else
		GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
	end
	GameTooltip:SetUnitBuff(self.unit, self:GetID())
end

-- Create heal buttons for a frame
local function Healium_CreateFrameButtons(frame)
	Healium_DEBUG("Healium_CreateFrameButtons")
	if not frame then return end
	if frame.healiumButtons then return end

	if InCombatLockdown() then
		tinsert(Healium_DelayedButtonsCreation, self)
		return
	end

	frame.healiumButtons = {}
	local settings = Healium_GetSettings()
	local spellSize = settings and settings.spellSize or frame:GetHeight()
	local spellSpacing = settings and settings.spellSpacing or 2
	for i = 1, Healium_MaxButtonCount, 1 do
		-- name
		local buttonName = frame:GetName().."_HealiumButton_"..i
		-- frame
		local button
		if i == 1 then
			button = CreateFrame("Button", buttonName, frame, "SecureActionButtonTemplate")
			button:CreatePanel("Default", spellSize, spellSize, "TOPLEFT", frame, "TOPRIGHT", spellSpacing, 0)
		else
			button = CreateFrame("Button", buttonName, frame, "SecureActionButtonTemplate")
			button:CreatePanel("Default", spellSize, spellSize, "TOPLEFT", frame.healiumButtons[i-1], "TOPRIGHT", spellSpacing, 0)
		end
		-- texture setup, texture icon is set in Healium_UpdateFrameButtons
		button.texture = button:CreateTexture(nil, "BORDER")
		button.texture:SetTexCoord(0.08, 0.92, 0.08, 0.92)
		button.texture:SetPoint("TOPLEFT", button ,"TOPLEFT", 0, 0)
		button.texture:SetPoint("BOTTOMRIGHT", button ,"BOTTOMRIGHT", 0, 0)
		button:SetPushedTexture("Interface/Buttons/UI-Quickslot-Depress")
		button:SetHighlightTexture("Interface/Buttons/ButtonHilight-Square")
		-- cooldown overlay
		button.cooldown = CreateFrame("Cooldown", "$parentCD", button, "CooldownFrameTemplate")
		button.cooldown:SetAllPoints(button.texture)
		-- click, attribute 'type' and 'spell' is set in Healium_UpdateFrameButtons
		button:RegisterForClicks("AnyUp")
		button:SetAttribute("useparent-unit","true")
		button:SetAttribute("*unit2", "target")
		-- tooltip
		if HealiumSettings.showButtonTooltip then
			button:SetScript("OnEnter", Healium_ButtonOnEnter)
			button:SetScript("OnLeave", function(frame) 
				GameTooltip:Hide()
			end)
		end
		-- hide
		button:Hide()
		-- save button
		tinsert(frame.healiumButtons, button)
	end
end

-- Create debuffs for a frame
local function Healium_CreateFrameDebuffs(frame)
	Healium_DEBUG("Healium_CreateFrameDebuffs")
	if not frame then return end
	if frame.healiumDebuffs then return end

	frame.healiumDebuffs = {}
	local settings = Healium_GetSettings()
	local debuffSize = settings and settings.debuffSize or frame:GetHeight()
	local debuffSpacing = settings and settings.debuffSpacing or 2
	for i = 1, Healium_MaxDebuffCount, 1 do
		--Healium_DEBUG("Create debuff "..i)
		-- name
		local debuffName = frame:GetName().."_HealiumDebuff_"..i
		-- frame
		local debuff
		if i == 1 then
			--debuff = CreateFrame("Frame", debuffName, frame, "TargetDebuffFrameTemplate")
			debuff = CreateFrame("Frame", debuffName, frame)
			debuff:CreatePanel("Default", debuffSize, debuffSize, "TOPLEFT", frame, "TOPRIGHT", debuffSpacing, 0)
		else
			--debuff = CreateFrame("Frame", debuffName, frame, "TargetDebuffFrameTemplate")
			debuff = CreateFrame("Frame", debuffName, frame)
			debuff:CreatePanel("Default", debuffSize, debuffSize, "TOPLEFT", frame.healiumDebuffs[i-1], "TOPRIGHT", debuffSpacing, 0)
		end
		-- icon
		debuff.icon = debuff:CreateTexture(nil, "ARTWORK")
		debuff.icon:Point("TOPLEFT", 2, -2)
		debuff.icon:Point("BOTTOMRIGHT", -2, 2)
		debuff.icon:SetTexCoord(0.1, 0.9, 0.1, 0.9)
		-- cooldown
		debuff.cooldown = CreateFrame("Cooldown", "$parentCD", debuff, "CooldownFrameTemplate")
		debuff.cooldown:SetAllPoints(debuff.icon)
		debuff.cooldown:SetReverse()
		-- count
		debuff.count = debuff:CreateFontString("$parentCount", "OVERLAY")
		debuff.count:SetFont(C["media"].uffont, 14, "OUTLINE")
		debuff.count:Point("BOTTOMRIGHT", 1, -1)
		debuff.count:SetJustifyH("CENTER")
		-- tooltip
		if HealiumSettings.showBuffDebuffTooltip then
			debuff:SetScript("OnEnter", Healium_DebuffOnEnter)
			debuff:SetScript("OnLeave", function(frame) 
				GameTooltip:Hide()
			end)
		end
		-- hide
		debuff:Hide()
		-- save debuff
		tinsert(frame.healiumDebuffs, debuff)
	end
end

-- Create buff for a frame
local function Healium_CreateFrameBuffs(frame)
	Healium_DEBUG("Healium_CreateFrameBuffs")
	if not frame then return end
	if frame.healiumBuffs then return end

	frame.healiumBuffs = {}
	local buffSize = settings and settings.buffSize or frame:GetHeight()
	local buffSpacing = settings and settings.buffSpacing or 2
	for i = 1, Healium_MaxBuffCount, 1 do
		local buffName = frame:GetName().."_HealiumBuff_"..i
		local buff
		if i == 1 then
			--buff = CreateFrame("Frame", buffName, frame, "TargetBuffFrameTemplate")
			buff = CreateFrame("Frame", buffName, frame)
			buff:CreatePanel("Default", buffSize, buffSize, "TOPRIGHT", frame, "TOPLEFT", -buffSpacing, 0)
		else
			--buff = CreateFrame("Frame", buffName, frame, "TargetBuffFrameTemplate")
			buff = CreateFrame("Frame", buffName, frame)
			buff:CreatePanel("Default", buffSize, buffSize, "TOPRIGHT", frame.healiumBuffs[i-1], "TOPLEFT", -buffSpacing, 0)
		end
		-- icon
		buff.icon = buff:CreateTexture(nil, "ARTWORK")
		buff.icon:Point("TOPLEFT", 2, -2)
		buff.icon:Point("BOTTOMRIGHT", -2, 2)
		buff.icon:SetTexCoord(0.1, 0.9, 0.1, 0.9)
		-- cooldown
		buff.cooldown = CreateFrame("Cooldown", "$parentCD", buff, "CooldownFrameTemplate")
		buff.cooldown:SetAllPoints(buff.icon)
		buff.cooldown:SetReverse()
		-- count
		buff.count = buff:CreateFontString("$parentCount", "OVERLAY")
		buff.count:SetFont(C["media"].uffont, 14, "OUTLINE")
		buff.count:Point("BOTTOMRIGHT", 1, -1)
		buff.count:SetJustifyH("CENTER")
		-- tooltip
		if HealiumSettings.showBuffDebuffTooltip then
			buff:SetScript("OnEnter", Healium_BuffOnEnter)
			buff:SetScript("OnLeave", function(frame) 
				GameTooltip:Hide()
			end)
		end
		-- hide
		buff:Hide()
		-- save buff
		tinsert(frame.healiumBuffs, buff)
	end
end

-- Create delayed frames
local function Healium_CreateDelayedButtons()
	Healium_DEBUG("Healium_CreateDelayedButtons")
	if InCombatLockdown() then return false end
	if not Healium_DelayedButtonsCreation or #Healium_DelayedButtonsCreation == 0 then return false end
	for _, frame in ipairs(Healium_DelayedButtonsCreation) do
		Healium_DEBUG("Delayed frame creation for "..frame:GetName())
		if not frame.healiumButtons then
			Healium_CreateFrameButtons(frame)
		else
			Healium_DEBUG("Frame already created for "..frame:GetName())
		end
	end
	Healium_DelayedButtonsCreation = {}
	return true
end

-- Handle events for Healium features
local function Healium_OnEvent(self, event, ...)
	local arg1 = select(1, ...)
	local arg2 = select(2, ...)
	local arg3 = select(3, ...)

	Healium_DEBUG("Event: "..event)

	if event == "ADDON_LOADED" then
		Healium_DEBUG("ADDON_LOADED: "..arg1)
	end

	if event == "PLAYER_ENTERING_WORLD" then
		Healium_ForEachMember(Healium_UpdateFrameButtons)
		Healium_ForEachMember(Healium_UpdateFrameDebuffsPosition)
		Healium_ForEachMember(Healium_UpdateFrameBuffsDebuffsSpecialSpells)
	end

	if event == "PARTY_MEMBERS_CHANGED" or event == "RAID_ROSTER_UPDATE" then
		Healium_ForEachMember(Healium_UpdateFrameButtons)
		Healium_ForEachMember(Healium_UpdateFrameDebuffsPosition)
		Healium_ForEachMember(Healium_UpdateFrameBuffsDebuffsSpecialSpells)
	end

	if event == "PLAYER_REGEN_ENABLED" then
		local created = Healium_CreateDelayedButtons()
		if created then
			Healium_ForEachMember(Healium_UpdateFrameButtons)
		end
	end

	if event == "PLAYER_TALENT_UPDATE" then
		--NOT NEEDED Healium_ForEachMember(Healium_CreateFrameButtons) -- Player may switch from a spec without settings to a spec with settings
		Healium_ForEachMember(Healium_UpdateFrameButtons)
		Healium_ForEachMember(Healium_UpdateFrameDebuffsPosition)
		Healium_ForEachMember(Healium_UpdateFrameBuffsDebuffsSpecialSpells)
	end

	if event == "SPELL_UPDATE_COOLDOWN" then -- TODO: use SPELL_UPDATE_USABLE instead ?
		Healium_UpdateCooldowns()
	end

	if event == "UNIT_AURA" then
		local frame = Healium_GetFrameFromUnit(arg1) -- Get frame from unit
		if frame then Healium_UpdateFrameBuffsDebuffsSpecialSpells(frame) end -- Update buff/debuff only for unit
	end

	if event == "UNIT_POWER" and arg1 == "player" then
		Healium_UpdateUsableSpells()
	end
end

-------------------------------------------------------------------
-- Unitframe creation
local function Shared(self, unit)
	Healium_DEBUG("Shared: "..(unit or "nil").."  "..self:GetName())

	self.colors = T.oUF_colors
	self:RegisterForClicks("AnyUp")
	self:SetScript('OnEnter', UnitFrame_OnEnter)
	self:SetScript('OnLeave', UnitFrame_OnLeave)

	self.menu = T.SpawnMenu

	self:SetBackdrop({bgFile = C["media"].blank, insets = {top = -T.mult, left = -T.mult, bottom = -T.mult, right = -T.mult}})
	self:SetBackdropColor(0.1, 0.1, 0.1)

	local health = CreateFrame('StatusBar', nil, self)
	health:SetPoint("TOPLEFT")
	health:SetPoint("TOPRIGHT")
	health:Height(27*T.raidscale)
	health:SetStatusBarTexture(C["media"].normTex)
	self.Health = health

	health.bg = health:CreateTexture(nil, 'BORDER')
	health.bg:SetAllPoints(health)
	health.bg:SetTexture(C["media"].normTex)
	health.bg:SetTexture(0.3, 0.3, 0.3)
	health.bg.multiplier = 0.3
	self.Health.bg = health.bg

	health.value = health:CreateFontString(nil, "OVERLAY")
	health.value:SetPoint("RIGHT", health, -3, 1)
	health.value:SetFont(C["media"].uffont, 12*T.raidscale, "THINOUTLINE")
	health.value:SetTextColor(1,1,1)
	health.value:SetShadowOffset(1, -1)
	self.Health.value = health.value

	health.PostUpdate = Healium_PostUpdateHeal
	health.frequentUpdates = true

	if C.unitframes.unicolor == true then
		health.colorDisconnected = false
		health.colorClass = false
		health:SetStatusBarColor(.3, .3, .3, 1)
		health.bg:SetVertexColor(.1, .1, .1, 1)
	else
		health.colorDisconnected = true
		health.colorClass = true
		health.colorReaction = true
	end

	local power = CreateFrame("StatusBar", nil, self)
	power:Height(4*T.raidscale)
	power:Point("TOPLEFT", health, "BOTTOMLEFT", 0, -1)
	power:Point("TOPRIGHT", health, "BOTTOMRIGHT", 0, -1)
	power:SetStatusBarTexture(C["media"].normTex)
	self.Power = power
	
	power.frequentUpdates = true
	power.colorDisconnected = true

	power.bg = self.Power:CreateTexture(nil, "BORDER")
	power.bg:SetAllPoints(power)
	power.bg:SetTexture(C["media"].normTex)
	power.bg:SetAlpha(1)
	power.bg.multiplier = 0.4
	self.Power.bg = power.bg

	if C.unitframes.unicolor == true then
		power.colorClass = true
		power.bg.multiplier = 0.1
	else
		power.colorPower = true
	end

	local name = health:CreateFontString(nil, "OVERLAY")
    name:SetPoint("LEFT", health, 3, 0)
	name:SetFont(C["media"].uffont, 12*T.raidscale, "THINOUTLINE")
	name:SetShadowOffset(1, -1)
	self:Tag(name, "[Tukui:namemedium]")
	self.Name = name

    local leader = health:CreateTexture(nil, "OVERLAY")
    leader:Height(12*T.raidscale)
    leader:Width(12*T.raidscale)
    leader:SetPoint("TOPLEFT", 0, 6)
	self.Leader = leader

    local LFDRole = health:CreateTexture(nil, "OVERLAY")
    LFDRole:Height(6*T.raidscale)
    LFDRole:Width(6*T.raidscale)
	LFDRole:Point("TOPRIGHT", -2, -2)
	LFDRole:SetTexture("Interface\\AddOns\\Tukui\\medias\\textures\\lfdicons.blp")
	self.LFDRole = LFDRole

    local MasterLooter = health:CreateTexture(nil, "OVERLAY")
    MasterLooter:Height(12*T.raidscale)
    MasterLooter:Width(12*T.raidscale)
	self.MasterLooter = MasterLooter
    self:RegisterEvent("PARTY_LEADER_CHANGED", T.MLAnchorUpdate)
    self:RegisterEvent("PARTY_MEMBERS_CHANGED", T.MLAnchorUpdate)

	if C["unitframes"].aggro == true then
		table.insert(self.__elements, Healium_UpdateThread)
		self:RegisterEvent('PLAYER_TARGET_CHANGED', Healium_UpdateThread)
		self:RegisterEvent('UNIT_THREAT_LIST_UPDATE', Healium_UpdateThread)
		self:RegisterEvent('UNIT_THREAT_SITUATION_UPDATE', Healium_UpdateThread)
    end

	if C["unitframes"].showsymbols == true then
		local RaidIcon = health:CreateTexture(nil, 'OVERLAY')
		RaidIcon:Height(18*T.raidscale)
		RaidIcon:Width(18*T.raidscale)
		RaidIcon:SetPoint('CENTER', self, 'TOP')
		RaidIcon:SetTexture("Interface\\AddOns\\Tukui\\medias\\textures\\raidicons.blp") -- thx hankthetank for texture
		self.RaidIcon = RaidIcon
	end

	local ReadyCheck = self.Power:CreateTexture(nil, "OVERLAY")
	ReadyCheck:Height(12*T.raidscale)
	ReadyCheck:Width(12*T.raidscale)
	ReadyCheck:SetPoint('CENTER')
	self.ReadyCheck = ReadyCheck

	if C["unitframes"].showrange == true then
		local range = {insideAlpha = 1, outsideAlpha = C["unitframes"].raidalphaoor}
		self.Range = range
	end

	if C["unitframes"].showsmooth == true then
		health.Smooth = true
		power.Smooth = true
	end

	if C["unitframes"].healcomm then
		local mhpb = CreateFrame('StatusBar', nil, self.Health)
		mhpb:SetPoint('TOPLEFT', self.Health:GetStatusBarTexture(), 'TOPRIGHT', 0, 0)
		mhpb:SetPoint('BOTTOMLEFT', self.Health:GetStatusBarTexture(), 'BOTTOMRIGHT', 0, 0)
		mhpb:SetWidth(150*T.raidscale)
		mhpb:SetStatusBarTexture(C["media"].normTex)
		mhpb:SetStatusBarColor(0, 1, 0.5, 0.25)

		local ohpb = CreateFrame('StatusBar', nil, self.Health)
		ohpb:SetPoint('TOPLEFT', mhpb:GetStatusBarTexture(), 'TOPRIGHT', 0, 0)
		ohpb:SetPoint('BOTTOMLEFT', mhpb:GetStatusBarTexture(), 'BOTTOMRIGHT', 0, 0)
		ohpb:SetWidth(150*T.raidscale)
		ohpb:SetStatusBarTexture(C["media"].normTex)
		ohpb:SetStatusBarColor(0, 1, 0, 0.25)

		self.HealPrediction = {
			myBar = mhpb,
			otherBar = ohpb,
			maxOverflow = 1,
		}
	end

	-- heal buttons
	Healium_CreateFrameButtons(self)

	-- healium debuffs
	Healium_CreateFrameDebuffs(self)

	-- healium buffs
	Healium_CreateFrameBuffs(self)

	-- Update healium buttons visibility, icon and attributes
	Healium_UpdateFrameButtons(self)
	-- Update debuff position
	Healium_UpdateFrameDebuffsPosition(self)
	-- Update buff/debuff/special spells
	--Healium_UpdateFrameBuffsDebuffsSpecialSpells(self) -- unit not yet set, unit passed as argument is "raid" instead of player or party1 or...

	-- Not disabled
	self.healiumDisabled = false

	-- Save frame to healium frame list
	tinsert(Healium_Frames, self)

	-- Show frame
	self:Show()

	return self
end

----------------------------------------------------------
-- Main

local playerRaid = nil
local petRaid = nil

oUF:RegisterStyle('TukuiHealiumR01R25', Shared)

-- Players
oUF:Factory(function(self)
	oUF:SetActiveStyle("TukuiHealiumR01R25")

	local unitframeWidth = HealiumSettings and HealiumSettings.unitframeWidth or 120
	local unitframeHeight = HealiumSettings and HealiumSettings.unitframeHeight or 28
	playerRaid = self:SpawnHeader("oUF_TukuiHealiumRaid0125", nil, "custom [@raid26,exists] hide;show", 
	'oUF-initialConfigFunction', [[
		local header = self:GetParent()
		self:SetWidth(header:GetAttribute('initial-width'))
		self:SetHeight(header:GetAttribute('initial-height'))
	]],
	'initial-width', T.Scale(unitframeWidth*T.raidscale),
	'initial-height', T.Scale(unitframeHeight*T.raidscale),
	"showSolo", C["unitframes"].showsolo,
	"showParty", true, 
	"showPlayer", C["unitframes"].showplayerinparty, 
	"showRaid", true, 
	"groupFilter", "1,2,3,4,5,6,7,8", 
	"groupingOrder", "1,2,3,4,5,6,7,8", 
	"groupBy", "GROUP", 
	"yOffset", T.Scale(-4))
	playerRaid:SetPoint("TOPLEFT", UIParent, "TOPLEFT", 150, -300*T.raidscale)
	
	-- local pets = {}
	-- if not AdvancedPetFrames then
		-- pets[1] = oUF:Spawn('partypet1', 'oUF_TukuiPartyPet1') 
		-- pets[1]:SetPoint('TOPLEFT', raid, 'TOPLEFT', 0, -240*T.raidscale)
		-- --pets[1]:SetPoint('CENTER', UIParent, 'CENTER', 0, 0)
		-- pets[1]:Size(150*T.raidscale, 32*T.raidscale)
		-- for i = 2, 4 do 
			-- pets[i] = oUF:Spawn('partypet'..i, 'oUF_TukuiPartyPet'..i) 
			-- pets[i]:SetPoint('TOP', pets[i-1], 'BOTTOM', 0, -8)
			-- pets[i]:Size(150*T.raidscale, 32*T.raidscale)
		-- end
	-- end

	-- local RaidMove = CreateFrame("Frame")
	-- RaidMove:RegisterEvent("PLAYER_ENTERING_WORLD")
	-- RaidMove:RegisterEvent("RAID_ROSTER_UPDATE")
	-- RaidMove:RegisterEvent("PARTY_LEADER_CHANGED")
	-- RaidMove:RegisterEvent("PARTY_MEMBERS_CHANGED")
	-- RaidMove:SetScript("OnEvent", function(self)
		-- if InCombatLockdown() then
			-- self:RegisterEvent("PLAYER_REGEN_ENABLED")
		-- else
			-- self:UnregisterEvent("PLAYER_REGEN_ENABLED")
			-- local numraid = GetNumRaidMembers()
			-- local numparty = GetNumPartyMembers()
			-- if numparty > 0 and numraid == 0 or numraid > 0 and numraid <= 5 then
				-- playerRaid:SetPoint("TOPLEFT", UIParent, "TOPLEFT", 150, -300*T.raidscale)
				-- --for i,v in ipairs(pets) do v:Enable() end
			-- elseif numraid > 5 and numraid <= 10 then
				-- playerRaid:SetPoint('TOPLEFT', UIParent, 150, -260*T.raidscale)
				-- --for i,v in ipairs(pets) do v:Disable() end
				-- --for i,v in ipairs(pets) do v:Enable() end
			-- elseif numraid > 10 and numraid <= 15 then
				-- playerRaid:SetPoint('TOPLEFT', UIParent, 150, -170*T.raidscale)
				-- --for i,v in ipairs(pets) do v:Disable() end
				-- --for i,v in ipairs(pets) do v:Enable() end
			-- elseif numraid > 15 then
				-- --for i,v in ipairs(pets) do v:Disable() end
				-- --for i,v in ipairs(pets) do v:Enable() end
			-- end
		-- end
	-- end)
end)

-- Pets
oUF:Factory(function(self)
	oUF:SetActiveStyle("TukuiHealiumR01R25")

	local unitframeWidth = HealiumSettings and HealiumSettings.unitframeWidth or 120
	local unitframeHeight = HealiumSettings and HealiumSettings.unitframeHeight or 28
	petRaid = self:SpawnHeader("oUF_TukuiHealiumRaidPet0125", "SecureGroupPetHeaderTemplate", "custom [@raid26,exists] hide;show",
		'oUF-initialConfigFunction', [[
			local header = self:GetParent()
			self:SetWidth(header:GetAttribute('initial-width'))
			self:SetHeight(header:GetAttribute('initial-height'))
		]],
		'initial-width', T.Scale(unitframeWidth*T.raidscale),--T.Scale(66*C["unitframes"].gridscale*T.raidscale),
		'initial-height', T.Scale(unitframeHeight*T.raidscale),--T.Scale(50*C["unitframes"].gridscale*T.raidscale),
		"showSolo", C["unitframes"].showsolo,
		"showParty", true,
		"showPlayer", C["unitframes"].showplayerinparty,
		"showRaid", true,
		--"xoffset", T.Scale(3),
		"yOffset", T.Scale(-3),
		--"point", "LEFT",
		"groupFilter", "1,2,3,4,5,6,7,8",
		"groupingOrder", "1,2,3,4,5,6,7,8",
		"groupBy", "GROUP",
		--"maxColumns", 8,
		"unitsPerColumn", 5,
		--"columnSpacing", T.Scale(3),
		--"columnAnchorPoint", "TOP",
		"filterOnPet", true,
		"sortMethod", "NAME"
	)
	--raid:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
	--raid:SetPoint("TOPLEFT", UIParent, "TOPLEFT", 200, -400)
	petRaid:SetPoint("TOPLEFT", playerRaid, "BOTTOMLEFT", 0, -50)
end)

local healiumEventHandler = CreateFrame("Frame")
healiumEventHandler:RegisterEvent("PLAYER_ENTERING_WORLD")
healiumEventHandler:RegisterEvent("ADDON_LOADED")
healiumEventHandler:RegisterEvent("RAID_ROSTER_UPDATE")
healiumEventHandler:RegisterEvent("PARTY_MEMBERS_CHANGED")
healiumEventHandler:RegisterEvent("PLAYER_REGEN_ENABLED")
healiumEventHandler:RegisterEvent("PLAYER_TALENT_UPDATE")
healiumEventHandler:RegisterEvent("SPELL_UPDATE_COOLDOWN")
healiumEventHandler:RegisterEvent("UNIT_AURA")
healiumEventHandler:RegisterEvent("UNIT_POWER")
healiumEventHandler:SetScript("OnEvent", Healium_OnEvent)

-- Check spells
local settings = Healium_GetSettings()
if settings then
	for _, spellSetting in ipairs(settings.spells) do
		if spellSetting.spellID and not Healium_IsSpellLearned(spellSetting.spellID) then
			Healium_WARNING("Spell "..spellSetting.spellID.." NOT learned")
		elseif spellSetting.macroName and GetMacroIndexByName(spellSetting.macroName) == 0 then
			Healium_WARNING("Macro "..macroName.." NOT found")
		end
	end
end