--!strict
-- Declarative contract for every client request action. Pure, no Roblox APIs, so
-- the action set and each action's required data shape can be unit tested and
-- cross-checked against docs/API_CONTRACTS.md (see docs/THREAT_MODEL.md T-03).

local Contracts = {}

-- Each action declares the string fields its handler requires in `payload.data`.
-- Actions whose handler reads no data omit `requires`. `requireProfile = false`
-- mirrors the dispatcher option for actions callable before a profile loads.
-- The contract only guarantees that a required field is present and a string;
-- the handler still validates the value it accepts.
export type ActionSpec = {
	requires: { string }?,
	requireProfile: boolean?,
}

local actions: { [string]: ActionSpec } = {
	RequestState = { requireProfile = false },
	EnterExpedition = { requires = { "templeId" } },
	AbandonExpedition = {},
	SetSprint = { requires = { "state" } },
	BuyUpgrade = { requires = { "upgradeId" } },
	BuyCompanion = { requires = { "companionId" } },
	EquipCompanion = { requires = { "companionId" } },
	UnequipCompanion = {},
	UnlockTemple = { requires = { "templeId" } },
	UpdateSettings = {},
	PlaceRelic = { requires = { "pedestalId", "uid" } },
	RemoveRelic = { requires = { "pedestalId" } },
	ClaimOfflineIncome = {},
	PurchaseOfflineDouble = {},
	PurchaseInstantRevive = {},
	DeclineInstantRevive = {},
}

Contracts.Actions = actions

-- Actions that require a loaded profile unless explicitly exempt.
function Contracts.requiresProfile(action: string): boolean
	local spec = Contracts.Actions[action]
	if spec == nil then
		return true
	end
	return spec.requireProfile ~= false
end

function Contracts.isKnownAction(action: string): boolean
	return Contracts.Actions[action] ~= nil
end

-- Validates a payload's `data` against the action's declared shape.
-- Returns (true, nil) when acceptable, or (false, reason) when not.
--
-- An action that requires no fields accepts any `data` (including nil); the
-- dispatcher has already guaranteed the payload is a table with a string action.
function Contracts.check(action: string, data: any): (boolean, string?)
	local spec = Contracts.Actions[action]
	if spec == nil then
		return false, string.format("unknown action '%s'", action)
	end
	local requires = spec.requires
	if requires == nil or #requires == 0 then
		return true, nil
	end
	if type(data) ~= "table" then
		return false, "missing request data"
	end
	for _, field in requires do
		if type(data[field]) ~= "string" then
			return false, string.format("missing or invalid '%s'", field)
		end
	end
	return true, nil
end

-- The declared action names, sorted, for drift checks and documentation tests.
function Contracts.actionNames(): { string }
	local names = {}
	for name in Contracts.Actions do
		table.insert(names, name)
	end
	table.sort(names)
	return names
end

return Contracts
