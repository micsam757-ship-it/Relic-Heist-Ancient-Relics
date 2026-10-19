--!nonstrict
-- Player settings persistence and validation.

local SettingsService = {}

local state = { ctx = nil }

function SettingsService:Init(ctx)
	state.ctx = ctx
end

function SettingsService:Start()
	state.ctx.Services.Network:RegisterAction("UpdateSettings", function(player, data)
		if type(data) ~= "table" then
			return false, "Invalid settings payload."
		end
		local profile = state.ctx.Services.PlayerData:GetProfile(player)
		if profile == nil then
			return false, "Profile not ready."
		end

		local changed = false
		if type(data.soundEnabled) == "boolean" then
			profile.settings.soundEnabled = data.soundEnabled
			changed = true
		end
		if type(data.visualEffects) == "boolean" then
			profile.settings.visualEffects = data.visualEffects
			changed = true
		end
		if not changed then
			return false, "No valid settings provided."
		end

		state.ctx.Services.PlayerData:MarkDirty(player)
		return true
	end, { perSecond = 3, burst = 6 })
end

return SettingsService
