--!strict
-- Pure expedition run rules: spawn planning, extraction credit, and the
-- haulability invariant that keeps every temple solvable. No Roblox APIs.

local RunRules = {}

export type SpawnEntry = { definitionId: string }
export type TempleConfig = {
	requiredRelics: number,
	relicSpawns: { SpawnEntry },
}
export type RelicDefinitions = { [string]: { weight: number } }

-- Deterministic per-temple spawn plan: the same temple table always yields
-- the same ordered list of definition ids, so per-expedition spawning is
-- reproducible and testable without touching the world.
function RunRules.spawnPlan(temple: TempleConfig): { string }
	local plan = {}
	for _, spawn in temple.relicSpawns do
		table.insert(plan, spawn.definitionId)
	end
	return plan
end

-- An extraction earns progression credit (a counted extraction toward the
-- next temple's unlock gate) only when it delivers at least the temple's
-- required relic count. Gold is always paid by the caller; this decides
-- credit only. The positive-haul clause closes the walk-in walk-out farm on
-- temples whose requirement is zero.
function RunRules.extractionCredit(transferred: number, requiredRelics: number): boolean
	local required = math.max(0, math.floor(requiredRelics))
	return transferred > 0 and transferred >= required
end

-- Total weight of the temple's N lightest relics, where N is the required
-- count. This must never exceed the fully upgraded carrying capacity, or the
-- temple's requiredRelics is unsatisfiable.
function RunRules.lightestHaulWeight(temple: TempleConfig, relics: RelicDefinitions): number
	local weights = {}
	for _, spawn in temple.relicSpawns do
		local definition = relics[spawn.definitionId]
		if definition ~= nil then
			table.insert(weights, math.max(0, definition.weight))
		end
	end
	table.sort(weights)
	local total = 0
	local wanted = math.clamp(temple.requiredRelics, 0, #weights)
	for index = 1, wanted do
		total += weights[index]
	end
	return total
end

return RunRules
