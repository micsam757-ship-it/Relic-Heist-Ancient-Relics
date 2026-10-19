--!strict
-- Pure progression rules. No Roblox APIs.

local Progression = {}

export type TempleUnlockDefinition = {
	name: string,
	minExtractions: number,
	unlockPrice: number,
}

function Progression.isUnlocked(unlockedTemples: { [string]: boolean }, templeId: string): boolean
	return unlockedTemples[templeId] == true
end

function Progression.canUnlock(
	unlockedTemples: { [string]: boolean },
	extractions: number,
	gold: number,
	temple: TempleUnlockDefinition
): (boolean, string?)
	if Progression.isUnlocked(unlockedTemples, temple.name) then
		return false, "This expedition is already unlocked."
	end
	if extractions < temple.minExtractions then
		return false,
			string.format(
				"Complete %d more successful extraction(s) to unlock this expedition.",
				temple.minExtractions - extractions
			)
	end
	if gold < temple.unlockPrice then
		return false, string.format("You need %d gold to unlock this expedition.", temple.unlockPrice)
	end
	return true, nil
end

function Progression.unlockRequirementsMet(
	unlockedTemples: { [string]: boolean },
	extractions: number,
	templeId: string,
	temple: TempleUnlockDefinition
): boolean
	if Progression.isUnlocked(unlockedTemples, templeId) then
		return true
	end
	return extractions >= temple.minExtractions
end

return Progression
