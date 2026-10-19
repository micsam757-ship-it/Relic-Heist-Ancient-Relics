--!strict
-- Pure encumbrance and movement calculations. No Roblox APIs.

local Encumbrance = {}

export type MovementConfig = {
	BaseWalkSpeed: number,
	MinSpeedMultiplier: number,
	WeightPenaltyPerUnit: number,
}

export type CapacityConfig = {
	BaseCapacity: number,
	BackpackCapacityPerLevel: number,
}

function Encumbrance.capacity(config: CapacityConfig, backpackLevel: number): number
	local level = math.max(0, backpackLevel)
	return config.BaseCapacity + config.BackpackCapacityPerLevel * level
end

function Encumbrance.totalWeight(carried: { { weight: number } }): number
	local total = 0
	for _, relic in carried do
		total += math.max(0, relic.weight)
	end
	return total
end

function Encumbrance.multiplier(carriedWeight: number, movement: MovementConfig, weightPenaltyReduction: number): number
	local reduction = math.clamp(weightPenaltyReduction, 0, 0.8)
	local effectiveWeight = math.max(0, carriedWeight) * (1 - reduction)
	local multiplier = 1 - effectiveWeight * movement.WeightPenaltyPerUnit
	return math.clamp(multiplier, movement.MinSpeedMultiplier, 1)
end

function Encumbrance.walkSpeed(carriedWeight: number, movement: MovementConfig, weightPenaltyReduction: number): number
	return movement.BaseWalkSpeed * Encumbrance.multiplier(carriedWeight, movement, weightPenaltyReduction)
end

function Encumbrance.checkCapacity(
	currentWeight: number,
	addedWeight: number,
	capacity: number,
	carriedCount: number,
	maxCarried: number
): (boolean, string?)
	if carriedCount + 1 > maxCarried then
		return false, "Your satchel is full."
	end
	if currentWeight + addedWeight > capacity then
		return false, "That relic is too heavy for your pack."
	end
	return true, nil
end

return Encumbrance
