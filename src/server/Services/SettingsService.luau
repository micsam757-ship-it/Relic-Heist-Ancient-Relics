--!nonstrict
-- Player settings persistence and validation.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local GameConfig = require(ReplicatedStorage.Shared.Config.GameConfig)

local SettingsService = {}

local state = { ctx = nil }

local function allowedTextScale(value): boolean
	for _, option in GameConfig.Settings.TextScaleOptions do
		if option == value then
			return true
		end
	end
	return false
end

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
		local booleanFields = { "soundEnabled", "visualEffects", "reducedMotion", "colorblindMode" }
		for _, field in booleanFields do
			if type(data[field]) == "boolean" then
				profile.settings[field] = data[field]
				changed = true
			end
		end
		if data.textScale ~= nil then
			if allowedTextScale(data.textScale) then
				profile.settings.textScale = data.textScale
				changed = true
			else
				return false, "Unsupported text size."
			end
		end
		if not changed then
			return false, "No valid settings provided."
		end

		state.ctx.Services.PlayerData:MarkDirty(player)
		return true
	end, { perSecond = 3, burst = 6 })
end

return SettingsService
