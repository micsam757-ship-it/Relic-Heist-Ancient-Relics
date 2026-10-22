--!strict
-- Pure encumbrance rules. No Roblox APIs.
--
-- The numbers behind these rules (capacity, the movement penalty, maximum
-- health) live in the stats resolver, which is the one place that combines
-- upgrades, training and companion bonuses. What stays here is the part that
-- is purely about the satchel: how heavy a haul is and whether it still fits.

local Encumbrance = {}

function Encumbrance.totalWeight(carried: { { weight: number } }): number
	local total = 0
	for _, relic in carried do
		total += math.max(0, relic.weight)
	end
	return total
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
