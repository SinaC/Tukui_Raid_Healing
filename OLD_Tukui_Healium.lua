local ADDON_NAME, ns = ...
local oUF = oUFTukui or oUF

local T, C, L = unpack(Tukui) -- Import: T - functions, constants, variables; C - config; L - locales

--http://www.wowwiki.com/World_of_Warcraft_API

-- TO TEST
-- buff (must implemented move tukui raid frame to test) -> OK
-- debuff -> OK
-- cd -> OK
-- button -> OK
-- cure + dispel -> OK
-- incoming heal ==> C["unitframes"].healcomm
-- aggro ==> C["unitframes"].aggro
-- disable tukui raid debuff/buff/hots   see \Tukui_Raid_Healing\oUF_hTukz_Raid01_15.lua:139   frame.Debuffs = nil  OK
-- mana ==> included in oUF  -> OK
-- special spells (swiftmend allowed if rejuv or regrowth on member) (see settings) -> OK

-- TODO: 
-- move tukui raid frame  see \Tukui\modules\unitframes\plugins\oUF_MovableFrames\movable.lua:372 and \Tukui\core\movers.lua
-- range: Tukui\Tukui\modules\unitframes\core\oUF\elements\range.lua
-- avoid using _G[] to get raid frame, use a local list
-- spell/buff/debuff tooltip (see Healium_HealButton_OnEnter in HealiumHealButton)
-- spell must be learned to appear in button (question-mark if not learned)
--		http://www.wowwiki.com/API_GetSpellBookItemInfo
--		http://www.wowwiki.com/API_GetSpellBookItemInfo
--		http://www.wowwiki.com/API_IsUsableSpell
--		local name = GetSpellInfo(spellID)		--> http://www.wowwiki.com/API_GetSpellInfo
--		local isLearned = GetSpellInfo(name)	--> http://www.wowwiki.com/API_GetSpellInfo
-- use spec name instead of spec ID in settings => DOESNT WORK spec name is localized

if C["gridonly"] then return end
if not HealiumSettings[T.myclass] then return end

-------------------------------------------------------
-- Constants
-------------------------------------------------------
local THDebug = true
local MaxButtonCount = 10
local MaxDebuffCount = 8
local MaxBuffCount = 6

-------------------------------------------------------
-- Variables
-------------------------------------------------------
local DelayedHealiumFrameCreation = {}

-------------------------------------------------------
-- Helpers
-------------------------------------------------------
local function ERROR(line)
	print("|CFFFF0000Tukui_Healium|r: ERROR - "..line)
end

local function WARNING(line)
	print("|CFF00FFFFTukui_Healium|r: WARNING - "..line)
end

local function DEBUG(line)
	if not THDebug or THDebug == false then return end
	print("|CFF00FF00Tukui_Healium|r: DEBUG - "..line)
end

-- Return settings for current spec
local function GetSettings()
	local ptt = GetPrimaryTalentTree()
	if not ptt then return end
	-- local settings
	-- if ptt > 0 then
		-- -- search by name
		-- local _, name = GetTalentTabInfo(ptt)
		-- DEBUG("GetSettings spec name:"..name)
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
	-- players
	local numMembers = GetNumMembers()
	for i = 1, numMembers, 1 do
		local frameName = (numMembers > 15) and ("TukuiGridUnitButton"..i) or ("oUF_TukuiHealRaid0115UnitButton"..i)
		local frame = _G[frameName]
		if frame then
			if frame.unit == unit then
				return frame
			end
		else
			DEBUG("GetFrameFromUnit: Raid Frame:"..frameName.." not found")
		end
	end
	-- -- pets
	-- for i = 1, 40, 1 do
		-- local frameName = "oUF_TukuiPartyPet"..i
		-- local frame = _G[frameName]
		-- if frame then
			-- if frame.unit == unit then
				-- return frame
			-- end
		-- else
			-- break
		-- end
	-- end
	return
end

-- Loop among every members in party/raid and call a function
local function ForEachMember(fct, ...)
	-- players
	local numMembers = GetNumMembers()
	for i = 1, numMembers, 1 do
		local frameName = (numMembers > 15) and ("TukuiGridUnitButton"..i) or ("oUF_TukuiHealRaid0115UnitButton"..i)
		local frame = _G[frameName]
		if frame then
			fct(frame, ...)
		else
			DEBUG("ForEachMember Raid Frame:"..frameName.." not found")
		end
	end
	-- -- pets
	-- for i = 1, 40, 1 do
		-- local frameName = "oUF_TukuiPartyPet"..i
		-- local frame = _G[frameName]
		-- if frame then
			-- fct(frame, ...)
		-- else
			-- break
		-- end
	-- end
end

-------------------------------------------------------
-- Healium functions
-------------------------------------------------------
-- Update healium button cooldown
local function UpdateHealiumFrameCooldown(frame, index, start, duration, enabled)
	--DEBUG("frame:"..(frame and frame:GetName() or "nil").." index:"..(index or "nil").." start:"..(start or "nil").." duration:"..(duration or "nil").." enabled:"..(enabled or "nil"))
	local button = frame.healiumButtons[index]
	--DEBUG("button:"..(button and button:GetName() or "nil").." cooldown:"..(button.cooldown and "ok" or "nil"))
	CooldownFrame_SetTimer(button.cooldown, start, duration, enabled)
end

-- Update healium frame buff/debuff and special spells
local function UpdateHealiumFrameBuffsDebuffsSpecialSpells(frame)
	local settings = GetSettings()
	local unit = frame.unit

	--DEBUG("UpdateHealiumFrameBuffsDebuffsSpecialSpells:.."..(unit or "nil"))

	-- reset vertex, border and backdrop color
	if frame.healiumButtons then
		for index, button in ipairs(frame.healiumButtons) do
			button.texture:SetVertexColor(1, 1, 1)
			button:SetBackdropColor(0.6, 0.6, 0.6)
			button:SetBackdropBorderColor(0.1, 0.1, 0.1)
		end
	end

	-- buff
	local buffs = {}
	if frame.healiumBuffs then
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
			debuffType = "Curse" -- TODO: remove
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
	if frame.healiumButtons then
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

-- Update healium frame debuff position
local function UpdateHealiumFrameDebuffsPosition(frame)
	--DEBUG("Update debuff position for "..frame:GetName())
	if not frame.healiumDebuffs then return end
	local settings = GetSettings()
	local lastButton = frame.healiumButtons[#settings.spells]
	local firstDebuff = frame.healiumDebuffs[1]
	--DEBUG("lastButton: "..lastButton:GetName().."  firstDebuff: "..firstDebuff:GetName())
	local debuffSpacing = settings and settings.debuffSpacing or frame:GetHeight()
	firstDebuff:ClearAllPoints()
	firstDebuff:Point("TOPLEFT", lastButton, "TOPRIGHT", debuffSpacing, 0)
end

-- Update healium frame buttons, set texture, extra attributes and show/hide.
local function UpdateHealiumFrameButtons(frame)
	DEBUG("Update frame buttons for "..frame:GetName())
	if not frame.healiumButtons then return end
	local settings = GetSettings()
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

-- Create healium frame buttons/buff/debuff and add them to tukui frame
local function CreateHealiumFrame(frame)
	DEBUG("Create frame for "..frame:GetName())
	-- move frame
	local settings = GetSettings()
	-- buttons
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
		-- texture setup, texture icon is set in UpdateHealiumFrameButtons
		button.texture = button:CreateTexture(nil, "BORDER")
		button.texture:SetTexCoord(0.08, 0.92, 0.08, 0.92)
		button.texture:SetPoint("TOPLEFT", button ,"TOPLEFT", 0, 0)
		button.texture:SetPoint("BOTTOMRIGHT", button ,"BOTTOMRIGHT", 0, 0)
		button:SetPushedTexture("Interface/Buttons/UI-Quickslot-Depress") -- TODO: use StyleButton from Tukui\Tukui\core\api.lua
		button:SetHighlightTexture("Interface/Buttons/ButtonHilight-Square")
		-- cooldown overlay
		button.cooldown = CreateFrame("Cooldown", "$parentCD", button, "CooldownFrameTemplate")
		button.cooldown:SetAllPoints(button.texture)
		-- click, attribute 'type' and 'spell' is set in UpdateHealiumFrameButtons
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

	-- debuff: TODO  if TargetDebuffFrameTemplate is used, texture/border/cd/count doesn't look like Tukui
	frame.Debuffs = nil -- Disable Tukui debuffs
	frame.healiumDebuffs = {}
	local lastButton = frame.healiumButtons[#frame.healiumButtons]
	local debuffSize = settings and settings.debuffSize or frame:GetHeight()
	local debuffSpacing = settings and settings.debuffSpacing or frame:GetHeight()
	for i = 1, MaxDebuffCount, 1 do
		--DEBUG("Create debuff "..i)
		-- name
		local debuffName = frame:GetName().."_HealiumDebuff_"..i
		-- frame
		local debuff
		if i == 1 then
			--debuff = CreateFrame("Frame", debuffName, frame, "TargetDebuffFrameTemplate")
			debuff = CreateFrame("Frame", debuffName, frame)
			debuff:CreatePanel("Default", debuffSize, debuffSize, "TOPLEFT", lastButton, "TOPRIGHT", debuffSpacing, 0)
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
		--hide
		debuff:Hide()
		-- save debuff
		tinsert(frame.healiumDebuffs, debuff)
	end

	-- buff: TODO  if TargetBuffFrameTemplate is used, texture is not shown but count and cd are shown
	frame.Buffs = nil -- Disable Tukui buffs
	frame.healiumBuffs = {}
	local buffSize = settings and settings.buffSize or frame:GetHeight()
	local buffSpacing = settings and settings.buffSpacing or frame:GetHeight()
	for i = 1, MaxBuffCount, 1 do
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
		-- hide
		buff:Hide()
		-- save buff
		tinsert(frame.healiumBuffs, buff)
	end
end

-- For each spell, get cooldown then loop among Healium Frames and set cooldown
local function UpdateHealiumCooldowns()
	local settings = GetSettings()
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
			ForEachMember(UpdateHealiumFrameCooldown, index, start, duration, enabled)
		end
	end
end

-- Create delayed frames
local function CreateDelayedHealiumFrames()
	if InCombatLockdown() then return end
	if not DelayedButtonCreation then return end
	for _, frame in ipairs(DelayedButtonCreation) do
		DEBUG("Delayed frame creation for "..frame:GetName())
		if not frame.healiumButtons then
			CreateHealiumFrame(frame)
		else
			DEBUG("Frame already created for "..frame:GetName())
		end
	end
	DelayedButtonCreation = {}
end

local function OnEvent(self, event, ...)
	local arg1 = select(1, ...)
	local arg2 = select(2, ...)
	local arg3 = select(3, ...)

	DEBUG("Event: "..event)

	if event == "ADDON_LOADED" then
		WARNING("ADDON_LOADED: "..arg1)
	end

	if event == "PLAYER_ENTERING_WORLD" then
		ForEachMember(CreateHealiumFrame)
		ForEachMember(UpdateHealiumFrameButtons)
		ForEachMember(UpdateHealiumFrameDebuffsPosition)
		ForEachMember(UpdateHealiumFrameBuffsDebuffsSpecialSpells)
	end

	if event == "PARTY_MEMBERS_CHANGED" or event == "RAID_ROSTER_UPDATE" then
		ForEachMember(CreateHealiumFrame)
		ForEachMember(UpdateHealiumFrameButtons)
		ForEachMember(UpdateHealiumFrameDebuffsPosition)
		ForEachMember(UpdateHealiumFrameBuffsDebuffsSpecialSpells)
	end

	if event == "PLAYER_REGEN_ENABLED" then
		CreateDelayedHealiumFrames()
		ForEachMember(UpdateHealiumFrameButtons)
	end

	if event == "PLAYER_TALENT_UPDATE" then
		ForEachMember(UpdateHealiumFrameButtons)
		ForEachMember(UpdateHealiumFrameDebuffsPosition)
	end

	if event == "SPELL_UPDATE_COOLDOWN" then -- TODO: use SPELL_UPDATE_USABLE instead ?
		UpdateHealiumCooldowns()
	end

	-- UNIT_AURA is called if 'player' has a modification in it's aura
	if event == "UNIT_AURA" then
		local frame = GetFrameFromUnit(arg1)
		if frame then UpdateHealiumFrameBuffsDebuffsSpecialSpells(frame) end -- Update buff/debuff only for unit
	end
end

-- TODO: check settings integrity
-- no more than MaxButtonCount entry in Settings[class][spec].spells

local frame = CreateFrame("Frame", "TukuiHealium", UIParent)
frame:RegisterEvent("PLAYER_ENTERING_WORLD")
frame:RegisterEvent("ADDON_LOADED")
frame:RegisterEvent("RAID_ROSTER_UPDATE")
frame:RegisterEvent("PARTY_MEMBERS_CHANGED")
frame:RegisterEvent("PLAYER_REGEN_ENABLED")
frame:RegisterEvent("PLAYER_TALENT_UPDATE")
frame:RegisterEvent("SPELL_UPDATE_COOLDOWN")
frame:RegisterEvent("UNIT_AURA")
frame:SetScript("OnEvent", OnEvent)