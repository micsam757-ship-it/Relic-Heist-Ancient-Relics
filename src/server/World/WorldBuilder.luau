--!strict
-- Composes the playable world: lighting, hub, and temples.

local Lighting = game:GetService("Lighting")

local GameConfig = require(game:GetService("ReplicatedStorage").Shared.Config.GameConfig)
local GroundBuilder = require(script.Parent.GroundBuilder)
local HubBuilder = require(script.Parent.HubBuilder)
local PathBuilder = require(script.Parent.PathBuilder)
local TempleBuilder = require(script.Parent.TempleBuilder)
local SceneryBuilder = require(script.Parent.SceneryBuilder)

local WorldBuilder = {}

local WORLD_NAME = "RelicHeistWorld"

-- Removes stray duplicates of a post-processing effect so repeated calls never
-- stack effects on top of each other.
local function removeDuplicateEffects(className: string, keep: Instance)
	for _, child in Lighting:GetChildren() do
		if child:IsA(className) and child ~= keep then
			child:Destroy()
		end
	end
end

local function acquireColorCorrection(): ColorCorrectionEffect
	local effect = Lighting:FindFirstChildOfClass("ColorCorrectionEffect")
	if not effect then
		effect = Instance.new("ColorCorrectionEffect")
	end
	effect.Name = "GoldenHourColorCorrection"
	removeDuplicateEffects("ColorCorrectionEffect", effect)
	effect.Parent = Lighting
	return effect
end

local function acquireBloom(): BloomEffect
	local effect = Lighting:FindFirstChildOfClass("BloomEffect")
	if not effect then
		effect = Instance.new("BloomEffect")
	end
	effect.Name = "GoldenHourBloom"
	removeDuplicateEffects("BloomEffect", effect)
	effect.Parent = Lighting
	return effect
end

-- Restrained golden-hour grade: warm low sun, gentle colour grade, and a mild
-- bloom on the brightest highlights only.
local function configureLighting()
	Lighting.Ambient = Color3.fromRGB(92, 76, 58)
	Lighting.OutdoorAmbient = Color3.fromRGB(120, 98, 74)
	Lighting.Brightness = 2
	Lighting.ClockTime = 17.2
	Lighting.GeographicLatitude = 20
	Lighting.GlobalShadows = true
	Lighting.ShadowSoftness = 0.2
	Lighting.EnvironmentDiffuseScale = 0.5
	Lighting.EnvironmentSpecularScale = 0.25
	Lighting.FogEnd = 2200
	Lighting.FogStart = 200
	Lighting.ColorShift_Top = Color3.fromRGB(255, 224, 176)
	Lighting.ColorShift_Bottom = Color3.fromRGB(46, 36, 44)

	local atmosphere = Lighting:FindFirstChildOfClass("Atmosphere") or Instance.new("Atmosphere")
	atmosphere.Density = 0.28
	atmosphere.Offset = 0.1
	atmosphere.Color = Color3.fromRGB(224, 198, 158)
	atmosphere.Decay = Color3.fromRGB(126, 100, 78)
	atmosphere.Glare = 0
	atmosphere.Haze = 1.6
	atmosphere.Parent = Lighting

	local colorCorrection = acquireColorCorrection()
	colorCorrection.Enabled = true
	colorCorrection.Brightness = 0
	colorCorrection.Contrast = 0.06
	colorCorrection.Saturation = 0.06
	colorCorrection.TintColor = Color3.fromRGB(255, 246, 232)

	local bloom = acquireBloom()
	bloom.Enabled = true
	bloom.Intensity = 0.05
	bloom.Size = 24
	bloom.Threshold = 0.85
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

	-- Unified ground first, so every structure sits on one solid surface.
	GroundBuilder.Build(world)

	local hub = HubBuilder.Build(world, GameConfig.Temples)

	local temples = {}
	for templeId, config in GameConfig.Temples do
		temples[templeId] = TempleBuilder.Build(world, templeId, config)
	end

	-- Connecting avenues after both hub and temples exist so they land exactly on
	-- each portal and plot footprint.
	PathBuilder.Build(world, temples)

	-- Far-horizon scenery last: the treeline and the ridge ring are decorative
	-- and sit outside the playable area, so they never touch the world above.
	SceneryBuilder.Build(world)

	return {
		Folder = world,
		Hub = hub,
		Temples = temples,
	}
end

return WorldBuilder
