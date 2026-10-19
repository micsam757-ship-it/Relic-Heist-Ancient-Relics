--!nonstrict
-- Lightweight, privacy-conscious analytics. v1 logs aggregate counters to the
-- server output only (no personal data beyond the Roblox UserId already known
-- to the server). See docs/SRS.md FR-020.

local Logger = require(script.Parent.Parent.Utilities.Logger)

local AnalyticsService = {}

local VERBOSE_EVENTS = {
	expedition_entered = true,
	expedition_extracted = true,
	expedition_abandoned = true,
	player_died = true,
	temple_unlocked = true,
	upgrade_purchased = true,
	tutorial_completed = true,
}

local state = {
	counters = {},
	logger = nil,
	started = false,
}

function AnalyticsService:Init(ctx)
	state.ctx = ctx
	state.logger = Logger.new("Analytics")
end

function AnalyticsService:Track(eventName: string, fields)
	if type(eventName) ~= "string" then
		return
	end
	state.counters[eventName] = (state.counters[eventName] or 0) + 1

	if VERBOSE_EVENTS[eventName] then
		local parts: { string } = {}
		if type(fields) == "table" then
			for key, value in pairs(fields) do
				if type(value) == "number" or type(value) == "string" or type(value) == "boolean" then
					table.insert(parts, string.format("%s=%s", tostring(key), tostring(value)))
				end
			end
		end
		state.logger:info("event=%s %s", eventName, table.concat(parts, " "))
	end
end

function AnalyticsService:GetCounters()
	return state.counters
end

function AnalyticsService:Start()
	if state.started then
		return
	end
	state.started = true
	task.spawn(function()
		while true do
			task.wait(120)
			local parts: { string } = {}
			for name, count in pairs(state.counters) do
				table.insert(parts, string.format("%s=%d", name, count))
			end
			if #parts > 0 then
				table.sort(parts)
				state.logger:info("counters %s", table.concat(parts, " "))
			end
		end
	end)
end

return AnalyticsService
