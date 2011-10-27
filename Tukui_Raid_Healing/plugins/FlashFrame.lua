-- local COLORTABLE = {
	-- white = {r=1.0, g=1.0, b=1.0},
	-- yellow = YELLOW_FONT_COLOR,
	-- purple = {r=1.0, g=0.0, b=1.0},
	-- blue = {r=0.0, g=0.0, b=1.0},
	-- orange = ORANGE_FONT_COLOR,
	-- aqua = {r=0.0, g=1.0, b=1.0},
	-- green = GREEN_FONT_COLOR,
	-- red = RED_FONT_COLOR,
	-- pink = {r=0.9, g=0.4, b=0.4},
	-- gray = GRAY_FONT_COLOR,
-- }

-- local function FlashFrameOnUpdate(self, elapsed)
	-- self.TimeSinceLastUpdate = self.TimeSinceLastUpdate + elapsed
	-- if self.TimeSinceLastUpdate >= self.UpdateInterval then
		-- self.modifier = self.FlashModifier
		-- self.FlashModifier = self.modifier - self.modifier * self.TimeSinceLastUpdate
		-- self.TimeSinceLastUpdate = 0
		-- self.alpha = self.FlashModifier * self.FlashBrightness
		-- if self.modifier < 0.1 or self.alpha <= 0 then
			-- self:Hide()
		-- else
			-- self.FlashTexture:SetHeight(self.modifier * self:GetHeight() * self.FlashSize)
			-- self.FlashTexture:SetWidth(self.modifier * self:GetWidth() * self.FlashSize)
			-- self.FlashTexture:SetAlpha(self.alpha)
		-- end
	-- end
-- end

-- local FlashFrameName = "SpellFlashCoreAddonFlashFrame"

-- function SpellFlashCore.FlashFrame(frame, color, size, brightness, blink)
	-- if frame and frame:IsVisible() then
		-- if blink and frame:GetName() and not UIFrameIsFading(frame) then
			-- UIFrameFlash(frame, 0, 0.2, 0.2, true, 0, 0)
		-- end
		-- if not frame[FlashFrameName] then
			-- frame[FlashFrameName] = CreateFrame("Frame", nil, frame)
			-- frame[FlashFrameName]:Hide()
			-- frame[FlashFrameName]:SetAllPoints(frame)
			-- frame[FlashFrameName].FlashTexture = frame[FlashFrameName]:CreateTexture(nil, "OVERLAY")
			-- frame[FlashFrameName].FlashTexture:SetTexture("Interface\\Cooldown\\star4")
			-- frame[FlashFrameName].FlashTexture:SetPoint("CENTER", frame[FlashFrameName], "CENTER")
			-- frame[FlashFrameName].FlashTexture:SetBlendMode("ADD")
			-- frame[FlashFrameName]:SetAlpha(1)
			-- frame[FlashFrameName].UpdateInterval = 0.02
			-- frame[FlashFrameName].TimeSinceLastUpdate = 0
			-- frame[FlashFrameName]:SetScript("OnUpdate", FlashFrameOnUpdate)
		-- end
		-- frame[FlashFrameName].FlashModifier = 1
		-- frame[FlashFrameName].FlashSize = (size or 240) / 100
		-- frame[FlashFrameName].FlashBrightness = (brightness or 100) / 100
		-- frame[FlashFrameName].FlashTexture:SetAlpha(1 * frame[FlashFrameName].FlashBrightness)
		-- frame[FlashFrameName].FlashTexture:SetHeight(frame[FlashFrameName]:GetHeight() * frame[FlashFrameName].FlashSize)
		-- frame[FlashFrameName].FlashTexture:SetWidth(frame[FlashFrameName]:GetWidth() * frame[FlashFrameName].FlashSize)
		-- if type(color) == "table" then
			-- frame[FlashFrameName].FlashTexture:SetVertexColor(color.r or 1, color.g or 1, color.b or 1)
		-- elseif type(color) == "string" then
			-- local color = COLORTABLE[color:lower()]
			-- if color then
				-- frame[FlashFrameName].FlashTexture:SetVertexColor(color.r or 1, color.g or 1, color.b or 1)
			-- else
				-- frame[FlashFrameName].FlashTexture:SetVertexColor(1, 1, 1)
			-- end
		-- else
			-- frame[FlashFrameName].FlashTexture:SetVertexColor(1, 1, 1)
		-- end
		-- frame[FlashFrameName]:Show()
		-- return true
	-- end
	-- return false
-- end

-----------------------------------------------------
-- Flash Frame

-- APIs:
--FlashFrame:ShowFlashFrame(frame, color, size, brightness): Start a flash on frame, size must be 10 times bigger than frame size to see it, brightness: 1->100
--FlashFrame:HideFlashFrame(frame): Stop a flash

-- Namespace
FlashFrame = {}

-- Create flash frame on a frame
local function CreateFlashFrame(frame)
	--if not HealiumSettings.flashDispel then return end
	if frame.ffFlashFrame then return end

	--print("CreateFlashFrame")

	frame.ffFlashFrame = CreateFrame("Frame", nil, frame)
	frame.ffFlashFrame:Hide()
	frame.ffFlashFrame:SetAllPoints(frame)
	frame.ffFlashFrame.texture = frame.ffFlashFrame:CreateTexture(nil, "OVERLAY")
	frame.ffFlashFrame.texture:SetTexture("Interface\\Cooldown\\star4")
	frame.ffFlashFrame.texture:SetPoint("CENTER", frame.ffFlashFrame, "CENTER")
	frame.ffFlashFrame.texture:SetBlendMode("ADD")
	frame.ffFlashFrame:SetAlpha(1)
	frame.ffFlashFrame.updateInterval = 0.02
	frame.ffFlashFrame.lastFlashTime = 0
	frame.ffFlashFrame.timeSinceLastUpdate = 0
	frame.ffFlashFrame:SetScript("OnUpdate", function (self, elapsed)
		if not self:IsShown() then return end
		self.timeSinceLastUpdate = self.timeSinceLastUpdate + elapsed
		if self.timeSinceLastUpdate >= self.updateInterval then
			--print("Interval")
			local oldModifier = self.flashModifier
			self.flashModifier = oldModifier - oldModifier * self.timeSinceLastUpdate
			self.timeSinceLastUpdate = 0
			self.alpha = self.flashModifier * self.flashBrightness
			if oldModifier < 0.1 or self.alpha <= 0 then
				--print("Hide")
				self:Hide()
			else
				--print("Show")
				self.texture:SetHeight(oldModifier * self:GetHeight() * self.flashSize)
				self.texture:SetWidth(oldModifier * self:GetWidth() * self.flashSize)
				self.texture:SetAlpha(self.alpha)
				--print("UPDATE:"..frame.ffFlashFrame.texture:GetHeight().."  "..frame.ffFlashFrame.texture:GetWidth().."  "..self.alpha)
			end
		end
	end)
end

-- Show flash frame
function FlashFrame:ShowFlashFrame(frame, color, size, brightness, blink)
	--print("ShowFlashFrame")
	--if not frame.ffFlashFrame then return end
	if not frame.ffFlashFrame then
		-- Create flash frame on-the-fly
		CreateFlashFrame(frame)
	end
	
	if blink and frame:GetName() and not UIFrameIsFading(frame) then
		UIFrameFlash(frame, 0, 0.2, 0.2, true, 0, 0)
	end

	-- Dont flash too often
	local now = GetTime()
	if now - frame.ffFlashFrame.lastFlashTime < 1 then return end
	frame.ffFlashFrame.lastFlashTime = now

	-- Show flash frame
	frame.ffFlashFrame.flashModifier = 1
	frame.ffFlashFrame.flashSize = (size or 240) / 100
	frame.ffFlashFrame.flashBrightness = (brightness or 100) / 100
	frame.ffFlashFrame.texture:SetAlpha(1 * frame.ffFlashFrame.flashBrightness)
	frame.ffFlashFrame.texture:SetHeight(frame.ffFlashFrame:GetHeight() * frame.ffFlashFrame.flashSize)
	frame.ffFlashFrame.texture:SetWidth(frame.ffFlashFrame:GetWidth() * frame.ffFlashFrame.flashSize)
	--print("FLASH SIZE:"..frame.ffFlashFrame:GetHeight().."  "..frame.ffFlashFrame:GetWidth())
	--print("FLASH TEXURE SIZE:"..frame.ffFlashFrame.texture:GetHeight().."  "..frame.ffFlashFrame.texture:GetWidth())
	if type(color) == "table" then
		frame.ffFlashFrame.texture:SetVertexColor(color.r or 1, color.g or 1, color.b or 1)
	elseif type(color) == "string" then
		local color = COLORTABLE[color:lower()]
		if color then
			frame.ffFlashFrame.texture:SetVertexColor(color.r or 1, color.g or 1, color.b or 1)
		else
			frame.ffFlashFrame.texture:SetVertexColor(1, 1, 1)
		end
	else
		frame.ffFlashFrame.texture:SetVertexColor(1, 1, 1)
	end
	frame.ffFlashFrame:Show()
end

-- Hide flash frame
function FlashFrame:HideFlashFrame(frame)
	--print("HideFlashFrame")
	if not frame.ffFlashFrame then return end

	frame.ffFlashFrame.flashModifier = 0
	frame.ffFlashFrame:Hide()
end

local function SetUpAnimGroup(self)
	--print("SetUpAnimGroup")
	self.anim = self:CreateAnimationGroup("Flash")
	self.anim.fadein = self.anim:CreateAnimation("ALPHA", "FadeIn")
	self.anim.fadein:SetChange(1)
	self.anim.fadein:SetOrder(2)

	self.anim.fadeout = self.anim:CreateAnimation("ALPHA", "FadeOut")
	self.anim.fadeout:SetChange(-1)
	self.anim.fadeout:SetOrder(1)
end

function FlashFrame:Fadeout(self, duration)
	--print("FlashFrame2:Flash "..self:GetName())
	if not self.anim then
		SetUpAnimGroup(self)
	end
	--print("FlashFrame2:Flash  after creation")


	self.anim.fadein:SetDuration(duration)
	self.anim.fadeout:SetDuration(duration)
	self.anim:Play()
end

function FlashFrame:StopFadeout(self)
	if self.anim then
		self.anim:Finish()
	end
end