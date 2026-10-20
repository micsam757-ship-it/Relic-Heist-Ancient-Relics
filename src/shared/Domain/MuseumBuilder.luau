--!strict
-- Pure museum-layout rules. No Roblox APIs, so the wing/pedestal layout, tier
-- selection, and enhancement gating can be unit tested and shared by the
-- builder and the services. `GameConfig.MuseumBuilding` is the data source.

export type Slot = { x: number, z: number, facing: number? }
export type WingDef = {
	id: string,
	name: string,
	description: string,
	unlockLevel: number,
	offset: { x: number, z: number },
	size: { x: number, z: number },
	height: number,
	theme: string,
	pedestalSlots: { Slot },
}
export type Placement = {
	id: string,
	wingId: string,
	wingName: string,
	slotIndex: number,
	x: number,
	z: number,
	facing: number,
}
export type TierDef = {
	tier: string,
	rank: number,
	glow: boolean,
}

local MuseumBuilder = {}

-- Wing level a player has unlocked, given the Museum Expansion upgrade level.
function MuseumBuilder.wingUnlocked(wing: WingDef, museumFloorLevel: number): boolean
	return museumFloorLevel >= (wing.unlockLevel or 0)
end

-- Flattens the wing list into ordered, plot-local pedestal placements. Wing
-- order is preserved and the walkway order within a wing is preserved, so a
-- pedestal index is stable across sessions. Global `id` is a 1-based string.
function MuseumBuilder.placements(wings: { WingDef }): { Placement }
	local placements: { Placement } = {}
	for _, wing in wings do
		for slotIndex, slot in wing.pedestalSlots do
			table.insert(placements, {
				id = tostring(#placements + 1),
				wingId = wing.id,
				wingName = wing.name,
				slotIndex = slotIndex,
				x = (wing.offset.x or 0) + (slot.x or 0),
				z = (wing.offset.z or 0) + (slot.z or 0),
				facing = slot.facing or 0,
			})
		end
	end
	return placements
end

-- The total number of pedestals the layout provides.
function MuseumBuilder.totalPedestals(wings: { WingDef }): number
	local total = 0
	for _, wing in wings do
		total += #wing.pedestalSlots
	end
	return total
end

-- Wings visible at a given Museum Expansion level, in order.
function MuseumBuilder.unlockedWings(wings: { WingDef }, museumFloorLevel: number): { WingDef }
	local result: { WingDef } = {}
	for _, wing in wings do
		if MuseumBuilder.wingUnlocked(wing, museumFloorLevel) then
			table.insert(result, wing)
		end
	end
	return result
end

-- Resolves a pedestal placement by its global id, or nil if unknown.
function MuseumBuilder.placementById(placements: { Placement }, id: string): Placement?
	for _, placement in placements do
		if placement.id == id then
			return placement
		end
	end
	return nil
end

-- Picks the pedestal tier definition for a relic rarity, falling back to Common
-- when the rarity is unknown so a pedestal always renders.
function MuseumBuilder.tierForRarity(tiers: { [string]: TierDef }, rarity: string?): TierDef
	local def = rarity ~= nil and tiers[rarity] or nil
	return def or tiers.Common
end

-- Whether a building enhancement is active at the given level.
function MuseumBuilder.enhancementActive(level: number): boolean
	return level > 0
end

-- Level of every enhancement, keyed by fixture feature (`lighting`, `pillars`,
-- ...). `enhancements` maps feature -> upgrade id; `upgrades` provides each
-- upgrade's definition (for its maxLevel) and the player's current levels.
function MuseumBuilder.featureLevels(
	enhancements: { [string]: string },
	upgrades: { [string]: any },
	profileUpgrades: { [string]: number }
): { [string]: number }
	local levels: { [string]: number } = {}
	for feature, upgradeId in enhancements do
		local definition = upgrades[upgradeId]
		local maxLevel = definition and definition.maxLevel or 0
		local level = math.clamp(math.floor(profileUpgrades[upgradeId] or 0), 0, maxLevel)
		levels[feature] = level
	end
	return levels
end

return MuseumBuilder
