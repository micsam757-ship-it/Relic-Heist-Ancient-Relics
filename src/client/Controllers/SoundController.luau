--!nonstrict
-- Client audio feedback. Sounds are data-driven from `GameConfig.Audio`; an asset
-- id of 0 means "not configured" and plays nothing, so the game stays silent but
-- playable until sounds are authored. Playback is gated by the player's
-- soundEnabled setting and never blocks gameplay.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local SoundService = game:GetService("SoundService")

local GameConfig = require(ReplicatedStorage.Shared.Config.GameConfig)
local Preferences = require(script.Parent.Parent.Preferences)

local SoundController = {}

local state = {
	ready = false,
	pool = {},
	cursor = 1,
	POOL_SIZE = 8,
}

local function definition(name: string)
	local audio = GameConfig.Audio
	local entry = audio and audio.Sounds and audio.Sounds[name]
	if entry == nil or entry.assetId == nil or entry.assetId == 0 then
		return nil
	end
	return entry
end

-- Always available for UI feedback regardless of setting, but returns nil when
-- audio is disabled or the sound is unconfigured.
local function play(name: string)
	local audio = GameConfig.Audio
	if not state.ready or audio == nil or audio.Enabled == false then
		return
	end
	if not Preferences.soundEnabled() then
		return
	end
	local entry = definition(name)
	if entry == nil then
		return
	end

	local sound = state.pool[state.cursor]
	state.cursor = state.cursor % state.POOL_SIZE + 1
	sound.SoundId = string.format("rbxassetid://%d", entry.assetId)
	sound.Volume = (entry.volume or 0.5) * (audio.MasterVolume or 0.6)
	sound.PlaybackSpeed = 1
	sound.TimePosition = 0
	sound:Play()
end

function SoundController.start()
	for index = 1, state.POOL_SIZE do
		local sound = Instance.new("Sound")
		sound.Name = string.format("Sfx%d", index)
		sound.Volume = 0
		sound.Parent = SoundService
		state.pool[index] = sound
	end
	state.ready = true
end

function SoundController.play(name: string)
	play(name)
end

return SoundController
