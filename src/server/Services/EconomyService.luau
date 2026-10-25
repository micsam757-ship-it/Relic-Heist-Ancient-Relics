--!nonstrict
-- Server-authoritative currency and passive museum income.
--
-- Live income auto-deposits into the player's gold balance on a one-second
-- server tick (see docs/ADR/0006-auto-tick-income.md). Offline income accrues
-- from `lastIncomeClaimAt`, is capped against the offline window, and is held in
-- `profile.pendingOfflineGold` so the player resolves it through the Welcome
-- Back modal (1x free, or 2x via a Developer Product). See
-- docs/ADR/0007-monetization.md.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local GameConfig = require(ReplicatedStorage.Shared.Config.GameConfig)
local Economy = require(ReplicatedStorage.Shared.Domain.Economy)
local StatsUtil = require(script.Parent.Parent.Utilities.StatsUtil)
local Logger = require(script.Parent.Parent.Utilities.Logger)

local EconomyService = {}

local INCOME_TICK_SECONDS = 1

local state = {
	ctx = nil,
	logger = nil,
	-- Fractional carry per player so a rate below 1/sec still pays out exactly.
	carry = {},
}

function EconomyService:Init(ctx)
	state.ctx = ctx
	state.logger = Logger.new("Economy")
end

local function depositIncome(player: Player, amount: number)
	if amount <= 0 then
		return
	end
	local profile = state.ctx.Services.PlayerData:GetProfile(player)
	if profile == nil then
		return
	end
	profile.gold += amount
	profile.stats.incomeClaimed += amount
	state.ctx.Services.PlayerData:MarkDirty(player)
end

function EconomyService:GetIncomeRate(profile): number
	local exhibitedIncome = 0
	for _, uid in profile.museum do
		local owned = profile.relics[uid]
		local definition = owned and GameConfig.Relics[owned.id]
		if definition then
			exhibitedIncome += definition.incomePerMinute
		end
	end
	local floorLevel = profile.upgrades.MuseumFloor or 0
	local rate = Economy.incomeRatePerSecond(
		exhibitedIncome,
		floorLevel,
		GameConfig.Museum.IncomePerMinuteFloorBonus,
		GameConfig.Museum.MaxIncomeRatePerMinute
	)
	-- Passive museum income uses the companion bonus plus the prestige bonus.
	-- The companion-only `goldMultiplier` is reserved for the extraction stipend.
	return rate * StatsUtil.forProfile(profile).museumIncomeMultiplier
end

-- VIP Pass holders get a longer window and a higher ceiling.
function EconomyService:GetOfflineCap(profile): (number, number)
	if profile.vip then
		return GameConfig.Economy.VipOfflineCapSeconds, GameConfig.Economy.VipMaxPendingIncome
	end
	return GameConfig.Economy.OfflineCapSeconds, GameConfig.Economy.MaxPendingIncome
end

-- Income accrued while the player was away, computed from the on-demand
-- timestamp model. Purely informational; the join path stores it as pending.
function EconomyService:GetOfflineIncome(player: Player): number
	local profile = state.ctx.Services.PlayerData:GetProfile(player)
	if profile == nil then
		return 0
	end
	local capSeconds, maxPending = EconomyService:GetOfflineCap(profile)
	return Economy.pendingIncome(
		EconomyService:GetIncomeRate(profile),
		profile.lastIncomeClaimAt,
		os.time(),
		capSeconds,
		maxPending
	)
end

-- Compute the offline payout on join, store it as pending, and advance the
-- timestamp so the live tick does not re-count the same stretch of time.
function EconomyService:AccrueOfflineIntoPending(player: Player): number
	local profile = state.ctx.Services.PlayerData:GetProfile(player)
	if profile == nil then
		return 0
	end
	local offline = EconomyService:GetOfflineIncome(player)
	profile.lastIncomeClaimAt = os.time()
	if offline > 0 then
		profile.pendingOfflineGold = math.max(profile.pendingOfflineGold, offline)
		state.ctx.Services.PlayerData:MarkDirty(player)
		state.ctx.Services.Analytics:Track("offline_pending", { amount = offline })
	end
	return offline
end

-- Resolve the pending balance at the requested multiplier and deposit it.
-- Returns the granted amount so callers can toast/analytics. `multiplier` is
-- validated by the caller (the MonetizationService owns purchase validation).
function EconomyService:ClaimPending(player: Player, multiplier: number): number
	local profile = state.ctx.Services.PlayerData:GetProfile(player)
	if profile == nil then
		return 0
	end
	local pending = math.max(0, math.floor(profile.pendingOfflineGold or 0))
	if pending <= 0 then
		return 0
	end
	local factor = math.max(1, math.floor(multiplier or 1))
	local granted = pending * factor
	profile.pendingOfflineGold = 0
	depositIncome(player, granted)
	if multiplier and multiplier > 1 then
		state.ctx.Services.Analytics:Track("offline_claim", { amount = granted, multiplier = factor })
	else
		state.ctx.Services.Analytics:Track("offline_claim", { amount = granted, multiplier = 1 })
	end
	return granted
end

function EconomyService:Spend(player: Player, amount: number): (boolean, string?)
	local profile = state.ctx.Services.PlayerData:GetProfile(player)
	if profile == nil then
		return false, "Profile not ready."
	end
	if type(amount) ~= "number" or amount ~= amount or amount <= 0 or amount % 1 ~= 0 then
		return false, "Invalid amount."
	end
	if profile.gold < amount then
		return false, "You do not have enough gold."
	end
	profile.gold -= amount
	state.ctx.Services.PlayerData:MarkDirty(player)
	return true, nil
end

function EconomyService:AddGold(player: Player, amount: number)
	if type(amount) ~= "number" or amount ~= amount or amount <= 0 then
		return
	end
	local profile = state.ctx.Services.PlayerData:GetProfile(player)
	if profile == nil then
		return
	end
	profile.gold += math.floor(amount)
	state.ctx.Services.PlayerData:MarkDirty(player)
end

local function tickPlayer(player: Player)
	local profile = state.ctx.Services.PlayerData:GetProfile(player)
	if profile == nil then
		return
	end
	local rate = EconomyService:GetIncomeRate(profile)
	profile.lastIncomeClaimAt = os.time()
	if rate <= 0 then
		state.carry[player] = 0
		return
	end
	local accrued = (state.carry[player] or 0) + rate * INCOME_TICK_SECONDS
	local whole = math.floor(accrued)
	state.carry[player] = accrued - whole
	if whole > 0 then
		depositIncome(player, whole)
	end
end

function EconomyService:GetPending(player: Player): number
	local profile = state.ctx.Services.PlayerData:GetProfile(player)
	if profile == nil then
		return 0
	end
	return math.max(0, math.floor(profile.pendingOfflineGold or 0))
end

function EconomyService:Start()
	state.ctx.Signals.ProfileLoaded:Connect(function(player)
		-- Hold the offline payout as pending; the WelcomeBack prompt (driven by
		-- MonetizationService) is what grants it, at 1x or 2x.
		EconomyService:AccrueOfflineIntoPending(player)
		local monetization = state.ctx.Services.Monetization
		if monetization and type(monetization.NotifyOfflineReady) == "function" then
			monetization:NotifyOfflineReady(player)
		end
	end)
	Players.PlayerRemoving:Connect(function(player)
		state.carry[player] = nil
	end)

	task.spawn(function()
		while true do
			task.wait(INCOME_TICK_SECONDS)
			for _, player in Players:GetPlayers() do
				tickPlayer(player)
			end
		end
	end)
end

return EconomyService
