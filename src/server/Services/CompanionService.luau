--!nonstrict
-- Relic companions: purchase, ownership, and the single equipped slot.
--
-- Ownership and the equipped id live on the profile. Bonuses are applied by the
-- shared stats resolver; this service only validates requests, moves gold, and
-- re-applies the effects that already exist (health, stamina pool, speed).

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local GameConfig = require(ReplicatedStorage.Shared.Config.GameConfig)
local Contracts = require(ReplicatedStorage.Shared.Net.Contracts)
local Companions = require(ReplicatedStorage.Shared.Domain.Companions)
local Logger = require(script.Parent.Parent.Utilities.Logger)

local CompanionService = {}

local state = {
	ctx = nil,
	logger = nil,
}

function CompanionService:Init(ctx)
	state.ctx = ctx
	state.logger = Logger.new("Companions")
end

local function applyEffects(player: Player)
	local services = state.ctx.Services
	services.Upgrade:ApplyEffects(player)
	local stamina = services.Stamina
	if stamina ~= nil then
		stamina:EnsureState(player)
	end
	services.Expedition:RecalculateMovement(player)
end

local function push(player: Player)
	state.ctx.Services.Network:PushState(player)
end

function CompanionService:Start()
	state.ctx.Services.Network:RegisterAction("BuyCompanion", function(player, data)
		local valid = Contracts.check("BuyCompanion", data)
		if not valid then
			return false, "Invalid companion request."
		end
		local profile = state.ctx.Services.PlayerData:GetProfile(player)
		if profile == nil then
			return false, "Profile not ready."
		end

		local companionId = data.companionId
		local definition = GameConfig.Companions.Definitions[companionId]
		if definition == nil then
			return false, "Unknown companion."
		end
		if Companions.owns(profile.companions, companionId) then
			return false, "You already own that companion."
		end

		local ok, reason = state.ctx.Services.Economy:Spend(player, definition.cost)
		if not ok then
			return false, reason
		end

		profile.companions[companionId] = true
		-- The first companion is equipped automatically so the purchase has an
		-- immediate effect; the player can still swap it in the Companions panel.
		if profile.equippedCompanion == nil then
			local equipped, equippedOk = Companions.equip(profile.companions, nil, companionId)
			if equippedOk then
				profile.equippedCompanion = equipped
			end
		end
		applyEffects(player)
		state.ctx.Services.PlayerData:MarkDirty(player)
		state.ctx.Services.Network:Toast(player, "success", string.format("Recruited %s!", definition.name))
		state.ctx.Services.Analytics:Track("companion_purchased", { companion = companionId, cost = definition.cost })
		push(player)
		return true, nil
	end, { perSecond = 1, burst = 2 })

	state.ctx.Services.Network:RegisterAction("EquipCompanion", function(player, data)
		local valid = Contracts.check("EquipCompanion", data)
		if not valid then
			return false, "Invalid companion request."
		end
		local profile = state.ctx.Services.PlayerData:GetProfile(player)
		if profile == nil then
			return false, "Profile not ready."
		end

		local companionId = data.companionId
		local definition = GameConfig.Companions.Definitions[companionId]
		if definition == nil then
			return false, "Unknown companion."
		end
		local equipped, ok, reason = Companions.equip(profile.companions, profile.equippedCompanion, companionId)
		if not ok then
			return false, reason
		end

		profile.equippedCompanion = equipped
		applyEffects(player)
		state.ctx.Services.PlayerData:MarkDirty(player)
		state.ctx.Services.Analytics:Track("companion_equipped", { companion = companionId })
		push(player)
		return true, string.format("%s equipped.", definition.name)
	end, { perSecond = 2, burst = 4 })

	state.ctx.Services.Network:RegisterAction("UnequipCompanion", function(_player, _data)
		local profile = state.ctx.Services.PlayerData:GetProfile(_player)
		if profile == nil then
			return false, "Profile not ready."
		end
		if profile.equippedCompanion == nil then
			return false, "No companion is equipped."
		end

		profile.equippedCompanion = Companions.unequip()
		applyEffects(_player)
		state.ctx.Services.PlayerData:MarkDirty(_player)
		state.ctx.Services.Analytics:Track("companion_unequipped", {})
		push(_player)
		return true, "Companion unequipped."
	end, { perSecond = 2, burst = 4 })

	state.ctx.Signals.ProfileLoaded:Connect(function(player)
		applyEffects(player)
	end)
end

return CompanionService
