--!strict
-- Composes the playable world: lighting, hub, and temples.

local Lighting = game:GetService("Lighting")

local GameConfig = require(game:GetService("ReplicatedStorage").Shared.Config.GameConfig)
local HubBuilder = require(script.Parent.HubBuilder)
local TempleBuilder = require(script.Parent.TempleBuilder)

local WorldBuilder = {}

local WORLD_NAME = "RelicHeistWorld"

local function configureLighting()
	Lighting.Ambient = Color3.fromRGB(86, 78, 66)
	Lighting.OutdoorAmbient = Color3.fromRGB(104, 96, 84)
	Lighting.Brightness = 2.4
	Lighting.ClockTime = 14.5
	Lighting.GeographicLatitude = 20
	Lighting.GlobalShadows = true
	Lighting.ShadowSoftness = 0.35
	Lighting.EnvironmentDiffuseScale = 0.4
	Lighting.EnvironmentSpecularScale = 0.35
	Lighting.FogEnd = 2200
	Lighting.FogStart = 200

	local atmosphere = Lighting:FindFirstChildOfClass("Atmosphere") or Instance.new("Atmosphere")
	atmosphere.Density = 0.32
	atmosphere.Offset = 0.2
	atmosphere.Color = Color3.fromRGB(206, 190, 164)
	atmosphere.Decay = Color3.fromRGB(112, 102, 92)
	atmosphere.Glare = 0.15
	atmosphere.Haze = 2.2
	atmosphere.Parent = Lighting
end

function WorldBuilder.Build()
	configureLighting()

	local existing = workspace:FindFirstChild(WORLD_NAME)
	if existing then
		existing:Destroy()
	end

	local world = Instance.new("Folder")
	world.Name = WORLD_NAME
	world.Parent = workspace

	local hub = HubBuilder.Build(world, GameConfig.Temples)

	local temples = {}
	for templeId, config in GameConfig.Temples do
		temples[templeId] = TempleBuilder.Build(world, templeId, config)
	end

	return {
		Folder = world,
		Hub = hub,
		Temples = temples,
	}
end

return WorldBuilder
