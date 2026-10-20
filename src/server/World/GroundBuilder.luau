--!strict
-- Builds the unified world ground so no structure floats on a disconnected
-- platform. One large solid stone base sits beneath the hub, every museum plot
-- and every temple, with decorative borders and a subtle inlay grid so the
-- expanse still reads as a finished plaza rather than an empty slab.
--
-- The ground top is flush with the hub plaza top (y = 2) so the hub, avenues,
-- plots and temple floors all sit on one continuous surface.

local BuilderUtil = require(script.Parent.BuilderUtil)
local GameConfig = require(game:GetService("ReplicatedStorage").Shared.Config.GameConfig)

local GroundBuilder = {}

-- Half-extent of the solid ground base. Temples run to z = 1130 + 260 = 1390;
-- museum plots sit on a 380-stud ring. 1800 half-extent covers everything with
-- margin while staying a single part.
local GROUND_HALF = 1800
local GROUND_TOP = GameConfig.World.GroundTop

local STONE = Color3.fromRGB(120, 108, 92)
local STONE_LIGHT = Color3.fromRGB(150, 138, 118)
local STONE_DARK = Color3.fromRGB(74, 66, 54)

function GroundBuilder.Build(world: Instance): Instance
	local model = Instance.new("Model")
	model.Name = "Ground"
	model.Parent = world

	local size = GROUND_HALF * 2

	-- Solid base slab. Anchored and collidable so nothing floats over a void.
	BuilderUtil.part({
		Name = "WorldGround",
		Size = Vector3.new(size, 4, size),
		CFrame = CFrame.new(0, GROUND_TOP - 2, 0),
		Color = STONE,
		Material = Enum.Material.Ground,
		Anchored = true,
		CanCollide = true,
		Parent = model,
	})

	-- A single large top surface in lighter stone so the plaza reading is clean
	-- and to hide the darker base seam.
	BuilderUtil.part({
		Name = "WorldGroundSurface",
		Size = Vector3.new(size, 0.4, size),
		CFrame = CFrame.new(0, GROUND_TOP - 0.2, 0),
		Color = STONE_LIGHT,
		Material = Enum.Material.Slate,
		CanCollide = false,
		CanQuery = false,
		CastShadow = false,
		Parent = model,
	})

	-- Inlaid grid lines: sparse long strips that give scale to the expanse
	-- without flooding the part count.
	local step = 200
	for coordinate = -GROUND_HALF + step, GROUND_HALF - step, step do
		BuilderUtil.part({
			Name = "GridLineX",
			Size = Vector3.new(1.5, 0.2, size),
			CFrame = CFrame.new(coordinate, GROUND_TOP + 0.05, 0),
			Color = STONE_DARK,
			Material = Enum.Material.Slate,
			CanCollide = false,
			CanQuery = false,
			CastShadow = false,
			Transparency = 0.35,
			Parent = model,
		})
		BuilderUtil.part({
			Name = "GridLineZ",
			Size = Vector3.new(size, 0.2, 1.5),
			CFrame = CFrame.new(0, GROUND_TOP + 0.05, coordinate),
			Color = STONE_DARK,
			Material = Enum.Material.Slate,
			CanCollide = false,
			CanQuery = false,
			CastShadow = false,
			Transparency = 0.35,
			Parent = model,
		})
	end

	model:SetAttribute("GroundTop", GROUND_TOP)
	return model
end

return GroundBuilder
