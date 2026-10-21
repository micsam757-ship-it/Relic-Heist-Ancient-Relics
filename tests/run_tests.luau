-- Standalone pure-logic test suite. Run with the Luau CLI:
--   luau tests/run_tests.luau
-- These tests cover only modules that contain no Roblox APIs.

local Economy = require("../src/shared/Domain/Economy")
local Encumbrance = require("../src/shared/Domain/Encumbrance")
local Inventory = require("../src/shared/Domain/Inventory")
local Progression = require("../src/shared/Domain/Progression")
local RunRules = require("../src/shared/Domain/RunRules")
local Schema = require("../src/shared/Domain/Schema")
local SceneryLayout = require("../src/shared/Domain/SceneryLayout")
local Tutorial = require("../src/shared/Domain/Tutorial")
local GameConfig = require("../src/shared/Config/GameConfig")
local Util = require("../src/shared/Utilities/Util")
local Validate = require("../src/shared/Utilities/Validate")
local Persist = require("../src/shared/Utilities/Persist")
local Contracts = require("../src/shared/Net/Contracts")
local RateLimiter = require("../src/server/Security/RateLimiter")

local passed = 0
local failed = 0

local function test(name, fn)
	local ok, err = pcall(fn)
	if ok then
		passed += 1
		print(string.format("[PASS] %s", name))
	else
		failed += 1
		print(string.format("[FAIL] %s\n        %s", name, tostring(err)))
	end
end

local function assertEquals(actual, expected, message)
	if actual ~= expected then
		error(
			string.format("%s: expected %s, got %s", message or "assertEquals", tostring(expected), tostring(actual)),
			2
		)
	end
end

local function assertTrue(value, message)
	if value ~= true then
		error(message or "expected true", 2)
	end
end

local function assertFalse(value, message)
	if value ~= false then
		error(message or "expected false", 2)
	end
end

-- Economy ------------------------------------------------------------------

test("upgradeCost scales with level and caps at max", function()
	local upgrade = GameConfig.Upgrades.SprintBoots
	assertEquals(Economy.upgradeCost(upgrade, 0), upgrade.basePrice, "level 0 cost")
	local expectedLevel2 = math.floor(upgrade.basePrice * upgrade.priceGrowth ^ 2)
	assertEquals(Economy.upgradeCost(upgrade, 2), expectedLevel2, "level 2 cost")
	assertEquals(Economy.upgradeCost(upgrade, upgrade.maxLevel), nil, "maxed returns nil")
end)

test("armorMaxHealth adds per level", function()
	assertEquals(Economy.armorMaxHealth(100, 20, 3), 160, "health at level 3")
end)

test("pedestalCount clamps to maximum", function()
	assertEquals(Economy.pedestalCount(4, 2, 2, 2, 1, 8), 8, "clamped")
	assertEquals(Economy.pedestalCount(4, 0, 2, 0, 1, 8), 4, "base only")
end)

test("incomeRatePerSecond applies floor bonus and cap, then divides by 60", function()
	assertEquals(Economy.incomeRatePerSecond(6000, 1, 0.05, 300000), 105, "5% bonus of 100/min")
	assertEquals(Economy.incomeRatePerSecond(6000000, 0, 0.05, 300000), 5000, "cap of 300000/min")
	assertEquals(Economy.incomeRatePerSecond(0, 0, 0.05, 300000), 0, "no exhibits")
end)

test("pendingIncome accrues per second up to the offline cap and max", function()
	assertEquals(Economy.pendingIncome(1, 0, 60, 28800, 50000), 60, "one minute at 1/sec")
	local expected = 28800
	assertEquals(Economy.pendingIncome(1, 0, 28800 * 2, 28800, 50000), expected, "clamped to offline window")
	assertEquals(Economy.pendingIncome(60, 0, 28800 * 2, 28800, 50000), 50000, "clamped to max pending")
	assertEquals(Economy.pendingIncome(60, 0, 28800, 28800, 10), 10, "small cap wins")
end)

test("extractionBonus floors value to gold", function()
	assertEquals(Economy.extractionBonus(1001, 0.25), 250, "floor of 250.25")
end)

-- Encumbrance --------------------------------------------------------------

test("capacity grows with backpack level", function()
	assertEquals(Encumbrance.capacity(GameConfig.Movement, 0), 40, "base")
	assertEquals(Encumbrance.capacity(GameConfig.Movement, 2), 80, "two levels")
end)

test("multiplier clamps at floor and never exceeds one", function()
	assertEquals(Encumbrance.multiplier(0, GameConfig.Movement, 0), 1, "empty")
	assertEquals(
		Encumbrance.multiplier(100000, GameConfig.Movement, 0),
		GameConfig.Movement.MinSpeedMultiplier,
		"clamped"
	)
end)

test("walkSpeed scales from base", function()
	assertEquals(Encumbrance.walkSpeed(0, GameConfig.Movement, 0), GameConfig.Movement.BaseWalkSpeed, "full speed")
end)

test("checkCapacity rejects overweight and over-count", function()
	local ok, reason = Encumbrance.checkCapacity(39, 5, 40, 0, 10)
	assertFalse(ok, "overweight rejected")
	assertTrue(type(reason) == "string", "reason provided")
	local okCount = Encumbrance.checkCapacity(0, 1, 40, 10, 10)
	assertFalse(okCount, "count rejected")
	assertTrue(Encumbrance.checkCapacity(0, 5, 40, 0, 10), "valid accepted")
end)

-- Inventory ----------------------------------------------------------------

local function newProfile()
	return { relics = {}, museum = {} }
end

test("addOwned enforces uniqueness and capacity", function()
	local profile = newProfile()
	assertTrue(Inventory.addOwned(profile, "r1", "ClayAnkh", 1, 2))
	local dup = Inventory.addOwned(profile, "r1", "ClayAnkh", 2, 2)
	assertFalse(dup, "duplicate rejected")
	assertTrue(Inventory.addOwned(profile, "r2", "GoldenScarab", 2, 2))
	local full = Inventory.addOwned(profile, "r3", "SunstoneIdol", 3, 2)
	assertFalse(full, "capacity rejected")
	assertEquals(Inventory.countOwned(profile), 2, "count")
end)

test("exhibit validates pedestal, ownership and occupancy", function()
	local profile = newProfile()
	Inventory.addOwned(profile, "r1", "ClayAnkh", 1, 10)
	assertFalse(Inventory.exhibit(profile, "r1", "9", 8), "locked pedestal rejected")
	assertFalse(Inventory.exhibit(profile, "missing", "1", 8), "unowned rejected")
	assertTrue(Inventory.exhibit(profile, "r1", "1", 8))
	assertFalse(Inventory.exhibit(profile, "r1", "1", 8), "occupied rejected")
	assertTrue(Inventory.isExhibited(profile, "r1"), "shows as exhibited")
end)

test("unexhibit frees the pedestal and returns the uid", function()
	local profile = newProfile()
	Inventory.addOwned(profile, "r1", "ClayAnkh", 1, 10)
	Inventory.exhibit(profile, "r1", "1", 8)
	local uid = Inventory.unexhibit(profile, "1")
	assertEquals(uid, "r1", "returned uid")
	assertFalse(Inventory.isExhibited(profile, "r1"), "no longer exhibited")
	assertEquals(Inventory.unexhibit(profile, "1"), nil, "empty pedestal returns nil")
end)

test("removeOwned clears any pedestal referencing it", function()
	local profile = newProfile()
	Inventory.addOwned(profile, "r1", "ClayAnkh", 1, 10)
	Inventory.exhibit(profile, "r1", "2", 8)
	assertTrue(Inventory.removeOwned(profile, "r1"))
	assertEquals(profile.museum["2"], nil, "pedestal cleared")
end)

-- Progression --------------------------------------------------------------

test("canUnlock requires extractions and gold", function()
	local temple = { name = "ForgottenCatacombs", minExtractions = 1, unlockPrice = 500 }
	local ok1, reason1 = Progression.canUnlock({}, 0, 1000, temple)
	assertFalse(ok1, "extraction requirement")
	assertTrue(type(reason1) == "string")
	local ok2 = Progression.canUnlock({}, 1, 100, temple)
	assertFalse(ok2, "gold requirement")
	assertTrue(Progression.canUnlock({}, 1, 500, temple), "unlockable")
	assertFalse(Progression.canUnlock({ ForgottenCatacombs = true }, 5, 5000, temple), "already unlocked")
end)

-- Schema -------------------------------------------------------------------

test("createDefault produces a valid v1 profile", function()
	local profile = Schema.createDefault(100, "session", 250)
	assertEquals(profile.schemaVersion, Schema.CURRENT_VERSION)
	assertEquals(profile.gold, 250)
	assertTrue(profile.unlockedTemples.TutorialRuins == true)
	assertEquals(profile.stats.extractions, 0)
end)

test("migrate rejects future schema versions", function()
	local result, _, err = Schema.migrate({ schemaVersion = 99 }, 0)
	assertEquals(result, nil)
	assertTrue(type(err) == "string")
end)

test("migrate fills missing fields for version 0", function()
	local legacy = { schemaVersion = 0, sessionId = "old", gold = 5 }
	local migrated, didMigrate = Schema.migrate(legacy, 50)
	assertTrue(migrated ~= nil, "migrated")
	assertTrue(didMigrate, "flagged as migrated")
	assertEquals(migrated.schemaVersion, Schema.CURRENT_VERSION)
	assertTrue(type(migrated.stats) == "table")
end)

test("createDefault seeds monetization fields", function()
	local profile = Schema.createDefault(100, "session", 250)
	assertEquals(profile.pendingOfflineGold, 0, "no pending offline gold")
	assertEquals(profile.vip, false, "not VIP by default")
end)

test("migrate upgrades v1 profiles to v2 with monetization fields", function()
	local v1 = {
		schemaVersion = 1,
		sessionId = "old",
		updatedAt = 10,
		gold = 500,
		tutorialComplete = true,
		stats = { extractions = 1, deaths = 0, relicsCollected = 2, incomeClaimed = 0 },
		relics = {},
		museum = {},
		upgrades = {},
		unlockedTemples = { TutorialRuins = true },
		lastIncomeClaimAt = 10,
		settings = { soundEnabled = true, visualEffects = true },
	}
	local migrated, didMigrate = Schema.migrate(v1, 50)
	assertTrue(migrated ~= nil, "migrated")
	assertTrue(didMigrate, "flagged as migrated")
	assertEquals(migrated.schemaVersion, Schema.CURRENT_VERSION)
	assertEquals(migrated.pendingOfflineGold, 0, "pending seeded")
	assertEquals(migrated.vip, false, "vip seeded")
	assertEquals(migrated.gold, 500, "existing gold preserved")
end)

test("normalize clamps pending gold and coerces vip", function()
	local profile = Schema.createDefault(100, "s", 250)
	profile.pendingOfflineGold = -120.7
	profile.vip = "yes"
	local normalized = Schema.normalize(profile, 200)
	assertEquals(normalized.pendingOfflineGold, 0, "negative pending clamped")
	assertEquals(normalized.vip, false, "non-boolean vip coerced")
end)

test("VIP config raises both the offline window and ceiling", function()
	assertTrue(GameConfig.Economy.VipOfflineCapSeconds > GameConfig.Economy.OfflineCapSeconds, "vip window is longer")
	assertTrue(GameConfig.Economy.VipMaxPendingIncome > GameConfig.Economy.MaxPendingIncome, "vip ceiling is higher")
	assertEquals(GameConfig.Economy.OfflineCapSeconds, 4 * 60 * 60, "standard window is 4h")
end)

test("total progression costs exceed the offline caps", function()
	local total = 0
	for _, temple in GameConfig.Temples do
		total += temple.unlockPrice
	end
	for _, upgrade in GameConfig.Upgrades do
		for level = 0, upgrade.maxLevel - 1 do
			total += Economy.upgradeCost(upgrade, level) or 0
		end
	end
	assertTrue(
		total > GameConfig.Economy.VipMaxPendingIncome,
		string.format(
			"progression sinks (%d) must exceed the VIP offline ceiling (%d)",
			total,
			GameConfig.Economy.VipMaxPendingIncome
		)
	)
	assertTrue(GameConfig.Economy.MaxPendingIncome < total, "standard offline ceiling must stay below total sinks")
end)

test("normalize strips invalid data and clamps values", function()
	local profile = Schema.createDefault(100, "s", 250)
	profile.gold = -50
	profile.relics = { r1 = { id = "ClayAnkh", acquiredAt = 5 }, bad = "nope" }
	profile.museum = { ["1"] = "r1", ["2"] = "missing", ["3"] = "r1" }
	profile.upgrades = { SprintBoots = -2 }
	local normalized = Schema.normalize(profile, 200)
	assertEquals(normalized.gold, 0, "gold clamped")
	assertEquals(normalized.relics.bad, nil, "invalid relic removed")
	assertEquals(normalized.museum["2"], nil, "dangling reference removed")
	assertEquals(normalized.upgrades.SprintBoots, 0, "negative upgrade clamped")
end)

-- Tutorial -----------------------------------------------------------------

local tutorialSteps = {
	{ id = "a", title = "A", text = "", complete = "enteredTemple" },
	{ id = "b", title = "B", text = "", complete = "collectedRelic" },
	{ id = "c", title = "C", text = "", complete = "extracted" },
}

test("tutorial advance requires the next step's action in order", function()
	assertEquals(Tutorial.advance(0, tutorialSteps, "collectedRelic"), 0, "out of order ignored")
	assertEquals(Tutorial.advance(0, tutorialSteps, "enteredTemple"), 1, "first step advances")
	assertEquals(Tutorial.advance(1, tutorialSteps, "enteredTemple"), 1, "repeat ignored")
	assertEquals(Tutorial.advance(1, tutorialSteps, "collectedRelic"), 2, "second step advances")
	assertEquals(Tutorial.advance(3, tutorialSteps, "extracted"), 3, "past end stays complete")
end)

test("tutorial isComplete compares completed count to total", function()
	assertFalse(Tutorial.isComplete(0, tutorialSteps), "start incomplete")
	assertFalse(Tutorial.isComplete(2, tutorialSteps), "penultimate incomplete")
	assertTrue(Tutorial.isComplete(3, tutorialSteps), "all complete")
	assertTrue(Tutorial.isComplete(0, {}), "empty tutorial is complete")
end)

test("tutorial stepIndexForAction finds the matching step", function()
	assertEquals(Tutorial.stepIndexForAction(tutorialSteps, "collectedRelic"), 2, "second step index")
	assertEquals(Tutorial.stepIndexForAction(tutorialSteps, "unknown"), nil, "unknown action")
end)

test("tutorial view reports progress and clamps out-of-range input", function()
	local view = Tutorial.view(1, tutorialSteps)
	assertTrue(view.active, "active mid-tutorial")
	assertEquals(view.completed, 1)
	assertEquals(view.total, 3)
	assertEquals(view.step.id, "b", "current step is the next one")
	local done = Tutorial.view(99, tutorialSteps)
	assertFalse(done.active, "complete view inactive")
	assertEquals(done.completed, 3, "clamped to total")
	local empty = Tutorial.view(0, {})
	assertFalse(empty.active, "empty tutorial inactive")
	assertEquals(empty.step, nil, "empty tutorial has no step")
end)

-- Schema v3 ----------------------------------------------------------------

test("migrate upgrades v2 profiles to v3 with settings and tutorial step", function()
	local v2 = {
		schemaVersion = 2,
		sessionId = "old",
		updatedAt = 10,
		gold = 500,
		tutorialComplete = false,
		stats = { extractions = 1, deaths = 0, relicsCollected = 2, incomeClaimed = 0 },
		relics = {},
		museum = {},
		upgrades = {},
		unlockedTemples = { TutorialRuins = true },
		lastIncomeClaimAt = 10,
		pendingOfflineGold = 42,
		vip = true,
		settings = { soundEnabled = false, visualEffects = true },
	}
	local migrated, didMigrate = Schema.migrate(v2, 50)
	assertTrue(migrated ~= nil, "migrated")
	assertTrue(didMigrate, "flagged as migrated")
	assertEquals(migrated.schemaVersion, Schema.CURRENT_VERSION)
	assertEquals(migrated.pendingOfflineGold, 42, "existing pending preserved")
	assertEquals(migrated.vip, true, "existing vip preserved")
	assertEquals(migrated.tutorialStep, 0, "tutorial step seeded")
	assertEquals(migrated.settings.soundEnabled, false, "existing setting preserved")
	assertEquals(migrated.settings.reducedMotion, false, "reducedMotion seeded")
	assertEquals(migrated.settings.colorblindMode, false, "colorblindMode seeded")
	assertEquals(migrated.settings.textScale, "Normal", "textScale seeded")
end)

test("normalize clamps tutorial step and rejects invalid text scale", function()
	local profile = Schema.createDefault(100, "s", 250)
	profile.tutorialStep = -3
	profile.settings.textScale = "Gigantic"
	profile.settings.reducedMotion = "yes"
	local normalized = Schema.normalize(profile, 200)
	assertEquals(normalized.tutorialStep, 0, "negative tutorial step clamped")
	assertEquals(normalized.settings.textScale, "Normal", "invalid text scale coerced")
	assertEquals(normalized.settings.reducedMotion, false, "non-boolean coerced")
end)

test("createDefault seeds accessibility settings and tutorial step", function()
	local profile = Schema.createDefault(100, "session", 250)
	assertEquals(profile.tutorialStep, 0, "tutorial starts at step zero")
	assertEquals(profile.settings.textScale, "Normal", "default text scale")
	assertEquals(profile.settings.reducedMotion, false, "reduced motion off")
	assertEquals(profile.settings.colorblindMode, false, "colorblind palette off")
end)

-- Util ---------------------------------------------------------------------

test("distanceToSegment2D handles on-segment, endpoint and perpendicular", function()
	assertEquals(Util.distanceToSegment2D(5, 0, 0, 0, 10, 0), 0, "on segment")
	assertEquals(Util.distanceToSegment2D(20, 0, 0, 0, 10, 0), 10, "beyond end")
	assertEquals(Util.distanceToSegment2D(5, 3, 0, 0, 10, 0), 3, "perpendicular")
	assertTrue(Util.distanceToSegment2D(0, 0, 0, 0, 0, 0) >= 0, "degenerate segment defined")
end)

-- GameConfig integrity -----------------------------------------------------

local VISUAL_KINDS = {
	scarab = true,
	ankh = true,
	idol = true,
	mask = true,
	urn = true,
	jackal = true,
	crystal = true,
	core = true,
}

test("every relic spawn references a defined relic", function()
	for templeId, temple in GameConfig.Temples do
		assertTrue(#temple.relicSpawns > 0, templeId .. " has relic spawns")
		for _, spawn in temple.relicSpawns do
			assertTrue(
				GameConfig.Relics[spawn.definitionId] ~= nil,
				string.format("%s spawns unknown relic %s", templeId, tostring(spawn.definitionId))
			)
		end
	end
end)

test("every relic visual kind is supported by the renderer", function()
	for relicId, relic in GameConfig.Relics do
		assertTrue(
			VISUAL_KINDS[relic.visual.kind] == true,
			string.format("%s uses unsupported visual kind %s", relicId, tostring(relic.visual.kind))
		)
	end
end)

test("every trap kind is handled by the hazard service", function()
	local supported = { dart = true, boulder = true, blade = true }
	for templeId, temple in GameConfig.Temples do
		for _, trap in temple.traps or {} do
			assertTrue(
				supported[trap.kind] == true,
				string.format("%s has unsupported trap kind %s", templeId, tostring(trap.kind))
			)
		end
	end
end)

test("every guardian kind is defined and has a patrol route", function()
	for templeId, temple in GameConfig.Temples do
		for _, guardian in temple.guardians or {} do
			assertTrue(
				GameConfig.Enemies.Kinds[guardian.kind] ~= nil,
				string.format("%s has unsupported guardian kind %s", templeId, tostring(guardian.kind))
			)
			assertTrue(
				type(guardian.waypoints) == "table" and #guardian.waypoints >= 2,
				string.format("%s guardian '%s' needs at least two waypoints", templeId, tostring(guardian.label))
			)
		end
	end
end)

test("guardian defaults resolve when a config omits overrides", function()
	local kind = GameConfig.Enemies.Kinds.Guardian
	assertTrue(kind ~= nil, "Guardian kind defined")
	assertTrue(kind.walkSpeed > 0 and kind.damage > 0, "positive speed and damage")
	assertTrue(kind.aggroRange > kind.contactRange, "aggro range exceeds contact range")
	assertTrue(GameConfig.Enemies.ContactCooldownSeconds > 0, "positive contact cooldown")
end)

test("guardian waypoints stay inside their temple hall footprint", function()
	for templeId, temple in GameConfig.Temples do
		local halfWidth = temple.hall.width / 2
		local length = temple.hall.length
		for _, guardian in temple.guardians or {} do
			for index, waypoint in guardian.waypoints do
				local within = waypoint.x >= -halfWidth
					and waypoint.x <= halfWidth
					and waypoint.z >= 0
					and waypoint.z <= length
				assertTrue(
					within,
					string.format(
						"%s guardian '%s' waypoint %d (%d, %d) is outside the %dx%d hall",
						templeId,
						tostring(guardian.label),
						index,
						waypoint.x,
						waypoint.z,
						temple.hall.width,
						length
					)
				)
			end
		end
	end
end)

test("every relic templeIds reference a defined temple", function()
	for relicId, relic in GameConfig.Relics do
		for _, templeId in relic.templeIds do
			assertTrue(
				GameConfig.Temples[templeId] ~= nil,
				string.format("%s references unknown temple %s", relicId, tostring(templeId))
			)
		end
	end
end)

test("unlock requirements increase with temple order", function()
	local ordered = {}
	for _, temple in GameConfig.Temples do
		table.insert(ordered, temple)
	end
	table.sort(ordered, function(a, b)
		return a.order < b.order
	end)
	local previous = -1
	for _, temple in ordered do
		assertTrue(temple.minExtractions >= previous, string.format("%s breaks the unlock chain", temple.name))
		previous = temple.minExtractions
	end
end)

test("temple unlock prices cost a fair band of the previous tier's earnings", function()
	local function bestHaulValue(temple)
		local best = 0
		local spawns = temple.relicSpawns
		for mask = 1, 2 ^ #spawns - 1 do
			local weight = 0
			local value = 0
			for index = 1, #spawns do
				if bit32.band(mask, 2 ^ (index - 1)) ~= 0 then
					local relic = GameConfig.Relics[spawns[index].definitionId]
					weight += relic.weight
					value += relic.value
				end
			end
			if weight <= 160 and value > best then
				best = value
			end
		end
		return best
	end
	local ordered = {}
	for _, temple in GameConfig.Temples do
		table.insert(ordered, temple)
	end
	table.sort(ordered, function(a, b)
		return a.order < b.order
	end)
	for index = 2, #ordered do
		local temple = ordered[index]
		local goldPerRun = math.floor(bestHaulValue(ordered[index - 1]) * GameConfig.Economy.ExtractionValueToGold)
		assertTrue(goldPerRun > 0, temple.name .. " has no earning baseline")
		local runs = temple.unlockPrice / goldPerRun
		assertTrue(
			runs >= 1.2 and runs <= 6,
			string.format(
				"%s unlock (%d gold) costs %.1f runs of the previous tier (band is 1.2-6)",
				temple.name,
				temple.unlockPrice,
				runs
			)
		)
	end
end)

-- Endgame temple + difficulty ramp -----------------------------------------

test("Void Citadel is the last-order endgame temple", function()
	local citadel = GameConfig.Temples.VoidCitadel
	assertTrue(citadel ~= nil, "Void Citadel defined")
	local maxOrder = 0
	local maxDifficulty = 0
	for _, temple in GameConfig.Temples do
		maxOrder = math.max(maxOrder, temple.order or 0)
		maxDifficulty = math.max(maxDifficulty, temple.difficulty or 0)
	end
	assertEquals(citadel.order, maxOrder, "Void Citadel is the final temple")
	assertEquals(citadel.difficulty, maxDifficulty, "Void Citadel is the hardest temple")
	assertEquals(citadel.theme, "void", "Void Citadel uses the void theme")
end)

test("Void Citadel is harder and richer than every earlier temple", function()
	local citadel = GameConfig.Temples.VoidCitadel
	for templeId, temple in GameConfig.Temples do
		if templeId ~= "VoidCitadel" then
			assertTrue(citadel.minExtractions > temple.minExtractions, templeId .. " unlock is below the Citadel")
			assertTrue(citadel.unlockPrice >= temple.unlockPrice, templeId .. " price is above the Citadel")
			assertTrue(
				citadel.durationSeconds >= temple.durationSeconds,
				templeId .. " grants a longer expedition than the Citadel"
			)
		end
	end
	local total = 0
	for _, spawn in citadel.relicSpawns do
		total += GameConfig.Relics[spawn.definitionId].value
	end
	local previousTotal = 0
	for _, spawn in GameConfig.Temples.SunkenSanctum.relicSpawns do
		previousTotal += GameConfig.Relics[spawn.definitionId].value
	end
	assertTrue(total > previousTotal, "Citadel haul outvalues the previous endgame")
end)

test("every Void Citadel relic is Legendary or Mythic and unique to the Citadel", function()
	for _, spawn in GameConfig.Temples.VoidCitadel.relicSpawns do
		local relic = GameConfig.Relics[spawn.definitionId]
		local rank = GameConfig.Rarities[relic.rarity].rank
		assertTrue(rank >= GameConfig.Rarities.Legendary.rank, relic.name .. " is below Legendary")
		assertEquals(#relic.templeIds, 1, relic.name .. " should be Citadel-exclusive")
		assertEquals(relic.templeIds[1], "VoidCitadel", relic.name .. " is not tied to the Citadel")
	end
end)

test("Void Warden kind is stronger than the base Guardian", function()
	local warden = GameConfig.Enemies.Kinds.VoidWarden
	local guardian = GameConfig.Enemies.Kinds.Guardian
	assertTrue(warden ~= nil, "VoidWarden kind defined")
	assertTrue(warden.aggroRange > guardian.aggroRange, "Void Warden detects from farther")
	assertTrue(warden.damage >= guardian.damage, "Void Warden hits at least as hard")
	assertTrue(warden.walkSpeed >= guardian.walkSpeed, "Void Warden is at least as fast")
	assertTrue(warden.attackWindup <= guardian.attackWindup, "Void Warden winds up no slower")
	assertEquals(GameConfig.Temples.VoidCitadel.guardians[1].kind, "VoidWarden", "Citadel uses Void Wardens")
end)

test("guardian tuning holds an aggressive chase through broken line of sight", function()
	local enemies = GameConfig.Enemies
	assertTrue(enemies.HuntSeconds > 0, "hunt window is positive")
	assertTrue(
		math.max(enemies.HuntSeconds, enemies.AggroLingerSeconds) > 2.5,
		"a broken line of sight keeps the chase alive longer than the old 2.5s"
	)
	assertTrue(enemies.HuntArriveTolerance > 0, "hunt arrival tolerance is positive")
	assertTrue(enemies.Chase.SpeedMultiplier > 1, "chase is faster than patrol")
	assertTrue(enemies.TickSeconds <= 0.1, "guardians think at least every 100ms")
end)

test("hard temples offer the Instant Revive product", function()
	local monetization = GameConfig.Monetization
	assertTrue(monetization.InstantRevivePriceRobux > 0, "revive price is set")
	assertTrue(monetization.InstantReviveWindowSeconds > 0, "revive window is positive")
	local allowed = {}
	for _, templeId in monetization.ReviveTempleIds do
		allowed[templeId] = true
		assertTrue(GameConfig.Temples[templeId] ~= nil, "revive temple " .. tostring(templeId) .. " is defined")
	end
	assertTrue(allowed.SunkenSanctum == true, "Sunken Sanctum is a hard temple")
	assertTrue(allowed.VoidCitadel == true, "Void Citadel is a hard temple")
	assertTrue(allowed.TutorialRuins ~= true, "the tutorial temple never offers a revive")
end)

-- M5 config integrity ------------------------------------------------------

test("tutorial steps are well-formed, ordered and match config actions", function()
	local steps = GameConfig.Tutorial.Steps
	assertTrue(#steps > 0, "tutorial has steps")
	local seen = {}
	for index, step in steps do
		assertTrue(type(step.id) == "string" and step.id ~= "", string.format("step %d needs an id", index))
		assertTrue(seen[step.id] == nil, "duplicate step id " .. tostring(step.id))
		seen[step.id] = true
		assertTrue(type(step.title) == "string" and step.title ~= "", "step needs a title")
		assertTrue(type(step.text) == "string" and step.text ~= "", "step needs text")
		assertTrue(type(step.complete) == "string" and step.complete ~= "", "step needs a completion action")
	end
end)

test("every tutorial completion action is a known teachable action", function()
	local known = {
		enteredTemple = true,
		collectedRelic = true,
		extracted = true,
		exhibited = true,
	}
	for _, step in GameConfig.Tutorial.Steps do
		assertTrue(
			known[step.complete] == true,
			string.format("tutorial step '%s' completes on unknown action '%s'", step.id, tostring(step.complete))
		)
	end
end)

test("settings defaults and text-scale multipliers are coherent", function()
	local settings = GameConfig.Settings
	assertTrue(settings.Defaults.textScale ~= nil, "defaults provide a text scale")
	local allowed = {}
	for _, option in settings.TextScaleOptions do
		allowed[option] = true
		assertTrue(
			settings.TextScaleMultipliers[option] ~= nil,
			string.format("text scale '%s' has no multiplier", tostring(option))
		)
	end
	assertTrue(allowed[settings.Defaults.textScale] == true, "default text scale is an allowed option")
	assertEquals(settings.TextScaleMultipliers.Normal, 1, "normal text is unscaled")
	assertTrue(settings.TextScaleMultipliers.Huge > settings.TextScaleMultipliers.Normal, "huge is larger than normal")
end)

test("every audio sound has a volume and non-negative asset id", function()
	for name, sound in GameConfig.Audio.Sounds do
		assertTrue(type(sound.assetId) == "number" and sound.assetId >= 0, name .. " needs a non-negative asset id")
		assertTrue(type(sound.volume) == "number" and sound.volume >= 0, name .. " needs a non-negative volume")
	end
	assertTrue(GameConfig.Audio.MasterVolume > 0, "master volume is positive")
end)

-- Exploit resistance: request payload validation (T-03) --------------------

test("payload validation accepts only a table with a non-empty string action", function()
	assertTrue(Validate.isValidPayload({ action = "BuyUpgrade" }), "valid payload")
	assertTrue(Validate.isValidPayload({ action = "EnterExpedition", data = { templeId = "X" } }), "with data")
	assertFalse(Validate.isValidPayload(nil), "nil rejected")
	assertFalse(Validate.isValidPayload("BuyUpgrade"), "string rejected")
	assertFalse(Validate.isValidPayload(42), "number rejected")
	assertFalse(Validate.isValidPayload({}), "missing action rejected")
	assertFalse(Validate.isValidPayload({ action = 5 }), "non-string action rejected")
	assertFalse(Validate.isValidPayload({ action = "" }), "empty action rejected")
end)

test("checkPayload returns a reason for every rejection", function()
	local payload, reason = Validate.checkPayload({ action = "BuyUpgrade" })
	assertTrue(payload ~= nil, "valid accepted")
	assertEquals(reason, nil, "no reason when valid")
	local nilPayload, nilReason = Validate.checkPayload(nil)
	assertEquals(nilPayload, nil, "nil rejected")
	assertTrue(type(nilReason) == "string", "reason provided")
	local emptyPayload, emptyReason = Validate.checkPayload({ action = "" })
	assertEquals(emptyPayload, nil, "empty action rejected")
	assertTrue(type(emptyReason) == "string", "reason provided for empty action")
end)

-- Exploit resistance: rate limiting (T-02) ----------------------------------

test("rate limiter allows the burst then rejects until tokens refill", function()
	local limiter = RateLimiter.new(1, 3)
	assertTrue(limiter:Allow("p1"), "first allowed")
	assertTrue(limiter:Allow("p1"), "second allowed")
	assertTrue(limiter:Allow("p1"), "third allowed (burst)")
	assertFalse(limiter:Allow("p1"), "fourth rejected (bucket empty)")
end)

test("rate limiter isolates keys and clears independently", function()
	local limiter = RateLimiter.new(1, 1)
	assertTrue(limiter:Allow("a"), "a first allowed")
	assertFalse(limiter:Allow("a"), "a exhausted")
	assertTrue(limiter:Allow("b"), "b unaffected by a")
	limiter:Clear("a")
	assertTrue(limiter:Allow("a"), "a allowed after clear")
end)

test("rate limiter rejects costs larger than the burst", function()
	local limiter = RateLimiter.new(1, 2)
	assertFalse(limiter:Allow("p", 5), "cost above burst is never allowed")
end)

test("rate limiter constructor rejects invalid limits", function()
	assertTrue(pcall(function()
		RateLimiter.new(0, 1)
	end) == false, "zero perSecond rejected")
	assertTrue(pcall(function()
		RateLimiter.new(1, 0)
	end) == false, "zero burst rejected")
end)

-- Persistence safety: save conflict guard (T-11) ---------------------------

test("conflict guard allows writes when no record exists", function()
	assertTrue(Persist.canCommit(nil, "sess", 100), "nil record commits")
	assertTrue(Persist.canCommit("notatable", "sess", 100), "non-table record commits")
end)

test("conflict guard allows our own session and blocks newer foreign writes", function()
	assertTrue(Persist.canCommit({ sessionId = "sess", updatedAt = 999 }, "sess", 100), "same session commits")
	assertFalse(
		Persist.canCommit({ sessionId = "other", updatedAt = 200 }, "sess", 100),
		"newer foreign write blocks commit"
	)
	assertTrue(
		Persist.canCommit({ sessionId = "other", updatedAt = 50 }, "sess", 100),
		"older foreign write does not block"
	)
	assertTrue(
		Persist.canCommit({ sessionId = "other", updatedAt = 100 }, "sess", 100),
		"equal-timestamp foreign write does not block"
	)
end)

test("conflict guard treats a missing timestamp as oldest", function()
	assertTrue(Persist.canCommit({ sessionId = "other" }, "sess", 100), "missing updatedAt is not newer")
	assertTrue(
		Persist.canCommit({ sessionId = "other", updatedAt = "bad" }, "sess", 100),
		"invalid updatedAt is not newer"
	)
end)

-- Persistence failure modes: load outcome (T-11/T-12) ------------------------

test("load outcome: missing store degrades to ephemeral", function()
	assertEquals(Persist.loadOutcome(false, Persist.LoadStatus.NOT_FOUND, nil, false), "EPHEMERAL", "live server")
	assertEquals(Persist.loadOutcome(false, Persist.LoadStatus.NOT_FOUND, nil, true), "EPHEMERAL", "studio")
end)

test("load outcome: not-found creates a new profile", function()
	assertEquals(Persist.loadOutcome(true, Persist.LoadStatus.NOT_FOUND, nil, false), "NEW", "live server")
	assertEquals(Persist.loadOutcome(true, Persist.LoadStatus.NOT_FOUND, nil, true), "NEW", "studio")
end)

test("load outcome: transient unavailable kicks live, ephemeral in studio", function()
	assertEquals(Persist.loadOutcome(true, Persist.LoadStatus.UNAVAILABLE, nil, false), "KICK", "live server")
	assertEquals(Persist.loadOutcome(true, Persist.LoadStatus.UNAVAILABLE, nil, true), "EPHEMERAL", "studio")
end)

test("load outcome: corrupt or future record never gets overwritten", function()
	assertEquals(Persist.loadOutcome(true, Persist.LoadStatus.OK, nil, false), "KICK", "live server refuses")
	assertEquals(Persist.loadOutcome(true, Persist.LoadStatus.OK, nil, true), "EPHEMERAL", "studio is read-only")
end)

test("load outcome: a migrated record goes live", function()
	local migrated = Schema.createDefault(100, "s", 250)
	assertEquals(Persist.loadOutcome(true, Persist.LoadStatus.OK, migrated, false), "LIVE", "live server")
end)

test("load outcome: unknown status fails closed", function()
	assertEquals(Persist.loadOutcome(true, "WEIRD", nil, false), "KICK", "live server")
	assertEquals(Persist.loadOutcome(true, "WEIRD", nil, true), "EPHEMERAL", "studio")
end)

test("only live and new outcomes are writable", function()
	assertTrue(Persist.isWritable("LIVE"), "live writable")
	assertTrue(Persist.isWritable("NEW"), "new writable")
	assertFalse(Persist.isWritable("EPHEMERAL"), "ephemeral not writable")
	assertFalse(Persist.isWritable("KICK"), "kicked not writable")
end)

test("retry backoff stops after the last attempt and reuses the final value", function()
	local backoff = GameConfig.Save.RetryBackoffSeconds
	assertEquals(Persist.retryBackoff(1, 3, backoff), 0.6, "first attempt")
	assertEquals(Persist.retryBackoff(2, 3, backoff), 1.5, "second attempt")
	assertEquals(Persist.retryBackoff(3, 3, backoff), nil, "last attempt has no backoff")
	assertEquals(Persist.retryBackoff(1, 5, backoff), 0.6, "first of five")
	assertEquals(Persist.retryBackoff(4, 5, backoff), 3, "reuses final value past table end")
end)

-- Network contract: action registry (drift + data-shape) --------------------

-- The canonical action set, kept in sync with docs/API_CONTRACTS.md "Registered
-- actions". If a handler is added/removed without updating the registry or the
-- docs, this test fails and points at the drift.
local DOCUMENTED_ACTIONS = {
	"AbandonExpedition",
	"BuyUpgrade",
	"ClaimOfflineIncome",
	"DeclineInstantRevive",
	"EnterExpedition",
	"PlaceRelic",
	"PurchaseInstantRevive",
	"PurchaseOfflineDouble",
	"RemoveRelic",
	"RequestState",
	"UnlockTemple",
	"UpdateSettings",
}

test("contract registry matches the documented action set", function()
	local registered = Contracts.actionNames()
	assertEquals(#registered, #DOCUMENTED_ACTIONS, "action count")
	local documented = {}
	for _, name in DOCUMENTED_ACTIONS do
		documented[name] = true
	end
	for _, name in registered do
		assertTrue(documented[name] == true, string.format("undocumented action %s", name))
	end
	for _, name in DOCUMENTED_ACTIONS do
		assertTrue(Contracts.isKnownAction(name), string.format("documented action %s is not registered", name))
	end
end)

test("contract check rejects unknown actions", function()
	local ok = Contracts.check("NotAnAction", {})
	assertFalse(ok, "unknown action rejected")
end)

test("contract check tolerates nil and wrong-typed data for fieldless actions", function()
	for _, action in { "AbandonExpedition", "UpdateSettings", "ClaimOfflineIncome", "PurchaseOfflineDouble" } do
		assertTrue(Contracts.check(action, nil), action .. " accepts nil data")
		assertTrue(Contracts.check(action, "junk"), action .. " ignores non-table data")
		assertTrue(Contracts.check(action, { extra = 1 }), action .. " accepts extra fields")
	end
end)

test("contract check enforces required string fields", function()
	assertFalse(Contracts.check("EnterExpedition", nil), "nil data rejected")
	assertFalse(Contracts.check("EnterExpedition", {}), "missing field rejected")
	assertFalse(Contracts.check("EnterExpedition", { templeId = 5 }), "non-string field rejected")
	assertTrue(Contracts.check("EnterExpedition", { templeId = "TutorialRuins" }), "valid accepted")
end)

test("contract check enforces every required field of a multi-field action", function()
	assertFalse(Contracts.check("PlaceRelic", { pedestalId = "1" }), "missing uid rejected")
	assertFalse(Contracts.check("PlaceRelic", { uid = "r1" }), "missing pedestalId rejected")
	assertTrue(Contracts.check("PlaceRelic", { pedestalId = "1", uid = "r1" }), "both fields accepted")
end)

test("contract profile requirement defaults to true and honors exemptions", function()
	assertTrue(Contracts.requiresProfile("BuyUpgrade"), "normal action requires profile")
	assertFalse(Contracts.requiresProfile("RequestState"), "RequestState exempt")
	assertTrue(Contracts.requiresProfile("SomethingUnknown"), "unknown action defaults to requiring profile")
end)

-- Museum building (wings, pedestal tiers, enhancements) --------------------

local MuseumBuilder = require("../src/shared/Domain/MuseumBuilder")

test("placements assigns stable 1-based global ids in wing order", function()
	local wings = GameConfig.MuseumBuilding.Wings
	local placements = MuseumBuilder.placements(wings)
	assertEquals(#placements, GameConfig.Museum.MaxPedestals, "total pedestals matches cap")
	assertEquals(placements[1].id, "1", "first id")
	assertEquals(placements[1].wingId, "Foyer", "first wing")
	assertEquals(placements[#placements].id, tostring(#placements), "last id")
	local seen = {}
	for _, placement in placements do
		assertTrue(seen[placement.id] == nil, "id " .. placement.id .. " unique")
		seen[placement.id] = true
	end
end)

test("placements applies wing offset to plot-local position", function()
	local foyer = GameConfig.MuseumBuilding.Wings[1]
	local wing = GameConfig.MuseumBuilding.Wings[2]
	local wings = { foyer, wing }
	local placements = MuseumBuilder.placements(wings)
	local hallFirst = placements[#foyer.pedestalSlots + 1]
	local slot = wing.pedestalSlots[1]
	assertEquals(hallFirst.wingId, "ExhibitionHall", "first hall pedestal follows the foyer")
	assertEquals(hallFirst.x, wing.offset.x + slot.x, "x offset applied")
	assertEquals(hallFirst.z, wing.offset.z + slot.z, "z offset applied")
end)

test("totalPedestals sums every wing", function()
	local total = 0
	for _, wing in GameConfig.MuseumBuilding.Wings do
		total += #wing.pedestalSlots
	end
	assertEquals(MuseumBuilder.totalPedestals(GameConfig.MuseumBuilding.Wings), total, "sums every wing")
	assertTrue(total > 8, "the museum offers more than the original 8 slots")
end)

test("museum upgrades unlock exactly every pedestal slot", function()
	local movement = GameConfig.Movement
	local floor = GameConfig.Upgrades.MuseumFloor
	local extra = GameConfig.Upgrades.ExtraPedestal
	local total = MuseumBuilder.totalPedestals(GameConfig.MuseumBuilding.Wings)
	local reachable = Economy.pedestalCount(
		movement.BasePedestals,
		floor.maxLevel,
		floor.perLevel,
		extra.maxLevel,
		extra.perLevel,
		GameConfig.Museum.MaxPedestals
	)
	assertEquals(reachable, total, "fully upgraded museum unlocks every slot")
	assertTrue(GameConfig.Museum.MaxPedestals >= total, "cap covers every slot")
end)

test("unlockedWings grows with MuseumFloor level", function()
	local wings = GameConfig.MuseumBuilding.Wings
	assertEquals(#MuseumBuilder.unlockedWings(wings, 0), 1, "foyer only at level 0")
	assertEquals(#MuseumBuilder.unlockedWings(wings, 1), 2, "hall at level 1")
	assertEquals(#MuseumBuilder.unlockedWings(wings, 2), 3, "vault at level 2")
	assertEquals(#MuseumBuilder.unlockedWings(wings, 99), 3, "no extra wings beyond config")
end)

test("placementById resolves known ids and returns nil otherwise", function()
	local placements = MuseumBuilder.placements(GameConfig.MuseumBuilding.Wings)
	assertEquals(MuseumBuilder.placementById(placements, "1").wingId, "Foyer", "id 1")
	assertEquals(MuseumBuilder.placementById(placements, "999"), nil, "unknown id")
end)

test("tierForRarity maps known rarities and falls back to Common", function()
	local tiers = GameConfig.MuseumBuilding.PedestalTiers
	assertEquals(MuseumBuilder.tierForRarity(tiers, "Legendary").tier, "Gilded", "legendary tier")
	assertEquals(MuseumBuilder.tierForRarity(tiers, "Mythic").tier, "Mythic", "mythic tier")
	assertEquals(MuseumBuilder.tierForRarity(tiers, nil).tier, tiers.Common.tier, "nil falls back")
	assertEquals(MuseumBuilder.tierForRarity(tiers, "Bogus").tier, tiers.Common.tier, "unknown falls back")
end)

test("enhancementActive is false at level 0 and true above", function()
	assertFalse(MuseumBuilder.enhancementActive(0), "level 0 inactive")
	assertTrue(MuseumBuilder.enhancementActive(1), "level 1 active")
end)

test("featureLevels clamps to each upgrade maxLevel and reads config mapping", function()
	local enhancements = GameConfig.MuseumBuilding.Enhancements
	local levels = MuseumBuilder.featureLevels(enhancements, GameConfig.Upgrades, {
		MarblePillars = GameConfig.Upgrades.MarblePillars.maxLevel,
		Lighting = 999,
	})
	local pillarsMax = GameConfig.Upgrades.MarblePillars.maxLevel
	assertEquals(levels.pillars, pillarsMax, "pillars at max")
	assertEquals(levels.lighting, GameConfig.Upgrades.Lighting.maxLevel, "lighting clamped")
	assertEquals(levels.glassCases, 0, "unowned defaults to 0")
end)

test("every enhancement maps to a real visual upgrade", function()
	for feature, upgradeId in GameConfig.MuseumBuilding.Enhancements do
		local upgrade = GameConfig.Upgrades[upgradeId]
		assertTrue(upgrade ~= nil, feature .. " maps to a real upgrade")
		assertEquals(upgrade.effect, "visual", upgradeId .. " is a visual upgrade")
	end
end)

test("schema v3 profile migrates to v4 with enhancement keys seeded", function()
	local profile = Schema.createDefault(0, "s", 0)
	profile.schemaVersion = 3
	profile.upgrades = { SprintBoots = 1 }
	local migrated, changed, err = Schema.migrate(profile, 0)
	assertEquals(err, nil, "no migration error")
	assertTrue(changed, "migration reported")
	assertEquals(migrated.schemaVersion, 4, "bumped to current")
	assertEquals(migrated.upgrades.MarblePillars, 0, "enhancement seeded")
	assertEquals(migrated.upgrades.SprintBoots, 1, "existing upgrade preserved")
end)

test("normalize preserves enhancement upgrade levels", function()
	local profile = Schema.createDefault(0, "s", 0)
	profile.upgrades.Chandeliers = 2
	local normalized = Schema.normalize(profile, 0)
	assertEquals(normalized.upgrades.Chandeliers, 2, "enhancement level kept")
end)

-- World layout --------------------------------------------------------------
test("world layout constants are consistent", function()
	assertTrue(GameConfig.World ~= nil, "World config present")
	assertTrue(GameConfig.World.RingRadius > 0, "ring radius positive")
	assertTrue(GameConfig.World.MaxPlots > 0, "max plots positive")
	assertTrue(GameConfig.World.GroundTop == 0, "ground top at world zero")
	assertTrue(GameConfig.World.Hub.PlazaRadius > 0, "hub plaza radius positive")
end)

test("every temple sits beyond the hub edge for its avenue", function()
	local hubRadius = GameConfig.World.Hub.PlazaRadius
	for _, temple in GameConfig.Temples do
		assertTrue(temple.origin.z > hubRadius, "temple sits beyond the hub edge")
	end
end)

test("plot ring radius is large enough for its plot count", function()
	local ring = GameConfig.World.RingRadius
	local count = GameConfig.World.MaxPlots
	local chord = 2 * ring * math.sin(math.pi / count)
	assertTrue(chord >= 100, "adjacent plots have room without overlapping")
end)

test("museum wings fit inside the plot footprint and stack without overlap", function()
	local foyer = GameConfig.MuseumBuilding.Wings[1]
	local footprint = foyer.size.x
	for _, wing in GameConfig.MuseumBuilding.Wings do
		assertTrue(wing.size.x <= footprint, wing.id .. " is no wider than the foyer footprint")
		assertTrue(wing.size.z <= footprint, wing.id .. " is no deeper than the foyer footprint")
	end
	local ordered = {}
	for _, wing in GameConfig.MuseumBuilding.Wings do
		table.insert(ordered, wing)
	end
	table.sort(ordered, function(a, b)
		return a.offset.z < b.offset.z
	end)
	local previousBack = nil
	for _, wing in ordered do
		local front = wing.offset.z - wing.size.z / 2
		local back = wing.offset.z + wing.size.z / 2
		if previousBack ~= nil then
			assertTrue(front >= previousBack, wing.id .. " clears the previous wing along Z")
		end
		previousBack = back
	end
end)

test("museum wings use human-scale interior heights", function()
	for _, wing in GameConfig.MuseumBuilding.Wings do
		assertTrue(wing.height >= 14 and wing.height <= 16, wing.id .. " ceiling is 14-16 studs tall")
	end
end)

test("temple corridor halls do not overlap along +Z", function()
	local ordered = {}
	for _, temple in GameConfig.Temples do
		table.insert(ordered, temple)
	end
	table.sort(ordered, function(a, b)
		return a.origin.z < b.origin.z
	end)
	for index = 2, #ordered do
		local previous = ordered[index - 1]
		local previousBack = previous.origin.z + previous.hall.length
		assertTrue(ordered[index].origin.z > previousBack, "temple fronts clear the previous temple's back")
	end
end)

-- Map footprint and scenery -------------------------------------------------

-- The layout module reduces the configuration to plain numbers, so these
-- tests read the very same numbers the world builder does.
local MAP = SceneryLayout.inputs(GameConfig)
local MAP_TREES = SceneryLayout.trees(MAP.grove, MAP.content, MAP.ground, MAP.regions, MAP.seed)
local MAP_ESCARPMENT = SceneryLayout.escarpment(MAP.ground, MAP.escarpment, MAP.seed + 1)

test("the ground footprint is the approved rounded rectangle", function()
	assertEquals(MAP.ground.minX, -650, "west edge")
	assertEquals(MAP.ground.maxX, 650, "east edge")
	assertEquals(MAP.ground.minZ, -640, "south edge")
	assertEquals(MAP.ground.maxZ, 1540, "north edge")
	assertEquals(MAP.ground.cornerRadius, 300, "corner radius")
	-- The corners are cut back, the straight sides are not.
	assertTrue(SceneryLayout.signedDistance(MAP.ground, 650, 1540) > 0, "the corner is cut away")
	assertTrue(SceneryLayout.signedDistance(MAP.ground, 500, 1300) < 0, "the corner arc is on the ground")
	assertTrue(SceneryLayout.signedDistance(MAP.ground, 649, 390) < 0, "the straight side is on the ground")
end)

test("the ground footprint is the smallest one that still holds the content", function()
	-- The ground has to reach far enough beyond the playable content for the
	-- forest belt and the rocky rim, and no further.
	local needed = MAP.grove.bands[1].outer + SceneryLayout.TREE_CANOPY_HALF_MAX + MAP.escarpment.depth
	local ring = GameConfig.World.RingRadius
	local step = 360 / GameConfig.World.MaxPlots
	local minX, maxX, minZ, maxZ = math.huge, -math.huge, math.huge, -math.huge
	for index = 0, GameConfig.World.MaxPlots - 1 do
		local angle = math.rad(GameConfig.World.StartAngleDegrees + index * step)
		local centreX = math.cos(angle) * ring
		local centreZ = math.sin(angle) * ring
		for _, along in { -128, 132 } do
			for _, across in { -60, 60 } do
				local x = centreX + (math.cos(angle) * along) + (math.sin(angle) * across)
				local z = centreZ + (math.sin(angle) * along) - (math.cos(angle) * across)
				minX = math.min(minX, x)
				maxX = math.max(maxX, x)
				minZ = math.min(minZ, z)
				maxZ = math.max(maxZ, z)
			end
		end
	end
	-- The back of the last temple on the processional way is the northern
	-- extreme of the playable content.
	for _, temple in GameConfig.Temples do
		maxZ = math.max(maxZ, temple.origin.z + temple.hall.length)
	end

	for _, margin in { MAP.ground.maxX - maxX, minX - MAP.ground.minX, MAP.ground.maxZ - maxZ, minZ - MAP.ground.minZ } do
		assertTrue(margin >= needed - 40, "the ground still holds the belt and the rim")
		assertTrue(margin <= needed + 40, "the ground does not waste empty margin")
	end
end)

test("every structure sits inside the ground footprint", function()
	for _, region in MAP.regions do
		if region.kind == "box" then
			for _, x in { region.minX, region.maxX } do
				for _, z in { region.minZ, region.maxZ } do
					assertTrue(SceneryLayout.contains(MAP.ground, x, z), region.name .. " sits on the ground")
				end
			end
		else
			for _, angle in { 0, math.pi / 2, math.pi, 3 * math.pi / 2 } do
				local x = region.centerX + math.cos(angle) * region.radius
				local z = region.centerZ + math.sin(angle) * region.radius
				assertTrue(SceneryLayout.contains(MAP.ground, x, z), region.name .. " sits on the ground")
			end
		end
	end
	-- The plot aprons reach past the ring radius, so they are checked too.
	local ring = GameConfig.World.RingRadius
	local step = 360 / GameConfig.World.MaxPlots
	for index = 0, GameConfig.World.MaxPlots - 1 do
		local angle = math.rad(GameConfig.World.StartAngleDegrees + index * step)
		local centreX = math.cos(angle) * ring
		local centreZ = math.sin(angle) * ring
		for _, along in { -128, 132 } do
			for _, across in { -60, 60 } do
				local x = centreX + (math.cos(angle) * along) + (math.sin(angle) * across)
				local z = centreZ + (math.sin(angle) * along) - (math.cos(angle) * across)
				assertTrue(SceneryLayout.contains(MAP.ground, x, z), "a plot apron sits on the ground")
			end
		end
	end
end)

test("the grove is deterministic", function()
	local again = SceneryLayout.trees(MAP.grove, MAP.content, MAP.ground, MAP.regions, MAP.seed)
	assertEquals(#again, #MAP_TREES, "same number of trees")
	for index = 1, #MAP_TREES do
		assertEquals(again[index].x, MAP_TREES[index].x, "tree " .. index .. " x")
		assertEquals(again[index].z, MAP_TREES[index].z, "tree " .. index .. " z")
		assertEquals(again[index].yaw, MAP_TREES[index].yaw, "tree " .. index .. " yaw")
	end
end)

test("the grove keeps the ground clearance and the protected areas clear", function()
	assertTrue(#MAP_TREES > 0, "the grove has trees")
	for _, tree in MAP_TREES do
		assertTrue(
			SceneryLayout.signedDistance(MAP.ground, tree.x, tree.z) <= -MAP.grove.groundClearance,
			"a tree keeps the ground clearance"
		)
		for _, region in MAP.regions do
			if region.hard then
				-- The canopy edge keeps the region's own margin.
				assertTrue(
					SceneryLayout.distanceToRegion(region, tree.x, tree.z) - SceneryLayout.canopyReach(tree)
						>= region.margin,
					"a tree clears " .. region.name
				)
			elseif not region.beltOnly then
				-- A path may be crowded, but the canopy may only lean over its
				-- edge by the agreed overhang.
				local overhang = SceneryLayout.canopyReach(tree)
					- SceneryLayout.distanceToRegion(region, tree.x, tree.z)
				assertTrue(overhang <= SceneryLayout.PATH_OVERHANG + 0.001, "a tree only borders " .. region.name)
			end
		end
		for _, corner in SceneryLayout.canopyCorners(tree) do
			assertTrue(SceneryLayout.contains(MAP.ground, corner.x, corner.z), "a canopy stays on the ground")
		end
	end
end)

test("the forest belt sits 30 to 60 studs beyond the playable content", function()
	local belt = MAP.grove.bands[1]
	local beltTrees = 0
	for _, tree in MAP_TREES do
		local _, distance, dirX, dirZ = SceneryLayout.nearestContent(MAP.regions, tree.x, tree.z)
		if distance <= belt.outer + SceneryLayout.canopyReach(tree) then
			beltTrees += 1
			local gap = distance - SceneryLayout.canopySupport(tree, dirX, dirZ)
			assertTrue(gap >= belt.inner - 0.001, "the canopy does not come closer than the belt")
			assertTrue(gap <= belt.outer + 0.001, "the canopy does not reach past the belt")
		end
	end
	assertTrue(beltTrees > 200, "the belt is dense enough to read as a forest wall")
end)

test("the grove keeps its minimum spacing", function()
	for first = 1, #MAP_TREES do
		for second = first + 1, #MAP_TREES do
			local dx = MAP_TREES[first].x - MAP_TREES[second].x
			local dz = MAP_TREES[first].z - MAP_TREES[second].z
			local distance = math.sqrt((dx * dx) + (dz * dz))
			assertTrue(distance >= MAP.grove.minSpacing, "two trees stay apart")
		end
	end
end)

test("the decorative part count stays inside the budget", function()
	local parts = SceneryLayout.partCount(MAP_TREES, MAP_ESCARPMENT)
	assertTrue(parts <= GameConfig.World.Scenery.PartBudget, "the scenery fits the part budget")
	assertTrue(parts >= 600, "the horizon is dense enough to read as a forest")
end)

test("the escarpment ring closes without a seam", function()
	local polygons = {}
	local cliffs = 0
	for _, segment in MAP_ESCARPMENT do
		if segment.layer == "cliff" then
			cliffs += 1
			table.insert(polygons, SceneryLayout.escarpmentPolygon(segment))
		end
	end
	assertTrue(cliffs > 50, "the rim has enough blocks to follow the outline")
	for index = 1, #polygons do
		local a = polygons[index]
		local b = polygons[(index % #polygons) + 1]
		local overlap = SceneryLayout.polygonOverlapArea(a, b)
		assertTrue(overlap >= SceneryLayout.ESCARPMENT_MIN_OVERLAP_AREA, "neighbouring segments overlap")
	end
	-- The mid-line of the band has to be covered by the rock everywhere, even
	-- where the blocks are shallower than the deepest one.
	local minDepth = math.huge
	for _, segment in MAP_ESCARPMENT do
		if segment.layer == "cliff" then
			minDepth = math.min(minDepth, segment.depth)
		end
	end
	local midLine = SceneryLayout.escarpmentMidline(MAP.ground, minDepth, 4)
	assertTrue(#midLine > 100, "the rim is sampled densely")
	for _, point in midLine do
		local covered = false
		for _, polygon in polygons do
			if SceneryLayout.polygonContainsPoint(polygon, point.x, point.z) then
				covered = true
				break
			end
		end
		assertTrue(covered, "the rocky rim has no gap")
	end
end)

test("the escarpment is layered, varied and set back behind the grove", function()
	local crests = 0
	local minDepth, maxDepth = math.huge, 0
	local minHeight, maxHeight = math.huge, 0
	for _, segment in MAP_ESCARPMENT do
		if segment.layer == "crest" then
			crests += 1
			assertTrue(segment.baseY > 0, "a crest block sits on top of the wall")
			assertTrue(segment.depth < MAP.escarpment.depth, "a crest block is shallower than the wall")
		else
			minDepth = math.min(minDepth, segment.depth)
			maxDepth = math.max(maxDepth, segment.depth)
			minHeight = math.min(minHeight, segment.height)
			maxHeight = math.max(maxHeight, segment.height)
		end
	end
	assertTrue(crests > 20, "the wall has a second course of rock")
	assertTrue(maxDepth - minDepth > 10, "the wall has varied depths")
	assertTrue(maxHeight - minHeight > 10, "the wall has varied heights")

	-- The rock stands shortly behind the grove: the canopies stop short of it.
	local closest = math.huge
	for _, tree in MAP_TREES do
		local toEdge = -SceneryLayout.signedDistance(MAP.ground, tree.x, tree.z)
		closest = math.min(closest, toEdge - SceneryLayout.canopyReach(tree) - MAP.escarpment.depth)
	end
	assertTrue(closest >= 0, "the grove does not grow into the rock")
	assertTrue(closest <= 60, "the rock stands close behind the grove")
end)

test("the escarpment hugs the ground edge", function()
	for _, segment in MAP_ESCARPMENT do
		if segment.layer == "cliff" then
			local outerX = segment.centerX - (segment.wX * (segment.depth / 2))
			local outerZ = segment.centerZ - (segment.wZ * (segment.depth / 2))
			local outside = SceneryLayout.signedDistance(MAP.ground, outerX, outerZ)
			assertTrue(outside <= SceneryLayout.ESCARPMENT_OUTWARD_OVERHANG + 0.5, "the band reaches the ground edge")
			-- A short straight segment across a rounded corner sits a fraction of a
			-- stud inside the outline; anything more would leave a visible gap.
			assertTrue(outside >= -1, "the band does not float inside the footprint")
		end
	end
end)

test("the rock never reaches into the playable content", function()
	for _, segment in MAP_ESCARPMENT do
		for _, corner in SceneryLayout.escarpmentPolygon(segment) do
			local _, distance = SceneryLayout.nearestContent(MAP.regions, corner.x, corner.z)
			assertTrue(distance >= 40, "the rock keeps away from the playable content")
		end
	end
end)

test("the world has no kill plane or fall guard of its own", function()
	assertTrue(GameConfig.World.KillPlane == nil, "no kill plane in the world config")
	assertTrue(GameConfig.World.FallenPartsDestroyHeight == nil, "no fall height in the world config")
	assertTrue(GameConfig.World.Gravity == nil, "gravity is left at the engine default")
end)

-- Run rules (replayable expeditions) ------------------------------------

test("every relic definition spawns in at least one temple", function()
	local spawned = {}
	for _, temple in GameConfig.Temples do
		for _, spawn in temple.relicSpawns do
			spawned[spawn.definitionId] = true
		end
	end
	for definitionId in GameConfig.Relics do
		assertTrue(spawned[definitionId] == true, definitionId .. " never spawns in any temple")
	end
end)

test("requiredRelics is haulable with the fully upgraded backpack", function()
	local maxCapacity = Encumbrance.capacity(GameConfig.Movement, GameConfig.Upgrades.Backpack.maxLevel)
	for templeId, temple in GameConfig.Temples do
		local weight = RunRules.lightestHaulWeight(temple, GameConfig.Relics)
		assertTrue(
			weight <= maxCapacity,
			string.format("%s requires %d weight but capacity is %d", templeId, weight, maxCapacity)
		)
	end
end)

test("extractionCredit requires a positive haul meeting the temple requirement", function()
	assertTrue(RunRules.extractionCredit(3, 3), "meeting the requirement counts")
	assertTrue(RunRules.extractionCredit(5, 3), "exceeding the requirement counts")
	assertTrue(RunRules.extractionCredit(1, 0), "any relic counts when nothing is required")
	assertFalse(RunRules.extractionCredit(2, 3), "short haul does not count")
	assertFalse(RunRules.extractionCredit(0, 0), "empty-handed never counts")
	assertFalse(RunRules.extractionCredit(0, 1), "zero transfer never counts")
end)

test("spawnPlan lists every configured spawn deterministically in order", function()
	for templeId, temple in GameConfig.Temples do
		local plan = RunRules.spawnPlan(temple)
		assertEquals(#plan, #temple.relicSpawns, templeId .. " plan length")
		for index, definitionId in plan do
			assertEquals(definitionId, temple.relicSpawns[index].definitionId, templeId .. " plan order")
		end
		local again = RunRules.spawnPlan(temple)
		for index, definitionId in plan do
			assertEquals(again[index], definitionId, templeId .. " plan is deterministic")
		end
	end
end)

test("relic income totals stay under the museum rate cap", function()
	local total = 0
	for _, relic in GameConfig.Relics do
		total += relic.incomePerMinute
	end
	assertTrue(
		total <= GameConfig.Museum.MaxIncomeRatePerMinute,
		string.format("relic income %d exceeds cap %d", total, GameConfig.Museum.MaxIncomeRatePerMinute)
	)
end)

-- Summary ------------------------------------------------------------------
print(string.format("\n%d passed, %d failed", passed, failed))
if failed > 0 then
	error(string.format("%d test(s) failed", failed))
end
