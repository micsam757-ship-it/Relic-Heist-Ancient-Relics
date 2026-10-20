--!strict
-- Builds the grand stone/marble avenues that physically link the central hub to
-- every museum plot and every temple portal, so no structure is left floating on
-- a disconnected platform. Each avenue is a raised, bordered causeway with a
-- central runner, flanking balustrades and evenly spaced lantern posts.
--
-- Paths are built in world space (they do not belong to a single owner) and sit
-- flush with the unified ground top and the hub plaza top.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local GameConfig = require(ReplicatedStorage.Shared.Config.GameConfig)
local BuilderUtil = require(script.Parent.BuilderUtil)

local PathBuilder = {}

local MARBLE = Color3.fromRGB(226, 222, 212)
local MARBLE_DARK = Color3.fromRGB(176, 170, 158)
local MARBLE_TRIM = Color3.fromRGB(198, 192, 180)
local GOLD = Color3.fromRGB(224, 178, 74)
local STONE_POST = Color3.fromRGB(150, 138, 118)

local AVENUE_WIDTH = GameConfig.World.AvenueWidth
local AVENUE_TOP = GameConfig.World.AvenueTop
local RING_RADIUS = GameConfig.World.RingRadius
local START_ANGLE = GameConfig.World.StartAngleDegrees
local MAX_PLOTS = GameConfig.World.MaxPlots

-- Builds a single straight avenue from `from` to `to` (XZ positions at ground
-- level). The deck, inlay, balustrades and lantern posts are laid along the run.
local function buildAvenue(model: Instance, from: Vector3, to: Vector3, width: number)
	local delta = Vector3.new(to.X - from.X, 0, to.Z - from.Z)
	local length = delta.Magnitude
	if length < 1 then
		return
	end
	local mid = Vector3.new((from.X + to.X) / 2, AVENUE_TOP, (from.Z + to.Z) / 2)
	local direction = delta.Unit
	local yaw = math.atan2(-direction.X, -direction.Z)
	local cframe = CFrame.new(mid) * CFrame.Angles(0, yaw, 0)

	-- Deck: raised marble causeway.
	BuilderUtil.part({
		Name = "AvenueDeck",
		Size = Vector3.new(width, 1, length),
		CFrame = cframe * CFrame.new(0, -0.5, 0),
		Color = MARBLE,
		Material = Enum.Material.Marble,
		Parent = model,
	})
	-- Border inlay: a slightly darker marble frame just above the deck.
	BuilderUtil.part({
		Name = "AvenueBorder",
		Size = Vector3.new(width - 4, 0.2, length - 2),
		CFrame = cframe * CFrame.new(0, 0.1, 0),
		Color = MARBLE_DARK,
		Material = Enum.Material.Marble,
		CanCollide = false,
		CanQuery = false,
		CastShadow = false,
		Parent = model,
	})
	-- Central runner: a bright polished strip down the middle.
	BuilderUtil.part({
		Name = "AvenueRunner",
		Size = Vector3.new(width - 8, 0.2, length - 6),
		CFrame = cframe * CFrame.new(0, 0.16, 0),
		Color = MARBLE,
		Material = Enum.Material.Marble,
		CanCollide = false,
		CanQuery = false,
		CastShadow = false,
		Parent = model,
	})

	-- Balustrades: low rails running the length of both sides.
	for side = -1, 1, 2 do
		BuilderUtil.part({
			Name = "AvenueRail",
			Size = Vector3.new(1.4, 2.6, length - 2),
			CFrame = cframe * CFrame.new(side * (width / 2 - 0.7), 1.3, 0),
			Color = MARBLE_TRIM,
			Material = Enum.Material.Marble,
			CanCollide = false,
			Parent = model,
		})
		BuilderUtil.part({
			Name = "AvenueRailCap",
			Size = Vector3.new(2, 0.5, length - 2),
			CFrame = cframe * CFrame.new(side * (width / 2 - 0.7), 2.85, 0),
			Color = MARBLE,
			Material = Enum.Material.Marble,
			CanCollide = false,
			CastShadow = false,
			Parent = model,
		})
	end

	-- Lantern posts spaced along both sides.
	local postSpacing = 40
	local count = math.max(1, math.floor(length / postSpacing))
	for index = 0, count do
		local along = -length / 2 + (index / math.max(1, count)) * length
		if math.abs(along) < length / 2 - 4 then
			for side = -1, 1, 2 do
				local post = BuilderUtil.part({
					Name = "AvenuePost",
					Size = Vector3.new(1.4, 7, 1.4),
					CFrame = cframe * CFrame.new(side * (width / 2 - 0.7), 3.5, along),
					Color = STONE_POST,
					Material = Enum.Material.Marble,
					CanCollide = false,
					Parent = model,
				})
				local lantern = BuilderUtil.part({
					Name = "AvenueLantern",
					Size = Vector3.new(1.6, 1.6, 1.6),
					CFrame = post.CFrame * CFrame.new(0, 4.2, 0),
					Color = GOLD,
					Material = Enum.Material.Neon,
					Transparency = 0.15,
					CanCollide = false,
					CanQuery = false,
					CastShadow = false,
					Parent = model,
				})
				BuilderUtil.pointLight(lantern, GOLD, 1, 18)
			end
		end
	end
end

-- Builds the processional approach that links the hub to the temple district.
-- The temples share the +Z corridor, so a single grand approach avenue runs from
-- the hub rim to the district entrance (just before the first temple's front),
-- where a cross-court spreads the approach across the district. This keeps the
-- hub visually and physically linked to the temples without an avenue cutting
-- through any temple hall.
local function buildTempleAvenues(model: Instance, temples: { [string]: any })
	local ordered: { any } = {}
	for _, temple in temples do
		table.insert(ordered, temple)
	end
	table.sort(ordered, function(a, b)
		return a.origin.Z < b.origin.Z
	end)

	local hubEdgeZ = GameConfig.World.Hub.PlazaRadius
	local firstFrontZ = ordered[1] and ordered[1].origin.Z or (hubEdgeZ + 120)
	local approachEndZ = firstFrontZ - 40

	-- Central approach avenue from the hub rim to the district entrance.
	buildAvenue(model, Vector3.new(0, 0, hubEdgeZ), Vector3.new(0, 0, approachEndZ), AVENUE_WIDTH + 6)

	-- Cross-court at the district entrance so the approach fans across the
	-- temple district.
	if #ordered > 1 then
		buildAvenue(model, Vector3.new(-60, 0, approachEndZ), Vector3.new(60, 0, approachEndZ), AVENUE_WIDTH)
	end
end

-- Builds a causeway from the hub ring out to every museum plot footprint. The
-- avenue stops at the plot's inner apron edge so it meets the building cleanly
-- with no unused gap between the path and the plot.
local function buildPlotAvenues(model: Instance, hubRadius: number)
	local step = 360 / MAX_PLOTS
	-- The plot is placed with its centre on the ring; its ground apron reaches
	-- inward toward the hub by roughly the wing depth. Stop the bridge a few
	-- studs onto that apron edge so the avenue meets the building flush — no
	-- overhang past the plot and no dead gap before it.
	local apronInwardReach = 122
	local innerStop = RING_RADIUS - apronInwardReach
	for index = 0, MAX_PLOTS - 1 do
		local angle = math.rad(START_ANGLE + index * step)
		local direction = Vector3.new(math.cos(angle), 0, math.sin(angle))
		local from = direction * hubRadius
		local to = direction * innerStop
		buildAvenue(model, from, to, AVENUE_WIDTH)
	end
end

function PathBuilder.Build(world: Instance, temples: { [string]: any }): Instance
	local model = Instance.new("Model")
	model.Name = "Avenues"
	model.Parent = world

	buildPlotAvenues(model, GameConfig.World.Hub.PlazaRadius)
	buildTempleAvenues(model, temples)

	return model
end

return PathBuilder
