--!nonstrict
-- Server-authoritative tutorial progression (see docs/ADR/0009-tutorial-and-ux.md).
--
-- The tutorial is an ordered list of steps in `GameConfig.Tutorial.Steps`. Other
-- services call `TutorialService:Advance(player, action)` when a player performs a
-- teachable action; this service decides whether that advances the current step
-- and, if so, records it on the profile and pushes a `TutorialStep` event so the
-- client can update its objective and celebrate. The tutorial never gates play:
-- a step only advances when the matching action happens, in order.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local GameConfig = require(ReplicatedStorage.Shared.Config.GameConfig)
local Tutorial = require(ReplicatedStorage.Shared.Domain.Tutorial)
local Logger = require(script.Parent.Parent.Utilities.Logger)

local TutorialService = {}

local state = {
	ctx = nil,
	logger = nil,
	steps = {},
}

local function steps(): { Tutorial.TutorialStep }
	return state.steps
end

-- Advances the player's tutorial if `action` matches their next step. Safe to
-- call for every teachable action; unmatched or out-of-order actions are ignored.
-- Returns true if the step advanced.
function TutorialService:Advance(player: Player, action: string): boolean
	if #steps() == 0 then
		return false
	end
	local profile = state.ctx.Services.PlayerData:GetProfile(player)
	if profile == nil then
		return false
	end

	local current = profile.tutorialStep or 0
	if Tutorial.isComplete(current, steps()) then
		return false
	end

	local next = Tutorial.advance(current, steps(), action)
	if next == current then
		return false
	end

	profile.tutorialStep = next
	state.ctx.Services.PlayerData:MarkDirty(player)

	local view = Tutorial.view(next, steps())
	state.ctx.Services.Network:PushEvent(player, "TutorialStep", {
		completed = view.completed,
		total = view.total,
		active = view.active,
		step = view.step,
	})
	if not view.active then
		state.ctx.Services.Network:PushEvent(player, "TutorialComplete", {})
	end
	return true
end

function TutorialService:Init(ctx)
	state.ctx = ctx
	state.logger = Logger.new("Tutorial")
	state.steps = GameConfig.Tutorial and GameConfig.Tutorial.Steps or {}
end

function TutorialService:Start()
	if #steps() > 0 then
		state.logger:info("Tutorial active with %d step(s)", #steps())
	end
end

return TutorialService
