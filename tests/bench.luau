-- Standalone micro-benchmark for the hot pure functions. Run with the Luau CLI:
--   luau tests/bench.luau
--
-- These functions run on the server's 1s income tick, 0.5s expedition timer, or
-- per request, so their cost scales with player count and carried relics. The
-- point is to catch accidental O(n^2) regressions and to record a baseline for
-- docs/PERFORMANCE.md. This script never fails the build; it only reports.

local Economy = require("../src/shared/Domain/Economy")
local Encumbrance = require("../src/shared/Domain/Encumbrance")
local Inventory = require("../src/shared/Domain/Inventory")
local Util = require("../src/shared/Utilities/Util")
local Contracts = require("../src/shared/Net/Contracts")
local RateLimiter = require("../src/server/Security/RateLimiter")

local clock = os.clock

-- Runs `fn` until at least MIN_SECONDS have elapsed, then reports per-call cost.
-- Warmup passes give the JIT a chance to settle before timing.
local MIN_SECONDS = 0.25
local WARMUP = 3

local function bench(name, iterations, fn)
	for _ = 1, WARMUP do
		for _ = 1, iterations do
			fn()
		end
	end
	local start = clock()
	local calls = 0
	repeat
		for _ = 1, iterations do
			fn()
		end
		calls += iterations
	until clock() - start >= MIN_SECONDS
	local elapsed = clock() - start
	local perCallUs = elapsed / calls * 1e6
	local perSecond = calls / elapsed
	print(string.format("%-44s %10.3f us/call  %12.0f calls/s", name, perCallUs, perSecond))
	return perCallUs
end

-- Fixtures ------------------------------------------------------------------

local Upgrade = {
	name = "Armor",
	description = "",
	maxLevel = 20,
	basePrice = 100,
	priceGrowth = 1.35,
	order = 1,
	effect = "ArmorMaxHealth",
	perLevel = 10,
}

local Movement = { BaseWalkSpeed = 16, MinSpeedMultiplier = 0.4, WeightPenaltyPerUnit = 0.025 }

-- A fully-laden satchel: the worst realistic case for weight math.
local CARRIED = {}
for i = 1, 40 do
	CARRIED[i] = { weight = 2.5 + (i % 7) }
end

-- A museum with every pedestal filled and a large archive, stressing the
-- ownership/occupancy scans (isExhibited / unexhibit). 12 plots x 8 pedestals.
local function bigProfile()
	local profile = { relics = {}, museum = {} }
	for i = 1, 500 do
		profile.relics[string.format("uid-%d", i)] = { id = "Relic", acquiredAt = i }
	end
	local pedestals = 0
	for _, uid in profile.relics do
		if pedestals >= 96 then
			break
		end
		pedestals += 1
		profile.museum[tostring(pedestals)] = uid
	end
	return profile
end

local profile = bigProfile()

-- 20 guardians, each chasing the player: the hazard/guardian distance test.
local GUARDIANS = {}
for i = 1, 20 do
	GUARDIANS[i] = { x = i * 8, z = i * 5 }
end

local limiter = RateLimiter.new(120, 30)

print("== Relic Heist micro-benchmarks ==")
print(string.format("%-44s %10s       %12s", "benchmark", "us/call", "calls/s"))
print(string.rep("-", 72))

print("-- 1s income tick (per active plot) --")
bench("Economy.incomeRatePerSecond", 2000, function()
	Economy.incomeRatePerSecond(120, 5, 0.1, 900)
end)
bench("Economy.pendingIncome", 2000, function()
	Economy.pendingIncome(2.5, 0, 3600, 14400, 9999999)
end)

print("-- shared tick: encumbrance (40 relics) --")
bench("Encumbrance.totalWeight x40", 2000, function()
	Encumbrance.totalWeight(CARRIED)
end)
bench("Encumbrance.walkSpeed x40", 2000, function()
	Encumbrance.walkSpeed(100, Movement, 0.2)
end)
bench("Encumbrance.checkCapacity", 4000, function()
	Encumbrance.checkCapacity(100, 3, 200, 12, 40)
end)

print("-- per request: upgrade/price math --")
bench("Economy.upgradeCost", 4000, function()
	Economy.upgradeCost(Upgrade, 7)
end)
bench("Economy.extractionBonus", 4000, function()
	Economy.extractionBonus(1234.5, 0.75)
end)

print("-- museum snapshot / placement (96 pedestals, 500 owned) --")
bench("Inventory.countOwned (500)", 2000, function()
	Inventory.countOwned(profile)
end)
bench("Inventory.isExhibited worst case", 2000, function()
	Inventory.isExhibited(profile, "uid-500")
end)

print("-- 0.5s guardian/hazard timer (20 guardians) --")
local px, pz = 0, 0
bench("Util.distanceToSegment2D x20", 1000, function()
	for _, g in GUARDIANS do
		Util.distanceToSegment2D(px, pz, g.x, g.z, g.x + 4, g.z + 2)
	end
end)

print("-- request admission --")
bench("Contracts.check", 8000, function()
	Contracts.check("EnterExpedition", { templeId = "TutorialRuins" })
end)
bench("RateLimiter:Allow", 8000, function()
	limiter:Allow("player-1", 1)
end)

print("")
print("done (baseline; see docs/PERFORMANCE.md for budgets)")
