--!nonstrict
-- Development-only administrative tools. Commands are available ONLY when the
-- server is running inside Roblox Studio, and are never connected in production.

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local GameConfig = require(ReplicatedStorage.Shared.Config.GameConfig)
local Schema = require(ReplicatedStorage.Shared.Domain.Schema)
local Inventory = require(ReplicatedStorage.Shared.Domain.Inventory)
local Ids = require(script.Parent.Parent.Utilities.Ids)
local Logger = require(script.Parent.Parent.Utilities.Logger)

local AdminService = {}

local state = {
	ctx = nil,
	logger = nil,
}

function AdminService:Init(ctx)
	state.ctx = ctx
	state.logger = Logger.new("Admin")
end

local function reply(player: Player, message: string)
	state.ctx.Services.Network:Toast(player, "info", message)
end

local commands = {}

commands.help = function(player)
	reply(player, "Commands: !rh_state, !rh_gold <n>, !rh_relic <id>, !rh_save, !rh_unlock <temple>, !rh_reset")
end

commands.state = function(player)
	local profile = state.ctx.Services.PlayerData:GetProfile(player)
	if profile == nil then
		reply(player, "Profile not loaded.")
		return
	end
	local relicCount = 0
	for _ in profile.relics do
		relicCount += 1
	end
	reply(
		player,
		string.format("gold=%d relics=%d extractions=%d", profile.gold, relicCount, profile.stats.extractions)
	)
end

commands.gold = function(player, argument)
	local amount = tonumber(argument)
	if amount == nil then
		reply(player, "Usage: !rh_gold <amount>")
		return
	end
	state.ctx.Services.Economy:AddGold(player, math.clamp(amount, 1, 1000000))
	reply(player, string.format("Added %d gold.", amount))
end

commands.relic = function(player, argument)
	if argument == nil or GameConfig.Relics[argument] == nil then
		reply(player, "Unknown relic id.")
		return
	end
	local profile = state.ctx.Services.PlayerData:GetProfile(player)
	if profile == nil then
		reply(player, "Profile not loaded.")
		return
	end
	local uid = Ids.relicUid()
	local success = Inventory.addOwned(profile, uid, argument, os.time(), GameConfig.Save.MaxRelicsPerProfile)
	if success then
		state.ctx.Services.PlayerData:MarkDirty(player)
		reply(player, "Granted " .. argument)
	else
		reply(player, "Could not grant relic.")
	end
end

commands.save = function(player)
	state.ctx.Services.PlayerData:SaveAsync(player, true)
	reply(player, "Save requested.")
end

commands.unlock = function(player, argument)
	if argument == nil or GameConfig.Temples[argument] == nil then
		reply(player, "Unknown temple id.")
		return
	end
	local profile = state.ctx.Services.PlayerData:GetProfile(player)
	profile.unlockedTemples[argument] = true
	state.ctx.Services.PlayerData:MarkDirty(player)
	reply(player, "Unlocked " .. argument)
end

commands.reset = function(player)
	local fresh = Schema.createDefault(os.time(), Ids.newGuid(), GameConfig.Economy.StartingGold)
	state.ctx.Services.PlayerData:ReplaceProfile(player, fresh)
	reply(player, "Profile reset. Rejoin to fully refresh.")
end

local function onChatted(player: Player, message: string)
	if message:sub(1, 4) ~= "!rh_" then
		return
	end
	local space = message:find(" ")
	local name = space and message:sub(5, space - 1) or message:sub(5)
	local argument = space and message:sub(space + 1) or nil
	local handler = commands[name]
	if handler == nil then
		reply(player, "Unknown command. Try !rh_help")
		return
	end
	local ok, err = pcall(handler, player, argument)
	if not ok then
		state.logger:error("Admin command '%s' failed: %s", name, tostring(err))
	end
end

function AdminService:Start()
	if not RunService:IsStudio() then
		return
	end
	state.logger:info("Admin commands enabled (Studio only)")
	Players.PlayerAdded:Connect(function(player)
		player.Chatted:Connect(function(message)
			onChatted(player, message)
		end)
	end)
	for _, player in Players:GetPlayers() do
		player.Chatted:Connect(function(message)
			onChatted(player, message)
		end)
	end
end

return AdminService
