-- Standalone pure-logic test suite. Run with the Luau CLI:
--   luau tests/run_tests.luau
-- These tests cover only modules that contain no Roblox APIs.

local Economy = require("../src/shared/Domain/Economy")
local Encumbrance = require("../src/shared/Domain/Encumbrance")
local Inventory = require("../src/shared/Domain/Inventory")
local Progression = require("../src/shared/Domain/Progression")
local Schema = require("../src/shared/Domain/Schema")
local GameConfig = require("../src/shared/Config/GameConfig")
local Util = require("../src/shared/Utilities/Util")

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

test("incomeRatePerMinute applies floor bonus and cap", function()
	assertEquals(Economy.incomeRatePerMinute(100, 1, 0.05, 5000), 105, "5% bonus")
	assertEquals(Economy.incomeRatePerMinute(100000, 0, 0.05, 5000), 5000, "cap")
end)

test("pendingIncome respects offline cap and max", function()
	local rate = 60
	assertEquals(Economy.pendingIncome(rate, 0, 60, 28800, 50000), 60, "one minute")
	assertEquals(Economy.pendingIncome(rate, 0, 28800 * 2, 28800, 50000), 28800, "capped at offline window")
	assertEquals(Economy.pendingIncome(rate, 0, 28800, 28800, 10), 10, "capped at max pending")
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

-- Summary ------------------------------------------------------------------

print(string.format("\n%d passed, %d failed", passed, failed))
if failed > 0 then
	error(string.format("%d test(s) failed", failed))
end
