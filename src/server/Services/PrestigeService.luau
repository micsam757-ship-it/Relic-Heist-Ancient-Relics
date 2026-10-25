--!nonstrict
-- Server-authoritative Museum Prestige (ADR 0014).
--
-- Prestige is the most destructive action in the game, so the persisted reset is
-- the commit point: build a pure reset copy, swap it in, force a save, and only
-- after a successful save run side effects. A failed save restores the original
-- profile and reports that nothing changed.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local GameConfig = require(ReplicatedStorage.Shared.Config.GameConfig)
local Contracts = require(ReplicatedStorage.Shared.Net.Contracts)
local Prestige = require(ReplicatedStorage.Shared.Domain.Prestige)
local Logger = require(script.Parent.Parent.Utilities.Logger)

local PrestigeService = {}

local state = {
	ctx = nil,
	logger = nil,
}

function PrestigeService:Init(ctx)
	state.ctx = ctx
	state.logger = Logger.new("Prestige")
end

function PrestigeService:Start()
	state.ctx.Services.Network:RegisterAction("Prestige", function(player, data)
		local valid = Contracts.check("Prestige", data)
		if not valid then
			return false, "Invalid prestige request."
		end
		if data.confirm ~= "PRESTIGE" then
			return false, "Type PRESTIGE to confirm."
		end

		local services = state.ctx.Services
		local profile = services.PlayerData:GetProfile(player)
		if profile == nil then
			return false, "Profile not ready."
		end
		if services.PlayerData:IsEphemeral(player) then
			return false, "Progress is not being saved this session, so prestige is unavailable."
		end
		if services.Expedition:GetState(player) ~= nil then
			return false, "Return from your expedition before prestiging."
		end

		local now = os.time()
		local report = Prestige.evaluate(profile, GameConfig.Prestige, GameConfig.MuseumBuilding.Wings, now)
		if not report.eligible then
			return false, "Your museum is not ready to prestige yet."
		end

		local nextProfile = Prestige.apply(profile, GameConfig.Prestige, now)
		if not services.PlayerData:SwapProfile(player, nextProfile) then
			return false, "Profile not ready."
		end

		if not services.PlayerData:SaveAsync(player, true) then
			services.PlayerData:SwapProfile(player, profile)
			state.logger:warn("Prestige save failed for %s; rolled back", player.Name)
			return false, "Prestige could not be saved. Nothing was reset."
		end

		state.ctx.Signals.PrestigeApplied:Fire(player, nextProfile.prestigeLevel)
		services.Upgrade:ApplyEffects(player)
		services.Network:PushState(player)
		services.Analytics:Track("prestige", {
			level = nextProfile.prestigeLevel,
			rank = Prestige.rank(nextProfile.prestigeLevel, GameConfig.Prestige),
		})
		services.Network:Toast(
			player,
			"success",
			string.format("Prestige %d complete. Your museum has been reborn.", nextProfile.prestigeLevel)
		)
		return true, nil
	end, { perSecond = 0.2, burst = 1 })
end

return PrestigeService
