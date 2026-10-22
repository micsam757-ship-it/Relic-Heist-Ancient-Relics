--!strict
-- Passive training progression. No Roblox APIs.
--
-- Players earn training experience by playing; the experience buys levels that
-- feed the stats resolver. Only the experience is stored: a level is always
-- derived from the points behind it, so the two can never disagree.

local Training = {}

-- Experience per attribute, keyed by attribute id.
export type TrainingState = { [string]: number }

export type AttributeDefinition = {
	MaxLevel: number,
}

export type Progress = {
	level: number,
	xp: number,
	intoLevel: number,
	neededForNext: number,
	ratio: number,
	maxed: boolean,
	maxLevel: number,
}

-- The curve: level 1 costs BASE_XP, every further level costs GROWTH_XP more
-- than the one before it (100, 150, 200, ...).
local BASE_XP = 100
local GROWTH_XP = 50

-- The total experience needed to reach `level`.
function Training.xpForLevel(level: number): number
	local steps = math.max(0, math.floor(level))
	return BASE_XP * steps + (GROWTH_XP * steps * (steps - 1)) / 2
end

-- The experience at which an attribute is maxed out. Experience stops being
-- awarded past this point, which keeps the stored profile small.
function Training.maxXp(maxLevel: number): number
	return Training.xpForLevel(maxLevel)
end

function Training.levelForXp(xp: number, maxLevel: number): number
	local total = math.max(0, math.floor(xp))
	local limit = math.max(0, math.floor(maxLevel))
	local level = 0
	while level < limit and total >= Training.xpForLevel(level + 1) do
		level += 1
	end
	return level
end

function Training.progress(xp: number, maxLevel: number): Progress
	local limit = math.max(0, math.floor(maxLevel))
	local total = math.max(0, math.floor(xp))
	local level = Training.levelForXp(total, limit)
	local intoLevel = total - Training.xpForLevel(level)
	local neededForNext = Training.xpForLevel(level + 1) - Training.xpForLevel(level)
	local maxed = level >= limit
	local ratio = 0
	if not maxed and neededForNext > 0 then
		ratio = math.clamp(intoLevel / neededForNext, 0, 1)
	end
	return {
		level = level,
		xp = total,
		intoLevel = intoLevel,
		neededForNext = neededForNext,
		ratio = ratio,
		maxed = maxed,
		maxLevel = limit,
	}
end

-- Adds experience to one attribute and returns the new state plus the amount
-- that was actually gained (zero once the attribute is maxed).
function Training.award(
	state: TrainingState,
	attribute: string,
	amount: number,
	maxLevel: number
): (TrainingState, number)
	local cap = Training.maxXp(maxLevel)
	local current = math.max(0, math.floor(state[attribute] or 0))
	local gain = math.max(0, math.floor(amount))
	local updated = math.min(cap, current + gain)
	local nextState: TrainingState = table.clone(state)
	nextState[attribute] = updated
	return nextState, updated - current
end

-- The training levels for every attribute, ready for the stats resolver.
function Training.levels(state: TrainingState, attributes: { [string]: AttributeDefinition }): { [string]: number }
	local levels: { [string]: number } = {}
	for attribute, definition in attributes do
		levels[attribute] = Training.levelForXp(state[attribute] or 0, definition.MaxLevel)
	end
	return levels
end

return Training
