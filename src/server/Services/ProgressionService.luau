--!nonstrict
-- Temple unlock progression.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local GameConfig = require(ReplicatedStorage.Shared.Config.GameConfig)
local Progression = require(ReplicatedStorage.Shared.Domain.Progression)

local ProgressionService = {}

local state = { ctx = nil }

function ProgressionService:Init(ctx)
	state.ctx = ctx
end

function ProgressionService:CanEnter(player: Player, templeId: string): (boolean, string?)
	local profile = state.ctx.Services.PlayerData:GetProfile(player)
	if profile == nil then
		return false, "Profile not ready."
	end
	if not Progression.isUnlocked(profile.unlockedTemples, templeId) then
		return false, "That expedition is locked."
	end
	return true, nil
end

function ProgressionService:Start()
	state.ctx.Services.Network:RegisterAction("UnlockTemple", function(player, data)
		if type(data) ~= "table" or type(data.templeId) ~= "string" then
			return false, "Invalid unlock request."
		end
		local profile = state.ctx.Services.PlayerData:GetProfile(player)
		if profile == nil then
			return false, "Profile not ready."
		end

		local templeId = data.templeId
		local definition = GameConfig.Temples[templeId]
		if definition == nil then
			return false, "Unknown expedition."
		end

		if Progression.isUnlocked(profile.unlockedTemples, templeId) then
			return false, "That expedition is already unlocked."
		end
		if profile.stats.extractions < definition.minExtractions then
			return false,
				string.format(
					"Complete %d successful extraction(s) first.",
					definition.minExtractions - profile.stats.extractions
				)
		end

		local ok, reason = state.ctx.Services.Economy:Spend(player, definition.unlockPrice)
		if not ok then
			return false, reason
		end

		profile.unlockedTemples[templeId] = true
		state.ctx.Services.PlayerData:MarkDirty(player)
		state.ctx.Signals.TempleUnlocked:Fire(player, templeId)
		state.ctx.Services.Analytics:Track("temple_unlocked", { temple = templeId })
		return true, string.format("Unlocked %s.", definition.name)
	end, { perSecond = 1, burst = 3 })
end

return ProgressionService
