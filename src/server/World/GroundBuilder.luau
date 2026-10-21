--!strict
-- Builds the unified world ground so no structure floats on a disconnected
-- platform. One large solid stone base sits beneath the hub, every museum plot
-- and every temple, with decorative borders and a subtle inlay grid so the
-- expanse still reads as a finished plaza rather than an empty slab.
--
-- The footprint is a rounded rectangle: four straight sides joined by quarter
-- circle corners, so the world edge reads as a carved plateau rather than a
-- square slab. The shape is described in `GameConfig.World.Ground` and the
-- geometry itself comes from the pure `SceneryLayout` module, so the outline
-- the ground uses and the outline the scenery hugs are the same one.
--
-- The ground top is flush with the hub plaza top (y = 0) so the hub, avenues,
-- plots and temple floors all sit on one continuous surface.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local BuilderUtil = require(script.Parent.BuilderUtil)
local GameConfig = require(ReplicatedStorage.Shared.Config.GameConfig)
local SceneryLayout = require(ReplicatedStorage.Shared.Domain.SceneryLayout)

local GroundBuilder = {}

local STONE = Color3.fromRGB(120, 108, 92)
local STONE_LIGHT = Color3.fromRGB(150, 138, 118)
local STONE_DARK = Color3.fromRGB(74, 66, 54)

-- The corner discs are quarter circles that reach under the straight side
-- pieces, so their top faces would share a plane with them. Dropping them by
-- a hair keeps the two surfaces from fighting for the depth buffer; the step
-- is far too small to see.
local DISC_SINK = 0.02

-- The visible surface layer does not collide, so the solid base below is the
-- floor the player stands on. It is dropped by a hair under the visible
-- surface, otherwise the player would stand a full surface thickness sunken
-- into the ground they can see.
local FLOOR_DROP = 0.05

local function groundShape(): SceneryLayout.RoundedRect
	local ground = GameConfig.World.Ground
	return {
		minX = ground.MinX,
		maxX = ground.MaxX,
		minZ = ground.MinZ,
		maxZ = ground.MaxZ,
		cornerRadius = ground.CornerRadius,
	}
end

-- Builds one layer of the footprint: a central slab, four side slabs and four
-- corner discs, which together form the rounded rectangle.
local function addRoundedLayer(
	model: Instance,
	shape: SceneryLayout.RoundedRect,
	thickness: number,
	topY: number,
	color: Color3,
	material: Enum.Material,
	collidable: boolean,
	discSink: number
)
	local centre = SceneryLayout.centre(shape)
	local halfX, halfZ = SceneryLayout.halfExtents(shape)
	local radius = SceneryLayout.radius(shape)
	local innerX = halfX - radius
	local innerZ = halfZ - radius

	local function slab(name: string, sizeX: number, sizeZ: number, offsetX: number, offsetZ: number)
		BuilderUtil.part({
			Name = name,
			Size = Vector3.new(sizeX, thickness, sizeZ),
			CFrame = CFrame.new(centre.x + offsetX, topY - (thickness / 2), centre.z + offsetZ),
			Color = color,
			Material = material,
			Anchored = true,
			CanCollide = collidable,
			CanQuery = collidable,
			CastShadow = collidable,
			Parent = model,
		})
	end

	local function disc(name: string, offsetX: number, offsetZ: number)
		BuilderUtil.part({
			Name = name,
			Size = Vector3.new(thickness, radius * 2, radius * 2),
			-- A cylinder is built around its local X axis, so the part is turned
			-- upright to lie flat on the ground.
			CFrame = CFrame.new(centre.x + offsetX, topY - discSink - (thickness / 2), centre.z + offsetZ)
				* CFrame.Angles(0, 0, math.rad(90)),
			Color = color,
			Material = material,
			Anchored = true,
			CanCollide = collidable,
			CanQuery = collidable,
			CastShadow = collidable,
			Shape = Enum.PartType.Cylinder,
			Parent = model,
		})
	end

	slab("WorldGround", innerX * 2, innerZ * 2, 0, 0)
	slab("WorldGroundEdgeEast", radius, innerZ * 2, innerX + (radius / 2), 0)
	slab("WorldGroundEdgeWest", radius, innerZ * 2, -(innerX + (radius / 2)), 0)
	slab("WorldGroundEdgeNorth", innerX * 2, radius, 0, innerZ + (radius / 2))
	slab("WorldGroundEdgeSouth", innerX * 2, radius, 0, -(innerZ + (radius / 2)))
	disc("WorldGroundCornerNorthEast", innerX, innerZ)
	disc("WorldGroundCornerNorthWest", -innerX, innerZ)
	disc("WorldGroundCornerSouthWest", -innerX, -innerZ)
	disc("WorldGroundCornerSouthEast", innerX, -innerZ)
end

function GroundBuilder.Build(world: Instance): Instance
	local model = Instance.new("Model")
	model.Name = "Ground"
	model.Parent = world

	local ground = GameConfig.World.Ground
	local shape = groundShape()
	local centre = SceneryLayout.centre(shape)
	local halfX, halfZ = SceneryLayout.halfExtents(shape)
	local groundTop = GameConfig.World.GroundTop

	-- Solid base slab. Anchored and collidable so nothing floats over a void.
	-- Its top sits just under the visible surface, so the player never stands
	-- below the ground they can see.
	local baseTop = groundTop - FLOOR_DROP
	addRoundedLayer(model, shape, ground.BaseThickness, baseTop, STONE, Enum.Material.Ground, true, 0)

	-- A lighter top surface so the plaza reading is clean and to hide the
	-- darker base seam. It does not collide: the base below is the floor.
	addRoundedLayer(
		model,
		shape,
		ground.SurfaceThickness,
		groundTop,
		STONE_LIGHT,
		Enum.Material.Slate,
		false,
		DISC_SINK
	)

	-- Inlaid grid lines: sparse long strips that give scale to the expanse
	-- without flooding the part count. Each strip is clipped to the footprint
	-- so no inlay hangs over the edge, and it stands a hair proud of the
	-- surface so it reads as inlay rather than z-fighting with the ground.
	local step = ground.GridStep
	for coordinate = shape.minX + step, shape.maxX - step, step do
		local extent = SceneryLayout.extentAt(shape, "z", coordinate)
		BuilderUtil.part({
			Name = "GridLineX",
			Size = Vector3.new(1.5, 0.1, extent * 2),
			CFrame = CFrame.new(coordinate, groundTop, centre.z),
			Color = STONE_DARK,
			Material = Enum.Material.Slate,
			CanCollide = false,
			CanQuery = false,
			CastShadow = false,
			Transparency = 0.35,
			Parent = model,
		})
	end
	for coordinate = shape.minZ + step, shape.maxZ - step, step do
		local extent = SceneryLayout.extentAt(shape, "x", coordinate)
		BuilderUtil.part({
			Name = "GridLineZ",
			Size = Vector3.new(extent * 2, 0.1, 1.5),
			CFrame = CFrame.new(centre.x, groundTop, coordinate),
			Color = STONE_DARK,
			Material = Enum.Material.Slate,
			CanCollide = false,
			CanQuery = false,
			CastShadow = false,
			Transparency = 0.35,
			Parent = model,
		})
	end

	model:SetAttribute("GroundTop", groundTop)
	model:SetAttribute("FootprintWidth", halfX * 2)
	model:SetAttribute("FootprintDepth", halfZ * 2)
	model:SetAttribute("CornerRadius", SceneryLayout.radius(shape))
	return model
end

return GroundBuilder
