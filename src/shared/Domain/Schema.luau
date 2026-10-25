--!strict
-- Versioned profile schema and migrations. Pure functions for testability.

local Schema = {}

-- Upper bound for stored training experience. The design cap is the attribute
-- maximum level; this only keeps a damaged profile from storing nonsense.
local MAX_TRAINING_XP = 1000000

-- Safety bound for the derived prestige reward. The design reaches its bonus cap
-- at level 10; this only prevents a damaged profile from storing nonsense.
local MAX_PRESTIGE_LEVEL = 1000

Schema.CURRENT_VERSION = 7

export type Profile = {
	schemaVersion: number,
	sessionId: string,
	updatedAt: number,
	gold: number,
	tutorialComplete: boolean,
	stats: { [string]: number },
	relics: { [string]: { id: string, acquiredAt: number } },
	museum: { [string]: string },
	upgrades: { [string]: number },
	-- Passive training experience per attribute. Levels are derived from it.
	training: { [string]: number },
	-- Relic companions owned by the player, keyed by definition id.
	companions: { [string]: boolean },
	-- The single equipped companion id, or nil when none is equipped.
	equippedCompanion: string?,
	unlockedTemples: { [string]: boolean },
	lastIncomeClaimAt: number,
	-- Offline income held until the player resolves the Welcome Back modal.
	pendingOfflineGold: number,
	-- Cached entitlement; refreshed from MarketplaceService on join.
	vip: boolean,
	tutorialStep: number,
	settings: { [string]: any },
	-- Museum Prestige (v7). The reward is derived from the level, never stored.
	prestigeLevel: number,
	lastPrestigeAt: number,
}

local function safeNumber(value: any, fallback: number): number
	if type(value) ~= "number" or value ~= value or value == math.huge or value == -math.huge then
		return fallback
	end
	return value
end

local function safeBoolean(value: any, fallback: boolean): boolean
	if type(value) ~= "boolean" then
		return fallback
	end
	return value
end

local function safeTable(value: any): { [any]: any }
	if type(value) ~= "table" then
		return {}
	end
	return value
end

function Schema.createDefault(now: number, sessionId: string, startingGold: number): Profile
	return {
		schemaVersion = Schema.CURRENT_VERSION,
		sessionId = sessionId,
		updatedAt = now,
		gold = startingGold,
		tutorialComplete = false,
		stats = { extractions = 0, deaths = 0, relicsCollected = 0, incomeClaimed = 0 },
		relics = {},
		museum = {},
		training = { strength = 0, stamina = 0, carrying = 0 },
		companions = {},
		equippedCompanion = nil,
		upgrades = {
			SprintBoots = 0,
			Backpack = 0,
			Armor = 0,
			MuseumFloor = 0,
			ExtraPedestal = 0,
			MarblePillars = 0,
			Lighting = 0,
			GlassCases = 0,
			VelvetRopes = 0,
			Chandeliers = 0,
		},
		unlockedTemples = { TutorialRuins = true },
		lastIncomeClaimAt = now,
		pendingOfflineGold = 0,
		vip = false,
		tutorialStep = 0,
		prestigeLevel = 0,
		lastPrestigeAt = 0,
		settings = {
			soundEnabled = true,
			visualEffects = true,
			reducedMotion = false,
			colorblindMode = false,
			textScale = "Normal",
		},
	}
end

-- Forward-only migrations. Each entry upgrades a profile from version N to N+1.
local migrations: { [number]: (profile: any, now: number) -> any } = {}

migrations[1] = function(profile, _now)
	profile.pendingOfflineGold = 0
	profile.vip = false
	return profile
end

migrations[2] = function(profile, _now)
	-- v3 adds accessibility settings and tutorial progress. Preserve any settings
	-- the player already has; only fill the new keys.
	local settings: any = profile.settings
	if type(settings) ~= "table" then
		settings = {}
		profile.settings = settings
	end
	if settings.reducedMotion == nil then
		settings.reducedMotion = false
	end
	if settings.colorblindMode == nil then
		settings.colorblindMode = false
	end
	if settings.textScale == nil then
		settings.textScale = "Normal"
	end
	if profile.tutorialStep == nil then
		profile.tutorialStep = 0
	end
	return profile
end

migrations[3] = function(profile, _now)
	-- v4 adds the museum building enhancements. Existing profiles keep their
	-- current upgrades; only the new visual-enhancement keys are seeded to 0.
	local upgrades: any = profile.upgrades
	if type(upgrades) ~= "table" then
		upgrades = {}
		profile.upgrades = upgrades
	end
	for _, id in { "MarblePillars", "Lighting", "GlassCases", "VelvetRopes", "Chandeliers" } do
		if upgrades[id] == nil then
			upgrades[id] = 0
		end
	end
	return profile
end

migrations[4] = function(profile, _now)
	-- v5 adds passive training. The experience starts empty for existing
	-- profiles; any experience already stored is preserved.
	local training: any = profile.training
	if type(training) ~= "table" then
		training = {}
		profile.training = training
	end
	for _, attribute in { "strength", "stamina", "carrying" } do
		if training[attribute] == nil then
			training[attribute] = 0
		end
	end
	return profile
end

migrations[5] = function(profile, _now)
	-- v6 adds relic companions. Existing players own none and have none
	-- equipped; any companion data already present is preserved.
	if type(profile.companions) ~= "table" then
		profile.companions = {}
	end
	if type(profile.equippedCompanion) ~= "string" then
		profile.equippedCompanion = nil
	end
	return profile
end

migrations[6] = function(profile, _now)
	-- v7 adds Museum Prestige. Existing players start at level 0 and have never
	-- prestiged; any prestige data already present is preserved.
	if profile.prestigeLevel == nil then
		profile.prestigeLevel = 0
	end
	if profile.lastPrestigeAt == nil then
		profile.lastPrestigeAt = 0
	end
	return profile
end

function Schema.migrate(rawProfile: any, now: number): (Profile?, boolean?, string?)
	if type(rawProfile) ~= "table" then
		return nil, nil, "Profile is not a table"
	end

	local profile = rawProfile
	local version = safeNumber(profile.schemaVersion, 0)
	local migrated = false

	if version > Schema.CURRENT_VERSION then
		return nil, nil, string.format("Profile schema %d is newer than supported %d", version, Schema.CURRENT_VERSION)
	end

	while version < Schema.CURRENT_VERSION do
		local migration = migrations[version]
		if migration == nil then
			if version == 0 then
				-- Initial migration: fill missing fields from a default shell while
				-- preserving any fields already present.
				local shell: any = Schema.createDefault(now, tostring(profile.sessionId or ""), 0)
				for key, value in shell do
					if profile[key] == nil then
						profile[key] = value
					end
				end
			else
				return nil, nil, string.format("Missing migration from schema %d", version)
			end
		else
			profile = migration(profile, now)
		end
		version += 1
		profile.schemaVersion = version
		migrated = true
	end

	return profile, migrated, nil
end

-- Normalizes types and removes invalid references without discarding valid data.
function Schema.normalize(profile: Profile, now: number): Profile
	profile.sessionId = tostring(profile.sessionId or "")
	profile.updatedAt = safeNumber(profile.updatedAt, now)
	profile.gold = math.max(0, math.floor(safeNumber(profile.gold, 0)))
	profile.tutorialComplete = safeBoolean(profile.tutorialComplete, false)
	profile.lastIncomeClaimAt = math.min(now, safeNumber(profile.lastIncomeClaimAt, now))
	profile.pendingOfflineGold = math.max(0, math.floor(safeNumber(profile.pendingOfflineGold, 0)))
	profile.vip = safeBoolean(profile.vip, false)
	profile.tutorialStep = math.max(0, math.floor(safeNumber(profile.tutorialStep, 0)))
	profile.prestigeLevel = math.clamp(math.floor(safeNumber(profile.prestigeLevel, 0)), 0, MAX_PRESTIGE_LEVEL)
	profile.lastPrestigeAt = math.clamp(math.floor(safeNumber(profile.lastPrestigeAt, 0)), 0, now)
	profile.schemaVersion = Schema.CURRENT_VERSION

	local stats = safeTable(profile.stats)
	profile.stats = {
		extractions = math.max(0, math.floor(safeNumber(stats.extractions, 0))),
		deaths = math.max(0, math.floor(safeNumber(stats.deaths, 0))),
		relicsCollected = math.max(0, math.floor(safeNumber(stats.relicsCollected, 0))),
		incomeClaimed = math.max(0, math.floor(safeNumber(stats.incomeClaimed, 0))),
	}

	local relics = safeTable(profile.relics)
	for uid, relic in relics do
		if type(uid) ~= "string" or type(relic) ~= "table" or type(relic.id) ~= "string" then
			relics[uid] = nil
		else
			relic.acquiredAt = safeNumber(relic.acquiredAt, now)
		end
	end
	profile.relics = relics

	local museum = safeTable(profile.museum)
	local usedUids: { [string]: boolean } = {}
	for pedestalId, uid in museum do
		if type(pedestalId) ~= "string" or type(uid) ~= "string" or relics[uid] == nil or usedUids[uid] then
			museum[pedestalId] = nil
		else
			usedUids[uid] = true
		end
	end
	profile.museum = museum

	local upgrades = safeTable(profile.upgrades)
	for upgradeId, level in upgrades do
		if type(upgradeId) ~= "string" or type(level) ~= "number" then
			upgrades[upgradeId] = nil
		else
			upgrades[upgradeId] = math.max(0, math.floor(level))
		end
	end
	profile.upgrades = upgrades

	-- Training experience is kept per attribute. Unknown attributes are kept
	-- as well so a profile written by a newer build never loses data here.
	local training = safeTable(profile.training)
	for attribute, xp in training do
		if type(attribute) ~= "string" or type(xp) ~= "number" or xp ~= xp or xp == math.huge or xp == -math.huge then
			training[attribute] = nil
		else
			training[attribute] = math.min(MAX_TRAINING_XP, math.max(0, math.floor(xp)))
		end
	end
	profile.training = training

	-- Companion ownership is a boolean map. Unknown ids are kept so a profile
	-- written by a newer build never loses data here; the resolver ignores ids
	-- it does not know. The equipped id is kept only while it is still owned.
	local companions = safeTable(profile.companions)
	for companionId, owned in companions do
		if type(companionId) ~= "string" or owned ~= true then
			companions[companionId] = nil
		end
	end
	profile.companions = companions
	local equipped = profile.equippedCompanion
	if type(equipped) ~= "string" or equipped == "" or companions[equipped] ~= true then
		profile.equippedCompanion = nil
	end

	local temples = safeTable(profile.unlockedTemples)
	for templeId, unlocked in temples do
		if type(templeId) ~= "string" or unlocked ~= true then
			temples[templeId] = nil
		end
	end
	profile.unlockedTemples = temples

	local settings = safeTable(profile.settings)
	local textScale = settings.textScale
	if textScale ~= "Normal" and textScale ~= "Large" and textScale ~= "Huge" then
		textScale = "Normal"
	end
	profile.settings = {
		soundEnabled = safeBoolean(settings.soundEnabled, true),
		visualEffects = safeBoolean(settings.visualEffects, true),
		reducedMotion = safeBoolean(settings.reducedMotion, false),
		colorblindMode = safeBoolean(settings.colorblindMode, false),
		textScale = textScale,
	}

	return profile
end

return Schema
