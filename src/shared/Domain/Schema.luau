--!strict
-- Versioned profile schema and migrations. Pure functions for testability.

local Schema = {}

Schema.CURRENT_VERSION = 1

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
	unlockedTemples: { [string]: boolean },
	lastIncomeClaimAt: number,
	settings: { [string]: boolean },
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
		upgrades = {
			SprintBoots = 0,
			Backpack = 0,
			Armor = 0,
			MuseumFloor = 0,
			ExtraPedestal = 0,
		},
		unlockedTemples = { TutorialRuins = true },
		lastIncomeClaimAt = now,
		settings = { soundEnabled = true, visualEffects = true },
	}
end

-- Forward-only migrations. Each entry upgrades a profile from version N to N+1.
local migrations: { [number]: (profile: any, now: number) -> any } = {}

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

	local temples = safeTable(profile.unlockedTemples)
	for templeId, unlocked in temples do
		if type(templeId) ~= "string" or unlocked ~= true then
			temples[templeId] = nil
		end
	end
	profile.unlockedTemples = temples

	local settings = safeTable(profile.settings)
	profile.settings = {
		soundEnabled = safeBoolean(settings.soundEnabled, true),
		visualEffects = safeBoolean(settings.visualEffects, true),
	}

	return profile
end

return Schema
