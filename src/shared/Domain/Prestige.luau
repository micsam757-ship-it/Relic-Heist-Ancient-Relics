--!strict
-- Museum Prestige rules (ADR 0014). Pure and Roblox-free so eligibility, the
-- reset copy, and the reward curve are shared by the server, the snapshot, and
-- the standalone test runner.
--
-- The reset is a named allowlist: only `ResetUpgradeIds`, gold, relics, museum,
-- pending offline gold, and the timestamp change. Every other profile key is
-- copied through unchanged, including unknown keys from a newer build.

local Prestige = {}

local function deepCopy(value: any): any
	if type(value) ~= "table" then
		return value
	end
	local copy = {}
	for key, child in pairs(value) do
		copy[deepCopy(key)] = deepCopy(child)
	end
	return copy
end

local function totalPedestals(wings: any): number
	local total = 0
	for _, wing in wings or {} do
		total += #(wing.pedestalSlots or {})
	end
	return total
end

local function levelOf(upgrades: any, id: string): number
	local value: any = upgrades and upgrades[id]
	if type(value) ~= "number" then
		return 0
	end
	return math.max(0, math.floor(value))
end

-- Additive fraction granted by a prestige level, capped by the config. The bonus
-- is always derived; it is never stored on the profile.
function Prestige.bonus(level: number?, config: any): number
	local safeLevel = math.max(0, math.floor(level or 0))
	local maxLevel = math.max(0, math.floor(config.MaxLevel or 0))
	local perLevel = math.max(0, config.BonusPerLevel or 0)
	local bonus = math.min(safeLevel, maxLevel) * perLevel
	return math.clamp(bonus, 0, math.max(0, config.MaxBonus or bonus))
end

-- The full museum-income multiplier contributed by prestige, e.g. 1.25 at level 5.
function Prestige.multiplier(level: number?, config: any): number
	return 1 + Prestige.bonus(level, config)
end

-- Derived cosmetic rank title, or nil before the first prestige.
function Prestige.rank(level: number?, config: any): string?
	local safeLevel = math.max(0, math.floor(level or 0))
	local best: any = nil
	for _, entry in config.Ranks or {} do
		local minimum = entry.minLevel or 0
		if safeLevel >= minimum and (best == nil or minimum > (best.minLevel or 0)) then
			best = entry
		end
	end
	return best and best.title or nil
end

-- Evaluates every pure requirement and returns a readable checklist for the UI.
-- The server additionally checks expedition state and persistence, which are
-- runtime facts the profile alone does not contain.
function Prestige.evaluate(profile: any, config: any, wings: any, now: number)
	local checks = {}
	local eligible = true

	for _, id in config.ResetUpgradeIds or {} do
		local definition = config.Upgrades and config.Upgrades[id]
		local maxLevel: number = definition and definition.maxLevel or 0
		local level: number = levelOf(profile.upgrades, id)
		local met = maxLevel > 0 and level >= maxLevel
		if not met then
			eligible = false
		end
		table.insert(checks, {
			id = id,
			label = string.format("%s maxed", definition and definition.name or id),
			detail = string.format("%d/%d", level, maxLevel),
			met = met,
		})
	end

	local total = totalPedestals(wings)
	local occupied = 0
	local museum = profile.museum or {}
	local relics = profile.relics or {}
	for index = 1, total do
		local uid = museum[tostring(index)]
		if uid ~= nil and relics[uid] ~= nil then
			occupied += 1
		end
	end
	local exhibitsMet = total > 0 and occupied >= total
	if not exhibitsMet then
		eligible = false
	end
	table.insert(checks, {
		id = "Pedestals",
		label = "Fill every pedestal",
		detail = string.format("%d/%d", occupied, total),
		met = exhibitsMet,
	})

	local minSeconds = math.max(0, config.MinSecondsBetween or 0)
	local lastPrestigeAt = profile.lastPrestigeAt or 0
	local cooldownRemaining = 0
	if lastPrestigeAt > 0 then
		cooldownRemaining = math.max(0, math.ceil(lastPrestigeAt + minSeconds - now))
	end
	local cooldownMet = cooldownRemaining <= 0
	if not cooldownMet then
		eligible = false
	end
	table.insert(checks, {
		id = "Cooldown",
		label = "Prestige cooldown",
		detail = cooldownMet and "Ready" or string.format("%ds left", cooldownRemaining),
		met = cooldownMet,
	})

	return {
		eligible = eligible,
		checks = checks,
		occupied = occupied,
		totalPedestals = total,
		cooldownRemaining = cooldownRemaining,
	}
end

function Prestige.canPrestige(profile: any, config: any, wings: any, now: number): boolean
	return Prestige.evaluate(profile, config, wings, now).eligible
end

-- Builds the reset profile without mutating the input. The caller persists the
-- result before applying any side effects.
function Prestige.apply(profile: any, config: any, now: number)
	local nextProfile: any = deepCopy(profile)
	nextProfile.gold = math.max(0, math.floor(config.StartingGold or 0))
	nextProfile.relics = {}
	nextProfile.museum = {}
	if type(nextProfile.upgrades) ~= "table" then
		nextProfile.upgrades = {}
	end
	for _, id in config.ResetUpgradeIds or {} do
		nextProfile.upgrades[id] = 0
	end
	nextProfile.pendingOfflineGold = 0
	nextProfile.lastIncomeClaimAt = now
	nextProfile.prestigeLevel = math.max(0, math.floor(nextProfile.prestigeLevel or 0)) + 1
	nextProfile.lastPrestigeAt = now
	return nextProfile
end

return Prestige
