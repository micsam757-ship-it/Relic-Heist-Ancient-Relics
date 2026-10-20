--!strict
-- Pure request-payload validation shared by the server dispatcher and the test
-- suite. No Roblox APIs, so the security-relevant shape checks can be unit
-- tested outside of Studio (see docs/THREAT_MODEL.md T-03).

local Validate = {}

-- The single Request remote carries `{ action = "<string>", data = <table|nil> }`.
-- Anything that is not a table with a non-empty string action is rejected before
-- it reaches a handler.
export type RequestPayload = {
	action: string,
	data: any?,
}

function Validate.isValidPayload(payload: any): boolean
	if type(payload) ~= "table" then
		return false
	end
	local action = payload.action
	return type(action) == "string" and #action > 0
end

-- Returns (payload, nil) when valid, or (nil, reason) when not.
function Validate.checkPayload(payload: any): (RequestPayload?, string?)
	if type(payload) ~= "table" then
		return nil, "payload is not a table"
	end
	local action = payload.action
	if type(action) ~= "string" then
		return nil, "payload.action is not a string"
	end
	if #action == 0 then
		return nil, "payload.action is empty"
	end
	return payload :: RequestPayload, nil
end

return Validate
