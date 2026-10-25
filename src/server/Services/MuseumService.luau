--!nonstrict
-- Museum display placement and pedestal interaction, fully server-authoritative.

local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local GameConfig = require(ReplicatedStorage.Shared.Config.GameConfig)
local Contracts = require(ReplicatedStorage.Shared.Net.Contracts)
local Economy = require(ReplicatedStorage.Shared.Domain.Economy)
local Inventory = require(ReplicatedStorage.Shared.Domain.Inventory)
local MuseumBuilder = require(ReplicatedStorage.Shared.Domain.MuseumBuilder)
local RelicVisuals = require(script.Parent.Parent.World.RelicVisuals)
local PlotBuilder = require(script.Parent.Parent.World.PlotBuilder)
local PlayerUtil = require(script.Parent.Parent.Utilities.PlayerUtil)
local RateLimiter = require(script.Parent.Parent.Security.RateLimiter)
local Logger = require(script.Parent.Parent.Utilities.Logger)

local MuseumService = {}

local UNLOCKED_TOP = Color3.fromRGB(224, 178, 74)
local LOCKED_TOP = Color3.fromRGB(70, 68, 66)

local state = {
	ctx = nil,
	logger = nil,
	plots = {},
	displays = {},
	connections = {},
	limiter = nil,
}

function MuseumService:Init(ctx)
	state.ctx = ctx
	state.logger = Logger.new("Museum")
	state.limiter = RateLimiter.new(GameConfig.RateLimits.PedestalInteractPerSecond, 4)
end

local function profileOf(player: Player)
	return state.ctx.Services.PlayerData:GetProfile(player)
end

local function maxPedestals(): number
	return GameConfig.Museum.MaxPedestals or 8
end

local function unlockedPedestalCount(profile): number
	local movement = GameConfig.Movement
	return Economy.pedestalCount(
		movement.BasePedestals,
		profile.upgrades.MuseumFloor or 0,
		GameConfig.Upgrades.MuseumFloor.perLevel,
		profile.upgrades.ExtraPedestal or 0,
		GameConfig.Upgrades.ExtraPedestal.perLevel,
		maxPedestals()
	)
end

-- The rarity tier that should skin a pedestal holding `definitionId`, or the
-- Common/default tier for an empty or unknown relic.
local function tierForRelic(definitionId: string?)
	if definitionId == nil then
		return MuseumBuilder.tierForRarity(GameConfig.MuseumBuilding.PedestalTiers, nil)
	end
	local definition = GameConfig.Relics[definitionId]
	return MuseumBuilder.tierForRarity(GameConfig.MuseumBuilding.PedestalTiers, definition and definition.rarity or nil)
end

local function destroyDisplay(player: Player, pedestalId: string)
	local playerDisplays = state.displays[player]
	if playerDisplays == nil or playerDisplays[pedestalId] == nil then
		return
	end
	playerDisplays[pedestalId]:Destroy()
	playerDisplays[pedestalId] = nil
end

local function buildDisplay(player: Player, plot, pedestal, definitionId: string)
	destroyDisplay(player, pedestal.id)
	local definition = GameConfig.Relics[definitionId]
	if definition == nil then
		return
	end
	local display = RelicVisuals.build(definition)
	display.Name = "Display_" .. pedestal.id
	display:SetAttribute("PedestalId", pedestal.id)
	display:PivotTo(pedestal.displayCFrame)
	display.Parent = plot.model
	CollectionService:AddTag(display, "MuseumDisplay")

	state.displays[player] = state.displays[player] or {}
	state.displays[player][pedestal.id] = display
end

function MuseumService:Refresh(player: Player)
	local plot = state.plots[player]
	local profile = profileOf(player)
	if plot == nil or profile == nil then
		return
	end
	local unlockedCount = unlockedPedestalCount(profile)

	for index, pedestal in plot.pedestals do
		local unlocked = index <= unlockedCount
		local uid = profile.museum[pedestal.id]
		pedestal.prompt.Enabled = unlocked
		pedestal.model = plot.model

		if not unlocked then
			pedestal.top.Color = LOCKED_TOP
			pedestal.labelText.Text = "Locked"
			pedestal.labelText.TextColor3 = LOCKED_TOP
			pedestal.labelSubtitle.Text = "Expand your museum"
			pedestal.labelAccent.BackgroundColor3 = LOCKED_TOP
			pedestal.prompt.ActionText = "Locked"
			pedestal.prompt.ObjectText = "Locked Pedestal"
			PlotBuilder.applyPedestalTier(pedestal, tierForRelic(nil))
			PlotBuilder.applyLockedIndicator(pedestal, true)
			destroyDisplay(player, pedestal.id)
		elseif uid ~= nil then
			local owned = profile.relics[uid]
			local definition = owned and GameConfig.Relics[owned.id]
			if definition then
				if state.displays[player] == nil or state.displays[player][pedestal.id] == nil then
					buildDisplay(player, plot, pedestal, owned.id)
				end
				PlotBuilder.applyPedestalTier(pedestal, tierForRelic(owned.id))
				PlotBuilder.applyLockedIndicator(pedestal, false)
				local rarity = GameConfig.Rarities[definition.rarity]
				local rarityColor = rarity and Color3.fromRGB(rarity.color[1], rarity.color[2], rarity.color[3])
					or UNLOCKED_TOP
				pedestal.top.Color = rarityColor
				pedestal.labelText.Text = definition.name
				pedestal.labelText.TextColor3 = rarityColor
				pedestal.labelSubtitle.Text = definition.rarity
				pedestal.labelAccent.BackgroundColor3 = rarityColor
				pedestal.prompt.ActionText = "Remove Display"
				pedestal.prompt.ObjectText = definition.name
			end
		else
			destroyDisplay(player, pedestal.id)
			PlotBuilder.applyPedestalTier(pedestal, tierForRelic(nil))
			PlotBuilder.applyLockedIndicator(pedestal, false)
			pedestal.top.Color = UNLOCKED_TOP
			pedestal.labelText.Text = "Empty Plinth"
			pedestal.labelText.TextColor3 = UNLOCKED_TOP
			pedestal.labelSubtitle.Text = "Exhibit a relic"
			pedestal.labelAccent.BackgroundColor3 = UNLOCKED_TOP
			pedestal.prompt.ActionText = "Exhibit Relic"
			pedestal.prompt.ObjectText = "Pedestal " .. pedestal.id
		end
	end
end

local function onPedestalTriggered(player: Player, plot, pedestal)
	if plot.owner ~= player then
		return
	end
	if not state.limiter:Allow(tostring(player.UserId)) then
		return
	end
	local distance = PlayerUtil.distanceToPoint(player, pedestal.topCFrame.Position)
	if distance == nil or distance > 14 then
		return
	end

	local profile = profileOf(player)
	if profile == nil then
		return
	end
	local unlocked = tonumber(pedestal.id) <= unlockedPedestalCount(profile)
	if not unlocked then
		state.ctx.Services.Network:Toast(player, "warning", "This pedestal is locked. Expand your museum first.")
		return
	end

	if profile.museum[pedestal.id] ~= nil then
		local uid = Inventory.unexhibit(profile, pedestal.id)
		if uid ~= nil then
			destroyDisplay(player, pedestal.id)
			MuseumService:Refresh(player)
			state.ctx.Services.PlayerData:MarkDirty(player)
			state.ctx.Services.Network:Toast(player, "info", "Relic returned to your archive.")
		end
	else
		state.ctx.Services.Network:PushEvent(player, "PedestalSelected", {
			pedestalId = pedestal.id,
			plotIndex = plot.index,
		})
	end
end

function MuseumService:SetupPlot(player: Player, plot)
	-- A footprint upgrade rebuilds the plot and fires PlotAssigned again, so any
	-- display models from the previous plot are stale. Drop them here so Refresh
	-- rebuilds each relic onto the new pedestals.
	if state.displays[player] then
		for _, display in state.displays[player] do
			if display.Parent then
				display:Destroy()
			end
		end
	end
	state.displays[player] = {}
	if state.connections[player] then
		for _, connection in state.connections[player] do
			connection:Disconnect()
		end
	end

	state.plots[player] = plot
	state.connections[player] = {}
	local profile = profileOf(player)
	local features = profile and plot.features or {}
	for _, pedestal in plot.pedestals do
		if features then
			PlotBuilder.applyPedestalEnhancements(pedestal, features)
		end
		local connection = pedestal.prompt.Triggered:Connect(function(triggeringPlayer)
			if triggeringPlayer == player then
				onPedestalTriggered(player, plot, pedestal)
			end
		end)
		table.insert(state.connections[player], connection)
	end
	MuseumService:Refresh(player)
end

function MuseumService:TeardownPlot(player: Player)
	for _, connection in state.connections[player] or {} do
		connection:Disconnect()
	end
	state.connections[player] = nil
	local playerDisplays = state.displays[player]
	if playerDisplays then
		for _, display in playerDisplays do
			display:Destroy()
		end
	end
	state.displays[player] = nil
	state.plots[player] = nil
end

function MuseumService:Start()
	state.ctx.Signals.PlotAssigned:Connect(function(player, plot)
		MuseumService:SetupPlot(player, plot)
	end)
	state.ctx.Signals.PlotReleased:Connect(function(player)
		MuseumService:TeardownPlot(player)
	end)
	state.ctx.Signals.UpgradePurchased:Connect(function(player)
		MuseumService:Refresh(player)
	end)
	state.ctx.Signals.PrestigeApplied:Connect(function(player)
		MuseumService:Refresh(player)
	end)

	state.ctx.Services.Network:RegisterAction("PlaceRelic", function(player, data)
		local valid = Contracts.check("PlaceRelic", data)
		if not valid then
			return false, "Invalid placement request."
		end
		local profile = profileOf(player)
		if profile == nil then
			return false, "Profile not ready."
		end
		local plot = state.plots[player]
		if plot == nil then
			return false, "You do not have a museum plot."
		end
		local pedestal = plot.pedestals[tonumber(data.pedestalId)]
		if pedestal == nil then
			return false, "Unknown pedestal."
		end
		local distance = PlayerUtil.distanceToPoint(player, pedestal.topCFrame.Position)
		if distance == nil or distance > 20 then
			return false, "Move closer to that pedestal."
		end

		local ok, reason = Inventory.exhibit(profile, data.uid, data.pedestalId, unlockedPedestalCount(profile))
		if not ok then
			return false, reason
		end

		local owned = profile.relics[data.uid]
		buildDisplay(player, plot, pedestal, owned.id)
		MuseumService:Refresh(player)
		state.ctx.Services.PlayerData:MarkDirty(player)
		state.ctx.Services.Analytics:Track("relic_exhibited", {})
		if state.ctx.Services.Tutorial then
			state.ctx.Services.Tutorial:Advance(player, "exhibited")
		end
		return true, string.format("Exhibited %s.", GameConfig.Relics[owned.id].name)
	end, { perSecond = 3, burst = 6 })

	state.ctx.Services.Network:RegisterAction("RemoveRelic", function(player, data)
		local valid = Contracts.check("RemoveRelic", data)
		if not valid then
			return false, "Invalid request."
		end
		local profile = profileOf(player)
		local plot = state.plots[player]
		if profile == nil or plot == nil then
			return false, "Museum not ready."
		end
		local pedestal = plot.pedestals[tonumber(data.pedestalId)]
		if pedestal == nil then
			return false, "Unknown pedestal."
		end
		local distance = PlayerUtil.distanceToPoint(player, pedestal.topCFrame.Position)
		if distance == nil or distance > 20 then
			return false, "Move closer to that pedestal."
		end

		local uid = Inventory.unexhibit(profile, data.pedestalId)
		if uid == nil then
			return false, "That pedestal is empty."
		end
		destroyDisplay(player, data.pedestalId)
		MuseumService:Refresh(player)
		state.ctx.Services.PlayerData:MarkDirty(player)
		return true, "Relic returned to your archive."
	end, { perSecond = 3, burst = 6 })
end

return MuseumService
