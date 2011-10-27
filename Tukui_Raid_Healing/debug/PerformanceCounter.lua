---------------------------------------------------------
-- PerformanceCounter

-- APIs:
-- PerformanceCounter:Increment(addonName, functionName): increment performance counter of functionName in addonName section
-- PerformanceCounter:Get(addonName, functionName): get performance counter of functionName or all performance counters in addonName section
-- PerformanceCounter:Reset(): reset performance counters

-- Namespace
PerformanceCounter = {}

-- Local variables
local counters = {}

function PerformanceCounter:Increment(addonName, fctName)
	local currentTime = GetTime()
	local addonSection = counters[addonName]
	if not addonSection then
		counters[addonName] = {}
		addonSection = counters[addonName]
	end
	local entry = addonSection[fctName]
	if not entry then
		addonSection[fctName] = { count = 1, lastTime = GetTime() }
	else
		local cnt = (entry.count or 0) + 1
		local diff = currentTime - (entry.lastTime or currentTime)
		local lowestDiff = entry.lowestSpan or 999999
		if diff < lowestDiff then lowestDiff = diff end
		local highestDiff = entry.highestSpan or 0
		if diff > highestDiff then highestDiff = diff end
		addonSection[fctName] = { count = cnt, lastTime = currentTime, lowestSpan = lowestDiff, highestSpan = highestDiff }
	end
end

function PerformanceCounter:Get(addonName, fctName)
	if not addonName then return nil end
	local addonEntry = counters[addonName]
	if not addonEntry then return nil end
	if not fctName then
		local list = {} -- make a copy to avoid caller modifying counters
		for key, value in pairs(addonEntry) do
			list[key] = { count = value.count, lastTime = value.lastTime, lowestSpan = value.lowestSpan, highestSpan = value.highestSpan }
		end
		return list
	else
		local entry = addonEntry[fctName]
		if entry then
			return { count = entry.count, lastTime = entry.lastTime, lowestSpan = entry.lowestSpan, highestSpan = entry.highestSpan }
		else
			return nil
		end
	end
end

function PerformanceCounter:Reset(addonName)
	if not addonName then
		for addon, _ in pairs(counters) do
			Reset(addon)
		end
	else
		-- local addonEntry = counters[addonName]
		-- if not addonEntry then return end
		-- for key, _ in pairs(addonEntry) do
			-- addonEntry[key] = {}
		-- end
		counters[addonName] = {}
	end
end