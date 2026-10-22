--!nonstrict
-- Server-validated equipment purchases.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local GameConfig = require(ReplicatedStorage.Shared.Config.GameConfig)
local Contracts = require(ReplicatedStorage.Shared.Net.Contracts)
local Economy = require(ReplicatedStorage.Shared.Domain.Economy)
local StatsUtil = require(script.Parent.Parent.Utilities.StatsUtil)
local PlayerUtil = require(script.Parent.Parent.Utilities.PlayerUtil)

local UpgradeService = {}

local state = { ctx = nil }

function UpgradeService:Init(ctx)
	state.ctx = ctx
end

function UpgradeService:ApplyEffects(player: Player)
	local profile = state.ctx.Services.PlayerData:GetProfile(player)
	if profile == nil then
		return
	end
	local humanoid = PlayerUtil.getHumanoid(player)
	if humanoid == nil then
		return
	end
	local maxHealth = StatsUtil.forProfile(profile).maxHealth
	humanoid.MaxHealth = maxHealth
	if humanoid.Health > maxHealth then
		humanoid.Health = maxHealth
	end
end

function UpgradeService:Start()
	state.ctx.Services.Network:RegisterAction("BuyUpgrade", function(player, data)
		local valid = Contracts.check("BuyUpgrade", data)
		if not valid then
			return false, "Invalid purchase request."
		end
		local profile = state.ctx.Services.PlayerData:GetProfile(player)
		if profile == nil then
			return false, "Profile not ready."
		end

		local upgradeId = data.upgradeId
		local definition = GameConfig.Upgrades[upgradeId]
		if definition == nil then
			return false, "Unknown upgrade."
		end

		local level = profile.upgrades[upgradeId] or 0
		local cost = Economy.upgradeCost(definition, level)
		if cost == nil then
			return false, "That upgrade is already at maximum level."
		end

		local ok, reason = state.ctx.Services.Economy:Spend(player, cost)
		if not ok then
			return false, reason
		end

		profile.upgrades[upgradeId] = level + 1
		UpgradeService:ApplyEffects(player)
		state.ctx.Services.PlayerData:MarkDirty(player)
		state.ctx.Signals.UpgradePurchased:Fire(player, upgradeId, level + 1)
		state.ctx.Services.Analytics:Track("upgrade_purchased", { upgrade = upgradeId, level = level + 1, cost = cost })
		return true, string.format("Purchased %s (level %d).", definition.name, level + 1)
	end, { perSecond = 2, burst = 4 })
end

return UpgradeService
