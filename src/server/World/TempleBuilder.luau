--!strict
-- Builds a configurable temple from data. Produces geometry, relic spawn
-- points, trap part references, and an extraction prompt for domain services.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local GameConfig = require(ReplicatedStorage.Shared.Config.GameConfig)
local BuilderUtil = require(script.Parent.BuilderUtil)

local TempleBuilder = {}

local THEMES: { [string]: any } = {
	sandstone = {
		floor = Color3.fromRGB(188, 164, 120),
		floorMaterial = Enum.Material.Sandstone,
		wall = Color3.fromRGB(166, 140, 98),
		wallMaterial = Enum.Material.Brick,
		pillar = Color3.fromRGB(178, 152, 108),
		pillarMaterial = Enum.Material.Sandstone,
		accent = Color3.fromRGB(232, 186, 86),
		light = Color3.fromRGB(255, 214, 150),
		ceiling = false,
	},
	catacomb = {
		floor = Color3.fromRGB(72, 72, 80),
		floorMaterial = Enum.Material.Slate,
		wall = Color3.fromRGB(56, 56, 64),
		wallMaterial = Enum.Material.Concrete,
		pillar = Color3.fromRGB(64, 64, 74),
		pillarMaterial = Enum.Material.Concrete,
		accent = Color3.fromRGB(78, 216, 214),
		light = Color3.fromRGB(120, 220, 220),
		ceiling = true,
	},
	sanctum = {
		floor = Color3.fromRGB(58, 88, 94),
		floorMaterial = Enum.Material.Slate,
		wall = Color3.fromRGB(46, 68, 78),
		wallMaterial = Enum.Material.Concrete,
		pillar = Color3.fromRGB(62, 98, 106),
		pillarMaterial = Enum.Material.Marble,
		accent = Color3.fromRGB(96, 226, 232),
		light = Color3.fromRGB(140, 232, 240),
		ceiling = true,
	},
}

local function offsetToWorld(origin: Vector3, offset: any): Vector3
	return origin + Vector3.new(offset.x or 0, offset.y or 0, offset.z or 0)
end

local function buildTorches(folder: Instance, origin: Vector3, hall: any, theme: any)
	local spacing = 30
	for z = 12, hall.length - 8, spacing do
		for side = -1, 1, 2 do
			local x = side * (hall.width / 2 - 1.5)
			local bracket = BuilderUtil.part({
				Name = "TorchBracket",
				Size = Vector3.new(0.6, 0.6, 1.2),
				CFrame = CFrame.new(origin + Vector3.new(x, 8, z)),
				Color = Color3.fromRGB(70, 58, 42),
				Material = Enum.Material.Metal,
				Parent = folder,
			})
			local flame = BuilderUtil.part({
				Name = "TorchFlame",
				Size = Vector3.new(0.9, 1.3, 0.9),
				CFrame = CFrame.new(origin + Vector3.new(x - side * 0.4, 8.8, z)),
				Color = theme.light,
				Material = Enum.Material.Neon,
				Transparency = 0.2,
				CanCollide = false,
				CanQuery = false,
				Parent = folder,
			})
			BuilderUtil.pointLight(flame, theme.light, 1.5, 20)
			bracket.CanQuery = false
		end
	end
end

local function buildDartTrap(folder: Instance, origin: Vector3, config: any, theme: any)
	local zone = config.zone
	local center = offsetToWorld(origin, config.position)
	local zonePart = BuilderUtil.part({
		Name = "DartZone",
		Size = Vector3.new(zone.x, zone.y, zone.z),
		CFrame = CFrame.new(center),
		Color = Color3.fromRGB(200, 70, 60),
		Material = Enum.Material.Neon,
		Transparency = 0.88,
		CanCollide = false,
		CanQuery = false,
		CanTouch = false,
		CastShadow = false,
		Parent = folder,
	})

	local emitters: { Part } = {}
	for side = -1, 1, 2 do
		local emitter = BuilderUtil.part({
			Name = "DartEmitter",
			Size = Vector3.new(1.4, 1.4, 1.4),
			CFrame = CFrame.new(center + Vector3.new(side * (zone.x / 2), 0, 0)),
			Color = Color3.fromRGB(120, 48, 44),
			Material = Enum.Material.Metal,
			CanCollide = false,
			Parent = folder,
		})
		BuilderUtil.pointLight(emitter, Color3.fromRGB(220, 70, 60), 0.4, 8)
		table.insert(emitters, emitter)
	end

	local beam = BuilderUtil.part({
		Name = "DartBeam",
		Size = Vector3.new(zone.x - 2, 1.6, 1.6),
		CFrame = CFrame.new(center),
		Color = Color3.fromRGB(255, 96, 80),
		Material = Enum.Material.Neon,
		Transparency = 1,
		CanCollide = false,
		CanQuery = false,
		CanTouch = false,
		CastShadow = false,
		Parent = folder,
	})

	BuilderUtil.billboard(beam, config.label .. " — DANGER ZONE", Color3.fromRGB(255, 150, 140), 240, 40, folder)

	return {
		kind = "dart",
		label = config.label,
		damage = config.damage,
		interval = config.interval,
		warning = config.warning,
		active = config.active,
		center = center,
		size = Vector3.new(zone.x, zone.y, zone.z),
		zonePart = zonePart,
		beam = beam,
		emitters = emitters,
		accent = theme.accent,
	}
end

local function buildBoulderTrap(folder: Instance, origin: Vector3, config: any, theme: any)
	local start = offsetToWorld(origin, config.startOffset)
	local finish = offsetToWorld(origin, config.endOffset)
	local ball = BuilderUtil.part({
		Name = "Boulder",
		Size = Vector3.new(config.radius * 2, config.radius * 2, config.radius * 2),
		CFrame = CFrame.new(start),
		Color = Color3.fromRGB(92, 84, 74),
		Material = Enum.Material.Rock,
		Shape = Enum.PartType.Ball,
		Transparency = 1,
		CanCollide = false,
		CanQuery = false,
		CanTouch = false,
		CastShadow = true,
		Parent = folder,
	})

	local length = (finish - start).Magnitude
	local midpoint = (start + finish) / 2
	BuilderUtil.part({
		Name = "BoulderGroove",
		Size = Vector3.new(config.radius * 1.6, 0.2, length),
		CFrame = CFrame.lookAt(
			Vector3.new(midpoint.X, origin.Y + 0.2, midpoint.Z),
			Vector3.new(finish.X, origin.Y + 0.2, finish.Z)
		),
		Color = theme.accent,
		Material = Enum.Material.Neon,
		Transparency = 0.6,
		CanCollide = false,
		CanQuery = false,
		CastShadow = false,
		Parent = folder,
	})

	local warningSign = BuilderUtil.part({
		Name = "BoulderSign",
		Size = Vector3.new(0.6, 4, 4),
		CFrame = CFrame.new(start + Vector3.new(8, 2, 0)),
		Color = Color3.fromRGB(120, 48, 44),
		Material = Enum.Material.Wood,
		CanCollide = false,
		Parent = folder,
	})
	BuilderUtil.billboard(warningSign, config.label .. " PATH", Color3.fromRGB(255, 160, 140), 200, 70, folder)

	return {
		kind = "boulder",
		label = config.label,
		damage = config.damage,
		interval = config.interval,
		warning = config.warning,
		travel = config.travel,
		radius = config.radius,
		start = start,
		finish = finish,
		model = ball,
	}
end

local function buildBladeTrap(folder: Instance, origin: Vector3, config: any, theme: any)
	local center = offsetToWorld(origin, config.position)

	local model = Instance.new("Model")
	model.Name = "Blade"
	model.Parent = folder

	BuilderUtil.part({
		Name = "BladeHub",
		Size = Vector3.new(2.6, 2.6, 2.6),
		CFrame = CFrame.new(center),
		Color = theme.pillar,
		Material = Enum.Material.Metal,
		CanCollide = false,
		CanQuery = false,
		CanTouch = false,
		Parent = model,
	})
	local hubLight = BuilderUtil.part({
		Name = "BladeHubLight",
		Size = Vector3.new(1.2, 1.2, 1.2),
		CFrame = CFrame.new(center),
		Color = Color3.fromRGB(255, 96, 80),
		Material = Enum.Material.Neon,
		Transparency = 0.25,
		CanCollide = false,
		CanQuery = false,
		CanTouch = false,
		Parent = model,
	})
	BuilderUtil.pointLight(hubLight, Color3.fromRGB(255, 96, 80), 0.8, 14)

	BuilderUtil.part({
		Name = "BladeBar",
		Size = Vector3.new(config.length, 0.6, 0.9),
		CFrame = CFrame.new(center),
		Color = Color3.fromRGB(186, 196, 210),
		Material = Enum.Material.Metal,
		CanCollide = false,
		CanQuery = false,
		CanTouch = false,
		CastShadow = false,
		Parent = model,
	})
	for side = -1, 1, 2 do
		BuilderUtil.part({
			Name = "BladeTip",
			Size = Vector3.new(1.6, 1.3, 1.6),
			CFrame = CFrame.new(center + Vector3.new(side * config.length / 2, 0, 0)),
			Color = Color3.fromRGB(255, 96, 80),
			Material = Enum.Material.Neon,
			Transparency = 0.15,
			CanCollide = false,
			CanQuery = false,
			CanTouch = false,
			CastShadow = false,
			Parent = model,
		})
	end

	BuilderUtil.billboard(hubLight, config.label .. " — KEEP MOVING", Color3.fromRGB(255, 150, 140), 240, 40, folder)

	return {
		kind = "blade",
		label = config.label,
		damage = config.damage,
		center = center,
		length = config.length,
		speed = config.speed,
		hitRadius = config.hitRadius,
		model = model,
	}
end

local function buildGuardian(folder: Instance, origin: Vector3, config: any)
	local kind = GameConfig.Enemies.Kinds[config.kind]
	local bodyColor = Color3.fromRGB(
		(config.bodyColor and config.bodyColor[1]) or kind.bodyColor[1],
		(config.bodyColor and config.bodyColor[2]) or kind.bodyColor[2],
		(config.bodyColor and config.bodyColor[3]) or kind.bodyColor[3]
	)
	local eyeColor = Color3.fromRGB(
		(config.eyeColor and config.eyeColor[1]) or kind.eyeColor[1],
		(config.eyeColor and config.eyeColor[2]) or kind.eyeColor[2],
		(config.eyeColor and config.eyeColor[3]) or kind.eyeColor[3]
	)

	local firstWaypoint = config.waypoints[1]
	local spawnPosition = offsetToWorld(origin, firstWaypoint)

	local model = Instance.new("Model")
	model.Name = "Guardian_" .. (config.label or kind.name)
	model.Parent = folder

	local root = BuilderUtil.part({
		Name = "HumanoidRootPart",
		Size = Vector3.new(2, 2, 1),
		CFrame = CFrame.new(spawnPosition + Vector3.new(0, 3, 0)),
		Color = bodyColor,
		Material = Enum.Material.Slate,
		Transparency = 1,
		Anchored = false,
		CanCollide = true,
		CanQuery = true,
		CanTouch = false,
		CastShadow = false,
		Parent = model,
	})

	local torso = BuilderUtil.part({
		Name = "Torso",
		Size = Vector3.new(3, 3.4, 1.8),
		CFrame = root.CFrame,
		Color = bodyColor,
		Material = Enum.Material.Slate,
		CanCollide = false,
		CanQuery = false,
		CanTouch = false,
		Parent = model,
	})
	torso.Massless = true

	local head = BuilderUtil.part({
		Name = "Head",
		Size = Vector3.new(1.8, 1.8, 1.8),
		CFrame = root.CFrame + Vector3.new(0, 3, 0),
		Color = bodyColor,
		Material = Enum.Material.Slate,
		CanCollide = false,
		CanQuery = false,
		CanTouch = false,
		Parent = model,
	})
	head.Massless = true

	local eye = BuilderUtil.part({
		Name = "Eye",
		Size = Vector3.new(1.4, 0.5, 0.3),
		CFrame = head.CFrame + Vector3.new(0, 0, -0.9),
		Color = eyeColor,
		Material = Enum.Material.Neon,
		CanCollide = false,
		CanQuery = false,
		CanTouch = false,
		CastShadow = false,
		Parent = model,
	})
	eye.Massless = true
	BuilderUtil.pointLight(eye, eyeColor, 0.8, 12)

	local leftArm = BuilderUtil.part({
		Name = "LeftArm",
		Size = Vector3.new(1.2, 3, 1.2),
		CFrame = root.CFrame + Vector3.new(-2.1, 0, 0),
		Color = bodyColor,
		Material = Enum.Material.Slate,
		CanCollide = false,
		CanQuery = false,
		CanTouch = false,
		Parent = model,
	})
	leftArm.Massless = true

	local rightArm = BuilderUtil.part({
		Name = "RightArm",
		Size = Vector3.new(1.2, 3, 1.2),
		CFrame = root.CFrame + Vector3.new(2.1, 0, 0),
		Color = bodyColor,
		Material = Enum.Material.Slate,
		CanCollide = false,
		CanQuery = false,
		CanTouch = false,
		Parent = model,
	})
	rightArm.Massless = true

	local function weld(part: BasePart)
		local weldConstraint = Instance.new("WeldConstraint")
		weldConstraint.Part0 = root
		weldConstraint.Part1 = part
		weldConstraint.Parent = part
	end
	weld(torso)
	weld(head)
	weld(eye)
	weld(leftArm)
	weld(rightArm)

	-- A custom rig moves through its HumanoidRootPart, so keep the standard
	-- (default) rig type. `AutoRotate` is left on so the Humanoid faces its
	-- MoveTo target for us; the state machine stays enabled so `MoveTo` actually
	-- drives the walk.
	local humanoid = Instance.new("Humanoid")
	humanoid.Name = "Humanoid"
	humanoid.WalkSpeed = (config.walkSpeed or kind.walkSpeed)
	humanoid.MaxHealth = kind.health
	humanoid.Health = kind.health
	humanoid.BreakJointsOnDeath = false
	humanoid.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
	humanoid.Parent = model

	model.PrimaryPart = root

	BuilderUtil.billboard(head, config.label or kind.name, eyeColor, 160, 30, folder)

	local waypoints = {}
	for _, waypoint in config.waypoints do
		table.insert(waypoints, offsetToWorld(origin, waypoint))
	end

	return {
		kind = config.kind,
		label = config.label or kind.name,
		model = model,
		humanoid = humanoid,
		root = root,
		head = head,
		eye = eye,
		waypoints = waypoints,
		damage = config.damage or kind.damage,
		walkSpeed = config.walkSpeed or kind.walkSpeed,
		aggroRange = config.aggroRange or kind.aggroRange,
		contactRange = config.contactRange or kind.contactRange,
		attackWindup = config.attackWindup or kind.attackWindup,
		eyeColor = eyeColor,
	}
end

function TempleBuilder.Build(world: Instance, templeId: string, config: any)
	local origin = Vector3.new(config.origin.x, config.origin.y, config.origin.z)
	local hall = config.hall
	local theme = THEMES[config.theme] or THEMES.sandstone

	local folder = Instance.new("Model")
	folder.Name = "Temple_" .. templeId
	folder.Parent = world

	BuilderUtil.part({
		Name = "Floor",
		Size = Vector3.new(hall.width, 1, hall.length),
		CFrame = CFrame.new(origin + Vector3.new(0, -0.5, hall.length / 2)),
		Color = theme.floor,
		Material = theme.floorMaterial,
		Parent = folder,
	})
	BuilderUtil.part({
		Name = "WallLeft",
		Size = Vector3.new(2, hall.height, hall.length),
		CFrame = CFrame.new(origin + Vector3.new(-hall.width / 2, hall.height / 2, hall.length / 2)),
		Color = theme.wall,
		Material = theme.wallMaterial,
		Parent = folder,
	})
	BuilderUtil.part({
		Name = "WallRight",
		Size = Vector3.new(2, hall.height, hall.length),
		CFrame = CFrame.new(origin + Vector3.new(hall.width / 2, hall.height / 2, hall.length / 2)),
		Color = theme.wall,
		Material = theme.wallMaterial,
		Parent = folder,
	})
	BuilderUtil.part({
		Name = "WallEnd",
		Size = Vector3.new(hall.width, hall.height, 2),
		CFrame = CFrame.new(origin + Vector3.new(0, hall.height / 2, hall.length)),
		Color = theme.wall,
		Material = theme.wallMaterial,
		Parent = folder,
	})
	BuilderUtil.part({
		Name = "WallBack",
		Size = Vector3.new(hall.width, hall.height, 2),
		CFrame = CFrame.new(origin + Vector3.new(0, hall.height / 2, -1)),
		Color = theme.wall,
		Material = theme.wallMaterial,
		Parent = folder,
	})

	if theme.ceiling then
		BuilderUtil.part({
			Name = "Ceiling",
			Size = Vector3.new(hall.width, 2, hall.length),
			CFrame = CFrame.new(origin + Vector3.new(0, hall.height, hall.length / 2)),
			Color = theme.wall,
			Material = theme.wallMaterial,
			Parent = folder,
		})
	else
		for z = 10, hall.length - 6, 25 do
			BuilderUtil.part({
				Name = "Rib",
				Size = Vector3.new(hall.width, 1.6, 2),
				CFrame = CFrame.new(origin + Vector3.new(0, hall.height - 1, z)),
				Color = theme.pillar,
				Material = theme.pillarMaterial,
				CanCollide = false,
				Parent = folder,
			})
		end
	end

	for z = 14, hall.length - 10, 24 do
		for side = -1, 1, 2 do
			local base = origin + Vector3.new(side * (hall.width / 2 - 4), 0, z)
			BuilderUtil.part({
				Name = "Pillar",
				Size = Vector3.new(3.2, hall.height - 2, 3.2),
				CFrame = CFrame.new(base + Vector3.new(0, (hall.height - 2) / 2, 0)),
				Color = theme.pillar,
				Material = theme.pillarMaterial,
				Parent = folder,
			})
			BuilderUtil.part({
				Name = "PillarBase",
				Size = Vector3.new(4.4, 1.2, 4.4),
				CFrame = CFrame.new(base + Vector3.new(0, 0.6, 0)),
				Color = theme.wall,
				Material = theme.pillarMaterial,
				Parent = folder,
			})
			BuilderUtil.part({
				Name = "PillarCapital",
				Size = Vector3.new(4.4, 1.2, 4.4),
				CFrame = CFrame.new(base + Vector3.new(0, hall.height - 1.4, 0)),
				Color = theme.wall,
				Material = theme.pillarMaterial,
				Parent = folder,
			})
		end
	end

	for _, obstacle in config.obstacles or {} do
		BuilderUtil.part({
			Name = "Obstacle",
			Size = Vector3.new(obstacle.size.x, obstacle.size.y, obstacle.size.z),
			CFrame = CFrame.new(offsetToWorld(origin, obstacle.position)),
			Color = theme.pillar,
			Material = theme.pillarMaterial,
			Parent = folder,
		})
	end

	buildTorches(folder, origin, hall, theme)

	local relicSpawns = {}
	for _, spawn in config.relicSpawns do
		local position = offsetToWorld(origin, spawn.position)
		BuilderUtil.part({
			Name = "Plinth",
			Size = Vector3.new(3, 1.6, 3),
			CFrame = CFrame.new(position + Vector3.new(0, -1.8, 0)),
			Color = theme.pillar,
			Material = theme.pillarMaterial,
			Parent = folder,
		})
		table.insert(relicSpawns, {
			definitionId = spawn.definitionId,
			position = position,
		})
	end

	local traps = {}
	for _, trapConfig in config.traps or {} do
		if trapConfig.kind == "dart" then
			table.insert(traps, buildDartTrap(folder, origin, trapConfig, theme))
		elseif trapConfig.kind == "boulder" then
			table.insert(traps, buildBoulderTrap(folder, origin, trapConfig, theme))
		elseif trapConfig.kind == "blade" then
			table.insert(traps, buildBladeTrap(folder, origin, trapConfig, theme))
		end
	end

	local guardians = {}
	for _, guardianConfig in config.guardians or {} do
		if guardianConfig.kind == "Guardian" then
			table.insert(guardians, buildGuardian(folder, origin, guardianConfig))
		end
	end

	local extractionPosition = offsetToWorld(origin, config.extractionOffset)
	BuilderUtil.part({
		Name = "ExtractionPad",
		Size = Vector3.new(2, 13, 13),
		CFrame = CFrame.new(extractionPosition + Vector3.new(0, 0.2, 0)) * CFrame.Angles(0, 0, math.rad(90)),
		Color = theme.accent,
		Material = Enum.Material.Neon,
		Transparency = 0.4,
		CanCollide = false,
		CanQuery = false,
		CastShadow = false,
		Parent = folder,
	})

	local promptPart = BuilderUtil.part({
		Name = "ExtractionPrompt",
		Size = Vector3.new(8, 8, 8),
		CFrame = CFrame.new(extractionPosition + Vector3.new(0, 3, 0)),
		Color = theme.accent,
		Transparency = 1,
		CanCollide = false,
		CanQuery = false,
		Parent = folder,
	})
	local prompt = Instance.new("ProximityPrompt")
	prompt.Name = "Extract"
	prompt.ActionText = "Escape With Relics"
	prompt.ObjectText = "Extraction Point"
	prompt.HoldDuration = 0.6
	prompt.MaxActivationDistance = 14
	prompt.RequiresLineOfSight = false
	prompt.Parent = promptPart
	BuilderUtil.billboard(promptPart, "ESCAPE", theme.accent, 200, 60, folder)

	local spawnPosition = offsetToWorld(origin, config.spawnOffset)
	local spawnCFrame = CFrame.lookAt(spawnPosition, spawnPosition + Vector3.new(0, 0, 12))

	-- Keep the accent color available for the hazard service.
	folder:SetAttribute("Accent", theme.accent)

	return {
		id = templeId,
		folder = folder,
		origin = origin,
		spawnCFrame = spawnCFrame,
		spawnPosition = spawnPosition,
		extraction = {
			prompt = prompt,
			position = extractionPosition,
			part = promptPart,
		},
		relicSpawns = relicSpawns,
		traps = traps,
		guardians = guardians,
		palette = theme,
	}
end

return TempleBuilder
