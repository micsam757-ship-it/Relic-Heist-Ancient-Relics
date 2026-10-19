--!nonstrict
-- Server-authoritative currency and passive museum income.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local GameConfig = require(ReplicatedStorage.Shared.Config.GameConfig)
local Economy = require(ReplicatedStorage.Shared.Domain.Economy)
local Logger = require(script.Parent.Parent.Utilities.Logger)

local EconomyService = {}

local state = {
	ctx = nil,
	logger = nil,
}

function EconomyService:Init(ctx)
	state.ctx = ctx
	state.logger = Logger.new("Economy")
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
	return Economy.incomeRatePerMinute(
		exhibitedIncome,
		floorLevel,
		GameConfig.Museum.IncomePerMinuteFloorBonus,
		GameConfig.Museum.MaxIncomeRatePerMinute
	)
end

function EconomyService:GetPendingIncome(player: Player): number
	local profile = state.ctx.Services.PlayerData:GetProfile(player)
	if profile == nil then
		return 0
	end
	return Economy.pendingIncome(
		EconomyService:GetIncomeRate(profile),
		profile.lastIncomeClaimAt,
		os.time(),
		GameConfig.Economy.OfflineCapSeconds,
		GameConfig.Economy.MaxPendingIncome
	)
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

function EconomyService:Start()
	state.ctx.Services.Network:RegisterAction("ClaimIncome", function(player, _data)
		local profile = state.ctx.Services.PlayerData:GetProfile(player)
		if profile == nil then
			return false, "Profile not ready."
		end
		local pending = EconomyService:GetPendingIncome(player)
		if pending <= 0 then
			return false, "There is no income to collect yet."
		end
		profile.gold += pending
		profile.stats.incomeClaimed += pending
		profile.lastIncomeClaimAt = os.time()
		state.ctx.Services.PlayerData:MarkDirty(player)
		state.ctx.Services.Analytics:Track("income_claimed", { amount = pending })
		return true, string.format("Collected %d gold in museum income.", pending)
	end, { perSecond = 1, burst = 3 })
end

return EconomyService
