--!strict
-- Builds the central hub: spawn plaza, expedition portals, shop kiosk,
-- and museum ledger terminal. All geometry is blockout placeholder art.

local BuilderUtil = require(script.Parent.BuilderUtil)
local TempleBuilder = require(script.Parent.TempleBuilder)

local HubBuilder = {}

local STONE = Color3.fromRGB(150, 132, 104)
local STONE_DARK = Color3.fromRGB(96, 82, 62)
local GOLD = Color3.fromRGB(224, 178, 74)
local CYAN = Color3.fromRGB(74, 214, 220)
-- Marble palette shared with the museum + avenues so the hub, portals and
-- connecting structures read as one continuous built environment.
local MARBLE = Color3.fromRGB(226, 222, 212)
local MARBLE_TRIM = Color3.fromRGB(198, 192, 180)
local MARBLE_DARK = Color3.fromRGB(176, 170, 158)

-- Grand marble portal archway styled to match the temple it leads to. `accent`
-- is the temple's signature glow color; the marble frame is shared so every
-- portal nestles into the hub's architecture.
local function buildPortal(parent: Instance, config: any, position: Vector3, facing: number, accent: Color3)
	local model = Instance.new("Model")
	model.Name = "Portal_" .. tostring(config.name)
	model.Parent = parent

	-- Stepped marble dais.
	local pad = BuilderUtil.part({
		Name = "Pad",
		Size = Vector3.new(18, 0.6, 18),
		Position = position + Vector3.new(0, 0.3, 0),
		Color = MARBLE_DARK,
		Material = Enum.Material.Marble,
		Shape = Enum.PartType.Cylinder,
		Parent = model,
	})
	pad.Orientation = Vector3.new(0, 0, 90)
	BuilderUtil.part({
		Name = "PadInlay",
		Size = Vector3.new(13, 0.3, 13),
		Position = position + Vector3.new(0, 0.65, 0),
		Color = accent,
		Material = Enum.Material.Neon,
		Transparency = 0.5,
		CanCollide = false,
		CanQuery = false,
		CastShadow = false,
		Shape = Enum.PartType.Cylinder,
		Parent = model,
	}).Orientation =
		Vector3.new(0, 0, 90)

	local cframe = CFrame.new(position) * CFrame.Angles(0, facing, 0)
	-- Flanking marble columns with base and capital.
	for side = -1, 1, 2 do
		BuilderUtil.part({
			Name = "ColumnBase",
			Size = Vector3.new(4, 1.4, 4),
			CFrame = cframe * CFrame.new(side * 6, 0.7, 0),
			Color = MARBLE_TRIM,
			Material = Enum.Material.Marble,
			Parent = model,
		})
		BuilderUtil.part({
			Name = "Pillar",
			Size = Vector3.new(3, 16, 3),
			CFrame = cframe * CFrame.new(side * 6, 9, 0),
			Color = MARBLE,
			Material = Enum.Material.Marble,
			Parent = model,
		})
		BuilderUtil.part({
			Name = "ColumnCapital",
			Size = Vector3.new(4, 1.4, 4),
			CFrame = cframe * CFrame.new(side * 6, 17, 0),
			Color = GOLD,
			Material = Enum.Material.Marble,
			Parent = model,
		})
	end
	-- Entablature and crown.
	BuilderUtil.part({
		Name = "Lintel",
		Size = Vector3.new(16.5, 2.6, 3.4),
		CFrame = cframe * CFrame.new(0, 17.8, 0),
		Color = MARBLE,
		Material = Enum.Material.Marble,
		Parent = model,
	})
	BuilderUtil.part({
		Name = "Keystone",
		Size = Vector3.new(3.4, 3, 3.8),
		CFrame = cframe * CFrame.new(0, 20.4, 0),
		Color = GOLD,
		Material = Enum.Material.Marble,
		Parent = model,
	})

	local veil = BuilderUtil.part({
		Name = "Veil",
		Size = Vector3.new(9, 14, 0.4),
		CFrame = cframe * CFrame.new(0, 8, 0),
		Color = accent,
		Material = Enum.Material.Neon,
		Transparency = 0.45,
		CanCollide = false,
		CanQuery = false,
		Parent = model,
	})
	local veilLight = BuilderUtil.pointLight(veil, accent, 1.4, 16)

	local promptPart = BuilderUtil.part({
		Name = "PromptPart",
		Size = Vector3.new(6, 8, 2),
		CFrame = cframe * CFrame.new(0, 4, -1.5),
		Color = MARBLE_DARK,
		Transparency = 1,
		CanCollide = false,
		CanQuery = false,
		Parent = model,
	})

	local prompt = Instance.new("ProximityPrompt")
	prompt.Name = "EnterPortal"
	prompt.ActionText = "Enter Expedition"
	prompt.ObjectText = tostring(config.name)
	prompt.HoldDuration = 0
	prompt.MaxActivationDistance = 12
	prompt.RequiresLineOfSight = false
	prompt.Parent = promptPart

	BuilderUtil.billboard(promptPart, tostring(config.name), GOLD, 220, 46, model)

	return {
		model = model,
		prompt = prompt,
		position = position,
		veil = veil,
		veilLight = veilLight,
	}
end

local function buildKiosk(
	parent: Instance,
	position: Vector3,
	facing: number,
	title: string,
	action: string,
	accent: Color3
)
	local model = Instance.new("Model")
	model.Name = title
	model.Parent = parent

	local cframe = CFrame.new(position) * CFrame.Angles(0, facing, 0)
	BuilderUtil.part({
		Name = "Counter",
		Size = Vector3.new(10, 3, 4),
		CFrame = cframe * CFrame.new(0, 1.5, 0),
		Color = STONE_DARK,
		Material = Enum.Material.WoodPlanks,
		Parent = model,
	})
	BuilderUtil.part({
		Name = "Canopy",
		Size = Vector3.new(12, 0.6, 7),
		CFrame = cframe * CFrame.new(0, 6.4, -1),
		Color = accent,
		Material = Enum.Material.Fabric,
		Parent = model,
	})
	for side = -1, 1, 2 do
		BuilderUtil.part({
			Name = "Post",
			Size = Vector3.new(0.6, 6.5, 0.6),
			CFrame = cframe * CFrame.new(side * 5.5, 3.2, -3.2),
			Color = STONE,
			Material = Enum.Material.Wood,
			Parent = model,
		})
	end

	local promptPart = BuilderUtil.part({
		Name = "PromptPart",
		Size = Vector3.new(6, 3, 3),
		CFrame = cframe * CFrame.new(0, 2, 2),
		Color = accent,
		Transparency = 1,
		CanCollide = false,
		Parent = model,
	})
	local prompt = Instance.new("ProximityPrompt")
	prompt.Name = "Kiosk"
	prompt.ActionText = action
	prompt.ObjectText = title
	prompt.HoldDuration = 0
	prompt.MaxActivationDistance = 12
	prompt.RequiresLineOfSight = false
	prompt.Parent = promptPart

	BuilderUtil.billboard(promptPart, title, accent, 200, 44, model)

	return { model = model, prompt = prompt }
end

function HubBuilder.Build(world: Instance, temples: { [string]: any })
	local hub = Instance.new("Model")
	hub.Name = "Hub"
	hub.Parent = world

	BuilderUtil.part({
		Name = "Plaza",
		Size = Vector3.new(2, 175, 175),
		CFrame = CFrame.new(0, -1, 0) * CFrame.Angles(0, 0, math.rad(90)),
		Color = MARBLE,
		Material = Enum.Material.Marble,
		Parent = hub,
	})
	-- Polished inner disc so the plaza reads as a finished marble court.
	BuilderUtil.part({
		Name = "PlazaInlay",
		Size = Vector3.new(2.1, 150, 150),
		CFrame = CFrame.new(0, -1, 0) * CFrame.Angles(0, 0, math.rad(90)),
		Color = MARBLE_TRIM,
		Material = Enum.Material.Marble,
		CanCollide = false,
		CanQuery = false,
		CastShadow = false,
		Parent = hub,
	})

	for index = 0, 23 do
		local angle = math.rad(index * 15)
		BuilderUtil.part({
			Name = "PlazaMark",
			Size = Vector3.new(6, 0.2, 1),
			CFrame = CFrame.new(math.cos(angle) * 78, 0.05, math.sin(angle) * 78) * CFrame.Angles(0, -angle, 0),
			Color = STONE_DARK,
			Material = Enum.Material.Slate,
			CanCollide = false,
			CanQuery = false,
			CastShadow = false,
			Parent = hub,
		})
	end

	local spawn = Instance.new("SpawnLocation")
	spawn.Name = "HubSpawn"
	spawn.Size = Vector3.new(16, 0.4, 16)
	spawn.CFrame = CFrame.new(0, 0.2, 0)
	spawn.Anchored = true
	spawn.CanCollide = false
	spawn.Transparency = 1
	spawn.Neutral = true
	spawn.Duration = 0
	spawn.Parent = hub

	for index = 0, 11 do
		local angle = math.rad(index * 30)
		local position = Vector3.new(math.cos(angle) * 78, 0, math.sin(angle) * 78)
		BuilderUtil.part({
			Name = "LanternPillar",
			Size = Vector3.new(2.6, 10, 2.6),
			Position = position + Vector3.new(0, 5, 0),
			Color = MARBLE,
			Material = Enum.Material.Marble,
			Parent = hub,
		})
		local lantern = BuilderUtil.part({
			Name = "Lantern",
			Size = Vector3.new(2.2, 2.2, 2.2),
			Position = position + Vector3.new(0, 11, 0),
			Color = GOLD,
			Material = Enum.Material.Neon,
			Transparency = 0.15,
			Parent = hub,
		})
		BuilderUtil.pointLight(lantern, GOLD, 1.2, 22)
	end

	local portals: { [string]: any } = {}
	local ordered: { { id: string, temple: any } } = {}
	for id, temple in temples do
		table.insert(ordered, { id = id, temple = temple })
	end
	table.sort(ordered, function(a, b)
		return (a.temple.order or 0) < (b.temple.order or 0)
	end)

	-- Expedition portals form a grand colonnade along the hub's northern rim,
	-- on the same +Z axis as the temple avenue, flanking it symmetrically and
	-- facing inward. Each arch is styled to its temple's accent color so the
	-- portals read as part of the hub's marble architecture.
	local rimZ = 74
	local spacing = 36
	local startX = -((#ordered - 1) / 2) * spacing
	for index, entry in ordered do
		local x = startX + (index - 1) * spacing
		-- Push the two central arches apart enough to keep the processional
		-- avenue (x = 0, width ~22) clear between them.
		if math.abs(x) < 20 then
			x = x < 0 and -30 or 30
		end
		local position = Vector3.new(x, 0, rimZ)
		local accent = TempleBuilder.themeAccent(entry.temple.theme)
		portals[entry.id] = buildPortal(hub, entry.temple, position, math.rad(180), accent)
	end

	local shop = buildKiosk(hub, Vector3.new(-46, 0, -62), math.rad(135), "Museum Shop", "Browse Upgrades", GOLD)
	local ledger = buildKiosk(hub, Vector3.new(46, 0, -62), math.rad(-135), "Museum Ledger", "Manage Museum", CYAN)

	return {
		model = hub,
		spawn = spawn,
		portals = portals,
		prompts = {
			{ prompt = shop.prompt, panel = "Shop" },
			{ prompt = ledger.prompt, panel = "Museum" },
		},
	}
end

return HubBuilder
