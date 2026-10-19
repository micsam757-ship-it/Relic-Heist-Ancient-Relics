--!strict
-- Procedural blockout relic models built from anchored Roblox parts.
-- These are intentionally temporary art assets, documented in docs/ASSETS.md.

local RelicVisuals = {}

local function color(triple: { number }): Color3
	return Color3.fromRGB(triple[1], triple[2], triple[3])
end

local function part(props: {
	Size: Vector3,
	CFrame: CFrame?,
	Color: Color3,
	Material: Enum.Material?,
	Transparency: number?,
	Shape: Enum.PartType?,
}): Part
	local instance = Instance.new("Part")
	instance.Anchored = true
	instance.CanCollide = false
	instance.CanQuery = false
	instance.CanTouch = false
	instance.CastShadow = false
	instance.Size = props.Size
	instance.CFrame = props.CFrame or CFrame.new()
	instance.Color = props.Color
	instance.Material = props.Material or Enum.Material.SmoothPlastic
	instance.Transparency = props.Transparency or 0
	instance.TopSurface = Enum.SurfaceType.Smooth
	instance.BottomSurface = Enum.SurfaceType.Smooth
	if props.Shape then
		instance.Shape = props.Shape
	end
	return instance
end

local function wedge(props: { Size: Vector3, CFrame: CFrame, Color: Color3, Material: Enum.Material? }): WedgePart
	local instance = Instance.new("WedgePart")
	instance.Anchored = true
	instance.CanCollide = false
	instance.CanQuery = false
	instance.CanTouch = false
	instance.CastShadow = false
	instance.Size = props.Size
	instance.CFrame = props.CFrame
	instance.Color = props.Color
	instance.Material = props.Material or Enum.Material.SmoothPlastic
	instance.TopSurface = Enum.SurfaceType.Smooth
	instance.BottomSurface = Enum.SurfaceType.Smooth
	return instance
end

local builders: { [string]: (definition: any) -> Model } = {}

builders.scarab = function(definition)
	local model = Instance.new("Model")
	model.Name = definition.name
	local primary = color(definition.visual.primary)
	local secondary = color(definition.visual.secondary)
	local body = part({
		Size = Vector3.new(2.4, 1, 3.6),
		CFrame = CFrame.new(0, 0, 0),
		Color = primary,
		Shape = Enum.PartType.Ball,
	})
	body.Name = "Body"
	body.Parent = model
	model.PrimaryPart = body

	local head = part({
		Size = Vector3.new(1.2, 0.8, 1),
		CFrame = CFrame.new(0, 0.2, 1.9),
		Color = secondary,
		Shape = Enum.PartType.Ball,
	})
	head.Parent = model

	for side = -1, 1, 2 do
		local wing = wedge({
			Size = Vector3.new(1.6, 0.35, 2.8),
			CFrame = CFrame.new(side * 1.3, 0.3, 0) * CFrame.Angles(0, 0, side * math.rad(-18)),
			Color = primary,
		})
		wing.Parent = model
		for leg = 0, 2 do
			local legPart = part({
				Size = Vector3.new(0.18, 0.16, 1.4),
				CFrame = CFrame.new(side * 1.1, -0.35, -1 + leg * 0.9) * CFrame.Angles(0, side * math.rad(25), 0),
				Color = secondary,
			})
			legPart.Parent = model
		end
	end
	return model
end

builders.ankh = function(definition)
	local model = Instance.new("Model")
	model.Name = definition.name
	local primary = color(definition.visual.primary)
	local secondary = color(definition.visual.secondary)

	local vertical = part({ Size = Vector3.new(0.55, 3.6, 0.55), CFrame = CFrame.new(0, -0.4, 0), Color = primary })
	vertical.Name = "Stem"
	vertical.Parent = model
	model.PrimaryPart = vertical

	part({ Size = Vector3.new(2.2, 0.5, 0.55), CFrame = CFrame.new(0, 0.6, 0), Color = secondary }).Parent = model
	for index = 0, 9 do
		local angle = math.rad(index * 36)
		local loop = part({
			Size = Vector3.new(0.32, 0.62, 0.36),
			CFrame = CFrame.new(0, 1.9, 0)
				* CFrame.Angles(0, 0, angle)
				* CFrame.new(0.72, 0, 0)
				* CFrame.Angles(0, 0, -angle),
			Color = primary,
		})
		loop.Parent = model
	end
	return model
end

builders.idol = function(definition)
	local model = Instance.new("Model")
	model.Name = definition.name
	local primary = color(definition.visual.primary)
	local secondary = color(definition.visual.secondary)

	local base = part({ Size = Vector3.new(2.6, 0.5, 2.2), CFrame = CFrame.new(0, -1.7, 0), Color = secondary })
	base.Name = "Base"
	base.Parent = model
	model.PrimaryPart = base
	local body = part({ Size = Vector3.new(1.9, 2.4, 1.5), CFrame = CFrame.new(0, -0.1, 0), Color = primary })
	body.Parent = model
	local head = part({
		Size = Vector3.new(1.2, 1.1, 1.1),
		CFrame = CFrame.new(0, 1.6, 0),
		Color = primary,
		Shape = Enum.PartType.Ball,
	})
	head.Parent = model
	for side = -1, 1, 2 do
		part({
			Size = Vector3.new(0.5, 1.6, 0.6),
			CFrame = CFrame.new(side * 1.2, -0.1, 0) * CFrame.Angles(0, 0, side * math.rad(8)),
			Color = secondary,
		}).Parent =
			model
	end
	local eyes = part({
		Size = Vector3.new(0.9, 0.16, 0.2),
		CFrame = CFrame.new(0, 1.7, 0.54),
		Color = Color3.fromRGB(255, 209, 102),
		Material = Enum.Material.Neon,
	})
	eyes.Parent = model
	return model
end

builders.mask = function(definition)
	local model = Instance.new("Model")
	model.Name = definition.name
	local primary = color(definition.visual.primary)
	local secondary = color(definition.visual.secondary)

	local face = part({
		Size = Vector3.new(2.4, 3, 1),
		CFrame = CFrame.new(0, 0, 0),
		Color = primary,
		Shape = Enum.PartType.Ball,
	})
	face.Name = "Face"
	face.Parent = model
	model.PrimaryPart = face
	local jaw = part({ Size = Vector3.new(1.4, 1, 0.9), CFrame = CFrame.new(0, -1.5, 0.1), Color = secondary })
	jaw.Parent = model
	for side = -1, 1, 2 do
		part({
			Size = Vector3.new(0.5, 0.3, 0.3),
			CFrame = CFrame.new(side * 0.55, 0.35, 0.48),
			Color = Color3.fromRGB(80, 220, 220),
			Material = Enum.Material.Neon,
		}).Parent =
			model
	end
	local crest = part({
		Size = Vector3.new(0.5, 1.8, 0.4),
		CFrame = CFrame.new(0, 1.9, -0.1) * CFrame.Angles(0, 0, math.rad(12)),
		Color = secondary,
	})
	crest.Parent = model
	return model
end

builders.urn = function(definition)
	local model = Instance.new("Model")
	model.Name = definition.name
	local primary = color(definition.visual.primary)
	local secondary = color(definition.visual.secondary)

	local body = part({
		Size = Vector3.new(2.2, 2.8, 2.2),
		CFrame = CFrame.new(0, 0, 0),
		Color = primary,
		Shape = Enum.PartType.Ball,
	})
	body.Name = "Body"
	body.Parent = model
	model.PrimaryPart = body
	local neck = part({
		Size = Vector3.new(1, 1.1, 1),
		CFrame = CFrame.new(0, 1.8, 0),
		Color = primary,
		Shape = Enum.PartType.Cylinder,
	})
	neck.Orientation = Vector3.new(0, 0, 90)
	neck.Parent = model
	for side = -1, 1, 2 do
		local handle = part({
			Size = Vector3.new(0.25, 1.6, 0.25),
			CFrame = CFrame.new(side * 1.4, 0.6, 0) * CFrame.Angles(0, 0, side * math.rad(35)),
			Color = secondary,
		})
		handle.Parent = model
	end
	local band = part({
		Size = Vector3.new(2.32, 0.18, 2.32),
		CFrame = CFrame.new(0, 0.35, 0),
		Color = Color3.fromRGB(90, 224, 214),
		Material = Enum.Material.Neon,
	})
	band.Parent = model
	return model
end

builders.jackal = function(definition)
	local model = Instance.new("Model")
	model.Name = definition.name
	local primary = color(definition.visual.primary)
	local secondary = color(definition.visual.secondary)

	local base = part({ Size = Vector3.new(2.4, 0.5, 2), CFrame = CFrame.new(0, -2, 0), Color = secondary })
	base.Name = "Base"
	base.Parent = model
	model.PrimaryPart = base
	local body = part({ Size = Vector3.new(1.5, 1.6, 1.8), CFrame = CFrame.new(0, -0.9, 0), Color = primary })
	body.Parent = model
	local head = part({ Size = Vector3.new(1.1, 1.1, 1.3), CFrame = CFrame.new(0, 0.6, 0.35), Color = primary })
	head.Parent = model
	for side = -1, 1, 2 do
		local ear = wedge({
			Size = Vector3.new(0.3, 1.2, 0.5),
			CFrame = CFrame.new(side * 0.35, 1.45, 0.25) * CFrame.Angles(0, 0, side * math.rad(-10)),
			Color = secondary,
		})
		ear.Parent = model
		part({
			Size = Vector3.new(0.24, 0.18, 0.24),
			CFrame = CFrame.new(side * 0.3, 0.7, 0.98),
			Color = Color3.fromRGB(255, 198, 84),
			Material = Enum.Material.Neon,
		}).Parent =
			model
	end
	local collar = part({
		Size = Vector3.new(1.7, 0.24, 1.7),
		CFrame = CFrame.new(0, 0.05, 0),
		Color = Color3.fromRGB(220, 174, 64),
		Material = Enum.Material.Metal,
	})
	collar.Parent = model
	return model
end

builders.crystal = function(definition)
	local model = Instance.new("Model")
	model.Name = definition.name
	local primary = color(definition.visual.primary)
	local secondary = color(definition.visual.secondary)

	local core = part({
		Size = Vector3.new(1.1, 3.2, 1.1),
		CFrame = CFrame.new(0, 0, 0) * CFrame.Angles(0, math.rad(45), 0),
		Color = primary,
		Material = Enum.Material.Neon,
	})
	core.Name = "Core"
	core.Parent = model
	model.PrimaryPart = core
	for index, config in
		{
			{ x = 1.1, y = -0.5, z = 0.2, tilt = 22, scale = 0.6 },
			{ x = -1, y = 0.4, z = -0.3, tilt = -28, scale = 0.5 },
			{ x = 0.2, y = 1.1, z = -0.8, tilt = 35, scale = 0.35 },
			{ x = -0.4, y = -1.1, z = 0.8, tilt = -18, scale = 0.4 },
		}
	do
		local shard = part({
			Size = Vector3.new(0.5, 2, 0.5) * config.scale,
			CFrame = CFrame.new(config.x, config.y, config.z)
				* CFrame.Angles(math.rad(config.tilt), 0, math.rad(index * 8)),
			Color = primary,
			Material = Enum.Material.Neon,
			Transparency = 0.25,
		})
		shard.Parent = model
	end
	local base = part({
		Size = Vector3.new(2.4, 0.4, 2.4),
		CFrame = CFrame.new(0, -2.1, 0),
		Color = secondary,
		Shape = Enum.PartType.Cylinder,
	})
	base.Orientation = Vector3.new(0, 0, 90)
	base.Parent = model
	return model
end

builders.core = function(definition)
	local model = Instance.new("Model")
	model.Name = definition.name
	local primary = color(definition.visual.primary)
	local secondary = color(definition.visual.secondary)

	local core = part({
		Size = Vector3.new(2.6, 2.6, 2.6),
		CFrame = CFrame.new(0, 0.4, 0),
		Color = primary,
		Material = Enum.Material.Neon,
		Shape = Enum.PartType.Ball,
	})
	core.Name = "Core"
	core.Parent = model
	model.PrimaryPart = core
	for index = 0, 2 do
		local ring = part({
			Size = Vector3.new(0.35, 4.6 + index * 0.5, 4.6 + index * 0.5),
			CFrame = CFrame.new(0, 0.4, 0) * CFrame.Angles(math.rad(index * 60), math.rad(index * 45), 0),
			Color = secondary,
			Material = Enum.Material.Metal,
			Shape = Enum.PartType.Cylinder,
		})
		ring.Orientation = Vector3.new(0, 0, 90)
		ring.Parent = model
	end
	for index = 0, 5 do
		local angle = math.rad(index * 60)
		local shard = part({
			Size = Vector3.new(0.35, 1.2, 0.35),
			CFrame = CFrame.new(math.cos(angle) * 3, 0.4, math.sin(angle) * 3)
				* CFrame.Angles(math.rad(index * 17), angle, 0),
			Color = primary,
			Material = Enum.Material.Neon,
			Transparency = 0.1,
		})
		shard.Parent = model
	end
	return model
end

function RelicVisuals.build(definition: any): Model
	local builder = builders[definition.visual.kind]
	if builder == nil then
		builder = builders.idol
	end
	local model = builder(definition)
	model:SetAttribute("DefinitionId", definition.name)

	if definition.visual.glow then
		local light = Instance.new("PointLight")
		light.Color = color(definition.visual.primary)
		light.Brightness = 1.6
		light.Range = 9
		light.Shadows = false
		light.Parent = model.PrimaryPart
	end

	model:SetAttribute("Rarity", definition.rarity)
	return model
end

function RelicVisuals.place(model: Model, cframe: CFrame)
	model:PivotTo(cframe)
end

return RelicVisuals
