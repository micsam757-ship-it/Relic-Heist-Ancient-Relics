--!nonstrict
-- Server-authoritative stamina and sprinting.
--
-- The client only states its intent ("I am holding sprint"); the server owns
-- the pool, decides when sprinting actually applies, and is the only writer
-- of the sprint speed. Sprinting is scoped to expeditions: outside a run the
-- character keeps the default walk speed, exactly as before this feature.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local GameConfig = require(ReplicatedStorage.Shared.Config.GameConfig)
local Contracts = require(ReplicatedStorage.Shared.Net.Contracts)
local Stamina = require(ReplicatedStorage.Shared.Domain.Stamina)
local Stats = require(ReplicatedStorage.Shared.Domain.Stats)
local StatsUtil = require(script.Parent.Parent.Utilities.StatsUtil)
local PlayerUtil = require(script.Parent.Parent.Utilities.PlayerUtil)
local Logger = require(script.Parent.Parent.Utilities.Logger)

local StaminaService = {}

-- How often the pool is advanced and the speed re-applied.
local TICK_SECONDS = 0.1
-- How often the pool is pushed to the owning client while it changes.
local PUSH_SECONDS = 0.25
-- Movement below this magnitude counts as standing still.
local MOVE_THRESHOLD = 0.05

local state = {
	ctx = nil,
	logger = nil,
	entries = {},
}

local function entryFor(player: Player)
	return state.entries[player]
end

-- The pool the player currently has, and how large it is.
function StaminaService:GetState(player: Player)
	local entry = entryFor(player)
	if entry == nil then
		return nil
	end
	return entry.stamina
end

function StaminaService:IsSprinting(player: Player): boolean
	local entry = entryFor(player)
	return entry ~= nil and entry.stamina.sprinting
end

-- Creates (or refreshes) the runtime pool for a player. The pool is not
-- persisted: it is rebuilt from the resolved stats every time the player
-- starts an expedition.
function StaminaService:EnsureState(player: Player)
	local entry = entryFor(player)
	local profile = state.ctx.Services.PlayerData:GetProfile(player)
	if profile == nil then
		return nil
	end
	local stats = StatsUtil.forProfile(profile)
	if entry == nil then
		entry = {
			stamina = Stamina.new(stats.staminaMax),
			wantsSprint = false,
			lastPush = 0,
			exhaustedNotified = false,
		}
		state.entries[player] = entry
	elseif entry.stamina.max ~= stats.staminaMax then
		-- The resolved pool changed (training or a new upgrade): resize the
		-- current pool, keeping the same fill ratio.
		local ratio = Stamina.ratio(entry.stamina)
		entry.stamina = Stamina.new(stats.staminaMax)
		entry.stamina.current = stats.staminaMax * ratio
	end
	return entry
end

-- Refills the pool and drops the sprint intent. Used when a run starts.
function StaminaService:Reset(player: Player)
	local entry = StaminaService:EnsureState(player)
	if entry == nil then
		return
	end
	entry.stamina = Stamina.new(entry.stamina.max)
	entry.wantsSprint = false
	entry.exhaustedNotified = false
end

-- The speed the character should move at for the current weight. Sprinting is
-- a temporary boost on top of the weight-penalised walk speed.
function StaminaService:GetSpeed(player: Player, weight: number): number
	local entry = entryFor(player)
	local profile = state.ctx.Services.PlayerData:GetProfile(player)
	if profile == nil then
		return GameConfig.Movement.BaseWalkSpeed
	end
	local stats = StatsUtil.forProfile(profile)
	if entry ~= nil and entry.stamina.sprinting then
		return Stats.sprintSpeed(weight, GameConfig.Movement, stats.weightPenaltyReduction)
	end
	return Stats.walkSpeed(weight, GameConfig.Movement, stats.weightPenaltyReduction)
end

-- Applies the walk or sprint speed. Only expeditions have a speed to manage;
-- everywhere else the character keeps its default speed.
function StaminaService:ApplySpeed(player: Player)
	local entry = entryFor(player)
	if entry == nil then
		return
	end
	if state.ctx.Services.Expedition:GetState(player) == nil then
		return
	end
	local humanoid = PlayerUtil.getHumanoid(player)
	if humanoid == nil then
		return
	end
	local weight = state.ctx.Services.Expedition:GetCarriedWeight(player)
	humanoid.WalkSpeed = StaminaService:GetSpeed(player, weight)
end

local function pushStamina(player: Player, entry)
	local stamina = entry.stamina
	state.ctx.Services.Network:PushEvent(player, "Stamina", {
		current = stamina.current,
		max = stamina.max,
		sprinting = stamina.sprinting,
		exhausted = stamina.exhausted,
	})
	entry.lastPush = os.clock()
end

local function tick()
	local now = os.clock()
	for player, entry in state.entries do
		if player.Parent ~= Players then
			state.entries[player] = nil
			continue
		end
		local humanoid = PlayerUtil.getHumanoid(player)
		if humanoid == nil then
			continue
		end
		local profile = state.ctx.Services.PlayerData:GetProfile(player)
		if profile == nil then
			continue
		end
		local stats = StatsUtil.forProfile(profile)
		local inExpedition = state.ctx.Services.Expedition:GetState(player) ~= nil
		if not inExpedition then
			-- Between runs the pool refills and the sprint intent is dropped.
			entry.wantsSprint = false
		end
		local moving = humanoid.MoveDirection.Magnitude > MOVE_THRESHOLD
		local sprinting = entry.wantsSprint and inExpedition and moving and not entry.stamina.exhausted

		local rules = {
			drainPerSecond = stats.staminaDrainPerSecond,
			recoveryPerSecond = stats.staminaRecoveryPerSecond,
			recoverRatio = GameConfig.Stamina.ExhaustedRecoveryRatio,
		}
		local before = entry.stamina
		entry.stamina = Stamina.update(entry.stamina, TICK_SECONDS, rules, sprinting)

		if before.exhausted ~= entry.stamina.exhausted then
			if entry.stamina.exhausted then
				entry.exhaustedNotified = true
				state.ctx.Services.Network:Toast(player, "warning", "Out of stamina!")
			else
				entry.exhaustedNotified = false
			end
		end

		StaminaService:ApplySpeed(player)

		if now - entry.lastPush >= PUSH_SECONDS then
			pushStamina(player, entry)
		end
	end
end

function StaminaService:Init(ctx)
	state.ctx = ctx
	state.logger = Logger.new("Stamina")
	state.ctx.Signals.ProfileLoaded:Connect(function(player)
		StaminaService:EnsureState(player)
	end)
end

function StaminaService:Start()
	state.ctx.Services.Network:RegisterAction("SetSprint", function(player, data)
		local valid = Contracts.check("SetSprint", data)
		if not valid then
			return false
		end
		local entry = StaminaService:EnsureState(player)
		if entry == nil then
			return false
		end
		if data.state == "sprint" then
			if state.ctx.Services.Expedition:GetState(player) == nil then
				-- Sprinting only applies inside an expedition.
				return true
			end
			entry.wantsSprint = true
			local stamina, ok = Stamina.startSprint(entry.stamina)
			entry.stamina = stamina
			if not ok then
				state.ctx.Services.Network:Toast(player, "warning", "You are too exhausted to sprint.")
			end
		elseif data.state == "walk" then
			entry.wantsSprint = false
			entry.stamina = Stamina.stopSprint(entry.stamina)
		else
			return false
		end
		StaminaService:ApplySpeed(player)
		pushStamina(player, entry)
		return true
	end, { perSecond = 10, burst = 20 })

	Players.PlayerRemoving:Connect(function(player)
		state.entries[player] = nil
	end)

	task.spawn(function()
		while true do
			task.wait(TICK_SECONDS)
			pcall(tick)
		end
	end)
end

return StaminaService
