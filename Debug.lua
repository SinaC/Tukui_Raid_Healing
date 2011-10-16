local T, C, L = unpack(Tukui) -- Import: T - functions, constants, variables; C - config; L - locales

-- APIs:
-- PerformanceCounter_Update(functionName): Increment performance counter of functionName
-- PerformanceCounter_Get(functionName): Get performance counter of functionName
-- PerformanceCounter_Reset(): Reset performance counter
-- PerformanceCounter_Dump(): print performance counter and send them to BugGrabber

-- Sack:Add(line): add a line to buffer
-- Sack:Flush(addonName): flush buffer to sack (create sack if not already created)
-- Sack:Show(): display sack
-- Sack:Hide(): hide sack

-- -----------------------------------------------------
-- -- BugGrabber support to dump informations
-- -----------------------------------------------------
-- local BugGrabber = _G["BugGrabber"]
-- --local BugGrabberLines = {}
-- local BugGrabberLines = "\n"

-- function BugGrabber_Print(line)
	-- if not BugGrabber then 
		-- print(line)
	-- else
		-- --table.insert(BugGrabberLines, line)
		-- BugGrabberLines = BugGrabberLines .. line .. "\n"
	-- end
-- end

-- function BugGrabber_Dump(addon)
	-- if not BugGrabber then return end
	-- print("Sent to BugGrabber")
	-- local errorObject = {
		-- message = BugGrabberLines,
		-- locals = nil,
		-- stack = nil,
		-- source = addon,
		-- session = BugGrabber:GetSessionId(),
		-- time = date("%Y/%m/%d %H:%M:%S"),
		-- type = "error",
		-- counter = 1,
	-- }
	-- BugGrabber:StoreError(errorObject)
	-- --BugGrabberLines = {}
	-- BugGrabberLines = "\n"
-- end

-----------------------------------------------------
-- HealiumSack
-----------------------------------------------------
-- Code ripped from BugSack
Sack = {}

local window
local textArea
local nextButton
local prevButton
local countLabel
local sessionLabel

local currentErrorObject = nil
--local currentSackSession = nil
local currentSackContents = {}
local currentErrorIndex = 1

local text = ""

local sessionFormat = "%s - |cffff4411%s|r" -- <date> - <sent by>
local countFormat = "%d/%d" -- 1/10
local sourceFormat = "Sent by %s (%s)" -- <source> -- <type>

local function UpdateSackDisplay()
	currentErrorObject = currentSackContents and currentSackContents[currentErrorIndex]
	local entry = nil
	local size = #currentSackContents
	for i, v in next, currentSackContents do
		if v == currentErrorObject then
			currentErrorIndex = i
			entry = v
			break
		end
	end
	if not entry then entry = currentSackContents[currentErrorIndex] end
	if not entry then entry = currentSackContents[size] end

	if size > 0 then
		local source = sourceFormat:format(entry.source, entry.type)

		countLabel:SetText(countFormat:format(currentErrorIndex, size))
		sessionLabel:SetText(sessionFormat:format(entry.time, source))
		textArea:SetText(entry.message)

		if currentErrorIndex >= size then
			nextButton:Disable()
		else
			nextButton:Enable()
		end
		if currentErrorIndex <= 1 then
			prevButton:Disable()
		else
			prevButton:Enable()
		end
		if sendButton then sendButton:Enable() end
	else
		countLabel:SetText()
		sessionLabel:SetText(sessionFormat:format(entry.time, source))
		textArea:SetText("No dump")

		nextButton:Disable()
		prevButton:Disable()
		if sendButton then sendButton:Disable() end
	end
end

local function CreateSackFrame()
	window = CreateFrame("Frame", "HealiumSackFrame", UIParent)
	window:CreatePanel("Default", 500, 500 / 1.618, "CENTER", UIParent, "CENTER", 0, 0 )
	window:SetFrameStrata("FULLSCREEN_DIALOG")
	window:SetMovable(true)
	window:EnableMouse(true)
	window:RegisterForDrag("LeftButton")
	window:SetScript("OnDragStart", window.StartMoving)
	window:SetScript("OnDragStop", window.StopMovingOrSizing)
	window:SetScript("OnHide", function()
		currentErrorObject = nil
	end)

	local titlebg = window:CreateTexture(nil, "BORDER")
	titlebg:SetTexture("Interface\\PaperDollInfoFrame\\UI-GearManager-Title-Background")
	titlebg:SetPoint("TOPLEFT", 9, -6)
	titlebg:SetPoint("BOTTOMRIGHT", window, "TOPRIGHT", -28, -24)

	local dialogbg = window:CreateTexture(nil, "BACKGROUND")
	dialogbg:SetTexture("Interface\\PaperDollInfoFrame\\UI-Character-CharacterTab-L1")
	dialogbg:SetPoint("TOPLEFT", 8, -12)
	dialogbg:SetPoint("BOTTOMRIGHT", -6, 8)
	dialogbg:SetTexCoord(0.255, 1, 0.29, 1)

	local topleft = window:CreateTexture(nil, "BORDER")
	topleft:SetTexture("Interface\\PaperDollInfoFrame\\UI-GearManager-Border")
	topleft:SetWidth(64)
	topleft:SetHeight(64)
	topleft:SetPoint("TOPLEFT")
	topleft:SetTexCoord(0.501953125, 0.625, 0, 1)

	local topright = window:CreateTexture(nil, "BORDER")
	topright:SetTexture("Interface\\PaperDollInfoFrame\\UI-GearManager-Border")
	topright:SetWidth(64)
	topright:SetHeight(64)
	topright:SetPoint("TOPRIGHT")
	topright:SetTexCoord(0.625, 0.75, 0, 1)

	local top = window:CreateTexture(nil, "BORDER")
	top:SetTexture("Interface\\PaperDollInfoFrame\\UI-GearManager-Border")
	top:SetHeight(64)
	top:SetPoint("TOPLEFT", topleft, "TOPRIGHT")
	top:SetPoint("TOPRIGHT", topright, "TOPLEFT")
	top:SetTexCoord(0.25, 0.369140625, 0, 1)

	local bottomleft = window:CreateTexture(nil, "BORDER")
	bottomleft:SetTexture("Interface\\PaperDollInfoFrame\\UI-GearManager-Border")
	bottomleft:SetWidth(64)
	bottomleft:SetHeight(64)
	bottomleft:SetPoint("BOTTOMLEFT")
	bottomleft:SetTexCoord(0.751953125, 0.875, 0, 1)

	local bottomright = window:CreateTexture(nil, "BORDER")
	bottomright:SetTexture("Interface\\PaperDollInfoFrame\\UI-GearManager-Border")
	bottomright:SetWidth(64)
	bottomright:SetHeight(64)
	bottomright:SetPoint("BOTTOMRIGHT")
	bottomright:SetTexCoord(0.875, 1, 0, 1)

	local bottom = window:CreateTexture(nil, "BORDER")
	bottom:SetTexture("Interface\\PaperDollInfoFrame\\UI-GearManager-Border")
	bottom:SetHeight(64)
	bottom:SetPoint("BOTTOMLEFT", bottomleft, "BOTTOMRIGHT")
	bottom:SetPoint("BOTTOMRIGHT", bottomright, "BOTTOMLEFT")
	bottom:SetTexCoord(0.376953125, 0.498046875, 0, 1)

	local left = window:CreateTexture(nil, "BORDER")
	left:SetTexture("Interface\\PaperDollInfoFrame\\UI-GearManager-Border")
	left:SetWidth(64)
	left:SetPoint("TOPLEFT", topleft, "BOTTOMLEFT")
	left:SetPoint("BOTTOMLEFT", bottomleft, "TOPLEFT")
	left:SetTexCoord(0.001953125, 0.125, 0, 1)

	local right = window:CreateTexture(nil, "BORDER")
	right:SetTexture("Interface\\PaperDollInfoFrame\\UI-GearManager-Border")
	right:SetWidth(64)
	right:SetPoint("TOPRIGHT", topright, "BOTTOMRIGHT")
	right:SetPoint("BOTTOMRIGHT", bottomright, "TOPRIGHT")
	right:SetTexCoord(0.1171875, 0.2421875, 0, 1)

	local close = CreateFrame("Button", nil, window, "UIPanelCloseButton")
	close:SetPoint("TOPRIGHT", 2, 1)
	close:SetScript("OnClick", Sack.Hide)

	sessionLabel = window:CreateFontString(nil, "ARTWORK", "GameFontNormal")
	sessionLabel:SetJustifyH("LEFT")
	sessionLabel:SetPoint("TOPLEFT", titlebg, 6, -3)
	sessionLabel:SetTextColor(1, 1, 1, 1)

	countLabel = window:CreateFontString(nil, "ARTWORK", "GameFontNormal")
	countLabel:SetPoint("TOPRIGHT", titlebg, -6, -3)
	countLabel:SetJustifyH("RIGHT")
	countLabel:SetTextColor(1, 1, 1, 1)

	nextButton = CreateFrame("Button", "HealiumSackNextButton", window, "UIPanelButtonTemplate2")
	--nextButton:SetTemplate("Default")
	-- nextButton:SetNormalTexture("")
	-- nextButton:SetPushedTexture("")
	-- nextButton:SetHighlightTexture("")
	nextButton:SetPoint("BOTTOMRIGHT", window, -11, 16)
	nextButton:SetWidth(130)
	nextButton:SetText("Next >")
	nextButton:SetScript("OnClick", function()
		if IsShiftKeyDown() then
			currentErrorIndex = #currentSackContents
		else
			currentErrorIndex = currentErrorIndex + 1
		end
		UpdateSackDisplay()
	end)

	prevButton = CreateFrame("Button", "HealiumSackPrevButton", window, "UIPanelButtonTemplate2")
	prevButton:SetPoint("BOTTOMLEFT", window, 14, 16)
	prevButton:SetWidth(130)
	prevButton:SetText("< Previous")
	prevButton:SetScript("OnClick", function()
		if IsShiftKeyDown() then
			currentErrorIndex = 1
		else
			currentErrorIndex = currentErrorIndex - 1
		end
		UpdateSackDisplay()
	end)

	local scroll = CreateFrame("ScrollFrame", "BugSackScroll", window, "UIPanelScrollFrameTemplate")
	scroll:SetPoint("TOPLEFT", window, "TOPLEFT", 16, -36)
	scroll:SetPoint("BOTTOMRIGHT", nextButton, "TOPRIGHT", -24, 8)

	textArea = CreateFrame("EditBox", "BugSackScrollText", scroll)
	textArea:SetAutoFocus(false)
	textArea:SetMultiLine(true)
	textArea:SetFontObject(GameFontHighlightSmall)
	textArea:SetMaxLetters(99999)
	textArea:EnableMouse(true)
	textArea:SetScript("OnEscapePressed", textArea.ClearFocus)
	-- XXX why the fuck doesn't SetPoint work on the editbox?
	textArea:SetWidth(450)

	scroll:SetScrollChild(textArea)
	
	window:Hide()
end

function Sack:Add(line)
	text = text .. line .. "\n" -- append text until a flush is called
end

function Sack:Flush(addonName)
	if not window then
		CreateSackFrame()
	end
	local entry = {
		message = text,
		locals = nil,
		stack = nil,
		source = addonName,
		session = 1,
		time = date("%Y/%m/%d %H:%M:%S"),
		type = "dump",
		counter = 1,
	}
	tinsert(currentSackContents, entry)
	Sack:Show()
	text = "" -- reset current text
end

function Sack:Show()
	UpdateSackDisplay()
	if not window or window:IsShown() then return end
	window:Show()
end

function Sack:Hide()
	if not window or not window:IsShown() then return end
	window:Hide()
end


-----------------------------------------------------
-- Perfomance counter management
-----------------------------------------------------
local PerformanceCounter = {}
local PerformanceCounterLastReset = GetTime()

function PerformanceCounter_Update(functionName)
	local entry = PerformanceCounter[functionName]
	if entry then
		PerformanceCounter[functionName] = PerformanceCounter[functionName] + 1
	else
		PerformanceCounter[functionName] = 1
	end
	return PerformanceCounter[functionName]
end

function PerformanceCounter_Get(functionName)
	return PerformanceCounter[functionName]
end

function PerformanceCounter_Reset()
	PerformanceCounterLastReset = GetTime()
	for key, _ in pairs(PerformanceCounter) do
		PerformanceCounter[key] = 0
	end
end

function PerformanceCounter_Dump()
	if not PerformanceCounter then return end
	local timespan = GetTime() - PerformanceCounterLastReset
	local header = "Performance counters. Elapsed=%.2f"
	local line = "%s=%d -> %.2f/sec"
	--BugGrabber_Print(header:format(timespan))
	Sack:Add(header:format(timespan))
	for key, value in pairs(PerformanceCounter) do
		--BugGrabber_Print(line:format(key,value,value/timespan))
		Sack:Add(line:format(key,value,value/timespan))
	end
	--BugGrabber_Dump("PerformanceCounter")
	Sack:Flush("PerformanceCounter")
end
