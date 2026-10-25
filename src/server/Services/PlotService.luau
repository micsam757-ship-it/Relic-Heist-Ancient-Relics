--!nonstrict
-- Museum plot allocation. Plots are built on demand and destroyed on release so
-- every active player owns exactly one valid plot and no plot is shared.
-- Expanding the footprint (wings and building enhancements) rebuilds the plot
-- in place so the geometry matches the player's purchases.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local GameConfig = require(ReplicatedStorage.Shared.Config.GameConfig)
local MuseumBuilder = require(ReplicatedStorage.Shared.Domain.MuseumBuilder)
local Logger = require(script.Parent.Parent.Utilities.Logger)
local PlotBuilder = require(script.Parent.Parent.World.PlotBuilder)

local PlotService = {}

local MAX_PLOTS = GameConfig.World.MaxPlots
-- Each wing now fits a 120x120 box and the three wings stack to ~280 studs deep.
-- The plots ring radius and start angle are shared with the world builders
-- (`GameConfig.World`) so the connecting avenues line up with each plot.
local RING_RADIUS = GameConfig.World.RingRadius
local ANGLE_STEP_DEGREES = 360 / MAX_PLOTS
-- Temples run straight along the +Z axis, so the ring starts offset from 90
-- degrees to keep the nearest plots clear of the temple lane.
local START_ANGLE_DEGREES = GameConfig.World.StartAngleDegrees

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

local function footprintOptions(profile)
	local floorLevel = profile and (profile.upgrades.MuseumFloor or 0) or 0
	local wings = MuseumBuilder.unlockedWings(GameConfig.MuseumBuilding.Wings, floorLevel)
	local features = MuseumBuilder.featureLevels(
		GameConfig.MuseumBuilding.Enhancements,
		GameConfig.Upgrades,
		profile and profile.upgrades or {}
	)
	return { wings = wings, features = features }
end

local function rebuildPlot(player: Player)
	local plot = state.plots[player]
	if plot == nil then
		return
	end
	local profile = state.ctx.Services.PlayerData:GetProfile(player)
	if profile == nil then
		return
	end
	local index = plot.index
	local cframe = plot.cframe
	plot.model:Destroy()
	local newPlot = PlotBuilder.Build(state.folder, index, cframe, footprintOptions(profile))
	newPlot.owner = player
	newPlot.model:SetAttribute("OwnerUserId", player.UserId)
	newPlot.signText.Text = player.DisplayName
	player.RespawnLocation = newPlot.spawn
	state.plots[player] = newPlot
	state.ctx.Signals.PlotAssigned:Fire(player, newPlot)
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

	local profile = state.ctx.Services.PlayerData:GetProfile(player)
	local plot = PlotBuilder.Build(state.folder, index, cframe, footprintOptions(profile))
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

local function isFootprintUpgrade(upgradeId: string): boolean
	if upgradeId == "MuseumFloor" or upgradeId == "ExtraPedestal" then
		return true
	end
	local enhancement = GameConfig.MuseumBuilding.Enhancements
	for _, id in enhancement do
		if id == upgradeId then
			return true
		end
	end
	return false
end

function PlotService:Start()
	-- Never reuse a stale plot folder. An older build (or a place copy) may leave a
	-- `MuseumPlots` folder in Workspace with pre-change geometry; destroy any such
	-- folder so the new multi-wing layout is the only one that exists.
	local stale = workspace:FindFirstChild("MuseumPlots")
	while stale ~= nil do
		stale:Destroy()
		stale = workspace:FindFirstChild("MuseumPlots")
	end

	state.folder = Instance.new("Folder")
	state.folder.Name = "MuseumPlots"
	state.folder.Parent = state.ctx.World.Folder

	state.ctx.Signals.ProfileLoaded:Connect(function(player)
		PlotService:Assign(player)
	end)
	state.ctx.Signals.ProfileUnloading:Connect(function(player)
		PlotService:Release(player)
	end)
	state.ctx.Signals.UpgradePurchased:Connect(function(player, upgradeId)
		-- Only footprint-affecting upgrades change the geometry. MuseumService
		-- also listens to re-run its own refresh after the plot is rebuilt.
		if isFootprintUpgrade(upgradeId) then
			rebuildPlot(player)
		end
	end)
	-- A prestige resets every footprint upgrade at once. Rebuild once from the
	-- new profile instead of firing seven UpgradePurchased signals.
	state.ctx.Signals.PrestigeApplied:Connect(function(player)
		rebuildPlot(player)
	end)
end

return PlotService
