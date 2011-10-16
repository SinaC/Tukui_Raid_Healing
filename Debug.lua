local T, C, L = unpack(Tukui) -- Import: T - functions, constants, variables; C - config; L - locales

-- TODO:
-- prevButton, nextButton: SetDisabledTexture
-- border around textarea or a line between title and textarea
-- stand-alone addon: performance counter a table by addon

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
-- Code ripped from HealiumSack
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

	local titlebg = window:CreateTexture("frame", "BORDER")
	titlebg:SetTexture(1,1,1,0.3)
	titlebg:SetPoint("TOPLEFT", 9, -6)
	titlebg:SetPoint("BOTTOMRIGHT", window, "TOPRIGHT", -28, -24)

	local close = CreateFrame("Button", "HealiumSackCloseButton", window)
	close:CreatePanel("Default", 20, 20, "TOPRIGHT", window, "TOPRIGHT", -4, -4)
	close:SetFrameStrata("TOOLTIP")
	close:StyleButton(false)
	close:FontString("text", C.media.pixelfont, 12, "MONOCHROME")
	close.text:SetText("X")
	close.text:SetPoint("CENTER", 1, 1)
	close:SetScript("OnClick", Sack.Hide)

	sessionLabel = window:CreateFontString(nil, "ARTWORK", "GameFontNormal")
	sessionLabel:SetJustifyH("LEFT")
	sessionLabel:SetPoint("TOPLEFT", titlebg, 6, -3)
	sessionLabel:SetTextColor(1, 1, 1, 1)

	countLabel = window:CreateFontString(nil, "ARTWORK", "GameFontNormal")
	countLabel:SetPoint("TOPRIGHT", titlebg, -6, -3)
	countLabel:SetJustifyH("RIGHT")
	countLabel:SetTextColor(1, 1, 1, 1)

	prevButton = CreateFrame("Button", "HealiumSackPrevButton", window)
	prevButton:CreatePanel("Default", 130, 20, "BOTTOMLEFT", window, "BOTTOMLEFT", 20, 16)
	prevButton:SetFrameStrata("TOOLTIP")
	prevButton:StyleButton(false)
	prevButton:FontString("text", C.media.pixelfont, 12, "MONOCHROME")
	prevButton.text:SetText("< Previous")
	prevButton.text:SetPoint("CENTER", 1, 1)
	prevButton:SetScript("OnClick", function()
		if IsShiftKeyDown() then
			currentErrorIndex = 1
		else
			currentErrorIndex = currentErrorIndex - 1
		end
		UpdateSackDisplay()
	end)

	nextButton = CreateFrame("Button", "HealiumSackNextButton", window)
	nextButton:CreatePanel("Default", 130, 20, "BOTTOMRIGHT", window, "BOTTOMRIGHT", -20, 16)
	nextButton:SetFrameStrata("TOOLTIP")
	nextButton:StyleButton(false)
	nextButton:FontString("text", C.media.pixelfont, 12, "MONOCHROME")
	nextButton.text:SetText("Next >")
	nextButton.text:SetPoint("CENTER", 1, 1)
	nextButton:SetScript("OnClick", function()
		if IsShiftKeyDown() then
			currentErrorIndex = #currentSackContents
		else
			currentErrorIndex = currentErrorIndex + 1
		end
		UpdateSackDisplay()
	end)

	local scroll = CreateFrame("ScrollFrame", "HealiumSackScroll", window, "UIPanelScrollFrameTemplate")
	scroll:SetPoint("TOPLEFT", window, "TOPLEFT", 16, -36)
	scroll:SetPoint("BOTTOMRIGHT", nextButton, "TOPRIGHT", -24, 8)

	textArea = CreateFrame("EditBox", "HealiumSackScrollText", scroll)
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

function PerformanceCounter_Dump(addonName)
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
	Sack:Flush(addonName)
end