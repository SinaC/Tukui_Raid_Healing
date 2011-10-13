-- APIs
-- BugGrabber_Print(line): print a line and add to BugGrabber buffer
-- BugGrabber_Dump(addon): send BugGrabber buffer to BugSack, addon should be Addon name
-- PerformanceCounter_Update(functionName): Increment performance counter of functionName
-- PerformanceCounter_Get(functionName): Get performance counter of functionName
-- PerformanceCounter_Reset(): Reset performance counter
-- PerformanceCounter_Dump(): print performance counter and send them to BugGrabber

-----------------------------------------------------
-- BugGrabber support to dump informations
-----------------------------------------------------
local BugGrabber = _G["BugGrabber"]
--local BugGrabberLines = {}
local BugGrabberLines = "\n"

function BugGrabber_Print(line)
	if not BugGrabber then 
		print(line)
	else
		--table.insert(BugGrabberLines, line)
		BugGrabberLines = BugGrabberLines .. line .. "\n"
	end
end

function BugGrabber_Dump(addon)
	if not BugGrabber then return end
	print("Sent to BugGrabber")
	local errorObject = {
		message = BugGrabberLines,
		locals = nil,
		stack = nil,
		source = addon,
		session = BugGrabber:GetSessionId(),
		time = date("%Y/%m/%d %H:%M:%S"),
		type = "error",
		counter = 1,
	}
	BugGrabber:StoreError(errorObject)
	--BugGrabberLines = {}
	BugGrabberLines = "\n"
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
	BugGrabber_Print(header:format(timespan))
	for key, value in pairs(PerformanceCounter) do
		BugGrabber_Print(line:format(key,value,value/timespan))
	end
	BugGrabber_Dump("PerformanceCounter")
end
