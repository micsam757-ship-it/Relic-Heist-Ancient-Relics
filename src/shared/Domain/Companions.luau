--!strict
-- Relic companion rules. Pure, no Roblox APIs.
--
-- A companion is owned once and one may be equipped at a time. Bonuses are
-- additive and are consumed by the stats resolver; this module never computes
-- an existing stat itself.

local Companions = {}

export type Bonuses = {
	Capacity: number?,
	WeightPenaltyReduction: number?,
	MaxHealth: number?,
	StaminaMax: number?,
	StaminaDrainReduction: number?,
	StaminaRecovery: number?,
	GoldMultiplier: number?,
}

export type Definition = {
	name: string,
	description: string,
	summary: string,
	rarity: string,
	cost: number,
	bonuses: Bonuses,
}

export type Definitions = { [string]: Definition }

-- Every bonus field the resolver understands. Unknown fields are ignored by
-- the resolver, but keeping the list here makes the aggregation explicit.
local BONUS_FIELDS = {
	"Capacity",
	"WeightPenaltyReduction",
	"MaxHealth",
	"StaminaMax",
	"StaminaDrainReduction",
	"StaminaRecovery",
	"GoldMultiplier",
}

function Companions.isDefined(definitions: Definitions, companionId: string?): boolean
	return companionId ~= nil and definitions[companionId] ~= nil
end

function Companions.owns(owned: { [string]: boolean }, companionId: string?): boolean
	return companionId ~= nil and owned[companionId] == true
end

-- Sums the bonuses of the equipped companion. An unknown or missing companion
-- grants nothing, so a damaged profile can never invent a bonus.
function Companions.bonuses(definitions: Definitions, companionId: string?): Bonuses
	local result: Bonuses = {}
	local definition = companionId and definitions[companionId]
	if definition == nil then
		return result
	end
	local source: any = definition.bonuses
	local target: any = result
	for _, field in BONUS_FIELDS do
		local value = source[field]
		if type(value) == "number" and value == value and value > 0 then
			target[field] = value
		end
	end
	return result
end

-- Equips an owned companion, replacing the current one (the limit is one).
-- Returns the new equipped id plus a success flag and a failure reason.
function Companions.equip(
	owned: { [string]: boolean },
	current: string?,
	companionId: string?
): (string?, boolean, string?)
	if companionId == nil or companionId == "" then
		return current, false, "Choose a companion to equip."
	end
	if not Companions.owns(owned, companionId) then
		return current, false, "You do not own that companion."
	end
	if current == companionId then
		return current, false, "That companion is already equipped."
	end
	return companionId, true, nil
end

-- An empty string is normalized away by the schema, so `nil` is the no-companion
-- state everywhere else.
function Companions.unequip(): string?
	return nil
end

return Companions
