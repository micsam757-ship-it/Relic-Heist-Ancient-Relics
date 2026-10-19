--!nonstrict
-- Museum plot allocation. Plots are built on demand and destroyed on release so
-- every active player owns exactly one valid plot and no plot is shared.

local Logger = require(script.Parent.Parent.Utilities.Logger)
local PlotBuilder = require(script.Parent.Parent.World.PlotBuilder)

local PlotService = {}

local MAX_PLOTS = 12
local RING_RADIUS = 176
local ANGLE_STEP_DEGREES = 360 / MAX_PLOTS
local START_ANGLE_DEGREES = 90

local state = {
	ctx = nil,
	logger = nil,
	folder = nil,
	plots = {},
	busy = {},
}

function PlotService:Init(ctx)
	state.ctx = ctx
	state.logger = Logger.new("Plot")
end

local function notify(player: Player, kind: string, message: string)
	state.ctx.Services.Network:Toast(player, kind, message)
end

local function teleportToPlot(player: Player)
	local plot = state.plots[player]
	if plot == nil then
		return
	end
	local character = player.Character or player.CharacterAdded:Wait()
	task.wait(0.2)
	if not player.Parent or state.plots[player] ~= plot then
		return
	end
	character:PivotTo(plot.spawnCFrame)
end

function PlotService:GetPlot(player: Player)
	return state.plots[player]
end

function PlotService:Assign(player: Player)
	if state.plots[player] ~= nil then
		return
	end

	local index = nil
	for candidate = 1, MAX_PLOTS do
		if state.busy[candidate] == nil then
			index = candidate
			break
		end
	end

	if index == nil then
		state.logger:warn("No free plot for %s", player.Name)
		notify(player, "warning", "All museum plots are occupied. You are visiting as a guest.")
		return
	end

	local angle = math.rad(START_ANGLE_DEGREES + (index - 1) * ANGLE_STEP_DEGREES)
	local position = Vector3.new(math.cos(angle) * RING_RADIUS, 1, math.sin(angle) * RING_RADIUS)
	local cframe = CFrame.lookAt(position, Vector3.new(0, 1, 0))

	local plot = PlotBuilder.Build(state.folder, index, cframe)
	plot.owner = player
	plot.model:SetAttribute("OwnerUserId", player.UserId)
	plot.signText.Text = player.DisplayName

	state.busy[index] = true
	state.plots[player] = plot

	player.RespawnLocation = plot.spawn
	task.spawn(teleportToPlot, player)

	state.ctx.Signals.PlotAssigned:Fire(player, plot)
	state.logger:info("Plot %d assigned to %s", index, player.Name)
end

function PlotService:Release(player: Player)
	local plot = state.plots[player]
	if plot == nil then
		return
	end
	state.ctx.Signals.PlotReleased:Fire(player, plot)

	plot.model:Destroy()
	state.busy[plot.index] = nil
	state.plots[player] = nil

	if player.Parent ~= nil then
		player.RespawnLocation = nil
	end
end

function PlotService:Start()
	state.folder = Instance.new("Folder")
	state.folder.Name = "MuseumPlots"
	state.folder.Parent = state.ctx.World.Folder

	state.ctx.Signals.ProfileLoaded:Connect(function(player)
		PlotService:Assign(player)
	end)
	state.ctx.Signals.ProfileUnloading:Connect(function(player)
		PlotService:Release(player)
	end)
end

return PlotService
