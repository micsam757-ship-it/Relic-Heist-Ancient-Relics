--!nonstrict
-- Server entry point. Initializes infrastructure, builds the world, starts
-- domain services in dependency order, then begins loading players.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Signal = require(ReplicatedStorage.Shared.Utilities.Signal)
local GameConfig = require(ReplicatedStorage.Shared.Config.GameConfig)
-- With init.server.luau, this directory becomes the "Server" Script itself, so
-- its children (Services, Utilities, World) are referenced directly off `script`.
local Logger = require(script.Utilities.Logger)
local WorldBuilder = require(script.World.WorldBuilder)

local services = {
	Network = require(script.Services.NetworkService),
	Analytics = require(script.Services.AnalyticsService),
	View = require(script.Services.ViewService),
	PlayerData = require(script.Services.PlayerDataService),
	Plot = require(script.Services.PlotService),
	Museum = require(script.Services.MuseumService),
	Relic = require(script.Services.RelicService),
	Economy = require(script.Services.EconomyService),
	Upgrade = require(script.Services.UpgradeService),
	Progression = require(script.Services.ProgressionService),
	Settings = require(script.Services.SettingsService),
	Expedition = require(script.Services.ExpeditionService),
	Hazard = require(script.Services.HazardService),
	Extraction = require(script.Services.ExtractionService),
	Admin = require(script.Services.AdminService),
}

local logger = Logger.new("Bootstrap")

local ctx = {
	Config = GameConfig,
	Services = services,
	Logger = logger,
	World = nil,
	Signals = {
		ProfileLoaded = Signal.new(),
		ProfileUnloading = Signal.new(),
		ProfileChanged = Signal.new(),
		PlotAssigned = Signal.new(),
		PlotReleased = Signal.new(),
		UpgradePurchased = Signal.new(),
		TempleUnlocked = Signal.new(),
	},
}

local initOrder = {
	"Network",
	"Analytics",
	"View",
	"PlayerData",
	"Economy",
	"Upgrade",
	"Progression",
	"Settings",
	"Plot",
	"Museum",
	"Relic",
	"Expedition",
	"Hazard",
	"Extraction",
	"Admin",
}

local startOrder = {
	"Network",
	"Analytics",
	"Economy",
	"Upgrade",
	"Progression",
	"Settings",
	"Plot",
	"Museum",
	"Relic",
	"Hazard",
	"Extraction",
	"Expedition",
	"Admin",
}

local function main()
	logger:info("Booting %s v%s", GameConfig.Game.Title, GameConfig.Game.Version)

	ctx.World = WorldBuilder.Build()
	logger:info(
		"World built with %d temple(s)",
		(function()
			local count = 0
			for _ in pairs(ctx.World.Temples) do
				count += 1
			end
			return count
		end)()
	)

	for _, name in initOrder do
		local service = services[name]
		if service and type(service.Init) == "function" then
			service:Init(ctx)
		end
	end

	ctx.Signals.ProfileLoaded:Connect(function(player)
		services.Network:PushState(player)
	end)
	ctx.Signals.ProfileChanged:Connect(function(player)
		services.Network:PushState(player)
	end)
	ctx.Signals.PlotAssigned:Connect(function(player)
		services.Network:PushState(player)
	end)
	ctx.Signals.PlotReleased:Connect(function(player)
		services.Network:PushState(player)
	end)
	ctx.Signals.TempleUnlocked:Connect(function(player)
		services.Network:PushState(player)
	end)

	for _, entry in ctx.World.Hub.prompts do
		entry.prompt.Triggered:Connect(function(player)
			services.Network:PushEvent(player, "OpenPanel", { panel = entry.panel })
		end)
	end

	services.Network:RegisterAction("RequestState", function(player)
		services.Network:PushState(player)
		return true
	end, { perSecond = 2, burst = 4, requireProfile = false })

	for _, name in startOrder do
		local service = services[name]
		if service and type(service.Start) == "function" then
			service:Start()
		end
	end

	-- Load players only after every consumer of ProfileLoaded has connected.
	services.PlayerData:Start()

	logger:info("Ready")
end

local ok, err = pcall(main)
if not ok then
	logger:error("Fatal boot error: %s", tostring(err))
end

return nil
