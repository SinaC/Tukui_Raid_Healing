------------------------------------------------
-- Healium unitframes management
-- by SinaC (https://github.com/SinaC/)
------------------------------------------------

local ADDON_NAME, ns = ...
local oUF = oUFTukui or oUF
assert(oUF, "Healium was unable to locate oUF install.")

ns._Objects = {}
ns._Headers = {}

local T, C, L = unpack(Tukui) -- Import: T - functions, constants, variables; C - config; L - locales

if not C["unitframes"].enable == true or C["unitframes"].gridonly == true then return end
-- Use oUF_hTukz_Raid01_25.lua if Healium disabled
if not (HealiumSettings and HealiumSettings.Options and HealiumSettings.Options.enabled and HealiumSettings[T.myclass]) then return end

-- Aliases
local FlashFrame = _G["FlashFrame"]
local PerformanceCounter = _G["PerformanceCounter"]
local DumpSack = _G["DumpSack"]
local TabMenu = _G["Tukui_TabMenu"]

-- Raid unitframes header
local PlayerRaidHeader = nil
local PetRaidHeader = nil
local TankRaidHeader = nil
local NamelistRaidHeader = nil

-- Fields added to Header
--		hVisibilityAttribute: custom visibility attribute used when calling SpawnHeader for this header
-- Fields added to TukuiUnitframe
--		hDisabled: true if unitframe is dead/ghost/disconnected, false otherwise
--		hButtons: heal buttons (SecureActionButtonTemplate)
--		hDebuffs: debuff on unit (no template)
--		hBuffs: buffs on unit (only buff castable by heal buttons)
-- Fields added to hButton
--		hSpellBookID: spellID of spell linked to button
--		hMacroName: name of macro linked to button
--		hPrereqFailed: button is disabled because of prereq
--		hOOM: not enough mana to cast spell
--		hNotUsable: not usable (see http://www.wowwiki.com/API_IsUsableSpell)  -> NOT YET USED
--		hDispelHighlight: debuff dispellable by button
--		hOOR: unit of range
--		hInvalid: spell is not valid

-------------------------------------------------------
-- Constants
-------------------------------------------------------
local Debug = true
local ActivatePrimarySpecSpellName = GetSpellInfo(63645)
local ActivateSecondarySpecSpellName = GetSpellInfo(63644)
local MaxButtonCount = 12
local MaxDebuffCount = 8
local MaxBuffCount = 6
local UpdateDelay = 0.2
local DispelSoundFile = "Sound\\Doodad\\BellTollHorde.wav"
local Visibility25 = "custom [@raid26,exists] hide;show"
local Visibility10 = "custom [@raid11,exists] hide;show"

-------------------------------------------------------
-- Helpers
-- use:
-- none
-- used by:
-- almost every modules
-------------------------------------------------------
local function Message(...)
	print("TukuiHealium:", ...)
end

local function ERROR(...)
	print("|CFFFF0000TukuiHealium|r:",...)
end

local function WARNING(...)
	print("|CFF00FFFFTukuiHealium|r:",...)
end

local function DEBUG(...)
	if not Debug or Debug == false then return end
	print("|CFF00FF00TH|r:",...)
end

-- Get value or set to default if nil
local function Getter(value, default)
	return value == nil and default or value
end

-- Format big number
local function ShortValueNegative(v)
	if v <= 999 then return v end
	if v >= 1000000 then
		local value = string.format("%.1fm", v/1000000)
		return value
	elseif v >= 1000 then
		local value = string.format("%.1fk", v/1000)
		return value
	end
end

-- Get book spell id from spell name
local function GetSpellBookID(spellName)
	for i = 1, 300, 1 do
		local spellBookName = GetSpellBookItemName(i, SpellBookFrame.bookType)
		if not spellBookName then break end
		if spellName == spellBookName then
			local slotType = GetSpellBookItemInfo(i, SpellBookFrame.bookType)
			if slotType == "SPELL" then
				return i
			end
			return nil
		end
	end
	return nil
end

-- Is spell learned?
local function IsSpellLearned(spellID)
	local spellName = GetSpellInfo(spellID)
	if not spellName then return nil end
	local skillType, globalSpellID = GetSpellBookItemInfo(spellName)
	-- skill type: "SPELL", "PETACTION", "FUTURESPELL", "FLYOUT"
	if skillType == "SPELL" and globalSpellID == spellID then return skillType end
	return nil
end

local function AddToNamelist(list, name)
	if list ~= "" then
		local names = { strsplit(",", list) }
		for _, v in ipairs(names) do
			if v == name then return false end
		end
		list = list .. "," .. name
	else
		list = name
	end
	return true
end

local function RemoveFromNamelist(list, name)
	if list == "" then return false end
	local names = { strsplit(",", list) }
	local found = false
	list = ""
	for _, v in ipairs(names) do
		if v == name then
			found = true
		else
			list = (list or "") .. "," .. v
		end
	end
	return found
end

-------------------------------------------------------
-- Unitframes list management
-- use:
-- PerformanceCounter:Increment
-- used by:
-- SlashCommandHandler, Update, EventHandler, Create
-------------------------------------------------------
local Unitframes = {}
-- Save frame
local function SaveUnitframe(frame)
	tinsert(Unitframes, frame)
end

-- Get unitframe with pointing to this unit
local function GetUnitframesFromUnit(unit)
	PerformanceCounter:Increment("TukuiHealium", "GetUnitframesFromUnit")
	if not Unitframes then return nil end
	local frames = {}
	for _, frame in ipairs(Unitframes) do
		--if frame and frame.unit == unit then return frame end
		if frame and frame.unit == unit then
			tinsert(frames, frame)
		end
	end
	--return nil
	return frames
end

-- Loop among every valid (parent shown and unit not nil) unitframe in party/raid and call a function
local function ForEachUnitframe(fct, ...)
	PerformanceCounter:Increment("TukuiHealium", "ForEachUnitframe")
	if not Unitframes then return end
	for _, frame in ipairs(Unitframes) do
		--if frame and frame:IsShown() then -- IsShown is false if /reloadui
		if frame and frame.unit ~= nil and frame:GetParent():IsShown() then -- IsShown is false if /reloadui
			fct(frame, ...)
		end
	end
end

-- Loop among every members in party/raid and call a function even if not shown or unit is nil (only for DEBUG purpose)
local function ForEachMember(fct, ...)
	PerformanceCounter:Increment("TukuiHealium", "ForEachMember")
	if not Unitframes then return end
	for _, frame in ipairs(Unitframes) do
		if frame then
			fct(frame, ...)
		end
	end
end

-------------------------------------------------------
-- Raid header management
-- use:
-- none
-- used by:
-- SlashCommandHandler, TabMenu
-------------------------------------------------------
local function ToggleHeader(header)
	if not header then return end
	--DEBUG("header:"..header:GetName().."  "..tostring(header:IsShown()))
	if header:IsShown() then
		UnregisterAttributeDriver(header, "state-visibility")
		header:Hide()
	else
		RegisterAttributeDriver(header, "state-visiblity", header.hVisibilityAttribute)
		header:Show()
	end
end

-------------------------------------------------------
-- Settings
-- use:
-- Helpers:IsSpellLearned, Helpers:ERROR
-- used by:
-- SlashCommandHandler, EventHandlers, Main
-------------------------------------------------------
local SpecSettings = nil
-- Return settings for current spec
local function GetSpecSettings()
	--DEBUG("GetSettings")
	local ptt = GetPrimaryTalentTree()
	if not ptt then return nil end
	SpecSettings = HealiumSettings[T.myclass][ptt]
	return SpecSettings
end

-- Check spell settings
local function CheckSpellSettings()
	--DEBUG("CheckSpellSettings")
	-- Check settings
	if SpecSettings then
		for _, spellSetting in ipairs(SpecSettings.spells) do
			if spellSetting.spellID and not IsSpellLearned(spellSetting.spellID) then
				local name = GetSpellInfo(spellSetting.spellID)
				if name then
					ERROR(string.format(L.healium_CHECKSPELL_SPELLNOTLEARNED, name, spellSetting.spellID))
				else
					ERROR(string.format(L.healium_CHECKSPELL_SPELLNOTEXISTS, spellSetting.spellID))
				end
			elseif spellSetting.macroName and GetMacroIndexByName(spellSetting.macroName) == 0 then
				ERROR(string.format(L.healium_CHECKSPELL_MACRONOTFOUND, spellSetting.macroName))
			end
		end
	end
end

-- Create a list with spellID and spellName from a list of spellID (+ remove duplicates)
local function CreateDebuffFilterList(listName, list)
	local newList = {}
	local i = 1
	local index = 1
	while i <= #list do
		local spellName = GetSpellInfo(list[i])
		if spellName then
			-- Check for duplicate
			local j = 1
			local found = false
			while j < #newList do
				if newList[j].spellName == spellName then
					found = true
					break
				end
				j = j + 1
			end
			if not found then
				-- Create entry in new list
				newList[index] = { spellID = list[i], spellName = spellName }
				index = index + 1
			-- else
				-- -- Duplicate found
				-- WARNING(string.format(L.healium_SETTINGS_DUPLICATEBUFFDEBUFF, list[i], newList[j].spellID, spellName, listName))
			end
		else
			-- Unknown spell found
			WARNING(string.format(L.healium_SETTINGS_UNKNOWNBUFFDEBUFF, list[i], listName))
		end
		i = i + 1
	end
	return newList
end

local function InitializeSettings()
	for class in pairs(HealiumSettings) do
		if class ~= T.myclass and class ~= "Options" then
			HealiumSettings[class] = nil
			--DEBUG("REMOVING "..class.." from settings")
		end
	end

	-- Fill blacklist and whitelist with spellName instead of spellID
	if HealiumSettings.Options.debuffBlacklist and HealiumSettings.Options.debuffFilter == "BLACKLIST" then
		HealiumSettings.Options.debuffBlacklist = CreateDebuffFilterList("debuffBlacklist", HealiumSettings.Options.debuffBlacklist)
	else
		--DEBUG("Clearing debuffBlacklist")
		HealiumSettings.Options.debuffBlacklist = nil
	end

	if HealiumSettings.Options.debuffWhitelist and HealiumSettings.Options.debuffFilter == "WHITELIST" then
		HealiumSettings.Options.debuffWhitelist = CreateDebuffFilterList("debuffWhitelist", HealiumSettings.Options.debuffWhitelist)
	else
		--DEBUG("Clearing debuffWhitelist")
		HealiumSettings.Options.debuffWhitelist = nil
	end

	-- Add spellName to spell list
	for _, specSetting in pairs(HealiumSettings[T.myclass]) do
		for _, spellSetting in ipairs(specSetting.spells) do
			if spellSetting.spellID then
				local spellName = GetSpellInfo(spellSetting.spellID)
				spellSetting.spellName = spellName
			end
		end
	end

	--DEBUG("InitializeSettings:"..tostring(HealiumSettings.Options.namelist))
	-- Set namelist to "" if not found
	if not HealiumSettings.Options.namelist then HealiumSettings.Options.namelist = "" end
end


-------------------------------------------------------
-- Tooltips
-- use:
-- none
-- used by:
-- Create
-------------------------------------------------------
-- Heal buttons tooltip
local function ButtonOnEnter(self)
	-- Heal tooltips are anchored to tukui tooltip
	local tooltipAnchor = ElvUI and _G["TooltipHolder"] or _G["TukuiTooltipAnchor"]
	GameTooltip:SetOwner(tooltipAnchor, "ANCHOR_NONE")
	if self.hInvalid then
		if self.hSpellBookID then
			local name = GetSpellInfo(self.hSpellBookID) -- in this case, hSpellBookID contains global spellID
			GameTooltip:AddLine(string.format(L.healium_TOOLTIP_UNKNOWNSPELL, name, self.hSpellBookID), 1, 1, 1)
		elseif self.hMacroName then
			GameTooltip:AddLine(string.format(L.healium_TOOLTIP_UNKNOWN_MACRO, self.hMacroName), 1, 1, 1)
		else
			GameTooltip:AddLine(L.healium_TOOLTIP_UNKNOWN, 1, 1, 1)
		end
	else
		if self.hSpellBookID then
			GameTooltip:SetSpellBookItem(self.hSpellBookID, SpellBookFrame.bookType)
		elseif self.hMacroName then
			GameTooltip:AddLine(string.format(L.healium_TOOLIP_MACRO, self.hMacroName), 1, 1, 1)
		else
			GameTooltip:AddLine(L.healium_TOOLTIP_UNKNOWN, 1, 1, 1)
		end
		local unit = SecureButton_GetUnit(self)
		if not UnitExists(unit) then return end
		local unitName = UnitName(unit)
		if not unitName then unitName = "-" end
		GameTooltip:AddLine(string.format(L.healium_TOOLTIP_TARGET, unitName), 1, 1, 1)
	end
	GameTooltip:Show()
end

-- Debuff tooltip
local function DebuffOnEnter(self)
	--http://wow.go-hero.net/framexml/13164/TargetFrame.xml
	if self:GetCenter() > GetScreenWidth()/2 then
		GameTooltip:SetOwner(self, "ANCHOR_LEFT")
	else
		GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
	end
	GameTooltip:SetUnitDebuff(self.unit, self:GetID())
end

-- Buff tooltip
local function BuffOnEnter(self)
	--http://wow.go-hero.net/framexml/13164/TargetFrame.xml
	if self:GetCenter() > GetScreenWidth()/2 then
		GameTooltip:SetOwner(self, "ANCHOR_LEFT")
	else
		GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
	end
	GameTooltip:SetUnitBuff(self.unit, self:GetID())
end

-------------------------------------------------------
-- Healium buttons/buff/debuffs update
-- use:
-- PerformanceCounter:Increment, SpecSettings, FlashFrame:ShowFlashFrame, Unitframes:ForEachUnitframe, Helpers:IsSpellLearned
-------------------------------------------------------
-- Update healium button cooldown
local function UpdateButtonCooldown(frame, index, start, duration, enabled)
	PerformanceCounter:Increment("TukuiHealium", "UpdateButtonCooldown")
	if not frame.hButtons then return end
	--DEBUG("UpdateButtonCooldown")
	local button = frame.hButtons[index]
	CooldownFrame_SetTimer(button.cooldown, start, duration, enabled)
end

-- Update healium button OOM
local function UpdateButtonOOM(frame, index, OOM)
	PerformanceCounter:Increment("TukuiHealium", "UpdateButtonOOM")
	if not frame.hButtons then return end
	--DEBUG("UpdateButtonOOM")
	local button = frame.hButtons[index]
	--if not button then return end
	button.hOOM = OOM
end

-- Update healium button OOR
local function UpdateButtonOOR(frame, index, spellName)
	PerformanceCounter:Increment("TukuiHealium", "UpdateButtonOOR")
	if not frame.hButtons then return end
	DEBUG("UpdateButtonOOR")
	local button = frame.hButtons[index]
	local inRange = IsSpellInRange(spellName, frame.unit)
	if not inRange or inRange == 0 then
		button.hOOR = true
	else
		button.hOOR = false
	end
end

-- Update healium button color depending on frame and button status
-- frame disabled -> color in dark red except rez if dead or ghost
-- out of range -> color in deep red
-- disabled -> dark gray
-- not usable -> color in medium red
-- out of mana -> color in medium blue
-- dispel highlight -> color in debuff color
local function UpdateButtonsColor(frame)
	PerformanceCounter:Increment("TukuiHealium", "UpdateButtonsColor")
	if not SpecSettings then return end
	if not frame.hButtons then return end
	if not frame:IsShown() then return end
	local unit = frame.unit

	local isDeadOrGhost = UnitIsDead(unit) or UnitIsGhost(unit)
	local isConnected = UnitIsConnected(unit)
	for index, spellSetting in ipairs(SpecSettings.spells) do
		local button = frame.hButtons[index]
		if frame.hDisabled and (not isConnected or ((not spellSetting.rez or spellSetting.rez == false) and isDeadOrGhost)) then
			-- not (rez and unit is dead) -> color in red
			button.texture:SetVertexColor(1, 0.1, 0.1)
		elseif button.hOOR and not button.hInvalid then
			-- out of range -> color in red
			button.texture:SetVertexColor(1.0, 0.3, 0.3)
		elseif button.hPrereqFailed and not button.hInvalid then
			-- button disabled -> color in gray
			button.texture:SetVertexColor(0.2, 0.2, 0.2)
		elseif button.hNotUsable and not button.hInvalid then
			-- button not usable -> color in medium red
			button.texture:SetVertexColor(1.0, 0.5, 0.5)
		elseif button.hOOM and not button.hInvalid then
			-- no mana -> color in blue
			button.texture:SetVertexColor(0.5, 0.5, 1.0)
		elseif button.hDispelHighlight ~= "none" and not button.hInvalid then
			-- dispel highlight -> color with debuff color
			local debuffColor = DebuffTypeColor[button.hDispelHighlight] or DebuffTypeColor["none"]
			button:SetBackdropColor(debuffColor.r, debuffColor.g, debuffColor.b)
			-- --button:SetBackdropBorderColor(debuffColor.r, debuffColor.g, debuffColor.b)
			button.texture:SetVertexColor(debuffColor.r, debuffColor.g, debuffColor.b)
		else
			button.texture:SetVertexColor(1, 1, 1)
			button:SetBackdropColor(0.6, 0.6, 0.6)
			button:SetBackdropBorderColor(0.1, 0.1, 0.1)
		end
	end
end

-- Update healium frame buff/debuff and prereq
local LastDebuffSoundTime = GetTime()
local listBuffs = {} -- GC-friendly
local listDebuffs = {} -- GC-friendly
local function UpdateFrameBuffsDebuffsPrereqs(frame)
	PerformanceCounter:Increment("TukuiHealium", "UpdateFrameBuffsDebuffsPrereqs")

	--DEBUG("UpdateFrameBuffsDebuffsPrereqs: frame: "..frame:GetName().." unit: "..(unit or "nil"))

	local unit = frame.unit
	if not unit then return end

	-- reset button.hPrereqFailed and button.hDispelHighlight
	if frame.hButtons and not frame.hDisabled then
		--DEBUG("---- reset dispel, disabled")
		for index, button in ipairs(frame.hButtons) do
			button.hDispelHighlight = "none"
			button.hPrereqFailed = false
		end
	end

	-- buff: parse buff even if showBuff is set to false for prereq
	local buffCount = 0
	if not frame.hDisabled then
		local buffIndex = 1
		if SpecSettings then
			for i = 1, 40, 1 do
				-- get buff
				name, _, icon, count, _, duration, expirationTime, _, _, _, spellID = UnitAura(unit, i, "PLAYER|HELPFUL")
				if not name then
					buffCount = i-1
					break
				end
				listBuffs[i] = spellID -- display only buff castable by player but keep whole list of buff to check prereq
				-- is buff casted by player and in spell list?
				local found = false
				for index, spellSetting in ipairs(SpecSettings.spells) do
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
				if found and frame.hBuffs then
					-- buff casted by player and in spell list
					local buff = frame.hBuffs[buffIndex]
					-- id, unit  used by tooltip
					buff:SetID(i)
					buff.unit = unit
					-- texture
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
					if buffIndex > MaxBuffCount then
						--WARNING(string.format(L.healium_BUFFDEBUFF_TOOMANYBUFF, frame:GetName(), unit))
						break
					end
				end
			end
		end
		if frame.hBuffs then
			for i = buffIndex, MaxBuffCount, 1 do
				-- hide remainder buff
				local buff = frame.hBuffs[i]
				buff:Hide()
			end
		end
	end

	-- debuff: parse debuff even if showDebuff is set to false for prereq
	local debuffCount = 0
	local debuffIndex = 1
	if SpecSettings or HealiumSettings.Options.showDebuff then
		for i = 1, 40, 1 do
			-- get debuff
			local name, _, icon, count, debuffType, duration, expirationTime, _, _, _, spellID = UnitDebuff(unit, i)
			if not name then
				debuffCount = i-1
				break
			end
			--debuffType = "Curse" -- DEBUG purpose :)
			listDebuffs[i] = {spellID, debuffType} -- display not filtered debuff but keep whole debuff list to check prereq
			local dispellable = false -- default: non-dispellable
			if debuffType then
				for _, spellSetting in ipairs(SpecSettings.spells) do
					if spellSetting.dispels then
						local canDispel = type(spellSetting.dispels[debuffType]) == "function" and spellSetting.dispels[debuffType]() or spellSetting.dispels[debuffType]
						if canDispel then
							dispellable = true
							break
						end
					end
				end
			end
			local filtered = false -- default: not filtered
			if not dispellable then
				-- non-dispellable are rejected or filtered using blacklist/whitelist
				if HealiumSettings.Options.debuffFilter == "DISPELLABLE" then
					filtered = true
				elseif HealiumSettings.Options.debuffFilter == "BLACKLIST" and HealiumSettings.Options.debuffBlacklist then
					-- blacklisted ?
					filtered = false -- default: not filtered
					for _, entry in ipairs(HealiumSettings.Options.debuffBlacklist) do
						if entry.spellName == name then
							filtered = true -- found in blacklist -> filtered
							break
						end
					end
				elseif HealiumSettings.Options.debuffFilter == "WHITELIST" and HealiumSettings.Options.debuffWhitelist then
					-- whitelisted ?
					filtered = true -- default: filtered
					for _, entry in ipairs(HealiumSettings.Options.debuffWhitelist) do
						if entry.spellName == name then
							filtered = false -- found in whitelist -> not filtered
							break
						end
					end
				end
			end
			if not filtered and frame.hDebuffs then
				-- debuff not filtered
				local debuff = frame.hDebuffs[debuffIndex]
				-- id, unit  used by tooltip
				debuff:SetID(i)
				debuff.unit = unit
				-- texture
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
				--DEBUG("debuffType: "..(debuffType or 'nil').."  debuffColor: "..(debuffColor and debuffColor.r or 'nil')..","..(debuffColor and debuffColor.g or 'nil')..","..(debuffColor and debuffColor.b or 'nil'))
				debuff:SetBackdropBorderColor(debuffColor.r, debuffColor.g, debuffColor.b)
				-- show
				debuff:Show()
				-- next debuff
				debuffIndex = debuffIndex + 1
				--- too many debuff?
				if debuffIndex > MaxDebuffCount then
					--WARNING(string.format(L.healium_BUFFDEBUFF_TOOMANYDEBUFF, frame:GetName(), unit))
					break
				end
			end
		end
	end
	if frame.hDebuffs then
		for i = debuffIndex, MaxDebuffCount, 1 do
			-- hide remainder debuff
			local debuff = frame.hDebuffs[i]
			debuff:Hide()
		end
	end

	--DEBUG("BUFF:"..buffCount.."  DEBUFF:"..debuffCount)

	-- color dispel button if dispellable debuff + prereqs management (is buff or debuff a prereq to enable/disable a spell)
	if SpecSettings and frame.hButtons and not frame.hDisabled then
		local isUnitInRange = UnitInRange(unit)
		local debuffDispellableFound = false
		local highlightDispel = Getter(HealiumSettings.Options.highlightDispel, true)
		local playSound = Getter(HealiumSettings.Options.playSoundOnDispel, true)
		--local flashDispel = Getter(HealiumSettings.Options.flashDispel, true)
		local flashStyle = HealiumSettings.Options.flashStyle
		for index, spellSetting in ipairs(SpecSettings.spells) do
			local button = frame.hButtons[index]
			-- buff prereq: if not present, spell is inactive
			if spellSetting.buffs then
				--DEBUG("searching buff prereq for "..spellSetting.spellID)
				local prereqBuffFound = false
				for _, prereqBuffSpellID in ipairs(spellSetting.buffs) do
					--DEBUG("buff prereq for "..spellSetting.spellID.." "..prereqBuffSpellID)
					--for _, buff in pairs(listBuffs) do
					for i = 1, buffCount, 1 do
						local buff = listBuffs[i]
						--DEBUG("buff on unit "..buffSpellID)
						if buff == prereqBuffSpellID then
							--DEBUG("PREREQ: "..prereqBuffSpellID.." is a buff prereq for "..spellSetting.spellID.." "..button:GetName())
							prereqBuffFound = true
							break
						end
					end
					if prereqBuffFound then break end
				end
				if not prereqBuffFound then
					--DEBUG("PREREQ: BUFF for "..spellSetting.spellID.." NOT FOUND")
					button.hPrereqFailed = true
				end
			end
			-- debuff prereq: if present, spell is inactive
			if spellSetting.debuffs then
				--DEBUG("searching buff prereq for "..spellSetting.spellID)
				local prereqDebuffFound = false
				for _, prereqDebuffSpellID in ipairs(spellSetting.debuffs) do
					--DEBUG("buff prereq for "..spellSetting.spellID.." "..prereqDebuffSpellID)
					--for _, debuff in ipairs(listDebuffs) do
					for i = 1, debuffCount, 1 do
						local debuff = listDebuffs[i]
						local debuffSpellID = debuff[1] -- [1] = spellID
						--DEBUG("debuff on unit "..debuffSpellID)
						if debuffSpellID == prereqDebuffSpellID then
							--DEBUG("PREREQ: "..prereqDebuffSpellID.." is a debuff prereq for "..spellSetting.spellID.." "..button:GetName())
							prereqDebuffFound = true
							break
						end
					end
					if prereqDebuffFound then break end
				end
				if prereqDebuffFound then
					--DEBUG("PREREQ: DEBUFF for "..spellSetting.spellID.." FOUND")
					button.hPrereqFailed = true
				end
			end
			-- color dispel button if affected by a debuff curable by a player spell
			if spellSetting.dispels and (highlightDispel or playSound or flashStyle ~= "NONE") then
				--for _, debuff in ipairs(listDebuffs) do
				for i = 1, debuffCount, 1 do
					local debuff = listDebuffs[i]
					local debuffType = debuff[2] -- [2] = debuffType
					if debuffType then
						--DEBUG("type: "..type(spellSetting.dispels[debuffType]))
						local canDispel = type(spellSetting.dispels[debuffType]) == "function" and spellSetting.dispels[debuffType]() or spellSetting.dispels[debuffType]
						if canDispel then
							--print("DEBUFF dispellable")
							local debuffColor = DebuffTypeColor[debuffType] or DebuffTypeColor["none"]
							-- Highlight dispel button?
							if highlightDispel then
								button.hDispelHighlight = debuffType
							end
							-- Flash dispel?
							if isUnitInRange then
								if flashStyle == "FLASH" then
									FlashFrame:ShowFlashFrame(button, debuffColor, 320, 100, false)
								elseif flashStyle == "FADEOUT" then
									FlashFrame:Fadeout(button, 0.3)
								end
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
			if playSound and isUnitInRange then
				local now = GetTime()
				--print("DEBUFF in range: "..now.."  "..h_listDebuffsoundTime)
				if now > LastDebuffSoundTime + 7 then -- no more than once every 7 seconds
					--print("DEBUFF in time")
					PlaySoundFile(DispelSoundFile)
					LastDebuffSoundTime = now
				end
			end
		end
	end

	-- Color buttons
	UpdateButtonsColor(frame)
end

-- For each spell, get cooldown then loop among Healium Unitframes and set cooldown
local lastCD = {} -- keep a list of CD between calls, if CD information are the same, no need to update buttons
local function UpdateCooldowns()
	PerformanceCounter:Increment("TukuiHealium", "UpdateCooldowns")
	--DEBUG("UpdateCooldowns")
	if not SpecSettings then return end
	for index, spellSetting in ipairs(SpecSettings.spells) do
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
		if start and start > 0 then
			local arrayEntry = lastCD[index]
			if not arrayEntry or arrayEntry.start ~= start or arrayEntry.duration ~= duration then
				--DEBUG("CD KEEP:"..index.."  "..start.."  "..duration.."  /  "..(arrayEntry and arrayEntry.start or 'nil').."  "..(arrayEntry and arrayEntry.duration or 'nil'))
				ForEachUnitframe(UpdateButtonCooldown, index, start, duration, enabled)
				lastCD[index] = { start = start, duration = duration }
			--else
				--DEBUG("CD SKIP:"..index.."  "..start.."  "..duration.."  /  "..(arrayEntry and arrayEntry.start or 'nil').."  "..(arrayEntry and arrayEntry.duration or 'nil'))
			end
		-- else
			-- DEBUG("CD: skipping:"..index)
		end
	end
end

-- Check OOM spells
local lastOOM = {} -- keep OOM status of previous step, if no change, no need to update butttons
local function UpdateOOMSpells()
	PerformanceCounter:Increment("TukuiHealium", "UpdateOOMSpells")
	if not HealiumSettings.Options.showOOM then return end
	--DEBUG("UpdateOOMSpells")
	if not SpecSettings then return end
	local change = false -- TODO: remove this flag by calling a new method ForEachUnitframe(UpdateButtonColor, index) -- update frame.hButtons[index] color
	for index, spellSetting in ipairs(SpecSettings.spells) do
		local spellName = spellSetting.spellName -- spellName is automatically set if spellID was found in settings
		if spellSetting.macroName then
			local macroID = GetMacroIndexByName(spellSetting.macroName)
			if macroID > 0 then
				spellName = GetMacroSpell(macroID)
			end
		end
		if spellName then
			--DEBUG("spellName:"..spellName)
			local _, OOM = IsUsableSpell(spellName)
			if lastOOM[index] ~= OOM then
				local change = true
				lastOOM[index] = OOM
				ForEachUnitframe(UpdateButtonOOM, index, OOM)
			-- else
				-- DEBUG("Skipping UpdateButtonOOM:"..index)
			end
		end
	end
	if change then
		ForEachUnitframe(UpdateButtonsColor)
	end
end

-- Check OOR spells
local function UpdateOORSpells()
	PerformanceCounter:Increment("TukuiHealium", "UpdateOORSpells")
	if not HealiumSettings.Options.showOOR then return end
	--DEBUG("UpdateOORSpells")
	if not SpecSettings then return end
	for index, spellSetting in ipairs(SpecSettings.spells) do
		local spellName = spellSetting.spellName -- spellName is automatically set if spellID was found in settings
		if spellSetting.macroName then
			local macroID = GetMacroIndexByName(spellSetting.macroName)
			if macroID > 0 then
				spellName = GetMacroSpell(macroID)
			end
		end
		if spellName then
			--DEBUG("spellName:"..spellName)
			ForEachUnitframe(UpdateButtonOOR, index, spellName)
		end
	end
	ForEachUnitframe(UpdateButtonsColor)
end

-- Change player's name's color if it has aggro or not
local function UpdateThreat(self, event, unit)
	PerformanceCounter:Increment("TukuiHealium", "UpdateThreat")
	if (self.unit ~= unit) or (unit == "target" or unit == "pet" or unit == "focus" or unit == "focustarget" or unit == "targettarget") then return end
	local threat = UnitThreatSituation(self.unit)
	--DEBUG("UpdateThreat:"..tostring(self.unit).." / "..tostring(unit).." --> "..tostring(threat))
	if threat and threat > 1 then
		--self.Name:SetTextColor(1,0.1,0.1)
		local r, g, b = GetThreatStatusColor(threat)
		--DEBUG("==>"..r..","..g..","..b)
		self.Name:SetTextColor(r, g, b)
	else
		self.Name:SetTextColor(1, 1, 1)
	end
end

-- PostUpdateHealth, called after health bar has been updated
local function PostUpdateHealth(health, unit, min, max)
	PerformanceCounter:Increment("TukuiHealium", "PostUpdateHeal")
	--DEBUG("PostUpdateHeal: "..(unit or "nil"))
	-- call normal raid post update heal
	T.PostUpdateHealthRaid(health, unit, min, max)

	local frame = health:GetParent()
	--local unit = frame.unit

	--DEBUG("PostUpdateHeal: "..frame:GetName().."  "..(unit or 'nil'))
	if not UnitIsConnected(unit) or UnitIsDead(unit) or UnitIsGhost(unit) then
		if not frame.hDisabled then
			--DEBUG("->DISABLE")
			frame.hDisabled = true
			-- hide buff
			if frame.hBuffs then
				--DEBUG("disable healium buffs")
				for _, buff in ipairs(frame.hBuffs) do
					buff:Hide()
				end
			end
			UpdateButtonsColor(frame)
		end
	elseif frame.hDisabled then
		--DEBUG("DISABLED")
		frame.hDisabled = false
		UpdateButtonsColor(frame)
	end
	local showPercentage = Getter(HealiumSettings.Options.showPercentage, false)
	if showPercentage and min ~= max and UnitIsConnected(unit) and not UnitIsDead(unit) and not UnitIsGhost(unit) then
		local r, g, b = oUF.ColorGradient(min/max, 0.69, 0.31, 0.31, 0.65, 0.63, 0.35, 0.33, 0.59, 0.33)
		--health.value:SetText("|cff559655-"..h_ShortValueNegative(max-min).."|r")
		--health.value:SetFormattedText("|cff%02x%02x%02x-"..h_ShortValueNegative(max-min).."|r", r * 255, g * 255, b * 255)
		--health.value:SetFormattedText("|cffAF5050%d|r |cffD7BEA5-|r |cff%02x%02x%02x%d%%|r", min, r * 255, g * 255, b * 255, floor(min / max * 100))
		health.value:SetFormattedText("|cff%02x%02x%02x%d%%|r", r * 255, g * 255, b * 255, floor(min / max * 100))
	end
end

-- Update healium frame debuff position, debuff must be anchored to last shown button
local function UpdateFrameDebuffsPosition(frame)
	PerformanceCounter:Increment("TukuiHealium", "UpdateFrameDebuffsPosition")
	if not frame.hDebuffs or not frame.hButtons then return end
	--DEBUG("UpdateFrameDebuffsPosition")
	--DEBUG("Update debuff position for "..frame:GetName())
	local anchor = frame
	if SpecSettings then -- if no heal buttons, anchor to unitframe
		anchor = frame.hButtons[#SpecSettings.spells]
	end
	--DEBUG("Update debuff position for "..frame:GetName().." anchoring on "..anchor:GetName())
	--local anchor = frame.hButtons[#SpecSettings.spells]
	local firstDebuff = frame.hDebuffs[1]
	--DEBUG("anchor: "..anchor:GetName().."  firstDebuff: "..firstDebuff:GetName())
	local debuffSpacing = SpecSettings and SpecSettings.debuffSpacing or 2
	firstDebuff:ClearAllPoints()
	firstDebuff:Point("TOPLEFT", anchor, "TOPRIGHT", debuffSpacing, 0)
end

-- Update healium frame buttons, set texture, extra attributes and show/hide.
local function UpdateFrameButtons(frame)
	PerformanceCounter:Increment("TukuiHealium", "UpdateFrameButtons")
	if InCombatLockdown() then
		--DEBUG("UpdateFrameButtons: Cannot update buttons while in combat")
		return
	end
	--DEBUG("Update frame buttons for "..frame:GetName())
	if not frame.hButtons then return end
	for i, button in ipairs(frame.hButtons) do
		if SpecSettings and i <= #SpecSettings.spells then
			local spellSetting = SpecSettings.spells[i]
			local icon, name, type
			if spellSetting.spellID then
				if IsSpellLearned(spellSetting.spellID) then
					type = "spell"
					name, _, icon = GetSpellInfo(spellSetting.spellID)
					button.hSpellBookID = GetSpellBookID(name)
					button.hMacroName = nil
				end
			elseif spellSetting.macroName then
				if GetMacroIndexByName(spellSetting.macroName) > 0 then
					type = "macro"
					icon = select(2,GetMacroInfo(spellSetting.macroName))
					name = spellSetting.macroName
					button.hSpellBookID = nil
					button.hMacroName = name
				end
			end
			if type and name and icon then
				--DEBUG("show button "..i.." "..frame:GetName().."  "..name)
				button.texture:SetTexture(icon)
				button:SetAttribute("type", type)
				button:SetAttribute(type, name)
				button.hInvalid = false
			else
				--DEBUG("invalid button "..i.." "..frame:GetName())
				button.hInvalid = true
				button.hSpellBookID = spellSetting.spellID
				button.hMacroName = spellSetting.macroName
				button.texture:SetTexture("Interface/Icons/INV_Misc_QuestionMark")
				button:SetAttribute("type","target") -- action is target if spell is not valid
			end
			button:Show()
		else
			--DEBUG("hide button "..i.." "..frame:GetName())
			button.hInvalid = true
			button.hSpellBookID = nil
			button.hMacroName = nil
			button.texture:SetTexture("")
			button:Hide()
		end
	end
end

-------------------------------------------------------
-- Unitframe and healium buttons/buff/debuffs creation
-- use:
-- Update:UpdateFrameButtons, Update:UpdateFrameDebuffsPosition, Unitframes:SaveUnitframe,
-- Tooltips:ButtonOnEnter, Tooltips:BuffOnEnter, Tooltips:DebuffOnEnter, Update:PostUpdateHealth, Update:UpdateThreat
-- used by:
-- SlashCommandHandler, EventHandlers, Main
-------------------------------------------------------
local DelayedButtonsCreation = {}
-- Create heal buttons for a frame
local function CreateFrameButtons(frame)
	if not frame then return end
	if frame.hButtons then return end

	--DEBUG("CreateFrameButtons")
	if InCombatLockdown() then
		--DEBUG("CreateFrameButtons: delayed creation of frame "..frame:GetName())
		tinsert(DelayedButtonsCreation, frame)
		return
	end

	frame.hButtons = {}
	local spellSize = frame:GetHeight()
	local spellSpacing = 2
	for i = 1, MaxButtonCount, 1 do
		-- name
		local buttonName = frame:GetName().."_HealiumButton_"..i
		-- frame
		local button = CreateFrame("Button", buttonName, frame, "SecureActionButtonTemplate")
		button:CreatePanel("Default", spellSize, spellSize, "TOPLEFT", frame, "TOPRIGHT", spellSpacing, 0)
		if i == 1 then
			button:Point("TOPLEFT", frame, "TOPRIGHT", spellSpacing, 0)
		else
			button:Point("TOPLEFT", frame.hButtons[i-1], "TOPRIGHT", spellSpacing, 0)
		end
		-- texture setup, texture icon is set in UpdateFrameButtons
		button.texture = button:CreateTexture(nil, "BORDER")
		button.texture:SetTexCoord(0.08, 0.92, 0.08, 0.92)
		button.texture:SetPoint("TOPLEFT", button ,"TOPLEFT", 0, 0)
		button.texture:SetPoint("BOTTOMRIGHT", button ,"BOTTOMRIGHT", 0, 0)
		button:SetPushedTexture("Interface/Buttons/UI-Quickslot-Depress")
		button:SetHighlightTexture("Interface/Buttons/ButtonHilight-Square")
		button.texture:SetVertexColor(1, 1, 1)
		button:SetBackdropColor(0.6, 0.6, 0.6)
		button:SetBackdropBorderColor(0.1, 0.1, 0.1)
		-- cooldown overlay
		button.cooldown = CreateFrame("Cooldown", "$parentCD", button, "CooldownFrameTemplate")
		button.cooldown:SetAllPoints(button.texture)
		-- click event/action, attributes 'type' and 'spell' are set in UpdateFrameButtons
		button:RegisterForClicks("AnyUp")
		button:SetAttribute("useparent-unit","true")
		button:SetAttribute("*unit2", "target")
		-- tooltip
		if HealiumSettings.Options.showButtonTooltip then
			button:SetScript("OnEnter", ButtonOnEnter)
			button:SetScript("OnLeave", function(frame)
				GameTooltip:Hide()
			end)
		end
		-- custom
		button.hPrereqFailed = false
		button.hOOM = false
		button.hDispelHighlight = "none"
		button.hOOR = false
		button.hInvalid = true
		button.hNotUsable = false
		-- hide
		button:Hide()
		-- save button
		tinsert(frame.hButtons, button)
	end
end

-- Create debuffs for a frame
local function CreateFrameDebuffs(frame)
	if not frame then return end
	if frame.hDebuffs then return end

	--DEBUG("CreateFrameDebuffs:"..frame:GetName())
	frame.hDebuffs = {}
	local debuffSize = frame:GetHeight()
	local debuffSpacing = 2
	for i = 1, MaxDebuffCount, 1 do
		--DEBUG("Create debuff "..i)
		-- name
		local debuffName = frame:GetName().."_HealiumDebuff_"..i
		-- frame
		local debuff = CreateFrame("Frame", debuffName, frame) -- --debuff = CreateFrame("Frame", debuffName, frame, "TargetDebuffFrameTemplate")
		debuff:CreatePanel("Default", debuffSize, debuffSize, "TOPLEFT", frame, "TOPRIGHT", debuffSpacing, 0)
		if i == 1 then
			debuff:Point("TOPLEFT", frame, "TOPRIGHT", debuffSpacing, 0)
		else
			debuff:Point("TOPLEFT", frame.hDebuffs[i-1], "TOPRIGHT", debuffSpacing, 0)
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
		if HealiumSettings.Options.showBuffDebuffTooltip then
			debuff:SetScript("OnEnter", DebuffOnEnter)
			debuff:SetScript("OnLeave", function(frame)
				GameTooltip:Hide()
			end)
		end
		-- hide
		debuff:Hide()
		-- save debuff
		tinsert(frame.hDebuffs, debuff)
	end
end

-- Create buff for a frame
local function CreateFrameBuffs(frame)
	if not frame then return end
	if frame.hBuffs then return end

	--DEBUG("CreateFrameBuffs:"..frame:GetName())
	frame.hBuffs = {}
	local buffSize = frame:GetHeight()
	local buffSpacing = 2
	for i = 1, MaxBuffCount, 1 do
		local buffName = frame:GetName().."_HealiumBuff_"..i
		local buff = CreateFrame("Frame", buffName, frame) --buff = CreateFrame("Frame", buffName, frame, "TargetBuffFrameTemplate")
		buff:CreatePanel("Default", buffSize, buffSize, "TOPRIGHT", frame, "TOPLEFT", -buffSpacing, 0)
		if i == 1 then
			buff:Point("TOPRIGHT", frame, "TOPLEFT", -buffSpacing, 0)
		else
			buff:Point("TOPRIGHT", frame.hBuffs[i-1], "TOPLEFT", -buffSpacing, 0)
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
		if HealiumSettings.Options.showBuffDebuffTooltip then
			buff:SetScript("OnEnter", BuffOnEnter)
			buff:SetScript("OnLeave", function(frame)
				GameTooltip:Hide()
			end)
		end
		-- hide
		buff:Hide()
		-- save buff
		tinsert(frame.hBuffs, buff)
	end
end

-- Create delayed frames
local function CreateDelayedButtons()
	if InCombatLockdown() then return false end
	--DEBUG("CreateDelayedButtons:"..tostring(DelayedButtonsCreation).."  "..(#DelayedButtonsCreation))
	if not DelayedButtonsCreation or #DelayedButtonsCreation == 0 then return false end

	for _, frame in ipairs(DelayedButtonsCreation) do
		--DEBUG("Delayed frame creation for "..frame:GetName())
		if not frame.hButtons then
			CreateFrameButtons(frame)
		--else
			--DEBUG("Frame already created for "..frame:GetName())
		end
	end
	DelayedButtonsCreation = {}
	return true
end

local function CreateUnitframe(self, unit)
	--Message("CreateUnitframe: "..(unit or "nil").."  "..self:GetName())

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

	health.PostUpdate = PostUpdateHealth
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

	--t:SetTexture("Interface\\TargetingFrame\\UI-RaidTargetingIcons");
	--SetRaidTargetIconTexture(t,i);
	local LFDRole = health:CreateTexture(nil, "OVERLAY")
	LFDRole:Height(6*T.raidscale)
	LFDRole:Width(6*T.raidscale)
	LFDRole:Point("TOPRIGHT", -2, -2)
	LFDRole:SetTexture("Interface\\AddOns\\Tukui\\medias\\textures\\lfdicons.blp")
	self.LFDRole = LFDRole

	local masterLooter = health:CreateTexture(nil, "OVERLAY")
	masterLooter:Height(12*T.raidscale)
	masterLooter:Width(12*T.raidscale)
	self.MasterLooter = masterLooter
	self:RegisterEvent("PARTY_LEADER_CHANGED", T.MLAnchorUpdate)
	self:RegisterEvent("PARTY_MEMBERS_CHANGED", T.MLAnchorUpdate)

	if C["unitframes"].aggro == true then
		tinsert(self.__elements, UpdateThreat)
		self:RegisterEvent('PLAYER_TARGET_CHANGED', UpdateThreat)
		self:RegisterEvent('UNIT_THREAT_LIST_UPDATE', UpdateThreat)
		self:RegisterEvent('UNIT_THREAT_SITUATION_UPDATE', UpdateThreat)
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

	local unitframeWidth = HealiumSettings.Options.unitframeWidth or 120
	if C["unitframes"].healcomm then
		local mhpb = CreateFrame('StatusBar', nil, self.Health)
		mhpb:SetPoint('TOPLEFT', self.Health:GetStatusBarTexture(), 'TOPRIGHT', 0, 0)
		mhpb:SetPoint('BOTTOMLEFT', self.Health:GetStatusBarTexture(), 'BOTTOMRIGHT', 0, 0)
		mhpb:SetWidth(unitframeWidth*T.raidscale)
		mhpb:SetStatusBarTexture(C["media"].normTex)
		mhpb:SetStatusBarColor(0, 1, 0.5, 0.25)

		local ohpb = CreateFrame('StatusBar', nil, self.Health)
		ohpb:SetPoint('TOPLEFT', mhpb:GetStatusBarTexture(), 'TOPRIGHT', 0, 0)
		ohpb:SetPoint('BOTTOMLEFT', mhpb:GetStatusBarTexture(), 'BOTTOMRIGHT', 0, 0)
		ohpb:SetWidth(unitframeWidth*T.raidscale)
		ohpb:SetStatusBarTexture(C["media"].normTex)
		ohpb:SetStatusBarColor(0, 1, 0, 0.25)

		self.HealPrediction = {
			myBar = mhpb,
			otherBar = ohpb,
			maxOverflow = 1,
		}
	end

	-- Healium frames
	-- ==============
	-- heal buttons
	CreateFrameButtons(self)

	-- healium debuffs
	if HealiumSettings.Options.showDebuff then
		CreateFrameDebuffs(self)
	end

	-- healium buffs
	if HealiumSettings.Options.showBuff then
		CreateFrameBuffs(self)
	end

	-- update healium buttons visibility, icon and attributes
	UpdateFrameButtons(self)

	-- update debuff position
	UpdateFrameDebuffsPosition(self)

	-- update buff/debuff/special spells
	--UpdateFrameBuffsDebuffsPrereqs(self) -- unit not yet set, unit passed as argument is "raid" instead of player or party1 or ...

	-- custom
	self.hDisabled = false

	-- save frame in healium frame list
	SaveUnitframe(self)

	return self
end

-------------------------------------------------------
-- Slash command handler
-- use:
-- Helpers:Message, DumpSack:Flush, DumpSack:Add, PerformanceCounter:Get, DumpSack:Show, PerformanceCounter:Reset, Helpers:ForEachMember
-- Settings:GetSpecSettings(), Settings:CheckSpellSettings(), Create:CreateDelayedButtons(), Unitframes:ForEachUnitframe, Update:UpdateFrameButtons,
-- Update:UpdateFrameDebuffsPosition, Update:UpdateFrameBuffsDebuffsPrereqs, Update:UpdateCooldowns(), Update:UpdateOOMSpells, Update:UpdateOORSpells,
-- PlayerRaidHeader, PetRaidHeader, TankRaidHeader, NamelistRaidHeader, Helpers:AddToNamelist, Helpers:RemoveFromNamelist, Unitframes:GetUnitframesFromUnit
-- used by:
-- none
-------------------------------------------------------
local LastPerformanceCounterReset = GetTime()
local function SlashHandlerShowHelp()
	Message(string.format(L.healium_CONSOLE_HELP_GENERAL, SLASH_THLM1, SLASH_THLM2))
	Message(SLASH_THLM1..L.healium_CONSOLE_HELP_DEBUG)
	Message(SLASH_THLM1..L.healium_CONSOLE_HELP_DUMPGENERAL)
	Message(SLASH_THLM1..L.healium_CONSOLE_HELP_DUMPUNIT)
	Message(SLASH_THLM1..L.healium_CONSOLE_HELP_DUMPPERF)
	Message(SLASH_THLM1..L.healium_CONSOLE_HELP_DUMPSHOW)
	Message(SLASH_THLM1..L.healium_CONSOLE_HELP_RESETPERF)
	Message(SLASH_THLM1..L.healium_CONSOLE_HELP_REFRESH)
	Message(SLASH_THLM1..L.healium_CONSOLE_HELP_TOGGLE)
	Message(SLASH_THLM1..L.healium_CONSOLE_HELP_NAMELISTADD)
	Message(SLASH_THLM1..L.healium_CONSOLE_HELP_NAMELISTREMOVE)
	Message(SLASH_THLM1..L.healium_CONSOLE_HELP_NAMELISTCLEAR)
end

local function SlashHandlerDump(args)
	local function DumpFrame(frame)
		if not frame then return end
		DumpSack:Add("Frame "..tostring(frame:GetName()).." S="..tostring(frame:IsShown()).." U="..tostring(frame.unit).." D="..tostring(frame.hDisabled).." PS="..tostring(frame:GetParent():IsShown()))
		if frame.hButtons then
			DumpSack:Add("Buttons")
			for i, button in ipairs(frame.hButtons) do
				if button:IsShown() then
					DumpSack:Add("  "..i.." SID="..tostring(button.hSpellBookID).." MN="..tostring(button.hMacroName).." D="..tostring(button.hPrereqFailed).." NM="..tostring(button.hOOM).." DH="..tostring(button.hDispelHighlight).." OOR="..tostring(button.hOOR).." NU="..tostring(button.hNotUsable).." I="..tostring(button.hInvalid))
				end
			end
		else
			DumpSack:Add("Healium buttons not created")
		end
		if frame.hDebuffs then
			DumpSack:Add("Debuffs")
			for i, debuff in ipairs(frame.hDebuffs) do
				if debuff:IsShown() then
					DumpSack:Add("  "..i.." ID="..tostring(debuff:GetID()).." U="..tostring(debuff.unit))
				end
			end
		else
			DumpSack:Add("Healium debuffs not created")
		end
		if frame.hBuffs then
			DumpSack:Add("Buffs")
			for i, buff in ipairs(frame.hBuffs) do
				if buff:IsShown() then
					DumpSack:Add("  "..i.." ID="..tostring(buff:GetID()).." U="..tostring(buff.unit))
				end
			end
		else
			DumpSack:Add("Healium buffs not created")
		end
	end
	if not args then
		ForEachMember(DumpFrame)
		DumpSack:Flush("TukuiHealium")
	elseif args == "perf" then
		local time = GetTime()
		local counters = PerformanceCounter:Get("TukuiHealium")
		if not counters then
			DumpSack:Add("No performance counters")
			DumpSack:Flush("TukuiHealium")
		else
			local timespan = GetTime() - LastPerformanceCounterReset
			local header = "Performance counters. Elapsed=%.2fsec"
			local line = "%s=#%d L:%.4f  H:%.2f -> %.2f/sec"
			table.sort(counters, function(a, b)
				print("comparing "..a.count.."  and "..b.count) -- TODO: DEBUG this
				return a.count < b.count
			end)
			DumpSack:Add(header:format(timespan))
			for key, value in pairs(counters) do
				local count = value.count or 1
				local lowestSpan = value.lowestSpan or 0
				local highestSpan = value.highestSpan or 0
				DumpSack:Add(line:format(key, count, lowestSpan, highestSpan, count/timespan))
			end
			DumpSack:Flush("TukuiHealium")
		end
	elseif args == "show" then
		DumpSack:Show()
	else
		local frames = GetUnitframesFromUnit(args)
		if frames then
			for _, frame in ipairs(frames) do
			--if frame then
				DumpFrame(frame)
				DumpSack:Flush("TukuiHealium")
			end
		else
			Message(string.format(L.healium_CONSOLE_DUMP_UNITNOTFOUND,args))
		end
	end
end

local function SlashHandlerReset(args)
	if args == "perf" then
		PerformanceCounter:Reset("TukuiHealium")
		LastPerformanceCounterReset = GetTime()
		Message(L.healium_CONSOLE_RESET_PERF)
	end
end

local function SlashHandlerRefresh(args)
	if InCombatLockdown() then
		Message(L.healium_NOTINCOMBAT)
	else
		GetSpecSettings()
		CheckSpellSettings()
		CreateDelayedButtons()
		ForEachUnitframe(UpdateFrameButtons)
		ForEachUnitframe(UpdateFrameDebuffsPosition)
		ForEachUnitframe(UpdateFrameBuffsDebuffsPrereqs)
		UpdateCooldowns()
		if HealiumSettings.Options.showOOM then
			UpdateOOMSpells()
		end
		if HealiumSettings.Options.showOOR then
			UpdateOORSpells()
		end
		Message(L.healium_CONSOLE_REFRESH_OK)
	end
end

local function SlashHandlerToggle(args)
	if InCombatLockdown() then
		Message(L.healium_NOTINCOMBAT)
		return
	end
	if args == "raid" then
		ToggleHeader(PlayerRaidHeader)
	elseif args == "tank" then
		ToggleHeader(TankRaidHeader)
	elseif args == "pet" then
		ToggleHeader(PetRaidHeader)
	elseif args == "namelist" then
		ToggleHeader(NamelistRaidHeader)
	else
		Message(L.healium_CONSOLE_TOGGLE_INVALID)
	end
end

local function SlashHandlerNamelist(cmd)
	local function NamelistAdd(args)
		local name = args
		if not name then
			local realm
			name, realm = UnitName("target")
			if realm ~= nil then
				if realm:len() > 0 then
					name = name.."-".. realm
				end
			end
		end
		if name then
			local fAdded = AddToNamelist(HealiumSettings.Options.namelist, name)
			if not fAdded then
				Message(L.healium_CONSOLE_NAMELIST_ADDALREADY)
			else
				Message(L.healium_CONSOLE_NAMELIST_ADDED:format(name))
				if NamelistRaidHeader then
					NamelistRaidHeader:SetAttribute("namelist", HealiumSettings.Options.namelist)
				end
			end
		else
			Message(L.healium_CONSOLE_NAMELIST_ADDREMOVEINVALID)
		end
	end

	local function NamelistRemove(args)
		local name = args
		if not name then
			local _, playerRealm = UnitName("player")
			local targetName, targetRealm = UnitName("target")
			if targetName and (targetRealm == nil or playerRealm == targetRealm)  then
				name = targetName
			end
		end
		if name then
			local fRemoved = RemoveFromNamelist(HealiumSettings.Options.namelist, name)
			if not fRemoved then
				Message(L.healium_CONSOLE_NAMELIST_REMOVENOTFOUND)
			else
				Message(L.healium_CONSOLE_NAMELIST_REMOVED:format(name))
				if NamelistRaidHeader then
					NamelistRaidHeader:SetAttribute("namelist", HealiumSettings.Options.namelist)
				end
			end
		else
			Message(L.healium_CONSOLE_NAMELIST_ADDREMOVEINVALID)
		end
	end

	local function NamelistClear()
		HealiumSettings.Options.namelist = ""
		if NamelistRaidHeader then
			NamelistRaidHeader:SetAttribute("namelist", list)
		end
	end

	local switch = cmd:match("([^ ]+)")
	local args = cmd:match("[^ ]+ (.+)")

	if switch == "add" then
		NamelistAdd(args)
	elseif switch == "remove" or switch == "rem" then
		NamelistRemove(args)
	elseif switch == "clear" then
		NamelistClear()
	else
		Message(L.healium_CONSOLE_NAMELIST_INVALIDOPTION)
	end
end


SLASH_THLM1 = "/th"
SLASH_THLM2 = "/thlm"
SlashCmdList["THLM"] = function(cmd)
	local switch = cmd:match("([^ ]+)")
	local args = cmd:match("[^ ]+ (.+)")
	-- debug: switch Debug
	if switch == "debug" then
		Debug = not Debug
		Message(Debug == false and L.healium_CONSOLE_DEBUG_DISABLED or L.healium_CONSOLE_DEBUG_ENABLED)
	-- DumpSack: dump frame/button/buff/debuff informations
	elseif switch == "dump" then
		SlashHandlerDump(args)
	elseif switch == "reset" then
		SlashHandlerReset(args)
	elseif switch == "refresh" then
		SlashHandlerRefresh(args)
	elseif switch == "toggle" then
		SlashHandlerToggle(args)
	elseif switch == "namelist" then
		SlashHandlerNamelist(args)
	else
		SlashHandlerShowHelp()
	end
end

-------------------------------------------------------
-- TabMenu with Dropdown list
-- use:
-- TankRaidHeader, PetRaidHeader, NamelistRaidHeader, Tukui_TabMenu:AddCustomTab
-- used by:
-- none
-------------------------------------------------------
if HealiumSettings.showTab and TabMenu and TukuiChatBackgroundRight then
	local function MenuToggleHeader(info, header)
		if InCombatLockdown() then
			Message(L.healium_NOTINCOMBAT)
			return
		end
		ToggleHeader(header)
	end
	-- menu function (see Interface\Addons\Healium\HealiumMenu.lua  and  http://www.wowwiki.com/Using_UIDropDownMenu)
	local function MenuInitializeDropDown(self, level)
		level = level or 1
		local info
		if level == 1 then
			info = UIDropDownMenu_CreateInfo()
			info.text = L.healium_TAB_TITLE
			info.isTitle = 1
			info.owner = self:GetParent()
			info.func = MenuToggleHeader
			info.arg1 = TankRaidHeader
			UIDropDownMenu_AddButton(info, level)
			if PlayerRaidHeader then
				info = UIDropDownMenu_CreateInfo()
				info.text = PlayerRaidHeader:IsShown() and L.healium_TAB_PLAYERFRAMEHIDE or L.healium_TAB_PLAYERFRAMESHOW
				info.notCheckable = 1
				info.owner = self:GetParent()
				info.func = MenuToggleHeader
				info.arg1 = PlayerRaidHeader
				UIDropDownMenu_AddButton(info, level)
			end
			if TankRaidHeader then
				info = UIDropDownMenu_CreateInfo()
				info.text = TankRaidHeader:IsShown() and L.healium_TAB_TANKFRAMEHIDE or L.healium_TAB_TANKFRAMESHOW
				info.notCheckable = 1
				info.owner = self:GetParent()
				info.func = MenuToggleHeader
				info.arg1 = TankRaidHeader
				UIDropDownMenu_AddButton(info, level)
			end
			if PetRaidHeader then
				info = UIDropDownMenu_CreateInfo()
				info.text = PetRaidHeader:IsShown() and L.healium_TAB_PETFRAMEHIDE or L.healium_TAB_PETFRAMESHOW
				info.notCheckable = 1
				info.owner = self:GetParent()
				info.func = MenuToggleHeader
				info.arg1 = PetRaidHeader
				UIDropDownMenu_AddButton(info, level)
			end
			if NamelistRaidHeader then
				info = UIDropDownMenu_CreateInfo()
				info.text = NamelistRaidHeader:IsShown() and L.healium_TAB_NAMELISTFRAMEHIDE or L.healium_TAB_NAMELISTFRAMESHOW
				info.notCheckable = 1
				info.owner = self:GetParent()
				info.func = MenuToggleHeader
				info.arg1 = NamelistRaidHeader
				UIDropDownMenu_AddButton(info, level)
			end
			info = UIDropDownMenu_CreateInfo()
			info.text = CLOSE
			info.owner = self:GetParent()
			info.func = self.HideMenu
			UIDropDownMenu_AddButton(info, level)
		end
	end

	local tab = TabMenu:AddCustomTab(TukuiChatBackgroundRight, "LEFT", "Healium", "Interface\\AddOns\\Tukui_Raid_Healing\\medias\\ability_druid_improvedtreeform")

	-- create menu frame
	local menu = CreateFrame("Frame", "HealiumMenu", tab, "UIDropDownMenuTemplate")
	menu:SetPoint("BOTTOM", tab, "TOP")
	UIDropDownMenu_Initialize(menu, MenuInitializeDropDown, "MENU")
	-- events
	tab:SetScript("OnEnter", function(self)
		GameTooltip:SetOwner(self, "ANCHOR_TOP", 0, T.Scale(6))
		GameTooltip:ClearAllPoints()
		GameTooltip:SetPoint("BOTTOM", self, "TOP", 0, T.mult)
		GameTooltip:ClearLines()
		GameTooltip:AddLine(L.healium_TAB_TOOLTIP, 1, 1, 1)
		GameTooltip:Show()
	end)
	tab:SetScript("OnLeave", function(self) GameTooltip:Hide() end)
	tab:SetScript("OnClick", function(self, button)
		GameTooltip:Hide()
		ToggleDropDownMenu(1, nil, menu, self, 0, 100)
	end)
end

-------------------------------------------------------
-- Handle healium specific events
-- use:
-- PerformanceCounter:Increment, Settings:GetSpecSettings, Settings:CheckSpellSettings, Unitframes:ForEachUnitframe, Update:UpdateFrameButtons,
-- Update:UpdateFrameDebuffsPosition, Update:UpdateFrameBuffsDebuffsPrereqs, Update:UpdateCooldowns, Unitframes:GetUnitframesFromUnit, Update:UpdateOOMSpells,
-- Update:UpdateOORSpells
-- used by:
-- none
-------------------------------------------------------

local fSettingsChecked = false -- stupid workaround  (when /reloadui PLAYER_ALIVE is not called)
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
healiumEventHandler:RegisterEvent("UNIT_MAXPOWER")
--healiumEventHandler:RegisterEvent("SPELL_UPDATE_USABLE")
healiumEventHandler:RegisterEvent("PLAYER_LOGIN")
healiumEventHandler:RegisterEvent("UNIT_SPELLCAST_SENT")
healiumEventHandler:RegisterEvent("UNIT_SPELLCAST_INTERRUPTED")
healiumEventHandler:RegisterEvent("UNIT_SPELLCAST_SUCCEEDED")
--healiumEventHandler:RegisterEvent("SPELLS_CHANGED")
healiumEventHandler:RegisterEvent("PLAYER_ALIVE")
healiumEventHandler:SetScript("OnEvent", function(self, event, arg1, arg2, arg3)
	--DEBUG("Event: "..event)
	PerformanceCounter:Increment("TukuiHealium", event)

	if event == "ADDON_LOADED" and arg1 == ADDON_NAME then
		--DEBUG("ADDON_LOADED:"..tostring(GetPrimaryTalentTree()).."  "..tostring(IsSpellLearned(974)).."  "..tostring(IsLoggedIn()))
		local version = GetAddOnMetadata(ADDON_NAME, "version")
		if version then
			Message(string.format(L.healium_GREETING_VERSION, tostring(version)))
		else
			Message(L.healium_GREETING_VERSIONUNKNOWN)
		end
		Message(L.healium_GREETING_OPTIONS)
		GetSpecSettings()
	elseif event == "PLAYER_LOGIN" then
		--DEBUG("PLAYER_LOGIN:"..tostring(GetPrimaryTalentTree()).."  "..tostring(IsSpellLearned(974)).."  "..tostring(IsLoggedIn()))
		GetSpecSettings()
		if SpecSettings then
			fSettingsChecked = true
			CheckSpellSettings()
		end
	elseif event == "PLAYER_ALIVE" then
		--DEBUG("PLAYER_ALIVE:"..tostring(GetPrimaryTalentTree()).."  "..tostring(IsSpellLearned(974)).."  "..tostring(IsLoggedIn()))
		GetSpecSettings()
		if SpecSettings and not fSettingsChecked then
			CheckSpellSettings()
		end
		ForEachUnitframe(UpdateFrameButtons)
		ForEachUnitframe(UpdateFrameDebuffsPosition)
		ForEachUnitframe(UpdateFrameBuffsDebuffsPrereqs)
	elseif event == "PLAYER_ENTERING_WORLD" then
		--DEBUG("PLAYER_ENTERING_WORLD:"..tostring(GetPrimaryTalentTree()).."  "..tostring(IsSpellLearned(974)).." "..tostring(self.hRespecing).."  "..tostring(IsLoggedIn()))
		ForEachUnitframe(UpdateFrameButtons)
		ForEachUnitframe(UpdateFrameDebuffsPosition)
		ForEachUnitframe(UpdateFrameBuffsDebuffsPrereqs)
	elseif event == "PARTY_MEMBERS_CHANGED" or event == "RAID_ROSTER_UPDATE" then
		ForEachUnitframe(UpdateFrameButtons)
		ForEachUnitframe(UpdateFrameDebuffsPosition)
		ForEachUnitframe(UpdateFrameBuffsDebuffsPrereqs)
	elseif event == "PLAYER_REGEN_ENABLED" then
		--DEBUG("PLAYER_REGEN_ENABLED")
		local created = CreateDelayedButtons()
		if created then
			ForEachUnitframe(UpdateFrameButtons)
			ForEachUnitframe(UpdateFrameDebuffsPosition)
			ForEachUnitframe(UpdateFrameBuffsDebuffsPrereqs)
		end
	elseif event == "UNIT_SPELLCAST_SENT" and (arg2 == ActivatePrimarySpecSpellName or arg2 == ActivateSecondarySpecSpellName) then
		--DEBUG("UNIT_SPELLCAST_SENT:"..tostring(GetPrimaryTalentTree()).."  "..tostring(IsSpellLearned(974)).." "..tostring(self.hRespecing))
		self.hRespecing = 1 -- respec started
	elseif (event == "UNIT_SPELLCAST_INTERRUPTED" or event == "UNIT_SPELLCAST_SUCCEEDED") and arg1 == "player" and (arg2 == ActivatePrimarySpecSpellName or arg2 == ActivateSecondarySpecSpellName) then
		--DEBUG("UNIT_SPELLCAST_INTERRUPTED:"..tostring(GetPrimaryTalentTree()).."  "..tostring(IsSpellLearned(974)).." "..tostring(self.hRespecing))
		self.hRespecing = nil --> respec stopped
	elseif event == "PLAYER_TALENT_UPDATE" then
		--DEBUG("PLAYER_TALENT_UPDATE:"..tostring(GetPrimaryTalentTree()).."  "..tostring(IsSpellLearned(974)).." "..tostring(self.hRespecing))
		if self.hRespecing == 2 then -- respec finished
			GetSpecSettings()
			CheckSpellSettings()
			ForEachUnitframe(UpdateFrameButtons)
			ForEachUnitframe(UpdateFrameDebuffsPosition)
			ForEachUnitframe(UpdateFrameBuffsDebuffsPrereqs)
			self.hRespecing = nil -- no respec running
		elseif self.hRespecing == 1 then -- respec not yet finished
			self.hRespecing = 2 -- respec finished
		else -- respec = nil, not respecing (called while connecting)
			GetSpecSettings()
			ForEachUnitframe(UpdateFrameButtons)
			ForEachUnitframe(UpdateFrameDebuffsPosition)
			ForEachUnitframe(UpdateFrameBuffsDebuffsPrereqs)
		end
	-- --elseif event == "SPELLS_CHANGED" and not self.hRespecing then
	-- elseif event == "SPELLS_CHANGED" then
		-- DEBUG("SPELLS_CHANGED:"..tostring(GetPrimaryTalentTree()).."  "..IsSpellLearned(974).." "..tostring(self.hRespecing))
		-- -- ForEachUnitframe(UpdateFrameButtons)
		-- -- ForEachUnitframe(UpdateFrameDebuffsPosition)
	-- end
	elseif event == "SPELL_UPDATE_COOLDOWN" then -- TODO: use SPELL_UPDATE_USABLE instead ?
		--DEBUG("SPELL_UPDATE_COOLDOWN:"..tostring(arg1).."  "..tostring(arg2).."  "..tostring(arg2))
		UpdateCooldowns()
	elseif event == "UNIT_AURA" then
		local frames = GetUnitframesFromUnit(arg1) -- Get frames from unit
		if frames then
			for _, frame in ipairs(frames) do
				if frame:IsShown() then UpdateFrameBuffsDebuffsPrereqs(frame) end -- Update buff/debuff only for unit
			end
		end
		--if frame and frame:IsShown() then UpdateFrameBuffsDebuffsPrereqs(frame) end -- Update buff/debuff only for unit
	elseif (event == "UNIT_POWER" or event == "UNIT_MAXPOWER") and arg1 == "player" then-- or event == "SPELL_UPDATE_USABLE" then
		if HealiumSettings.Options.showOOM then
			UpdateOOMSpells()
		end
	end
end)

if HealiumSettings.Options.showOOR then
	healiumEventHandler.hTimeSinceLastUpdate = GetTime()
	healiumEventHandler:SetScript("OnUpdate", function (self, elapsed)
		self.hTimeSinceLastUpdate = self.hTimeSinceLastUpdate + elapsed
		if self.hTimeSinceLastUpdate > UpdateDelay then
			if HealiumSettings.Options.showOOR then
				UpdateOORSpells()
			end
			self.hTimeSinceLastUpdate = 0
		end
	end)
end

-------------------------------------------------------
-- Main
-- use:
-- Settings:InitializeSettings, PlayerRaidHeader, PetRaidHeader, TankRaidHeader, NamelistRaidHeader, Create:CreateUnitframe
-- used by:
-- none
-------------------------------------------------------

-- Remove unused section, get spellName from spellID, update buff/debuff lists, set default value
InitializeSettings()

-- Register style
oUF:RegisterStyle('TukuiHealiumR01R25', CreateUnitframe)

-- Set unitframe creation handler
oUF:Factory(function(self)
	oUF:SetActiveStyle("TukuiHealiumR01R25")

	local unitframeWidth = HealiumSettings.Options.unitframeWidth or 120
	local unitframeHeight = HealiumSettings.Options.unitframeHeight or 28

	-- Players
	PlayerRaidHeader = self:SpawnHeader("oUF_TukuiHealiumRaid0125", nil, Visibility25,
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
	PlayerRaidHeader:SetPoint("TOPLEFT", UIParent, "TOPLEFT", 150, -300*T.raidscale)
	PlayerRaidHeader.hVisibilityAttribute = Visibility25

	-- Pets, no pets in a group with 10 or more players
	if HealiumSettings.Options.showPets then
		PetRaidHeader = self:SpawnHeader("oUF_TukuiHealiumRaidPet0125", "SecureGroupPetHeaderTemplate", Visibility10,
			'oUF-initialConfigFunction', [[
				local header = self:GetParent()
				self:SetWidth(header:GetAttribute('initial-width'))
				self:SetHeight(header:GetAttribute('initial-height'))
			]],
			'initial-width', T.Scale(unitframeWidth*T.raidscale),--T.Scale(66*C["unitframes"].gridscale*T.raidscale),
			'initial-height', T.Scale(unitframeHeight*T.raidscale),--T.Scale(50*C["unitframes"].gridscale*T.raidscale),
			"showSolo", C["unitframes"].showsolo,
			"showParty", true,
			--"showPlayer", C["unitframes"].showplayerinparty,
			"showRaid", true,
			--"xoffset", T.Scale(3),
			"yOffset", T.Scale(-4),
			--"point", "LEFT",
			"groupFilter", "1,2,3,4,5,6,7,8",
			"groupingOrder", "1,2,3,4,5,6,7,8",
			"groupBy", "GROUP",
			--"maxColumns", 8,
			--"unitsPerColumn", 5,
			--"columnSpacing", T.Scale(3),
			--"columnAnchorPoint", "TOP",
			"filterOnPet", true,
			"sortMethod", "NAME"
		)
		PetRaidHeader:SetPoint("TOPLEFT", PlayerRaidHeader, "BOTTOMLEFT", 0, -50)
		PetRaidHeader.hVisibilityAttribute = Visibility10
	end

	if HealiumSettings.Options.showTanks then
		-- Tank frame (attributes: [["groupFilter", "MAINTANK,TANK"]],  [["groupBy", "ROLE"]],    showParty, showRaid but not showSolo)
		TankRaidHeader = self:SpawnHeader("oUF_TukuiHealiumRaidTank0125", nil, Visibilityl25,
			'oUF-initialConfigFunction', [[
				local header = self:GetParent()
				self:SetWidth(header:GetAttribute('initial-width'))
				self:SetHeight(header:GetAttribute('initial-height'))
			]],
			'initial-width', T.Scale(unitframeWidth*T.raidscale),--T.Scale(66*C["unitframes"].gridscale*T.raidscale),
			'initial-height', T.Scale(unitframeHeight*T.raidscale),--T.Scale(50*C["unitframes"].gridscale*T.raidscale),
			"showSolo", false,
			"showParty", true,
			"showRaid", true,
			"showPlayer", C["unitframes"].showplayerinparty,
			"yOffset", T.Scale(-4),
			--"groupingOrder", "1,2,3,4,5,6,7,8",
			"groupFilter", "MAINTANK,TANK",
			--"groupBy", "ROLE",
			"sortMethod", "NAME"
		)
		TankRaidHeader:SetPoint("BOTTOMLEFT", PlayerRaidHeader, "TOPLEFT", 0, 50)
		TankRaidHeader.hVisibilityAttribute = Visibility25
	end

	if HealiumSettings.Options.showNamelist and HealiumSettings.Options.namelist then
		-- Namelist frame
		NamelistRaidHeader = self:SpawnHeader("oUF_TukuiHealiumRaidNamelist0125", nil, Visibility25,
			'oUF-initialConfigFunction', [[
				local header = self:GetParent()
				self:SetWidth(header:GetAttribute('initial-width'))
				self:SetHeight(header:GetAttribute('initial-height'))
			]],
			'initial-width', T.Scale(unitframeWidth*T.raidscale),--T.Scale(66*C["unitframes"].gridscale*T.raidscale),
			'initial-height', T.Scale(unitframeHeight*T.raidscale),--T.Scale(50*C["unitframes"].gridscale*T.raidscale),
			"showSolo", C["unitframes"].showsolo,
			"showParty", true,
			"showRaid", true,
			"showPlayer", C["unitframes"].showplayerinparty,
			"yOffset", T.Scale(-4),
			"sortMethod", "NAME",
			"unitsPerColumn", 20,
			"nameList", HealiumSettings.Options.namelist
		)
		NamelistRaidHeader:SetPoint("TOPRIGHT", UIParent, "TOPRIGHT", -400, -300*T.raidscale)
		NamelistRaidHeader.hVisibilityAttribute = Visibility25
	end
end)