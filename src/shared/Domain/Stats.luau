--!strict
-- The single effective-stat resolver.
--
-- Capacity, the movement penalty from carried weight, maximum health and the
-- stamina pool can each be raised by more than one source: shop upgrades,
-- passive training and (later) companions. All of them are derived here
-- exactly once so no two systems can disagree about the same number.
--
-- The module is pure and requires nothing, so it runs under the standalone Luau
-- CLI test runner like the other domain rules.

local Stats = {}

export type MovementConfig = {
	BaseWalkSpeed: number,
	MinSpeedMultiplier: number,
	WeightPenaltyPerUnit: number,
	SprintSpeedMultiplier: number,
	BaseCapacity: number,
	BackpackCapacityPerLevel: number,
	BaseMaxHealth: number,
	ArmorHealthPerLevel: number,
}

export type StaminaConfig = {
	BaseMax: number,
	BaseDrainPerSecond: number,
	MinDrainPerSecond: number,
	RecoveryPerSecond: number,
}

export type UpgradeStatDefinition = {
	perLevel: number,
	maxLevel: number,
}

export type TrainingAttributeDefinition = {
	MaxLevel: number,
	CapacityPerLevel: number,
	WeightPenaltyReductionPerLevel: number,
	StaminaMaxPerLevel: number,
	StaminaDrainReductionPerLevel: number,
}

export type StatConfig = {
	Movement: MovementConfig,
	Stamina: StaminaConfig,
	Upgrades: { [string]: UpgradeStatDefinition },
	Training: { [string]: TrainingAttributeDefinition },
}

-- Level tables keyed by id: shop upgrade ids and training attribute ids.
export type Levels = { [string]: number }

-- Additive bonuses from sources that are not levels, such as companions.
export type CompanionBonuses = {
	Capacity: number?,
	WeightPenaltyReduction: number?,
	MaxHealth: number?,
	StaminaMax: number?,
	StaminaDrainReduction: number?,
	StaminaRecovery: number?,
}

export type EffectiveStats = {
	capacity: number,
	weightPenaltyReduction: number,
	maxHealth: number,
	staminaMax: number,
	staminaDrainPerSecond: number,
	staminaRecoveryPerSecond: number,
	sprintSpeedMultiplier: number,
}

-- The movement penalty can never be reduced by more than this share of the
-- carried weight, no matter how many sources stack up.
local MAX_WEIGHT_PENALTY_REDUCTION = 0.8

local function levelOf(levels: Levels, id: string): number
	return math.max(0, math.floor(levels[id] or 0))
end

-- Training levels are clamped to the attribute maximum so a damaged profile
-- can never grant more than the design allows.
function Stats.trainingLevel(config: StatConfig, attribute: string, level: number): number
	local definition = config.Training[attribute]
	if definition == nil then
		return 0
	end
	return math.clamp(math.max(0, math.floor(level)), 0, definition.MaxLevel)
end

function Stats.capacity(config: StatConfig, upgrades: Levels, training: Levels, companions: CompanionBonuses?): number
	local carryingLevel = Stats.trainingLevel(config, "carrying", training.carrying or 0)
	local carrying = config.Training.carrying
	local trainingBonus = 0
	if carrying ~= nil then
		trainingBonus = carrying.CapacityPerLevel * carryingLevel
	end
	local companionBonus = 0
	if companions ~= nil then
		companionBonus = companions.Capacity or 0
	end
	return config.Movement.BaseCapacity
		+ config.Movement.BackpackCapacityPerLevel * levelOf(upgrades, "Backpack")
		+ trainingBonus
		+ companionBonus
end

function Stats.weightPenaltyReduction(
	config: StatConfig,
	upgrades: Levels,
	training: Levels,
	companions: CompanionBonuses?
): number
	local reduction = 0
	local boots = config.Upgrades.SprintBoots
	if boots ~= nil then
		reduction += boots.perLevel * levelOf(upgrades, "SprintBoots")
	end
	local strengthLevel = Stats.trainingLevel(config, "strength", training.strength or 0)
	local strength = config.Training.strength
	if strength ~= nil then
		reduction += strength.WeightPenaltyReductionPerLevel * strengthLevel
	end
	if companions ~= nil then
		reduction += companions.WeightPenaltyReduction or 0
	end
	return math.clamp(reduction, 0, MAX_WEIGHT_PENALTY_REDUCTION)
end

function Stats.speedMultiplier(carriedWeight: number, movement: MovementConfig, weightPenaltyReduction: number): number
	local reduction = math.clamp(weightPenaltyReduction, 0, MAX_WEIGHT_PENALTY_REDUCTION)
	local effectiveWeight = math.max(0, carriedWeight) * (1 - reduction)
	local multiplier = 1 - effectiveWeight * movement.WeightPenaltyPerUnit
	return math.clamp(multiplier, movement.MinSpeedMultiplier, 1)
end

function Stats.walkSpeed(carriedWeight: number, movement: MovementConfig, weightPenaltyReduction: number): number
	return movement.BaseWalkSpeed * Stats.speedMultiplier(carriedWeight, movement, weightPenaltyReduction)
end

function Stats.sprintSpeed(carriedWeight: number, movement: MovementConfig, weightPenaltyReduction: number): number
	return Stats.walkSpeed(carriedWeight, movement, weightPenaltyReduction) * movement.SprintSpeedMultiplier
end

function Stats.maxHealth(config: StatConfig, upgrades: Levels, _training: Levels, companions: CompanionBonuses?): number
	local health = config.Movement.BaseMaxHealth
	local armor = config.Upgrades.Armor
	if armor ~= nil then
		health += armor.perLevel * levelOf(upgrades, "Armor")
	end
	if companions ~= nil then
		health += companions.MaxHealth or 0
	end
	return health
end

function Stats.staminaMax(config: StatConfig, training: Levels, companions: CompanionBonuses?): number
	local staminaLevel = Stats.trainingLevel(config, "stamina", training.stamina or 0)
	local stamina = config.Training.stamina
	local max = config.Stamina.BaseMax
	if stamina ~= nil then
		max += stamina.StaminaMaxPerLevel * staminaLevel
	end
	if companions ~= nil then
		max += companions.StaminaMax or 0
	end
	return max
end

function Stats.staminaDrainPerSecond(config: StatConfig, training: Levels, companions: CompanionBonuses?): number
	local staminaLevel = Stats.trainingLevel(config, "stamina", training.stamina or 0)
	local stamina = config.Training.stamina
	local drain = config.Stamina.BaseDrainPerSecond
	if stamina ~= nil then
		drain -= stamina.StaminaDrainReductionPerLevel * staminaLevel
	end
	if companions ~= nil then
		drain -= companions.StaminaDrainReduction or 0
	end
	return math.max(config.Stamina.MinDrainPerSecond, drain)
end

function Stats.staminaRecoveryPerSecond(config: StatConfig, companions: CompanionBonuses?): number
	local recovery = config.Stamina.RecoveryPerSecond
	if companions ~= nil then
		recovery += companions.StaminaRecovery or 0
	end
	return math.max(0, recovery)
end

-- Resolves every derived stat from the sources that can raise it.
function Stats.resolve(
	config: StatConfig,
	upgrades: Levels,
	training: Levels,
	companions: CompanionBonuses?
): EffectiveStats
	return {
		capacity = Stats.capacity(config, upgrades, training, companions),
		weightPenaltyReduction = Stats.weightPenaltyReduction(config, upgrades, training, companions),
		maxHealth = Stats.maxHealth(config, upgrades, training, companions),
		staminaMax = Stats.staminaMax(config, training, companions),
		staminaDrainPerSecond = Stats.staminaDrainPerSecond(config, training, companions),
		staminaRecoveryPerSecond = Stats.staminaRecoveryPerSecond(config, companions),
		sprintSpeedMultiplier = config.Movement.SprintSpeedMultiplier,
	}
end

return Stats
