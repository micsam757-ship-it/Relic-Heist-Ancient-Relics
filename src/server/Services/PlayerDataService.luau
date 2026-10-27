--!nonstrict
-- Server-authoritative, versioned player profile persistence.
--
-- Safety rules implemented here (see docs/DATA_MODEL.md and docs/THREAT_MODEL.md):
--  * A failed load never silently creates and saves over existing data.
--  * Saves use UpdateAsync with a session conflict guard to avoid blind
--    overwrites from a second server.
--  * Writes are debounced and bounded; BindToClose uses a timeout.
--  * In Studio (API access disabled) profiles run in ephemeral, read-only mode.

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local DataStoreService = game:GetService("DataStoreService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local GameConfig = require(ReplicatedStorage.Shared.Config.GameConfig)
local Schema = require(ReplicatedStorage.Shared.Domain.Schema)
local Persist = require(ReplicatedStorage.Shared.Utilities.Persist)
local Util = require(ReplicatedStorage.Shared.Utilities.Util)
local Ids = require(script.Parent.Parent.Utilities.Ids)
local Logger = require(script.Parent.Parent.Utilities.Logger)

local PlayerDataService = {}

local state = {
	ctx = nil,
	logger = nil,
	store = nil,
	profiles = {},
	started = false,
}

local SAVE_DEBOUNCE_SECONDS = 4
local SAVE_TICK_SECONDS = 3

local function profileKey(player: Player): string
	return "player_" .. tostring(player.UserId)
end

local function notify(player: Player, kind: string, message: string)
	if state.ctx and state.ctx.Services.Network then
		state.ctx.Services.Network:Toast(player, kind, message)
	end
end

function PlayerDataService:Init(ctx)
	state.ctx = ctx
	state.logger = Logger.new("PlayerData")

	local ok, store = pcall(function()
		return DataStoreService:GetDataStore(GameConfig.Save.DataStoreName, GameConfig.Save.DataStoreScope)
	end)
	if ok then
		state.store = store
	else
		state.store = nil
		state.logger:warn("DataStore unavailable: %s", tostring(store))
	end
end

local function fetchWithRetries(player: Player): (any, string)
	local key = profileKey(player)
	for attempt = 1, GameConfig.Save.MaxLoadRetries do
		local ok, result = pcall(function()
			return state.store:GetAsync(key)
		end)
		if ok then
			if result == nil then
				return nil, Persist.LoadStatus.NOT_FOUND
			end
			return result, Persist.LoadStatus.OK
		end
		state.logger:warn("Load attempt %d failed for %s: %s", attempt, player.Name, tostring(result))
		local backoff =
			Persist.retryBackoff(attempt, GameConfig.Save.MaxLoadRetries, GameConfig.Save.RetryBackoffSeconds)
		if backoff then
			task.wait(backoff)
		end
	end
	return nil, Persist.LoadStatus.UNAVAILABLE
end

local function newEphemeralProfile(now: number, sessionId: string)
	return Schema.createDefault(now, sessionId, GameConfig.Economy.StartingGold)
end

local function enterEphemeral(player: Player, handle, reason: string)
	handle.ephemeral = true
	handle.data = newEphemeralProfile(os.time(), handle.sessionId)
	handle.dirty = false
	state.logger:warn("Ephemeral profile for %s: %s", player.Name, reason)
	notify(player, "warning", "Persistence unavailable. Progress will NOT be saved this session.")
end

local function loadProfile(player: Player)
	local now = os.time()
	local handle = {
		data = nil,
		sessionId = Ids.newGuid(),
		dirty = false,
		loadedAt = now,
		ephemeral = false,
		saving = false,
		loaded = false,
		conflict = false,
		failNextSave = false,
	}
	state.profiles[player] = handle

	local storeAvailable = state.store ~= nil
	local status = Persist.LoadStatus.NOT_FOUND
	local raw = nil
	if storeAvailable then
		raw, status = fetchWithRetries(player)
	end

	local migrated, didMigrate, migrateError = nil, false, nil
	if storeAvailable and status == Persist.LoadStatus.OK then
		migrated, didMigrate, migrateError = Schema.migrate(raw, now)
	end

	local isStudio = RunService:IsStudio()
	local outcome = Persist.loadOutcome(storeAvailable, status, migrated, isStudio)

	if outcome == "KICK" then
		if status == Persist.LoadStatus.OK then
			state.logger:error("Refusing to overwrite profile for %s: %s", player.Name, tostring(migrateError))
			player:Kick("Your saved data could not be read safely. Please rejoin in a moment.")
		else
			state.logger:error("Kicking %s: could not load persistent data", player.Name)
			player:Kick("Unable to load your data right now. Please rejoin in a moment.")
		end
		state.profiles[player] = nil
		return
	end

	if outcome == "EPHEMERAL" then
		local reason = if not storeAvailable
			then "DataStore service unavailable"
			elseif status == Persist.LoadStatus.OK then ("Unreadable profile in Studio: " .. tostring(migrateError))
			else "Load failed after retries (Studio)"
		enterEphemeral(player, handle, reason)
	elseif outcome == "NEW" then
		handle.data = Schema.createDefault(now, handle.sessionId, GameConfig.Economy.StartingGold)
		handle.dirty = true
	else -- LIVE
		handle.data = Schema.normalize(migrated, now)
		handle.dirty = didMigrate == true
	end

	if not player:IsDescendantOf(Players) then
		state.profiles[player] = nil
		return
	end

	handle.loaded = true
	state.logger:info("Profile ready for %s (ephemeral=%s)", player.Name, tostring(handle.ephemeral))
	state.ctx.Signals.ProfileLoaded:Fire(player, handle.data)
end

local function attemptSave(player: Player, handle): (string, string?)
	if state.store == nil or handle.ephemeral then
		return "SKIPPED"
	end

	handle.data.sessionId = handle.sessionId
	handle.data.updatedAt = os.time()
	local snapshot = Util.deepCopy(handle.data)
	local key = profileKey(player)
	local committed = false

	local ok, err = pcall(function()
		state.store:UpdateAsync(key, function(current)
			if not Persist.canCommit(current, handle.sessionId, handle.loadedAt) then
				return nil
			end
			committed = true
			return snapshot
		end)
	end)

	if not ok then
		return "ERROR", tostring(err)
	end
	if not committed then
		return "CONFLICT"
	end
	return "OK"
end

function PlayerDataService:SaveAsync(player: Player, force: boolean): boolean
	local handle = state.profiles[player]
	if handle == nil or not handle.loaded or handle.ephemeral then
		return false
	end
	if handle.saving then
		return false
	end
	if force and handle.failNextSave then
		handle.failNextSave = false
		state.logger:warn("Injected forced-save failure for %s", player.Name)
		return false
	end
	if not force and not handle.dirty then
		return true
	end

	handle.saving = true
	local succeeded = false
	for attempt = 1, GameConfig.Save.MaxSaveRetries do
		local status, err = attemptSave(player, handle)
		if status == "OK" or status == "SKIPPED" then
			succeeded = true
			break
		elseif status == "CONFLICT" then
			handle.conflict = true
			handle.ephemeral = true
			state.logger:error("Save conflict for %s; disabling further writes to protect newer data", player.Name)
			notify(player, "warning", "A newer save was detected on another server. Changes will not overwrite it.")
			break
		else
			state.logger:warn("Save attempt %d failed for %s: %s", attempt, player.Name, tostring(err))
			local backoff =
				Persist.retryBackoff(attempt, GameConfig.Save.MaxSaveRetries, GameConfig.Save.RetryBackoffSeconds)
			if backoff then
				task.wait(backoff)
			end
		end
	end
	handle.saving = false

	if succeeded then
		handle.dirty = false
		handle.loadedAt = os.time()
	end
	return succeeded
end

function PlayerDataService:GetProfile(player: Player)
	local handle = state.profiles[player]
	if handle == nil then
		return nil
	end
	return handle.data
end

function PlayerDataService:IsLoaded(player: Player): boolean
	local handle = state.profiles[player]
	return handle ~= nil and handle.loaded
end

function PlayerDataService:IsEphemeral(player: Player): boolean
	local handle = state.profiles[player]
	return handle ~= nil and handle.ephemeral
end

-- Development-only: make the next forced save fail without touching DataStore.
-- Used by the Studio Session M rollback test; cleared when consumed.
function PlayerDataService:ArmSaveFailure(player: Player, enabled: boolean): boolean
	if not RunService:IsStudio() then
		return false
	end
	local handle = state.profiles[player]
	if handle == nil or not handle.loaded then
		return false
	end
	handle.failNextSave = enabled == true
	return true
end

function PlayerDataService:MarkDirty(player: Player)
	local handle = state.profiles[player]
	if handle == nil then
		return
	end
	handle.dirty = true
	handle.dirtyAt = os.clock()
	state.ctx.Signals.ProfileChanged:Fire(player)
end

-- Replaces the in-memory profile without saving or normalizing it. Used by
-- Prestige to swap in a pure reset copy and to roll back if the forced save
-- fails. The caller owns validation and must persist before side effects.
function PlayerDataService:SwapProfile(player: Player, newProfile): boolean
	local handle = state.profiles[player]
	if handle == nil or not handle.loaded or type(newProfile) ~= "table" then
		return false
	end
	handle.data = newProfile
	return true
end

-- Development-only: replace the in-memory profile for a player.
function PlayerDataService:ReplaceProfile(player: Player, newProfile)
	local handle = state.profiles[player]
	if handle == nil then
		return false
	end
	handle.data = Schema.normalize(newProfile, os.time())
	handle.dirty = true
	return true
end

function PlayerDataService:Start()
	if state.started then
		return
	end
	state.started = true

	Players.PlayerAdded:Connect(function(player)
		task.spawn(loadProfile, player)
	end)

	Players.PlayerRemoving:Connect(function(player)
		state.ctx.Signals.ProfileUnloading:Fire(player)
		PlayerDataService:SaveAsync(player, true)
		state.profiles[player] = nil
	end)

	task.spawn(function()
		while true do
			task.wait(SAVE_TICK_SECONDS)
			local now = os.clock()
			for player, handle in pairs(state.profiles) do
				if
					handle.loaded
					and not handle.ephemeral
					and handle.dirty
					and not handle.saving
					and now - (handle.dirtyAt or 0) >= SAVE_DEBOUNCE_SECONDS
				then
					task.spawn(function()
						PlayerDataService:SaveAsync(player, false)
					end)
				end
			end
		end
	end)

	game:BindToClose(function()
		local pending = 0
		for player, handle in pairs(state.profiles) do
			if handle.loaded and not handle.ephemeral then
				pending += 1
				task.spawn(function()
					PlayerDataService:SaveAsync(player, true)
					pending -= 1
				end)
			end
		end
		local deadline = os.clock() + GameConfig.Save.BindToCloseTimeoutSeconds
		while pending > 0 and os.clock() < deadline do
			task.wait(0.1)
		end
	end)

	for _, player in Players:GetPlayers() do
		task.spawn(loadProfile, player)
	end
end

return PlayerDataService
