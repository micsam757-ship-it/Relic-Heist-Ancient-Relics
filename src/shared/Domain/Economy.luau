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

-- Authoritative museum rate per second. The config expresses relic income and
-- the cap per minute for readability; the domain works in per-second so accrual
-- math and the HUD share one unit. Display only rounds this value.
function Economy.incomeRatePerSecond(
	exhibitedIncomePerMinute: number,
	floorLevel: number,
	floorBonusPerLevel: number,
	capPerMinute: number
): number
	local bonus = 1 + math.max(0, floorLevel) * floorBonusPerLevel
	local ratePerMinute = math.min(math.max(0, exhibitedIncomePerMinute) * bonus, capPerMinute)
	return ratePerMinute / 60
end

function Economy.pendingIncome(
	ratePerSecond: number,
	lastClaimAt: number,
	now: number,
	offlineCapSeconds: number,
	maxPending: number
): number
	local elapsed = math.clamp(now - lastClaimAt, 0, offlineCapSeconds)
	local earned = math.floor(math.max(0, ratePerSecond) * elapsed)
	return math.clamp(earned, 0, maxPending)
end

function Economy.extractionBonus(totalRelicValue: number, valueToGold: number): number
	return math.floor(math.max(0, totalRelicValue) * math.max(0, valueToGold))
end

return Economy
