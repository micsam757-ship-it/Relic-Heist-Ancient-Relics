--!strict
-- Session and instance identifier generation.

local HttpService = game:GetService("HttpService")

local Ids = {}

function Ids.newGuid(): string
	local ok, guid = pcall(function()
		return HttpService:GenerateGUID(false)
	end)
	if ok and type(guid) == "string" then
		return guid
	end
	return string.format(
		"%08x-%04x-4%03x-%04x-%012x",
		math.random(0, 0xFFFFFFFF),
		math.random(0, 0xFFFF),
		math.random(0, 0xFFF),
		math.random(0, 0xFFFF),
		math.random(0, 0xFFFFFFFFFFFF)
	)
end

function Ids.relicUid(): string
	return "relic_" .. Ids.newGuid()
end

return Ids
