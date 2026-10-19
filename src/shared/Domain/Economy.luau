--!strict
-- Pure economy calculations. No Roblox APIs.

local Economy = {}

export type UpgradeDefinition = {
	name: string,
	description: string,
	maxLevel: number,
	basePrice: number,
	priceGrowth: number,
	order: number,
	effect: string,
	perLevel: number,
}

function Economy.upgradeCost(upgrade: UpgradeDefinition, currentLevel: number): number?
	local level = math.max(0, math.floor(currentLevel))
	if level >= upgrade.maxLevel then
		return nil
	end
	return math.floor(upgrade.basePrice * upgrade.priceGrowth ^ level)
end

function Economy.armorMaxHealth(base: number, perLevel: number, level: number): number
	return base + perLevel * math.max(0, level)
end

function Economy.pedestalCount(
	basePedestals: number,
	floorLevel: number,
	floorPedestalsPerLevel: number,
	extraLevel: number,
	extraPedestalsPerLevel: number,
	maximum: number
): number
	local count = basePedestals
		+ math.max(0, floorLevel) * floorPedestalsPerLevel
		+ math.max(0, extraLevel) * extraPedestalsPerLevel
	return math.clamp(count, 0, maximum)
end

function Economy.incomeRatePerMinute(
	exhibitedIncomePerMinute: number,
	floorLevel: number,
	floorBonusPerLevel: number,
	cap: number
): number
	local bonus = 1 + math.max(0, floorLevel) * floorBonusPerLevel
	return math.min(math.max(0, exhibitedIncomePerMinute) * bonus, cap)
end

function Economy.pendingIncome(
	ratePerMinute: number,
	lastClaimAt: number,
	now: number,
	offlineCapSeconds: number,
	maxPending: number
): number
	local elapsed = math.clamp(now - lastClaimAt, 0, offlineCapSeconds)
	local earned = math.floor((ratePerMinute / 60) * elapsed)
	return math.clamp(earned, 0, maxPending)
end

function Economy.extractionBonus(totalRelicValue: number, valueToGold: number): number
	return math.floor(math.max(0, totalRelicValue) * math.max(0, valueToGold))
end

return Economy
