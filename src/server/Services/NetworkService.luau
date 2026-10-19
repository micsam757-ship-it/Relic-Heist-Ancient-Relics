--!nonstrict
-- Central network dispatcher. One RemoteEvent carries all client requests so
-- validation, rate limiting, and logging are centralized (see docs/API_CONTRACTS.md).

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local GameConfig = require(ReplicatedStorage.Shared.Config.GameConfig)
local RateLimiter = require(script.Parent.Parent.Security.RateLimiter)
local Logger = require(script.Parent.Parent.Utilities.Logger)

local NetworkService = {}

local state = {
	ctx = nil,
	logger = nil,
	request = nil,
	stateEvent = nil,
	eventEvent = nil,
	handlers = {},
	globalLimiter = nil,
	actionLimiters = {},
}

function NetworkService:Init(ctx)
	state.ctx = ctx
	state.logger = Logger.new("Network")
	state.globalLimiter = RateLimiter.new(GameConfig.RateLimits.ActionPerSecond, GameConfig.RateLimits.ActionBurst)

	local remotes = ReplicatedStorage:WaitForChild("Remotes")
	state.request = remotes:WaitForChild("Request")
	state.stateEvent = remotes:WaitForChild("State")
	state.eventEvent = remotes:WaitForChild("Event")
end

function NetworkService:RegisterAction(name: string, handler, options)
	assert(type(name) == "string" and #name > 0, "action name required")
	assert(type(handler) == "function", "handler must be a function")
	state.handlers[name] = {
		handler = handler,
		options = options or {},
	}
	if options and (options.perSecond or options.burst) then
		state.actionLimiters[name] = RateLimiter.new(options.perSecond or 5, options.burst or 10)
	end
end

local function isValidPayload(payload): boolean
	if type(payload) ~= "table" then
		return false
	end
	return type(payload.action) == "string"
end

local function handleRequest(player: Player, payload)
	if not isValidPayload(payload) then
		state.logger:warn("Malformed request from %s", player.Name)
		return
	end

	if not state.globalLimiter:Allow(tostring(player.UserId)) then
		return
	end

	local entry = state.handlers[payload.action]
	if entry == nil then
		state.logger:warn("Unknown action '%s' from %s", tostring(payload.action), player.Name)
		return
	end

	local handler = entry.handler
	local options = entry.options
	if options.requireProfile ~= false and not state.ctx.Services.PlayerData:IsLoaded(player) then
		return
	end

	local limiter = state.actionLimiters[payload.action]
	if limiter and not limiter:Allow(tostring(player.UserId)) then
		return
	end

	local ok, result, message = pcall(handler, player, payload.data)
	if not ok then
		state.logger:error("Handler '%s' errored for %s: %s", payload.action, player.Name, tostring(result))
		NetworkService:Toast(player, "error", "Something went wrong. Please try again.")
		return
	end

	if result == false and message then
		NetworkService:Toast(player, "error", message)
	elseif result == true and message then
		NetworkService:Toast(player, "success", message)
	end
end

function NetworkService:Start()
	state.request.OnServerEvent:Connect(handleRequest)
end

function NetworkService:PushState(player: Player)
	if not player:IsDescendantOf(Players) then
		return
	end
	local view = state.ctx.Services.View:Build(player)
	if view == nil then
		return
	end
	state.stateEvent:FireClient(player, view)
end

function NetworkService:PushEvent(player: Player, name: string, data)
	if not player:IsDescendantOf(Players) then
		return
	end
	state.eventEvent:FireClient(player, { name = name, data = data })
end

function NetworkService:Toast(player: Player, kind: string, message: string)
	NetworkService:PushEvent(player, "Toast", { kind = kind, message = message })
end

return NetworkService
