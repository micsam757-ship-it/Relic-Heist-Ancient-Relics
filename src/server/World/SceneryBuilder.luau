--!strict
-- Builds the decorative scenery that frames the play area: a belt of forest
-- that hugs the playable content, and a layered rocky escarpment that closes
-- the horizon just behind the trees.
--
-- Every part is decorative only. Nothing here collides, is queryable, is
-- touchable, or casts a shadow, so the horizon can never change a raycast, a
-- collision, or the lighting cost of the world. The geometry itself is decided
-- by the pure `SceneryLayout` module, which is unit tested.
--
-- The grove stands outside the playable area and the escarpment follows the
-- ground edge, so neither can reach the hub, the museum plots, the avenues or
-- the temples.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local BuilderUtil = require(script.Parent.BuilderUtil)
local GameConfig = require(ReplicatedStorage.Shared.Config.GameConfig)
local SceneryLayout = require(ReplicatedStorage.Shared.Domain.SceneryLayout)

local SceneryBuilder = {}

local BARK = Color3.fromRGB(92, 72, 52)
local LEAF = Color3.fromRGB(74, 96, 58)
local LEAF_DARK = Color3.fromRGB(58, 78, 48)
local ROCK_DARK = Color3.fromRGB(84, 78, 70)
local ROCK_MID = Color3.fromRGB(108, 100, 90)
local ROCK_LIGHT = Color3.fromRGB(132, 122, 108)
local ROCK_CREST = Color3.fromRGB(146, 136, 120)

-- Builds one tree: a trunk and a canopy, both decorative.
local function buildTree(model: Instance, tree: SceneryLayout.TreeDef)
	local base = CFrame.new(tree.x, 0, tree.z)

	BuilderUtil.decorative({
		Name = "SceneryTrunk",
		Size = Vector3.new(tree.trunkWidth, tree.trunkHeight, tree.trunkWidth),
		CFrame = base * CFrame.new(0, tree.trunkHeight / 2, 0),
		Color = BARK,
		Material = Enum.Material.Wood,
		Parent = model,
	})

	BuilderUtil.decorative({
		Name = "SceneryCanopy",
		Size = Vector3.new(tree.canopyWidth, tree.canopyHeight, tree.canopyDepth),
		CFrame = base
			* CFrame.new(0, tree.trunkHeight + (tree.canopyHeight / 2) - 3, 0)
			* CFrame.Angles(0, tree.yaw, 0),
		Color = if tree.index % 2 == 0 then LEAF else LEAF_DARK,
		Material = Enum.Material.Grass,
		Parent = model,
	})
end

-- Builds one rock block of the rim. The cliff blocks form the wall and the
-- crest blocks step back on top of them, so the wall reads as layered rock
-- instead of a single extruded ribbon.
local function buildEscarpmentBlock(model: Instance, segment: SceneryLayout.EscarpmentDef)
	local color = ROCK_MID
	if segment.layer == "crest" then
		color = ROCK_CREST
	elseif segment.index % 3 == 0 then
		color = ROCK_DARK
	elseif segment.index % 3 == 1 then
		color = ROCK_MID
	else
		color = ROCK_LIGHT
	end
	BuilderUtil.decorative({
		Name = if segment.layer == "crest" then "SceneryRockCrest" else "SceneryRock",
		Size = Vector3.new(segment.length, segment.height, segment.depth),
		CFrame = CFrame.new(segment.centerX, segment.baseY + (segment.height / 2), segment.centerZ)
			* CFrame.Angles(0, segment.yaw, 0),
		Color = color,
		Material = Enum.Material.Rock,
		Parent = model,
	})
end

function SceneryBuilder.Build(world: Instance): Instance
	local model = Instance.new("Model")
	model.Name = "Scenery"
	model.Parent = world

	-- The layout module reduces the configuration to plain numbers, so the
	-- builder and the test suite always agree on the horizon.
	local inputs = SceneryLayout.inputs(GameConfig)
	local trees = SceneryLayout.trees(inputs.grove, inputs.content, inputs.ground, inputs.regions, inputs.seed)
	local escarpment = SceneryLayout.escarpment(inputs.ground, inputs.escarpment, inputs.seed + 1)

	for _, tree in trees do
		buildTree(model, tree)
	end
	for _, segment in escarpment do
		buildEscarpmentBlock(model, segment)
	end

	model:SetAttribute("TreeCount", #trees)
	model:SetAttribute("EscarpmentSegmentCount", #escarpment)
	model:SetAttribute("PartCount", SceneryLayout.partCount(trees, escarpment))

	return model
end

return SceneryBuilder
