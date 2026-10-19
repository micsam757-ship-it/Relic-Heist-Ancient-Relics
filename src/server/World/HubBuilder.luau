--!strict
-- Builds the central hub: spawn plaza, expedition portals, shop kiosk,
-- and museum ledger terminal. All geometry is blockout placeholder art.

local BuilderUtil = require(script.Parent.BuilderUtil)

local HubBuilder = {}

local STONE = Color3.fromRGB(150, 132, 104)
local STONE_DARK = Color3.fromRGB(96, 82, 62)
local GOLD = Color3.fromRGB(224, 178, 74)
local CYAN = Color3.fromRGB(74, 214, 220)

local function buildPortal(parent: Instance, config: any, position: Vector3, facing: number)
	local model = Instance.new("Model")
	model.Name = "Portal_" .. tostring(config.name)
	model.Parent = parent

	local pad = BuilderUtil.part({
		Name = "Pad",
		Size = Vector3.new(14, 0.6, 14),
		Position = position + Vector3.new(0, 0.3, 0),
		Color = STONE_DARK,
		Material = Enum.Material.Slate,
		Shape = Enum.PartType.Cylinder,
		Parent = model,
	})
	pad.Orientation = Vector3.new(0, 0, 90)

	local cframe = CFrame.new(position) * CFrame.Angles(0, facing, 0)
	for side = -1, 1, 2 do
		BuilderUtil.part({
			Name = "Pillar",
			Size = Vector3.new(2.4, 14, 2.4),
			CFrame = cframe * CFrame.new(side * 5, 7, 0),
			Color = STONE,
			Material = Enum.Material.Sandstone,
			Parent = model,
		})
	end
	BuilderUtil.part({
		Name = "Lintel",
		Size = Vector3.new(12.8, 2.2, 2.8),
		CFrame = cframe * CFrame.new(0, 14.5, 0),
		Color = STONE,
		Material = Enum.Material.Sandstone,
		Parent = model,
	})

	local veil = BuilderUtil.part({
		Name = "Veil",
		Size = Vector3.new(8.6, 12, 0.4),
		CFrame = cframe * CFrame.new(0, 6.6, 0),
		Color = CYAN,
		Material = Enum.Material.Neon,
		Transparency = 0.45,
		CanCollide = false,
		CanQuery = false,
		Parent = model,
	})
	local veilLight = BuilderUtil.pointLight(veil, CYAN, 1.4, 16)

	local promptPart = BuilderUtil.part({
		Name = "PromptPart",
		Size = Vector3.new(6, 8, 2),
		CFrame = cframe * CFrame.new(0, 4, -1.5),
		Color = STONE_DARK,
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
		CFrame = CFrame.new(0, 1, 0) * CFrame.Angles(0, 0, math.rad(90)),
		Color = STONE,
		Material = Enum.Material.Cobblestone,
		Parent = hub,
	})

	for index = 0, 23 do
		local angle = math.rad(index * 15)
		BuilderUtil.part({
			Name = "PlazaMark",
			Size = Vector3.new(6, 0.2, 1),
			CFrame = CFrame.new(math.cos(angle) * 78, 2.05, math.sin(angle) * 78) * CFrame.Angles(0, -angle, 0),
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
	spawn.CFrame = CFrame.new(0, 2.2, 0)
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
			Color = STONE,
			Material = Enum.Material.Brick,
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

	local slots = {
		{ Vector3.new(-62, 0, 58), math.rad(-40) },
		{ Vector3.new(62, 0, 58), math.rad(40) },
		{ Vector3.new(0, 0, -74), math.rad(180) },
		{ Vector3.new(-96, 0, -30), math.rad(-120) },
		{ Vector3.new(96, 0, -30), math.rad(120) },
	}
	for index, entry in ordered do
		local slot = slots[((index - 1) % #slots) + 1]
		portals[entry.id] = buildPortal(hub, entry.temple, slot[1], slot[2])
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
