--!strict
-- Builds a single player museum plot with expanding thematic wings.
-- Plots are created on demand when a player joins and destroyed on release.
-- The wing/pedestal layout comes from the pure `MuseumBuilder` domain module;
-- this file only turns those placements into Roblox geometry and applies the
-- per-relic rarity tier and purchased building enhancements.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local GameConfig = require(ReplicatedStorage.Shared.Config.GameConfig)
local MuseumBuilder = require(ReplicatedStorage.Shared.Domain.MuseumBuilder)
local BuilderUtil = require(script.Parent.BuilderUtil)

local PlotBuilder = {}

local FLOOR_TRIM = Color3.fromRGB(78, 60, 44)
local PILLAR = Color3.fromRGB(232, 230, 224)
local GOLD = Color3.fromRGB(224, 178, 74)
local LOCKED = Color3.fromRGB(70, 68, 66)
local GLASS = Color3.fromRGB(206, 230, 236)
local BRASS = Color3.fromRGB(186, 142, 64)
local VELVET = Color3.fromRGB(126, 30, 46)
local CRYSTAL = Color3.fromRGB(232, 244, 255)
local MARBLE_LIGHT = Color3.fromRGB(244, 243, 239)
local MARBLE_DARK = Color3.fromRGB(206, 202, 193)

type WingTheme = {
	floor: Color3,
	floorAlt: Color3,
	wall: Color3,
	trim: Color3,
	crown: Color3,
	accent: Color3,
}

-- Bright white-marble museum palette. Walls, floors and pillars are near-white
-- marble with a subtle warm/grey inlay so the winged halls read as a grand,
-- high-ceiling gallery rather than the old basic brick.
local WING_THEME: { [string]: WingTheme } = {
	entry = {
		floor = MARBLE_LIGHT,
		floorAlt = MARBLE_DARK,
		wall = Color3.fromRGB(248, 247, 243),
		trim = Color3.fromRGB(198, 192, 180),
		crown = Color3.fromRGB(226, 222, 212),
		accent = GOLD,
	},
	gallery = {
		floor = Color3.fromRGB(240, 238, 232),
		floorAlt = Color3.fromRGB(202, 197, 187),
		wall = Color3.fromRGB(245, 243, 238),
		trim = Color3.fromRGB(190, 183, 170),
		crown = Color3.fromRGB(220, 216, 206),
		accent = BRASS,
	},
	vault = {
		floor = Color3.fromRGB(214, 210, 220),
		floorAlt = Color3.fromRGB(178, 172, 188),
		wall = Color3.fromRGB(228, 226, 236),
		trim = Color3.fromRGB(150, 132, 190),
		crown = Color3.fromRGB(198, 190, 216),
		accent = Color3.fromRGB(150, 120, 196),
	},
}

local function rgb(triple: { number }): Color3
	return Color3.fromRGB(triple[1], triple[2], triple[3])
end

local function material(name: string?): Enum.Material
	if name and Enum.Material[name] then
		return Enum.Material[name]
	end
	return Enum.Material.SmoothPlastic
end

-- Builds one wing room: floor, walls with a doorway, optional pillars, ceiling
-- and ceiling lighting. Returns the wing root CFrame for placing fixtures.
local function buildWing(
	model: Instance,
	cframe: CFrame,
	wing: MuseumBuilder.WingDef,
	features: { [string]: number }
): CFrame
	local theme = WING_THEME[wing.theme] or WING_THEME.entry
	local base = cframe * CFrame.new(wing.offset.x or 0, 0, wing.offset.z or 0)
	local sizeX, sizeZ, height = wing.size.x, wing.size.z, wing.height

	local function at(x: number, y: number, z: number): CFrame
		return base * CFrame.new(x, y, z)
	end

	-- Polished tile floor: a marble base with a darker border inlay and a light
	-- central runner so the hall reads as a finished museum floor.
	BuilderUtil.part({
		Name = "WingFloor_" .. wing.id,
		Size = Vector3.new(sizeX, 1, sizeZ),
		CFrame = at(0, -0.5, 0),
		Color = theme.floor,
		Material = Enum.Material.Marble,
		Parent = model,
	})
	BuilderUtil.part({
		Name = "WingFloorBorder_" .. wing.id,
		Size = Vector3.new(sizeX - 2, 0.2, sizeZ - 2),
		CFrame = at(0, 0.05, 0),
		Color = theme.floorAlt,
		Material = Enum.Material.Marble,
		CanCollide = false,
		CanQuery = false,
		Parent = model,
	})
	BuilderUtil.part({
		Name = "WingFloorRunner_" .. wing.id,
		Size = Vector3.new(sizeX - 12, 0.2, sizeZ - 12),
		CFrame = at(0, 0.14, 0),
		Color = theme.floor,
		Material = Enum.Material.Marble,
		CanCollide = false,
		CanQuery = false,
		Parent = model,
	})

	-- Walls with a gap on the wing edge that faces the plot origin so the player
	-- can walk between wings. The Foyer opens forward (+Z, toward the Exhibition
	-- Hall); a wing positioned toward +Z opens backward (−Z, toward the Foyer);
	-- a wing positioned toward −Z opens forward (+Z, toward the Foyer).
	local wallThickness = 1.5
	local wallHeight = height
	local openings = {}
	if (wing.offset.z or 0) >= 0 then
		openings.front = wing.unlockLevel == 0
		openings.back = wing.unlockLevel ~= 0
	else
		openings.front = true
	end

	local halfX, halfZ = sizeX / 2, sizeZ / 2

	-- A wall segment plus its base wainscot and top crown molding, so every wall
	-- gains layered stone detail instead of a flat slab of brick.
	local function wall(size: Vector3, position: Vector3)
		BuilderUtil.part({
			Name = "WingWall_" .. wing.id,
			Size = size,
			CFrame = base * CFrame.new(position),
			Color = theme.wall,
			Material = Enum.Material.Marble,
			Parent = model,
		})
		-- Wainscot: a warmer inlay skirting along the bottom of the segment.
		BuilderUtil.part({
			Name = "Wainscot",
			Size = Vector3.new(size.X, 1.6, size.Z + 0.4),
			CFrame = base * CFrame.new(position.X, 0.8, position.Z),
			Color = theme.trim,
			Material = Enum.Material.Marble,
			CanCollide = false,
			CanQuery = false,
			Parent = model,
		})
		-- Crown molding: a lighter cap along the top of the segment.
		BuilderUtil.part({
			Name = "Crown",
			Size = Vector3.new(size.X, 0.7, size.Z + 0.5),
			CFrame = base * CFrame.new(position.X, wallHeight - 0.35, position.Z),
			Color = theme.crown,
			Material = Enum.Material.Marble,
			CanCollide = false,
			CanQuery = false,
			Parent = model,
		})
	end

	-- A grand entrance: two flanking gate columns, a lintel above the opening,
	-- and a stepped keystone arch spanning the doorway. Door proportions are
	-- kept human-scale so every room's opening matches character size.
	local doorWidth = math.clamp(sizeX * 0.1, 7, 9)
	local doorHeight = math.clamp(wallHeight - 6, 7, 9)
	local function archWall(z: number)
		local segment = (sizeX - doorWidth) / 2
		local lintelHeight = wallHeight - doorHeight
		local sideX = doorWidth / 2 + segment / 2
		wall(Vector3.new(segment, wallHeight, wallThickness), Vector3.new(-sideX, wallHeight / 2, z))
		wall(Vector3.new(segment, wallHeight, wallThickness), Vector3.new(sideX, wallHeight / 2, z))
		if lintelHeight > 0 then
			wall(Vector3.new(doorWidth, lintelHeight, wallThickness), Vector3.new(0, doorHeight + lintelHeight / 2, z))
		end
		-- Flanking gate columns framing the opening.
		for _, side in { -1, 1 } do
			BuilderUtil.part({
				Name = "GateColumn",
				Size = Vector3.new(1.4, doorHeight, 1.8),
				CFrame = base * CFrame.new(side * (doorWidth / 2 + 0.7), doorHeight / 2, z),
				Color = MARBLE_LIGHT,
				Material = Enum.Material.Marble,
				Parent = model,
			})
			BuilderUtil.part({
				Name = "GateCap",
				Size = Vector3.new(2, 0.7, 2.2),
				CFrame = base * CFrame.new(side * (doorWidth / 2 + 0.7), doorHeight + 0.35, z),
				Color = theme.crown,
				Material = Enum.Material.Marble,
				CanCollide = false,
				CanQuery = false,
				Parent = model,
			})
		end
		-- Keystone: a stepped marble block at the arch apex, in the accent color.
		BuilderUtil.part({
			Name = "Keystone",
			Size = Vector3.new(2, 1.6, wallThickness + 0.6),
			CFrame = base * CFrame.new(0, doorHeight + 0.8, z),
			Color = theme.accent,
			Material = Enum.Material.Marble,
			Reflectance = 0.1,
			CanCollide = false,
			CanQuery = false,
			Parent = model,
		})
	end

	-- Back wall (negative Z), arched when there is a back opening.
	if openings.back then
		archWall(-halfZ)
	else
		wall(Vector3.new(sizeX, wallHeight, wallThickness), Vector3.new(0, wallHeight / 2, -halfZ))
	end
	-- Front wall (positive Z), arched when there is a front opening.
	if openings.front then
		archWall(halfZ)
	else
		wall(Vector3.new(sizeX, wallHeight, wallThickness), Vector3.new(0, wallHeight / 2, halfZ))
	end
	wall(Vector3.new(wallThickness, wallHeight, sizeZ), Vector3.new(-halfX, wallHeight / 2, 0))
	wall(Vector3.new(wallThickness, wallHeight, sizeZ), Vector3.new(halfX, wallHeight / 2, 0))

	-- Coffered ceiling: a light marble slab with a grid of beams crossing it so
	-- the roof reads as a structural vault rather than a flat lid.
	BuilderUtil.part({
		Name = "WingCeiling_" .. wing.id,
		Size = Vector3.new(sizeX, 0.8, sizeZ),
		CFrame = at(0, height, 0),
		Color = theme.crown,
		Material = Enum.Material.Marble,
		Parent = model,
	})
	local beamCount = math.max(2, math.floor(sizeX / 16))
	for beamIndex = 1, beamCount - 1 do
		local x = -halfX + (beamIndex / beamCount) * sizeX
		BuilderUtil.part({
			Name = "CeilingBeam",
			Size = Vector3.new(0.9, 1.1, sizeZ),
			CFrame = at(x, height - 0.55, 0),
			Color = theme.crown,
			Material = Enum.Material.Marble,
			CanCollide = false,
			CanQuery = false,
			Parent = model,
		})
	end
	BuilderUtil.part({
		Name = "CeilingBeam",
		Size = Vector3.new(sizeX, 1.1, 0.9),
		CFrame = at(0, height - 0.55, 0),
		Color = theme.crown,
		Material = Enum.Material.Marble,
		CanCollide = false,
		CanQuery = false,
		Parent = model,
	})

	-- Warm downlighting: spotlights recessed in the ceiling throughout the wing.
	local spotCount = math.max(3, math.floor(sizeZ / 14))
	for spotIndex = 1, spotCount do
		local t = (spotIndex - 0.5) / spotCount
		local z = -halfZ + t * sizeZ
		local housing = BuilderUtil.part({
			Name = "CeilingSpot",
			Size = Vector3.new(1, 0.5, 1),
			CFrame = at(0, height - 0.9, z),
			Color = Color3.fromRGB(255, 238, 205),
			Material = Enum.Material.Neon,
			CanCollide = false,
			CanQuery = false,
			Parent = model,
		})
		local spot = Instance.new("SpotLight")
		spot.Name = "Downlight"
		spot.Face = Enum.NormalId.Bottom
		spot.Color = Color3.fromRGB(255, 232, 190)
		spot.Brightness = 1.4
		spot.Range = height + 8
		spot.Angle = 80
		spot.Shadows = false
		spot.Parent = housing
	end

	-- Marble colonnade: one column near each corner at level 1, plus mid-wall
	-- columns at level 2, plus a pair at level 3. Columns are human-scale
	-- (2x2 studs) so the room reads grand but not oversized.
	local pillarLevel = features.pillars or 0
	if pillarLevel > 0 then
		local inset = 3.5
		local columns = {
			Vector3.new(-halfX + inset, 0, -halfZ + inset),
			Vector3.new(halfX - inset, 0, -halfZ + inset),
			Vector3.new(-halfX + inset, 0, halfZ - inset),
			Vector3.new(halfX - inset, 0, halfZ - inset),
		}
		if pillarLevel >= 2 then
			table.insert(columns, Vector3.new(-halfX + inset, 0, 0))
			table.insert(columns, Vector3.new(halfX - inset, 0, 0))
		end
		if pillarLevel >= 3 then
			table.insert(columns, Vector3.new(0, 0, -halfZ + inset))
			table.insert(columns, Vector3.new(0, 0, halfZ - inset))
		end
		for _, offset in columns do
			BuilderUtil.part({
				Name = "Pillar",
				Size = Vector3.new(2, height - 1, 2),
				CFrame = base * CFrame.new(offset.X, (height - 1) / 2, offset.Z),
				Color = PILLAR,
				Material = Enum.Material.Marble,
				Parent = model,
			})
			BuilderUtil.part({
				Name = "PillarCap",
				Size = Vector3.new(2.6, 0.6, 2.6),
				CFrame = base * CFrame.new(offset.X, height - 0.7, offset.Z),
				Color = PILLAR,
				Material = Enum.Material.Marble,
				CanCollide = false,
				Parent = model,
			})
		end
	end

	-- Gallery lighting: warm point lights along the ceiling.
	local lightingLevel = features.lighting or 0
	if lightingLevel > 0 then
		local count = 2 + lightingLevel
		for lightIndex = 1, count do
			local t = (lightIndex - 0.5) / count
			local z = -halfZ + t * sizeZ
			local lightPart = BuilderUtil.part({
				Name = "Sconce",
				Size = Vector3.new(0.8, 0.8, 0.8),
				CFrame = at(0, height - 0.8, z),
				Color = Color3.fromRGB(255, 236, 196),
				Material = Enum.Material.Neon,
				CanCollide = false,
				CanQuery = false,
				Parent = model,
			})
			local light = BuilderUtil.pointLight(
				lightPart,
				Color3.fromRGB(255, 232, 190),
				1 + lightingLevel * 0.3,
				20 + lightingLevel * 6
			)
			light.Shadows = false
		end
	end

	-- Crystal chandeliers: suspended from the ceiling center.
	local chandelierLevel = features.chandeliers or 0
	if chandelierLevel > 0 then
		for chandelierIndex = 1, chandelierLevel do
			local span = sizeZ - 12
			local t = chandelierLevel == 1 and 0.5 or (chandelierIndex - 0.5) / chandelierLevel
			local z = -halfZ + 6 + t * span
			local hub = BuilderUtil.part({
				Name = "Chandelier",
				Size = Vector3.new(1.8, 1.4, 1.8),
				CFrame = at(0, height - 3.2, z),
				Color = BRASS,
				Material = Enum.Material.Metal,
				CanCollide = false,
				CanQuery = false,
				Parent = model,
			})
			BuilderUtil.part({
				Name = "ChandelierStem",
				Size = Vector3.new(0.2, 2, 0.2),
				CFrame = at(0, height - 1.6, z),
				Color = BRASS,
				Material = Enum.Material.Metal,
				CanCollide = false,
				CanQuery = false,
				Parent = model,
			})
			for arm = 1, 6 do
				local angle = math.rad(arm * 60)
				BuilderUtil.part({
					Name = "ChandelierCrystal",
					Size = Vector3.new(0.4, 1.2, 0.4),
					CFrame = at(math.cos(angle) * 1.6, height - 2.4, z + math.sin(angle) * 1.6)
						* CFrame.Angles(0, angle, math.rad(10)),
					Color = CRYSTAL,
					Material = Enum.Material.Glass,
					Transparency = 0.35,
					CanCollide = false,
					CanQuery = false,
					Parent = model,
				})
			end
			BuilderUtil.pointLight(hub, Color3.fromRGB(255, 246, 220), 1.6 + chandelierLevel * 0.6, 24)
		end
	end

	return base
end

-- Builds one pedestal at a plot-local slot. Returns the runtime record the
-- service uses to prompt, label and re-skin it. Tier visuals start at the
-- Common/default look; `applyPedestalTier` re-skins on exhibit.
local function buildPedestal(model: Instance, base: CFrame, placement: MuseumBuilder.Placement): any
	local slot = placement
	local function at(x: number, y: number, z: number): CFrame
		return base * CFrame.new(x, y, z)
	end

	local pedestalBase = BuilderUtil.part({
		Name = "PedestalBase",
		Size = Vector3.new(4, 0.5, 4),
		CFrame = at(slot.x, 0.25, slot.z),
		Color = PILLAR,
		Material = Enum.Material.Marble,
		Parent = model,
	})
	local column = BuilderUtil.part({
		Name = "PedestalColumn",
		Size = Vector3.new(2.4, 2.2, 2.4),
		CFrame = at(slot.x, 1.6, slot.z),
		Color = PILLAR,
		Material = Enum.Material.Marble,
		Parent = model,
	})
	local top = BuilderUtil.part({
		Name = "PedestalTop",
		Size = Vector3.new(4.4, 0.5, 4.4),
		CFrame = at(slot.x, 2.95, slot.z),
		Color = GOLD,
		Material = Enum.Material.Marble,
		Parent = model,
	})
	top:SetAttribute("PedestalId", slot.id)

	local glowPart = BuilderUtil.part({
		Name = "PedestalGlow",
		Size = Vector3.new(3.8, 0.3, 3.8),
		CFrame = at(slot.x, 3.3, slot.z),
		Color = GOLD,
		Material = Enum.Material.Neon,
		Transparency = 1,
		CanCollide = false,
		CanQuery = false,
		CanTouch = false,
		Parent = model,
	})
	local glowLight = BuilderUtil.pointLight(glowPart, GOLD, 0, 0)

	local promptPart = BuilderUtil.part({
		Name = "PedestalPrompt",
		Size = Vector3.new(5, 3, 5),
		CFrame = at(slot.x, 3.7, slot.z),
		Color = LOCKED,
		Transparency = 1,
		CanCollide = false,
		CanQuery = false,
		Parent = model,
	})
	local prompt = Instance.new("ProximityPrompt")
	prompt.Name = "Pedestal"
	prompt.ActionText = "Exhibit Relic"
	prompt.ObjectText = "Pedestal " .. slot.id
	prompt.HoldDuration = 0
	prompt.MaxActivationDistance = 12
	prompt.RequiresLineOfSight = false
	prompt.Enabled = false
	prompt.Parent = promptPart

	-- Floating label: a clean rounded card that sits well above the pedestal so
	-- it never overlaps the relic or the prompt. It carries a rarity accent bar,
	-- a bold title, and a muted status line ("Locked", "Empty", or the rarity).
	local labelPart = BuilderUtil.part({
		Name = "PedestalLabel",
		Size = Vector3.new(1, 1, 0.2),
		CFrame = at(slot.x, 6.6, slot.z),
		Color = LOCKED,
		Transparency = 1,
		CanCollide = false,
		CanQuery = false,
		CanTouch = false,
		Parent = model,
	})
	local labelGui = Instance.new("BillboardGui")
	labelGui.Name = "Label"
	labelGui.Size = UDim2.fromOffset(240, 66)
	labelGui.StudsOffsetWorldSpace = Vector3.new(0, 0, 0)
	labelGui.AlwaysOnTop = false
	labelGui.MaxDistance = 150
	labelGui.LightInfluence = 0
	labelGui.Adornee = labelPart
	labelGui.Parent = labelPart

	local card = Instance.new("Frame")
	card.Name = "Card"
	card.BackgroundColor3 = Color3.fromRGB(18, 16, 22)
	card.BackgroundTransparency = 0.18
	card.BorderSizePixel = 0
	card.Size = UDim2.fromScale(1, 1)
	card.Parent = labelGui
	local cardCorner = Instance.new("UICorner")
	cardCorner.CornerRadius = UDim.new(0, 10)
	cardCorner.Parent = card
	local cardStroke = Instance.new("UIStroke")
	cardStroke.Color = Color3.fromRGB(224, 178, 74)
	cardStroke.Thickness = 1.5
	cardStroke.Transparency = 0.35
	cardStroke.Parent = card

	local accent = Instance.new("Frame")
	accent.Name = "Accent"
	accent.BackgroundColor3 = GOLD
	accent.BorderSizePixel = 0
	accent.Size = UDim2.new(0, 6, 1, -16)
	accent.Position = UDim2.fromOffset(8, 8)
	accent.Parent = card
	local accentCorner = Instance.new("UICorner")
	accentCorner.CornerRadius = UDim.new(1, 0)
	accentCorner.Parent = accent

	local labelText = Instance.new("TextLabel")
	labelText.Name = "Text"
	labelText.BackgroundTransparency = 1
	labelText.Size = UDim2.new(1, -32, 0, 34)
	labelText.Position = UDim2.fromOffset(22, 8)
	labelText.Font = Enum.Font.GothamBold
	labelText.Text = "Locked"
	labelText.TextColor3 = LOCKED
	labelText.TextSize = 22
	labelText.TextXAlignment = Enum.TextXAlignment.Left
	labelText.TextTruncate = Enum.TextTruncate.AtEnd
	labelText.Parent = card

	local labelSubtitle = Instance.new("TextLabel")
	labelSubtitle.Name = "Subtitle"
	labelSubtitle.BackgroundTransparency = 1
	labelSubtitle.Size = UDim2.new(1, -32, 0, 22)
	labelSubtitle.Position = UDim2.fromOffset(22, 42)
	labelSubtitle.Font = Enum.Font.Gotham
	labelSubtitle.Text = "Expand your museum"
	labelSubtitle.TextColor3 = Color3.fromRGB(150, 146, 156)
	labelSubtitle.TextSize = 15
	labelSubtitle.TextXAlignment = Enum.TextXAlignment.Left
	labelSubtitle.TextTruncate = Enum.TextTruncate.AtEnd
	labelSubtitle.Parent = card

	-- Optional fixtures; toggled by building enhancements via applyEnhancements.
	local caseRoot = Instance.new("Model")
	caseRoot.Name = "GlassCase"
	caseRoot.Parent = model
	local ropeRoot = Instance.new("Model")
	ropeRoot.Name = "VelvetRope"
	ropeRoot.Parent = model
	-- A glass dome shown on locked pedestals so "locked" reads at a glance.
	local lockRoot = Instance.new("Model")
	lockRoot.Name = "LockedIndicator"
	lockRoot.Parent = model

	return {
		id = slot.id,
		base = pedestalBase,
		column = column,
		top = top,
		glow = glowPart,
		glowLight = glowLight,
		prompt = prompt,
		promptPart = promptPart,
		labelPart = labelPart,
		labelText = labelText,
		labelSubtitle = labelSubtitle,
		labelAccent = accent,
		labelCard = card,
		wingId = slot.wingId,
		wingName = slot.wingName,
		caseRoot = caseRoot,
		ropeRoot = ropeRoot,
		lockRoot = lockRoot,
		topCFrame = top.CFrame,
		displayCFrame = at(slot.x, 3.55, slot.z),
	}
end

function PlotBuilder.Build(parent: Instance, index: number, cframe: CFrame, options: any?)
	local opts = options or {}
	local wings: { MuseumBuilder.WingDef } = opts.wings or {}
	local features: { [string]: number } = opts.features or {}

	local model = Instance.new("Model")
	model.Name = "MuseumPlot_" .. tostring(index)
	model:SetAttribute("PlotIndex", index)
	model:SetAttribute("OwnerUserId", 0)
	model.Parent = parent

	-- Plots are allocated with their centre at ground level; raise the whole
	-- build so the wing floors top out on the unified ground surface, keeping
	-- the museum flush with the hub, avenues and temples.
	local base = cframe * CFrame.new(0, GameConfig.World.GroundTop - 1, 0)

	local function at(x: number, y: number, z: number): CFrame
		return base * CFrame.new(x, y, z)
	end

	-- Ground apron under all wings. Sized to hug the three-wing footprint with a
	-- slim outer margin, so the building reads as sitting on a plaza without
	-- leaving a wide empty apron around it.
	BuilderUtil.part({
		Name = "Ground",
		Size = Vector3.new(120, 1, 260),
		CFrame = at(0, -1.6, 2),
		Color = Color3.fromRGB(176, 172, 164),
		Material = Enum.Material.Slate,
		CanCollide = true,
		Parent = model,
	})
	model:SetAttribute("PlotWidth", 90)
	model:SetAttribute("PlotDepth", 90)

	-- Build every wing room and remember the inward edge so pedestal ids stay
	-- aligned with `MuseumBuilder.placements` (which preserves wing order).
	local placements = MuseumBuilder.placements(wings)
	for _, wing in wings do
		buildWing(model, base, wing, features)
	end

	-- Owner sign on the Foyer's front wall (Foyer front edge is at z = +45).
	local signPart = BuilderUtil.part({
		Name = "OwnerSign",
		Size = Vector3.new(14, 14, 1),
		CFrame = at(0, 26, 45.5),
		Color = FLOOR_TRIM,
		Material = Enum.Material.Wood,
		CanCollide = false,
		Parent = model,
	})
	local signGui = Instance.new("SurfaceGui")
	signGui.Name = "OwnerLabel"
	signGui.Face = Enum.NormalId.Front
	signGui.CanvasSize = Vector2.new(600, 600)
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
	spawn.Size = Vector3.new(16, 0.4, 16)
	spawn.CFrame = at(0, 0.4, 60)
	spawn.Anchored = true
	spawn.CanCollide = false
	spawn.Transparency = 1
	spawn.Neutral = true
	spawn.Duration = 0
	spawn.Parent = model

	-- Foyer base CFrame is the plot root; pedestal placements are plot-local and
	-- already include each wing's offset, so build them against `base`.
	local pedestals = {}
	for _, placement in placements do
		table.insert(pedestals, buildPedestal(model, base, placement))
	end

	return {
		index = index,
		model = model,
		cframe = cframe,
		spawn = spawn,
		spawnCFrame = spawn.CFrame + Vector3.new(0, 4, 0),
		signText = signText,
		pedestals = pedestals,
		placements = placements,
		wings = wings,
		features = features,
	}
end

-- Re-skins a pedestal to a rarity tier. `tier` is a `GameConfig.MuseumBuilding`
-- tier definition; Call with the Common/default tier to reset.
function PlotBuilder.applyPedestalTier(pedestal: any, tier: MuseumBuilder.TierDef)
	pedestal.column.Material = material(tier.columnMaterial)
	pedestal.top.Material = material(tier.topMaterial)
	local trim = tier.trim
	local trimColor = rgb(trim)
	pedestal.top.Color = trimColor
	pedestal.glow.Color = trimColor
	if tier.glow then
		pedestal.glow.Transparency = 0.25
		pedestal.glowLight.Color = trimColor
		pedestal.glowLight.Brightness = tier.lightBrightness
		pedestal.glowLight.Range = tier.lightRange
	else
		pedestal.glow.Transparency = 1
		pedestal.glowLight.Brightness = 0
		pedestal.glowLight.Range = 0
	end
	pedestal.tier = tier.tier
end

-- Rebuilds the optional fixtures (glass case, velvet ropes) on a pedestal to
-- match the player's enhancement levels. Levels are the `features` map.
function PlotBuilder.applyPedestalEnhancements(pedestal: any, features: { [string]: number })
	pedestal.caseRoot:ClearAllChildren()
	pedestal.ropeRoot:ClearAllChildren()

	local glassLevel = features.glassCases or 0
	if glassLevel > 0 then
		local topCFrame = pedestal.topCFrame
		-- A short glass case sitting on the low plinth (surface ~0.25 above top).
		local pane = BuilderUtil.part({
			Name = "GlassPane",
			Size = Vector3.new(3.6, 2.8, 3.6),
			CFrame = topCFrame * CFrame.new(0, 1.65, 0),
			Color = GLASS,
			Material = Enum.Material.Glass,
			Transparency = 0.78,
			Reflectance = 0.15,
			CanCollide = false,
			CanQuery = false,
		})
		pane.Parent = pedestal.caseRoot
	end

	local ropeLevel = features.velvetRopes or 0
	if ropeLevel > 0 then
		local topCFrame = pedestal.topCFrame
		local half = 2.8
		local postHeight = 1.6
		local baseOffset = 0.25
		for _, corner in
			{
				Vector3.new(-half, 0, -half),
				Vector3.new(half, 0, -half),
				Vector3.new(-half, 0, half),
				Vector3.new(half, 0, half),
			}
		do
			local post = BuilderUtil.part({
				Name = "RopePost",
				Size = Vector3.new(0.3, postHeight, 0.3),
				CFrame = topCFrame * CFrame.new(corner.X, baseOffset + postHeight / 2, corner.Z),
				Color = BRASS,
				Material = Enum.Material.Metal,
				CanCollide = false,
				CanQuery = false,
			})
			post.Parent = pedestal.ropeRoot
		end
		local railHeight = baseOffset + postHeight - 0.2
		local segments = {
			{ Vector3.new(0, 0, -half), Vector3.new(half * 2, 0.35, 0.35) },
			{ Vector3.new(0, 0, half), Vector3.new(half * 2, 0.35, 0.35) },
			{ Vector3.new(-half, 0, 0), Vector3.new(0.35, 0.35, half * 2) },
			{ Vector3.new(half, 0, 0), Vector3.new(0.35, 0.35, half * 2) },
		}
		for _, segment in segments do
			local rope = BuilderUtil.part({
				Name = "VelvetRope",
				Size = segment[2],
				CFrame = topCFrame * CFrame.new(segment[1].X, railHeight, segment[1].Z),
				Color = VELVET,
				Material = Enum.Material.Fabric,
				CanCollide = false,
				CanQuery = false,
			})
			rope.Parent = pedestal.ropeRoot
		end
	end
end

-- Shows or clears a translucent glass dome over a pedestal so a locked pedestal
-- is unmistakable from across the room. Levels are rebuilt from scratch each call.
function PlotBuilder.applyLockedIndicator(pedestal: any, locked: boolean)
	pedestal.lockRoot:ClearAllChildren()
	if not locked then
		return
	end
	local topCFrame = pedestal.topCFrame
	local surface = 0.25
	local dome = BuilderUtil.part({
		Name = "LockedDome",
		Size = Vector3.new(4.8, 4.8, 4.8),
		Shape = Enum.PartType.Ball,
		CFrame = topCFrame * CFrame.new(0, surface + 1.4, 0),
		Color = Color3.fromRGB(150, 170, 200),
		Material = Enum.Material.Glass,
		Transparency = 0.62,
		Reflectance = 0.2,
		CanCollide = false,
		CanQuery = false,
	})
	dome.Parent = pedestal.lockRoot
	local collar = BuilderUtil.part({
		Name = "DomeCollar",
		Size = Vector3.new(4, 0.4, 4),
		CFrame = topCFrame * CFrame.new(0, surface, 0),
		Color = LOCKED,
		Material = Enum.Material.Metal,
		CanCollide = false,
		CanQuery = false,
	})
	collar.Parent = pedestal.lockRoot
	-- A padlock emblem hovering on the dome so "Locked" reads unmistakably.
	local body = BuilderUtil.part({
		Name = "LockPad",
		Size = Vector3.new(1.6, 1.2, 0.4),
		CFrame = topCFrame * CFrame.new(0, surface + 1.4, 0.1),
		Color = LOCKED,
		Material = Enum.Material.Metal,
		CanCollide = false,
		CanQuery = false,
	})
	body.Parent = pedestal.lockRoot
	local shackle = BuilderUtil.part({
		Name = "LockShackle",
		Size = Vector3.new(1, 0.25, 0.25),
		Shape = Enum.PartType.Cylinder,
		CFrame = topCFrame * CFrame.new(0, surface + 2.15, 0.1) * CFrame.Angles(0, 0, math.rad(90)),
		Color = LOCKED,
		Material = Enum.Material.Metal,
		CanCollide = false,
		CanQuery = false,
	})
	shackle.Parent = pedestal.lockRoot
end

return PlotBuilder
