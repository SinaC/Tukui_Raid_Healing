-- TESTED
-- buff (must implemented move tukui raid frame to test) -> OK
-- debuff -> OK
-- cd -> OK
-- button -> OK
-- cure + dispel -> OK
-- incoming heal ==> C["unitframes"].healcomm
-- disable tukui raid debuff/buff/hots   see \Tukui_Raid_Healing\oUF_hTukz_Raid01_15.lua:139   frame.Debuffs = nil  OK
-- mana ==> included in oUF  -> OK
-- special spells (swiftmend allowed if rejuv or regrowth on member) (see settings) -> OK
-- change alpha when dead/ghost or disconnected -> OK if dead/ghost/disconnected
-- HealiumEnabled -> OK
-- avoid using _G[] to get raid frame, use a local list -> OK

-- TO TEST
-- aggro ==> C["unitframes"].aggro
-- delayed healium buttons creation while in combat (call HealiumCreateFrameButtons when out of combat)
-- spell/buff/debuff size/spacing
-- buff/debuff are not shown when connecting  this is because unit is not yet set when Shared is called (unit = raid instead of player1)   SEEMS TO WORK BUT SHOULD BE RETESTED

-- TODO:
-- range: Tukui\Tukui\modules\unitframes\core\oUF\elements\range.lua
-- spell/buff/debuff tooltip (see Healium_HealButton_OnEnter in HealiumHealButton)
-- spell must be learned to appear in button (question-mark if not learned)
--		http://www.wowwiki.com/API_GetSpellBookItemInfo
--		http://www.wowwiki.com/API_GetSpellBookItemInfo
--		http://www.wowwiki.com/API_IsUsableSpell
--		local name = GetSpellInfo(spellID)		--> http://www.wowwiki.com/API_GetSpellInfo
--		local isLearned = GetSpellInfo(name)	--> http://www.wowwiki.com/API_GetSpellInfo
-- use spec name instead of spec ID in settings => DOESNT WORK spec name is localized

local ADDON_NAME, ns = ...
local oUF = oUFTukui or oUF
assert(oUF, "Tukui was unable to locate oUF install.")

ns._Objects = {}
ns._Headers = {}

local T, C, L = unpack(Tukui) -- Import: T - functions, constants, variables; C - config; L - locales
if not C["unitframes"].enable == true or C["unitframes"].gridonly == true then return end

-------------------------------------------------------
-- Constants
-------------------------------------------------------
local font2 = C["media"].uffont
local font1 = C["media"].font
local normTex = C["media"].normTex
local HealiumDebug = true
local MaxButtonCount = 10
local MaxDebuffCount = 8
local MaxBuffCount = 6

-------------------------------------------------------
-- Variables
-------------------------------------------------------
local HealiumDelayedButtonsCreation = {}
local HealiumFrames = {}

-------------------------------------------------------
-- Helpers
-------------------------------------------------------
local function ERROR(line)
	print("|CFFFF0000TH|r:"..line)
end

local function WARNING(line)
	print("|CFF00FFFFTH|r:"..line)
end

local function DEBUG(line)
	if not HealiumDebug or HealiumDebug == false then return end
	print("|CFF00FF00TH|r:"..line)
end

-- Enabled ?
local function HealiumEnabled()
	if not HealiumSettings.enabled or HealiumSettings.enabled == false then return false end
	if not HealiumSettings[T.myclass] then return false end
	return true
end

-- Return settings for current spec
local function GetHealiumSettings()
	if not HealiumEnabled() then return end
	local ptt = GetPrimaryTalentTree()
	if not ptt then return end
	-- local settings
	-- if ptt > 0 then
		-- -- search by name
		-- local _, name = GetTalentTabInfo(ptt)
		-- DEBUG("GetHealiumSettings spec name:"..name)
		-- settings = HealiumSettings[T.myclass][name]
	-- else
		-- ptt = 1
	-- end
	-- -- search by id
	-- if not settings then
		-- settings = HealiumSettings[T.myclass][ptt]
	-- end
	--return settings
	return HealiumSettings[T.myclass][ptt]
end

-- Return number of person in the party/raid
local function GetNumMembers()
	local numparty = GetNumPartyMembers() -- excluding self
	local numraid = GetNumRaidMembers() -- including self
	-- --	if not in raid
	-- --		if alone in the party, return 0
	-- --		else, return numparty+1
	-- --	else, return numraid
	-- return numraid == 0 and (numparty > 0 and numparty+1 or numparty) or numraid
	return numraid == 0 and numparty + (C["unitframes"].showsolo and 1 or 0) or numraid
end

-- Get frame from unit
local function GetFrameFromUnit(unit)
	-- -- players
	-- local numMembers = GetNumMembers()
	-- for i = 1, numMembers, 1 do
		-- local frameName = "oUF_TukuiHealiumRaid0115UnitButton"..i
		-- local frame = _G[frameName]
		-- if frame and frame:IsShown() then
			-- if frame.unit == unit then
				-- return frame
			-- end
		-- else
			-- --DEBUG("GetFrameFromUnit: Raid Frame:"..frameName.." not found or hidden")
		-- end
	-- end
	-- -- -- pets
	-- -- for i = 1, 40, 1 do
		-- -- local frameName = "oUF_TukuiPartyPet"..i
		-- -- local frame = _G[frameName]
		-- -- if frame then
			-- -- if frame.unit == unit then
				-- -- return frame
			-- -- end
		-- -- else
			-- -- break
		-- -- end
	-- -- end
	-- return
	for _, frame in ipairs(HealiumFrames) do
		--DEBUG("GetFrameFromUnit:"..frame:GetName().."  "..(frame.unit or 'nil').."  "..(frame:IsShown() and 'shown' or 'hidden'))
		if frame and frame:IsShown() and frame.unit == unit then return frame end
	end
	return nil
end

-- Loop among every members in party/raid and call a function
local function ForEachMember(fct, ...)
	-- -- players
	-- local numMembers = GetNumMembers()
	-- for i = 1, numMembers, 1 do
		-- local frameName = "oUF_TukuiHealiumRaid0115UnitButton"..i
		-- local frame = _G[frameName]
		-- if frame and frame:IsShown() then
			-- fct(frame, ...)
		-- else
			-- --DEBUG("ForEachMember Raid Frame:"..frameName.." not found or hidden")
		-- end
	-- end
	-- -- -- pets
	-- -- for i = 1, 40, 1 do
		-- -- local frameName = "oUF_TukuiPartyPet"..i
		-- -- local frame = _G[frameName]
		-- -- if frame then
			-- -- fct(frame, ...)
		-- -- else
			-- -- break
		-- -- end
	-- -- end
	for _, frame in ipairs(HealiumFrames) do
		--DEBUG("ForEachMember:"..frame:GetName().."  "..(frame.unit or 'nil').."  "..(frame:IsShown() and 'shown' or 'hidden'))
		if frame and frame:IsShown() then
			fct(frame, ...)
		end
	end
end

-------------------------------------------------------
-- Healium functions
-------------------------------------------------------
-- Update healium button cooldown
local function HealiumUpdateFrameCooldown(frame, index, start, duration, enabled)
	if not HealiumEnabled() then return end
	--DEBUG("frame:"..(frame and frame:GetName() or "nil").." index:"..(index or "nil").." start:"..(start or "nil").." duration:"..(duration or "nil").." enabled:"..(enabled or "nil"))
	local button = frame.healiumButtons[index]
	--DEBUG("button:"..(button and button:GetName() or "nil").." cooldown:"..(button.cooldown and "ok" or "nil"))
	CooldownFrame_SetTimer(button.cooldown, start, duration, enabled)
end

-- Update healium frame debuff position
local function HealiumUpdateFrameDebuffsPosition(frame)
	if not HealiumEnabled() then return end
	--DEBUG("Update debuff position for "..frame:GetName())
	if not frame.healiumDebuffs then return end
	local settings = GetHealiumSettings()
	local lastButton = frame.healiumButtons[#settings.spells]
	local firstDebuff = frame.healiumDebuffs[1]
	--DEBUG("lastButton: "..lastButton:GetName().."  firstDebuff: "..firstDebuff:GetName())
	local debuffSpacing = settings and settings.debuffSpacing or frame:GetHeight()
	firstDebuff:ClearAllPoints()
	firstDebuff:Point("TOPLEFT", lastButton, "TOPRIGHT", debuffSpacing, 0)
end

-- Update healium frame buff/debuff and special spells
local function HealiumUpdateFrameBuffsDebuffsSpecialSpells(frame)
	if not HealiumEnabled() then return end
	local settings = GetHealiumSettings()
	local unit = frame.unit

	DEBUG("HealiumUpdateFrameBuffsDebuffsSpecialSpells: frame: "..frame:GetName().." unit: "..(unit or "nil"))
	
	if not unit then return end

	-- buff and buttons are not modified if unit is disabled (dead, ghost or disconnected)
	-- debuff are modified if unit is disabled

	-- reset vertex, border and backdrop color
	if frame.healiumButtons and not frame.healiumDisabled then
		DEBUG("---- reset vertex, border and backdrop color")
		for index, button in ipairs(frame.healiumButtons) do
			button.texture:SetVertexColor(1, 1, 1)
			button:SetBackdropColor(0.6, 0.6, 0.6)
			button:SetBackdropBorderColor(0.1, 0.1, 0.1)
		end
	end

	-- buff
	local buffs = {}
	if frame.healiumBuffs and not frame.healiumDisabled then
		local buffIndex = 1
		for i = 1, 100, 1 do
			-- get buff
			name, _, icon, count, _, duration, expirationTime, _, _, _, spellID = UnitAura(unit, i, "PLAYER|HELPFUL")
			if not name then break end
			tinsert(buffs, spellID)
			-- is buff casted by player and in spell list?
			local found = false
			for index, spellSetting in ipairs(settings.spells) do
				if spellSetting.spellID and spellSetting.spellID == spellID then
					found = true
				elseif spellSetting.macroName then
					local spellName = GetMacroSpell(spellSetting.macroName)
					if spellName == name then
						found = true
					end
				end
			end
			if found then
				-- buff casted by player and in spell list
				-- id, unit and texture
				local buff = frame.healiumBuffs[buffIndex]
				buff:SetID(i)
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
				if buffIndex > MaxBuffCount then
					WARNING("Too many buff for "..frame:GetName().." "..unit)
					break
				end
			end
		end
		for i = buffIndex, MaxBuffCount, 1 do
			-- hide remainder buff
			local buff = frame.healiumBuffs[buffIndex]
			buff:Hide()
		end
	end

	-- debuff
	local debuffs = {}
	if frame.healiumDebuffs then
		local debuffIndex = 1
		for i = 1, 100, 1 do
			-- get debuff
			local name, _, icon, count, debuffType, duration, expirationTime, _, _, _, spellID = UnitDebuff(unit, i) 
			if not name then break end
			--debuffType = "Curse" -- TODO: remove
			tinsert(debuffs, { spellID, debuffType } )
			-- is debuff blacklisted?
			local filtered = false
			if HealiumSettings.debuffBlacklist then
				for _, item in ipairs(HealiumSettings.debuffBlacklist) do
					if item == spellID then
						filtered = true
						break
					end
				end
			end
			if not filtered then
				-- debuff not blacklisted
				local debuff = frame.healiumDebuffs[debuffIndex]
				-- id, unit and texture
				debuff:SetID(i)
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
				-- dispel and debuff border
				local debuffColor = debuffType and DebuffTypeColor[debuffType] or DebuffTypeColor["none"]
				--DEBUG("debuffType: "..(debuffType or 'nil').."  debuffColor: "..(debuffColor and debuffColor.r or 'nil')..","..(debuffColor and debuffColor.g or 'nil')..","..(debuffColor and debuffColor.b or 'nil'))
				debuff:SetBackdropBorderColor(debuffColor.r, debuffColor.g, debuffColor.b)
				-- show
				debuff:Show()
				-- next debuff
				debuffIndex = debuffIndex + 1
				if debuffIndex > MaxDebuffCount then
					WARNING("Too many debuff for "..frame:GetName().." "..unit)
					break
				end
			end
		end
		for i = debuffIndex, MaxDebuffCount, 1 do
			-- hide remainder debuff
			local debuff = frame.healiumDebuffs[debuffIndex]
			debuff:Hide()
		end
	end

	-- special spells and color dispel button debuffs
	-- is buff or debuff a prereq to enable/disable a spell
	if frame.healiumButtons and not frame.healiumDisabled then
		for index, spellSetting in ipairs(settings.spells) do
			local button = frame.healiumButtons[index]
			if spellSetting.buffs then
				--DEBUG("searching buff prereq for "..spellSetting.spellID)
				local prereqBuffFound = false
				for _, prereqBuffSpellID in ipairs(spellSetting.buffs) do
					--DEBUG("buff prereq for "..spellSetting.spellID.." "..prereqBuffSpellID)
					for _, buffSpellID in pairs(buffs) do
						--DEBUG("buff on unit "..buffSpellID)
						if buffSpellID == prereqBuffSpellID then
							--DEBUG("PREREQ: "..prereqBuffSpellID.." is a buff prereq for "..spellSetting.spellID.." "..button:GetName())
							prereqBuffFound = true
							break
						end
					end
					if prereqBuffFound then break end
				end
				if prereqBuffFound == false then
					--DEBUG("PREREQ: BUFF for "..spellSetting.spellID.." NOT FOUND")
					button.texture:SetVertexColor(0.4, 0.4, 0.4)
				end
			end
			if spellSetting.debuffs then
				--DEBUG("searching buff prereq for "..spellSetting.spellID)
				local prereqDebuffFound = false
				for _, prereqDebuffSpellID in ipairs(spellSetting.debuffs) do
					--DEBUG("buff prereq for "..spellSetting.spellID.." "..prereqDebuffSpellID)
					for _, debuff in ipairs(debuffs) do
						local debuffSpellID = debuff[1]
						--DEBUG("debuff on unit "..debuffSpellID)
						if debuffSpellID == prereqDebuffSpellID then
							--DEBUG("PREREQ: "..prereqDebuffSpellID.." is a debuff prereq for "..spellSetting.spellID.." "..button:GetName())
							prereqDebuffFound = true
							break
						end
					end
					if prereqDebuffFound then break end
				end
				if prereqDebuffFound == true then
					--DEBUG("PREREQ: DEBUFF for "..spellSetting.spellID.." FOUND")
					button.texture:SetVertexColor(0.4, 0.4, 0.4)
				end
			end
			if spellSetting.cures then
				for _, debuff in ipairs(debuffs) do
					local debuffType = debuff[2]
					if debuffType then
						local debuffColor = DebuffTypeColor[debuffType] or DebuffTypeColor["none"]
						local cureFound = false
						--DEBUG("type: "..type(spellSetting.cures[debuffType]))
						local canCure = type(spellSetting.cures[debuffType]) == "function" and spellSetting.cures[debuffType]() or spellSetting.cures[debuffType]
						if canCure == true then
							--DEBUG("debuff "..debuff[1].." dispellable by "..(spellSetting.spellID or spellSetting.macroName).." on button "..button:GetName())
							button:SetBackdropColor(debuffColor.r, debuffColor.g, debuffColor.b)
							--button:SetBackdropBorderColor(debuffColor.r, debuffColor.g, debuffColor.b)
							button.texture:SetVertexColor(debuffColor.r, debuffColor.g, debuffColor.b)
						end
					end
				end
			end
		end
	end
end

-- Update healium frame buttons, set texture, extra attributes and show/hide.
local function HealiumUpdateFrameButtons(frame)
	if not HealiumEnabled() then return end
	--DEBUG("Update frame buttons for "..frame:GetName())
	if not frame.healiumButtons then return end
	local settings = GetHealiumSettings()
	for i, button in ipairs(frame.healiumButtons) do
		if settings and i <= #settings.spells then
			--DEBUG("show button "..i.." "..frame:GetName())
			local spellSetting = settings.spells[i]
			local icon, name, kind
			if spellSetting.spellID then
				kind = "spell"
				name, _, icon = GetSpellInfo(spellSetting.spellID)
			elseif spellSetting.macroName then
				kind = "macro"
				icon = select(2,GetMacroInfo(spellSetting.macroName))
				name = spellSetting.macroName
			end
			if icon then
				button.texture:SetTexture(icon)
			else
				button.texture:SetTexture("Interface/Icons/INV_Misc_QuestionMark")
			end
			button:SetAttribute("type",kind)
			button:SetAttribute(kind, name)
			button:Show()
		else
			--DEBUG("hide button "..i.." "..frame:GetName())
			button.texture:SetTexture("Interface/Icons/INV_Misc_QuestionMark")
			button:Hide()
		end
	end
end

-- -- For each spell, get cooldown then loop among Healium Frames and set cooldown
local function HealiumUpdateCooldowns()
	if not HealiumEnabled() then return end
	local settings = GetHealiumSettings()
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
			ForEachMember(HealiumUpdateFrameCooldown, index, start, duration, enabled)
		end
	end
end

local function HealiumCreateFrameButtons(frame)
	if not HealiumEnabled() then return end
	if not frame then return end
	if frame.healiumButtons then return end
	local settings = GetHealiumSettings()

	frame.healiumButtons = {}
	local spellSize = settings and settings.spellSize or frame:GetHeight()
	local spellSpacing = settings and settings.spellSpacing or 2
	local previousButton = nil
	for i = 1, MaxButtonCount, 1 do
		-- name
		local buttonName = frame:GetName().."_HealiumButton_"..i
		-- frame
		local button
		if i == 1 then
			button = CreateFrame("Button", buttonName, frame, "SecureActionButtonTemplate")
			button:CreatePanel("Default", spellSize, spellSize, "TOPLEFT", frame, "TOPRIGHT", spellSpacing, 0)
		else
			button = CreateFrame("Button", buttonName, frame, "SecureActionButtonTemplate")
			button:CreatePanel("Default", spellSize, spellSize, "TOPLEFT", previousButton, "TOPRIGHT", spellSpacing, 0)
		end
		-- texture setup, texture icon is set in HealiumUpdateFrameButtons
		button.texture = button:CreateTexture(nil, "BORDER")
		button.texture:SetTexCoord(0.08, 0.92, 0.08, 0.92)
		button.texture:SetPoint("TOPLEFT", button ,"TOPLEFT", 0, 0)
		button.texture:SetPoint("BOTTOMRIGHT", button ,"BOTTOMRIGHT", 0, 0)
		button:SetPushedTexture("Interface/Buttons/UI-Quickslot-Depress") -- TODO: use StyleButton from Tukui\Tukui\core\api.lua
		button:SetHighlightTexture("Interface/Buttons/ButtonHilight-Square")
		-- cooldown overlay
		button.cooldown = CreateFrame("Cooldown", "$parentCD", button, "CooldownFrameTemplate")
		button.cooldown:SetAllPoints(button.texture)
		-- click, attribute 'type' and 'spell' is set in HealiumUpdateFrameButtons
		button:RegisterForClicks("AnyUp")
		button:SetAttribute("useparent-unit","true")
		button:SetAttribute("*unit2", "target")
		-- hide
		button:Hide()
		-- save previous
		previousButton = button
		-- save button
		tinsert(frame.healiumButtons, button)
	end
end

-- Create delayed frames
local function HealiumCreateDelayedButtons()
	if not HealiumEnabled() then return end
	if InCombatLockdown() then return end
	if not HealiumDelayedButtonsCreation then return end
	for _, frame in ipairs(HealiumDelayedButtonsCreation) do
		DEBUG("Delayed frame creation for "..frame:GetName())
		if not frame.healiumButtons then
			HealiumCreateFrameButtons(frame)
		else
			DEBUG("Frame already created for "..frame:GetName())
		end
	end
	HealiumDelayedButtonsCreation = {}
end

-- PostUpdateHealth
local function HealiumPostUpdateHeal(health, unit, min, max)
	--DEBUG("HealiumPostUpdateHeal: "..(unit or "nil"))
	-- call normal raid post update heal
	T.PostUpdateHealthRaid(health, unit, min, max)

	if not HealiumEnabled() then return end
	local frame = health:GetParent()
	--local unit = frame.unit

	--DEBUG("HealiumPostUpdateHeal: "..frame:GetName().."  "..(unit or 'nil'))
	if not UnitIsConnected(unit) or UnitIsDead(unit) or UnitIsGhost(unit) then
		--DEBUG("->DISABLE")
		frame.healiumDisabled = true
		-- change healium buttons texture and reset buff/debuff
		if frame.healiumButtons then
			local settings = GetHealiumSettings()
			--DEBUG("disable healium buttons")
			for index, spellSetting in ipairs(settings.spells) do
				local button = frame.healiumButtons[index]
				if ((UnitIsDead(unit) or UnitIsGhost(unit)) and (not spellSetting.rez or spellSetting.rez == false)) or not UnitIsConnected(unit) then
					--DEBUG("disable button "..button:GetName())
					-- --button.texture:SetVertexColor(1, 0.1, 0.1)
					-- --button:SetBackdropColor(1,0.1,0.1)
					-- --button:SetBackdropBorderColor(1,0.1,0.1)
					button.texture:SetVertexColor(1,0.1,0.1)
				end
			end
		end
		-- hide buff
		if frame.healiumBuffs then
			--DEBUG("disable healium buffs")
			for _, buff in ipairs(frame.healiumBuffs) do
				buff:Hide()
			end
		end
		-- if frame.healiumDebuffs then
			-- DEBUG("disable healium debuffs")
			-- for _, debuff in ipairs(frame.healiumDebuffs) do
				-- debuff:Hide()
			-- end
		-- end
	elseif frame.healiumDisabled then
		--DEBUG("DISABLED")
		if frame.healiumButtons then
			local settings = GetHealiumSettings()
			--DEBUG("enable healium buttons")
			for index, button in ipairs(frame.healiumButtons) do
				--DEBUG("enable button:"..button:GetName())
				button.texture:SetVertexColor(1,1,1)
			end
		end
		frame.healiumDisabled = false
	end
end

-- Handle event specifically for Healium features
local function HealiumOnEvent(self, event, ...)
	local arg1 = select(1, ...)
	local arg2 = select(2, ...)
	local arg3 = select(3, ...)

	DEBUG("Event: "..event)

	if event == "ADDON_LOADED" then
		DEBUG("ADDON_LOADED: "..arg1)
	end

	if event == "PLAYER_ENTERING_WORLD" then
		ForEachMember(HealiumUpdateFrameButtons)
		ForEachMember(HealiumUpdateFrameDebuffsPosition)
		ForEachMember(HealiumUpdateFrameBuffsDebuffsSpecialSpells)
	end

	if event == "PARTY_MEMBERS_CHANGED" or event == "RAID_ROSTER_UPDATE" then
		ForEachMember(HealiumUpdateFrameButtons)
		ForEachMember(HealiumUpdateFrameDebuffsPosition)
		ForEachMember(HealiumUpdateFrameBuffsDebuffsSpecialSpells)
	end

	if event == "PLAYER_REGEN_ENABLED" then
		HealiumCreateDelayedButtons()
		ForEachMember(HealiumUpdateFrameButtons)
	end

	if event == "PLAYER_TALENT_UPDATE" then
		ForEachMember(HealiumUpdateFrameButtons)
		ForEachMember(HealiumUpdateFrameDebuffsPosition)
	end

	if event == "SPELL_UPDATE_COOLDOWN" then -- TODO: use SPELL_UPDATE_USABLE instead ?
		HealiumUpdateCooldowns()
	end

	-- UNIT_AURA is called if 'player' has a modification in it's aura
	if event == "UNIT_AURA" then
		local frame = GetFrameFromUnit(arg1)
		if frame then HealiumUpdateFrameBuffsDebuffsSpecialSpells(frame) end -- Update buff/debuff only for unit
	end

	-- if event == "PARTY_MEMBER_DISABLE" then
		-- --WARNING("PARTY_MEMBER_DISABLE:"..(arg1 or 'nil'))
		-- ForEachMember(HealiumSetFrameVisibility)
	-- end

	-- if event == "PARTY_MEMBER_ENABLE" then
		-- -- TODO: enable debuffs and set alpha to 0.5
		-- --WARNING("PARTY_MEMBER_ENABLE:"..(arg1 or 'nil'))
		-- ForEachMember(HealiumSetFrameVisibility)
	-- end
end

-------------------------------------------------------------------
-- Unitframe creation
local function Shared(self, unit)
	print("Shared: "..(unit or "nil").."  "..self:GetName())

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
	health:SetStatusBarTexture(normTex)
	self.Health = health

	health.bg = health:CreateTexture(nil, 'BORDER')
	health.bg:SetAllPoints(health)
	health.bg:SetTexture(normTex)
	health.bg:SetTexture(0.3, 0.3, 0.3)
	health.bg.multiplier = 0.3
	self.Health.bg = health.bg

	health.value = health:CreateFontString(nil, "OVERLAY")
	health.value:SetPoint("RIGHT", health, -3, 1)
	health.value:SetFont(font2, 12*T.raidscale, "THINOUTLINE")
	health.value:SetTextColor(1,1,1)
	health.value:SetShadowOffset(1, -1)
	self.Health.value = health.value

	if HealiumEnabled() then
		health.PostUpdate = HealiumPostUpdateHeal
	end

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
	power:SetStatusBarTexture(normTex)
	self.Power = power
	
	power.frequentUpdates = true
	power.colorDisconnected = true

	power.bg = self.Power:CreateTexture(nil, "BORDER")
	power.bg:SetAllPoints(power)
	power.bg:SetTexture(normTex)
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
	name:SetFont(font2, 12*T.raidscale, "THINOUTLINE")
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
		table.insert(self.__elements, T.UpdateThreat)
		self:RegisterEvent('PLAYER_TARGET_CHANGED', T.UpdateThreat)
		self:RegisterEvent('UNIT_THREAT_LIST_UPDATE', T.UpdateThreat)
		self:RegisterEvent('UNIT_THREAT_SITUATION_UPDATE', T.UpdateThreat)
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
		mhpb:SetStatusBarTexture(normTex)
		mhpb:SetStatusBarColor(0, 1, 0.5, 0.25)

		local ohpb = CreateFrame('StatusBar', nil, self.Health)
		ohpb:SetPoint('TOPLEFT', mhpb:GetStatusBarTexture(), 'TOPRIGHT', 0, 0)
		ohpb:SetPoint('BOTTOMLEFT', mhpb:GetStatusBarTexture(), 'BOTTOMRIGHT', 0, 0)
		ohpb:SetWidth(150*T.raidscale)
		ohpb:SetStatusBarTexture(normTex)
		ohpb:SetStatusBarColor(0, 1, 0, 0.25)

		self.HealPrediction = {
			myBar = mhpb,
			otherBar = ohpb,
			maxOverflow = 1,
		}
	end

	if HealiumEnabled() then
		local settings = GetHealiumSettings()
		-- buttons
		if InCombatLockdown() then
			tinsert(HealiumDelayedButtonsCreation, self)
		else
			HealiumCreateFrameButtons(self)
		end

		-- debuffs
		-- TODO: tooltip
		self.healiumDebuffs = {}
		local debuffSize = settings and settings.debuffSize or self:GetHeight()
		local debuffSpacing = settings and settings.debuffSpacing or 2
		for i = 1, MaxDebuffCount, 1 do
			--DEBUG("Create debuff "..i)
			-- name
			local debuffName = self:GetName().."_HealiumDebuff_"..i
			-- frame
			local debuff
			if i == 1 then
				--debuff = CreateFrame("Frame", debuffName, self, "TargetDebuffFrameTemplate")
				debuff = CreateFrame("Frame", debuffName, self)
				debuff:CreatePanel("Default", debuffSize, debuffSize, "TOPLEFT", self, "TOPRIGHT", debuffSpacing, 0)
			else
				--debuff = CreateFrame("Frame", debuffName, self, "TargetDebuffFrameTemplate")
				debuff = CreateFrame("Frame", debuffName, self)
				debuff:CreatePanel("Default", debuffSize, debuffSize, "TOPLEFT", self.healiumDebuffs[i-1], "TOPRIGHT", debuffSpacing, 0)
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
			--hide
			debuff:Hide()
			-- save debuff
			tinsert(self.healiumDebuffs, debuff)
		end

		-- buffs
		-- TODO: tooltip
		self.healiumBuffs = {}
		local buffSize = settings and settings.buffSize or self:GetHeight()
		local buffSpacing = settings and settings.buffSpacing or 2
		for i = 1, MaxBuffCount, 1 do
			local buffName = self:GetName().."_HealiumBuff_"..i
			local buff
			if i == 1 then
				--buff = CreateFrame("Frame", buffName, self, "TargetBuffFrameTemplate")
				buff = CreateFrame("Frame", buffName, self)
				buff:CreatePanel("Default", buffSize, buffSize, "TOPRIGHT", self, "TOPLEFT", -buffSpacing, 0)
			else
				--buff = CreateFrame("Frame", buffName, self, "TargetBuffFrameTemplate")
				buff = CreateFrame("Frame", buffName, self)
				buff:CreatePanel("Default", buffSize, buffSize, "TOPRIGHT", self.healiumBuffs[i-1], "TOPLEFT", -buffSpacing, 0)
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
			-- hide
			buff:Hide()
			-- save buff
			tinsert(self.healiumBuffs, buff)
		end

		-- Update healium buttons visibility, icon and attributes
		HealiumUpdateFrameButtons(self)
		-- Update debuff position
		HealiumUpdateFrameDebuffsPosition(self)
		-- Update buff/debuff/special spells
		--HealiumUpdateFrameBuffsDebuffsSpecialSpells(self) -- unit not yet set, unit passed as argument is "raid" instead of player or party1 or...
	end

	-- Not disabled
	self.healiumDisabled = false

	-- Save frame to healium frame list
	tinsert(HealiumFrames, self)

	-- Show frame
	self:Show()

	return self
end

oUF:RegisterStyle('TukuiHealiumR01R15', Shared)
oUF:Factory(function(self)
	oUF:SetActiveStyle("TukuiHealiumR01R15")

	local raid = self:SpawnHeader("oUF_TukuiHealiumRaid0115", nil, "custom [@raid16,exists] hide;show", 
	'oUF-initialConfigFunction', [[
		local header = self:GetParent()
		self:SetWidth(header:GetAttribute('initial-width'))
		self:SetHeight(header:GetAttribute('initial-height'))
	]],
	'initial-width', T.Scale(150*T.raidscale),
	'initial-height', T.Scale(32*T.raidscale),
	"showSolo", C["unitframes"].showsolo,
	"showParty", true, 
	"showPlayer", C["unitframes"].showplayerinparty, 
	"showRaid", true, 
	"groupFilter", "1,2,3,4,5,6,7,8", 
	"groupingOrder", "1,2,3,4,5,6,7,8", 
	"groupBy", "GROUP", 
	"yOffset", T.Scale(-4))
	raid:SetPoint("TOPLEFT", UIParent, "TOPLEFT", 150, -300*T.raidscale)
	
	local pets = {} 
	-- pets[1] = oUF:Spawn('partypet1', 'oUF_TukuiPartyPet1') 
	-- pets[1]:SetPoint('TOPLEFT', raid, 'TOPLEFT', 0, -240*T.raidscale)
	-- pets[1]:Size(150*T.raidscale, 32*T.raidscale)
	-- for i =2, 4 do 
		-- pets[i] = oUF:Spawn('partypet'..i, 'oUF_TukuiPartyPet'..i) 
		-- pets[i]:SetPoint('TOP', pets[i-1], 'BOTTOM', 0, -8)
		-- pets[i]:Size(150*T.raidscale, 32*T.raidscale)
	-- end

	local RaidMove = CreateFrame("Frame")
	RaidMove:RegisterEvent("PLAYER_ENTERING_WORLD")
	RaidMove:RegisterEvent("RAID_ROSTER_UPDATE")
	RaidMove:RegisterEvent("PARTY_LEADER_CHANGED")
	RaidMove:RegisterEvent("PARTY_MEMBERS_CHANGED")
	RaidMove:SetScript("OnEvent", function(self)
		if InCombatLockdown() then
			self:RegisterEvent("PLAYER_REGEN_ENABLED")
		else
			self:UnregisterEvent("PLAYER_REGEN_ENABLED")
			local numraid = GetNumRaidMembers()
			local numparty = GetNumPartyMembers()
			if numparty > 0 and numraid == 0 or numraid > 0 and numraid <= 5 then
				raid:SetPoint("TOPLEFT", UIParent, "TOPLEFT", 150, -300*T.raidscale)
				for i,v in ipairs(pets) do v:Enable() end
			elseif numraid > 5 and numraid <= 10 then
				raid:SetPoint('TOPLEFT', UIParent, 150, -260*T.raidscale)
				for i,v in ipairs(pets) do v:Disable() end
			elseif numraid > 10 and numraid <= 15 then
				raid:SetPoint('TOPLEFT', UIParent, 150, -170*T.raidscale)
				for i,v in ipairs(pets) do v:Disable() end
			elseif numraid > 15 then
				for i,v in ipairs(pets) do v:Disable() end
			end
		end
	end)

	if HealiumEnabled() then
		local healiumEventHandler = CreateFrame("Frame")
		healiumEventHandler:RegisterEvent("PLAYER_ENTERING_WORLD")
		healiumEventHandler:RegisterEvent("ADDON_LOADED")
		healiumEventHandler:RegisterEvent("RAID_ROSTER_UPDATE")
		healiumEventHandler:RegisterEvent("PARTY_MEMBERS_CHANGED")
		healiumEventHandler:RegisterEvent("PLAYER_REGEN_ENABLED")
		healiumEventHandler:RegisterEvent("PLAYER_TALENT_UPDATE")
		healiumEventHandler:RegisterEvent("SPELL_UPDATE_COOLDOWN")
		-- healiumEventHandler:RegisterEvent("PARTY_MEMBER_DISABLE")
		-- healiumEventHandler:RegisterEvent("PARTY_MEMBER_ENABLE")
		healiumEventHandler:RegisterEvent("UNIT_AURA")
		healiumEventHandler:SetScript("OnEvent", HealiumOnEvent)
	end
end)

-- TODO: check settings integrity
-- no more than MaxButtonCount entry in Settings[class][spec].spells
