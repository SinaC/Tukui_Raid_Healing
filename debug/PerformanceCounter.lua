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
	local addonSection = counters[addonName]
	if not addonSection then
		counters[addonName] = {}
		addonSection = counters[addonName]
	end
	local entry = addonSection[fctName]
	if not entry then
		addonSection[fctName] = 1
	else
		addonSection[fctName] = addonSection[fctName] + 1
	end
end

function PerformanceCounter:Get(addonName, fctName)
	if not addonName then return nil end
	local addonEntry = counters[addonName]
	if not addonEntry then return nil end
	if not fctName then
		local list = {} -- make a copy to avoid caller modifying counters
		for key, value in pairs(addonEntry) do
			list[key] = value
		end
		return list
	else
		return addonEntry[fctName]
	end
end

function PerformanceCounter:Reset(addonName)
	if not addonName then
		for addon, _ in pairs(counters) do
			Reset(addon)
		end
	else
		local addonEntry = counters[addonName]
		if not addonEntry then return end
		for key, _ in pairs(addonEntry) do
			addonEntry[key] = 0
		end
	end
end