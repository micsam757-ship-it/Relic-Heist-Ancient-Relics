--!strict
-- Small pure utility helpers shared by client, server, and tests.

local Util = {}

function Util.deepCopy<T>(value: T): T
	if type(value) ~= "table" then
		return (value :: any) :: T
	end
	local copy = {}
	for key, child in pairs(value :: any) do
		copy[Util.deepCopy(key)] = Util.deepCopy(child)
	end
	return copy :: T
end

function Util.formatNumber(value: number): string
	local rounded = math.floor(value + 0.5)
	local text = tostring(rounded)
	local sign = ""
	if rounded < 0 then
		sign = "-"
		text = tostring(math.abs(rounded))
	end
	local formatted = text:reverse():gsub("(%d%d%d)", "%1,"):reverse()
	formatted = formatted:gsub("^,", "")
	return sign .. formatted
end

function Util.formatDuration(seconds: number): string
	local safe = math.max(0, math.floor(seconds))
	local minutes = math.floor(safe / 60)
	local remainder = safe % 60
	return string.format("%d:%02d", minutes, remainder)
end

-- Shortest distance from point (px, py) to the segment (ax, ay)-(bx, by) on a
-- 2D plane. Pure so hazard hit-testing can be unit tested outside of Roblox.
function Util.distanceToSegment2D(px: number, py: number, ax: number, ay: number, bx: number, by: number): number
	local abx, aby = bx - ax, by - ay
	local apx, apy = px - ax, py - ay
	local lengthSq = abx * abx + aby * aby
	local t = 0
	if lengthSq > 1e-9 then
		t = math.clamp((apx * abx + apy * aby) / lengthSq, 0, 1)
	end
	local closestX, closestY = ax + abx * t, ay + aby * t
	local dx, dy = px - closestX, py - closestY
	return math.sqrt(dx * dx + dy * dy)
end

return Util
