--!strict
-- Builds a single player museum plot with eight pedestals.
-- Plots are created on demand when a player joins and destroyed on release.

local BuilderUtil = require(script.Parent.BuilderUtil)

local PlotBuilder = {}

local FLOOR = Color3.fromRGB(118, 96, 72)
local FLOOR_TRIM = Color3.fromRGB(78, 60, 44)
local PILLAR = Color3.fromRGB(158, 130, 96)
local GOLD = Color3.fromRGB(224, 178, 74)
local LOCKED = Color3.fromRGB(70, 68, 66)

local PEDESTAL_SLOTS = {
	{ x = -14, z = -8 },
	{ x = -4.7, z = -8 },
	{ x = 4.7, z = -8 },
	{ x = 14, z = -8 },
	{ x = -14, z = 6 },
	{ x = -4.7, z = 6 },
	{ x = 4.7, z = 6 },
	{ x = 14, z = 6 },
}

function PlotBuilder.Build(parent: Instance, index: number, cframe: CFrame)
	local model = Instance.new("Model")
	model.Name = "MuseumPlot_" .. tostring(index)
	model:SetAttribute("PlotIndex", index)
	model:SetAttribute("OwnerUserId", 0)
	model.Parent = parent

	local function at(x: number, y: number, z: number): CFrame
		return cframe * CFrame.new(x, y, z)
	end

	BuilderUtil.part({
		Name = "Floor",
		Size = Vector3.new(46, 1, 46),
		CFrame = at(0, -0.5, 0),
		Color = FLOOR,
		Material = Enum.Material.Marble,
		Parent = model,
	})
	BuilderUtil.part({
		Name = "Trim",
		Size = Vector3.new(50, 0.4, 50),
		CFrame = at(0, -0.1, 0),
		Color = FLOOR_TRIM,
		Material = Enum.Material.Slate,
		CanCollide = false,
		Parent = model,
	})

	local borderSize = Vector3.new(48, 3, 1.4)
	for _, config in
		{
			{ CFrame.new(0, 1.5, -24), borderSize },
			{ CFrame.new(0, 1.5, 24), borderSize },
			{ CFrame.new(-24, 1.5, 0), Vector3.new(1.4, 3, 48) },
			{ CFrame.new(24, 1.5, 0), Vector3.new(1.4, 3, 48) },
		}
	do
		BuilderUtil.part({
			Name = "Border",
			Size = config[2],
			CFrame = cframe * config[1],
			Color = FLOOR_TRIM,
			Material = Enum.Material.Brick,
			Parent = model,
		})
	end

	BuilderUtil.part({
		Name = "Backdrop",
		Size = Vector3.new(40, 16, 1.5),
		CFrame = at(0, 8, -22),
		Color = FLOOR_TRIM,
		Material = Enum.Material.Brick,
		Parent = model,
	})

	local signPart = BuilderUtil.part({
		Name = "OwnerSign",
		Size = Vector3.new(6, 8, 0.8),
		CFrame = at(0, 12, -21),
		Color = FLOOR_TRIM,
		Material = Enum.Material.Wood,
		CanCollide = false,
		Parent = model,
	})
	local signGui = Instance.new("SurfaceGui")
	signGui.Name = "OwnerLabel"
	signGui.Face = Enum.NormalId.Back
	signGui.CanvasSize = Vector2.new(600, 800)
	signGui.LightInfluence = 0
	signGui.Parent = signPart
	local signText = Instance.new("TextLabel")
	signText.Name = "Text"
	signText.BackgroundTransparency = 1
	signText.Size = UDim2.fromScale(1, 1)
	signText.Font = Enum.Font.GothamBold
	signText.Text = "Unclaimed"
	signText.TextColor3 = GOLD
	signText.TextScaled = true
	signText.TextWrapped = true
	signText.Parent = signGui

	local spawn = Instance.new("SpawnLocation")
	spawn.Name = "PlotSpawn"
	spawn.Size = Vector3.new(12, 0.4, 12)
	spawn.CFrame = at(0, 2.2, 18)
	spawn.Anchored = true
	spawn.CanCollide = false
	spawn.Transparency = 1
	spawn.Neutral = true
	spawn.Duration = 0
	spawn.Parent = model

	local pedestals = {}
	for slotIndex, slot in PEDESTAL_SLOTS do
		local base = BuilderUtil.part({
			Name = "PedestalBase",
			Size = Vector3.new(3.4, 1, 3.4),
			CFrame = at(slot.x, 0.5, slot.z),
			Color = PILLAR,
			Material = Enum.Material.Marble,
			Parent = model,
		})
		BuilderUtil.part({
			Name = "PedestalColumn",
			Size = Vector3.new(2, 3.6, 2),
			CFrame = at(slot.x, 2.8, slot.z),
			Color = PILLAR,
			Material = Enum.Material.Marble,
			Parent = model,
		})
		local top = BuilderUtil.part({
			Name = "PedestalTop",
			Size = Vector3.new(3.8, 0.6, 3.8),
			CFrame = at(slot.x, 4.9, slot.z),
			Color = GOLD,
			Material = Enum.Material.Marble,
			Parent = model,
		})
		top:SetAttribute("PedestalId", tostring(slotIndex))

		local promptPart = BuilderUtil.part({
			Name = "PedestalPrompt",
			Size = Vector3.new(3.6, 2.4, 3.6),
			CFrame = at(slot.x, 6, slot.z),
			Color = LOCKED,
			Transparency = 1,
			CanCollide = false,
			CanQuery = false,
			Parent = model,
		})
		local prompt = Instance.new("ProximityPrompt")
		prompt.Name = "Pedestal"
		prompt.ActionText = "Exhibit Relic"
		prompt.ObjectText = "Pedestal " .. tostring(slotIndex)
		prompt.HoldDuration = 0
		prompt.MaxActivationDistance = 10
		prompt.RequiresLineOfSight = false
		prompt.Enabled = false
		prompt.Parent = promptPart

		local labelPart = BuilderUtil.part({
			Name = "PedestalLabel",
			Size = Vector3.new(2, 1, 0.2),
			CFrame = at(slot.x, 6.6, slot.z),
			Color = LOCKED,
			Transparency = 1,
			CanCollide = false,
			CanQuery = false,
			Parent = model,
		})
		local labelGui = Instance.new("BillboardGui")
		labelGui.Name = "Label"
		labelGui.Size = UDim2.fromOffset(200, 50)
		labelGui.StudsOffsetWorldSpace = Vector3.new(0, 1, 0)
		labelGui.MaxDistance = 120
		labelGui.Adornee = labelPart
		labelGui.Parent = labelPart
		local labelText = Instance.new("TextLabel")
		labelText.Name = "Text"
		labelText.BackgroundTransparency = 1
		labelText.Size = UDim2.fromScale(1, 1)
		labelText.Font = Enum.Font.GothamBold
		labelText.Text = "Locked"
		labelText.TextColor3 = LOCKED
		labelText.TextScaled = true
		labelText.Parent = labelGui

		table.insert(pedestals, {
			id = tostring(slotIndex),
			base = base,
			top = top,
			prompt = prompt,
			promptPart = promptPart,
			labelPart = labelPart,
			labelText = labelText,
			topCFrame = top.CFrame,
			displayCFrame = at(slot.x, 5.2, slot.z),
		})
	end

	return {
		index = index,
		model = model,
		cframe = cframe,
		spawn = spawn,
		spawnCFrame = spawn.CFrame + Vector3.new(0, 4, 0),
		signText = signText,
		pedestals = pedestals,
	}
end

return PlotBuilder
