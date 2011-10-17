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
	if frame.hFlashFrame then return end

	print("CreateFlashFrame")

	frame.hFlashFrame = CreateFrame("Frame", nil, frame)
	frame.hFlashFrame:Hide()
	frame.hFlashFrame:SetAllPoints(frame)
	frame.hFlashFrame.texture = frame.hFlashFrame:CreateTexture(nil, "OVERLAY")
	frame.hFlashFrame.texture:SetTexture("Interface\\Cooldown\\star4")
	frame.hFlashFrame.texture:SetPoint("CENTER", frame.hFlashFrame, "CENTER")
	frame.hFlashFrame.texture:SetBlendMode("ADD")
	frame.hFlashFrame:SetAlpha(1)
	frame.hFlashFrame.updateInterval = 0.02
	frame.hFlashFrame.timeSinceLastUpdate = 0
	frame.hFlashFrame:SetScript("OnUpdate", function (self, elapsed)
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
				--print("UPDATE:"..frame.hFlashFrame.texture:GetHeight().."  "..frame.hFlashFrame.texture:GetWidth().."  "..self.alpha)
			end
		end
	end)
end

-- Show flash frame
function FlashFrame:ShowFlashFrame(frame, color, size, brightness)
	--print("ShowFlashFrame")
	--if not frame.hFlashFrame then return end
	if not frame.hFlashFrame then
		-- Create flash frame on-the-fly
		CreateFlashFrame(frame)
	end

	-- Show flash frame
	frame.hFlashFrame.flashModifier = 1
	frame.hFlashFrame.flashSize = (size or 240) / 100
	frame.hFlashFrame.flashBrightness = (brightness or 100) / 100
	frame.hFlashFrame.texture:SetAlpha(1 * frame.hFlashFrame.flashBrightness)
	frame.hFlashFrame.texture:SetHeight(frame.hFlashFrame:GetHeight() * frame.hFlashFrame.flashSize)
	frame.hFlashFrame.texture:SetWidth(frame.hFlashFrame:GetWidth() * frame.hFlashFrame.flashSize)
	--print("FLASH SIZE:"..frame.hFlashFrame:GetHeight().."  "..frame.hFlashFrame:GetWidth())
	--print("FLASH TEXURE SIZE:"..frame.hFlashFrame.texture:GetHeight().."  "..frame.hFlashFrame.texture:GetWidth())
	if type(color) == "table" then
		frame.hFlashFrame.texture:SetVertexColor(color.r or 1, color.g or 1, color.b or 1)
	elseif type(color) == "string" then
		local color = COLORTABLE[color:lower()]
		if color then
			frame.hFlashFrame.texture:SetVertexColor(color.r or 1, color.g or 1, color.b or 1)
		else
			frame.hFlashFrame.texture:SetVertexColor(1, 1, 1)
		end
	else
		frame.hFlashFrame.texture:SetVertexColor(1, 1, 1)
	end
	frame.hFlashFrame:Show()
end

-- Hide flash frame
function FlashFrame:HideFlashFrame(frame)
	print("HideFlashFrame")
	if not frame.hFlashFrame then return end

	frame.hFlashFrame.flashModifier = 0
	frame.hFlashFrame:Hide()
end