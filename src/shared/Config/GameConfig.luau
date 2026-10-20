--!nonstrict
-- Central, data-driven game configuration.
-- This module intentionally contains no Roblox API calls so it can be exercised
-- by the standalone Luau test runner as well as in Roblox.

local GameConfig = {}

GameConfig.Game = {
	Title = "Relic Heist: Ancient Relics",
	Version = "0.1.0",
}

-- World layout: shared geometry constants used by the hub, museum plot ring and
-- the connecting avenues so the hub, plots and temples stay physically linked.
GameConfig.World = {
	-- Museum plot ring. Plots are placed at `startAngle + n * angleStep` on a
	-- circle of `ringRadius` around the hub. The ring is offset from the +Z
	-- temple lane so no plot overlaps a temple avenue. The radius is kept just
	-- large enough for 12 plot footprints to sit with a comfortable (not
	-- sprawling) gap, so walking from the hub to any plot stays short.
	RingRadius = 380,
	StartAngleDegrees = 105,
	MaxPlots = 12,
	-- Ground top height; hub plaza, avenues, plots and temples all sit on it.
	GroundTop = 0,
	Hub = {
		PlazaRadius = 87,
		PlazaTop = 0,
	},
	-- Width of the grand connecting avenues (hub <-> plots and hub <-> temples).
	AvenueWidth = 16,
	AvenueTop = 0,
}

GameConfig.Save = {
	SchemaVersion = 1,
	DataStoreName = "RelicHeistProfiles",
	DataStoreScope = "v1",
	AutosaveSeconds = 120,
	MaxLoadRetries = 3,
	MaxSaveRetries = 3,
	RetryBackoffSeconds = { 0.6, 1.5, 3 },
	BindToCloseTimeoutSeconds = 20,
	MaxRelicsPerProfile = 100,
}

GameConfig.Economy = {
	StartingGold = 250,
	-- Offline income is held as pending and claimed through the Welcome Back
	-- modal, so the cap is measured against the offline window only.
	OfflineCapSeconds = 4 * 60 * 60,
	MaxPendingIncome = 50000,
	-- VIP Pass (a Game Pass) raises both the window and the ceiling.
	VipOfflineCapSeconds = 24 * 60 * 60,
	VipMaxPendingIncome = 200000,
	MaxCarriedRelics = 10,
	ExtractionValueToGold = 0.25,
}

GameConfig.Movement = {
	BaseWalkSpeed = 19,
	MinSpeedMultiplier = 0.35,
	WeightPenaltyPerUnit = 0.008,
	BaseCapacity = 40,
	BackpackCapacityPerLevel = 20,
	BasePedestals = 6,
	BaseMaxHealth = 100,
	ArmorHealthPerLevel = 20,
}

GameConfig.Museum = {
	IncomePerMinuteFloorBonus = 0.05,
	MaxIncomeRatePerMinute = 5000,
	MaxPedestals = 14,
}

-- Museum footprint: distinct, expanding wings. A wing is a physical room added
-- to the player's plot, holding a fixed set of pedestals. `unlockLevel` gates a
-- wing behind the Museum Expansion upgrade level; the Foyer (level 0) always
-- exists. Pedestal ids are global indices assigned Foyer-first so the existing
-- pedestal-count unlock logic is preserved. Offsets are plot-local (studs),
-- outward from the plot origin; `size` is the interior clear footprint.
GameConfig.MuseumBuilding = {
	Wings = {
		{
			id = "Foyer",
			name = "Grand Foyer",
			description = "A soaring entrance hall. Plinths line the grand walkway.",
			unlockLevel = 0,
			offset = { x = 0, z = 0 },
			size = { x = 90, z = 90 },
			height = 16,
			theme = "entry",
			-- Six plinths in two rows of three, well spaced so the floating label
			-- cards (and their ProximityPrompts) never crowd each other.
			pedestalSlots = {
				{ x = -30, z = -28, facing = 180 },
				{ x = 0, z = -28, facing = 180 },
				{ x = 30, z = -28, facing = 180 },
				{ x = -30, z = 30, facing = 180 },
				{ x = 0, z = 30, facing = 180 },
				{ x = 30, z = 30, facing = 180 },
			},
		},
		{
			id = "ExhibitionHall",
			name = "Exhibition Hall",
			description = "A vast gallery of glass cases and velvet ropes, brooding over a long central corridor.",
			unlockLevel = 1,
			offset = { x = 0, z = 81 },
			size = { x = 80, z = 56 },
			height = 14,
			theme = "gallery",
			-- Four displays in two rows of two, clear of the central corridor.
			pedestalSlots = {
				{ x = -22, z = -14, facing = 0 },
				{ x = 22, z = -14, facing = 0 },
				{ x = -22, z = 14, facing = 0 },
				{ x = 22, z = 14, facing = 0 },
			},
		},
		{
			id = "Vault",
			name = "Secure Vault",
			description = "A cavernous vault where the most valuable relics rest in shadow.",
			unlockLevel = 2,
			offset = { x = 0, z = -79 },
			size = { x = 76, z = 52 },
			height = 14,
			theme = "vault",
			pedestalSlots = {
				{ x = -20, z = -12, facing = 0 },
				{ x = 20, z = -12, facing = 0 },
				{ x = -20, z = 12, facing = 0 },
				{ x = 20, z = 12, facing = 0 },
			},
		},
	},
	-- Purchasable visual enhancements, keyed by the fixture feature the plot
	-- builder switches on. Each value is the id of an entry in
	-- `GameConfig.Upgrades`, so these are bought through the ordinary upgrade
	-- pipeline and share its price growth, schema storage, and refresh signal.
	Enhancements = {
		pillars = "MarblePillars",
		lighting = "Lighting",
		glassCases = "GlassCases",
		velvetRopes = "VelvetRopes",
		chandeliers = "Chandeliers",
	},
	-- Per-rarity pedestal styling. `rank` is the rarity's numeric rank
	-- (GameConfig.Rarities[*].rank). Higher tiers get richer material, trim,
	-- glow, and a small matching light. `tier` is the label shown in the UI.
	PedestalTiers = {
		Common = {
			tier = "Stone",
			rank = 1,
			columnMaterial = "Slate",
			topMaterial = "Marble",
			trim = { 176, 154, 112 },
			glow = false,
			lightRange = 0,
			lightBrightness = 0,
		},
		Rare = {
			tier = "Polished",
			rank = 2,
			columnMaterial = "Marble",
			topMaterial = "Marble",
			trim = { 96, 170, 214 },
			glow = false,
			lightRange = 0,
			lightBrightness = 0,
		},
		Legendary = {
			tier = "Gilded",
			rank = 3,
			columnMaterial = "Marble",
			topMaterial = "Metal",
			trim = { 235, 178, 70 },
			glow = true,
			lightRange = 8,
			lightBrightness = 1.2,
		},
		Mythic = {
			tier = "Mythic",
			rank = 4,
			columnMaterial = "Granite",
			topMaterial = "Neon",
			trim = { 196, 92, 224 },
			glow = true,
			lightRange = 12,
			lightBrightness = 2,
		},
	},
}

GameConfig.Rarities = {
	Common = {
		label = "Common",
		short = "C",
		color = { 196, 178, 140 },
		rank = 1,
	},
	Rare = {
		label = "Rare",
		short = "R",
		color = { 78, 160, 220 },
		rank = 2,
	},
	Legendary = {
		label = "Legendary",
		short = "L",
		color = { 235, 166, 58 },
		rank = 3,
	},
	Mythic = {
		label = "Mythic",
		short = "M",
		color = { 196, 92, 224 },
		rank = 4,
	},
}

GameConfig.Relics = {
	ClayAnkh = {
		name = "Clay Ankh",
		description = "A modest funerary ankh pressed from river clay.",
		rarity = "Common",
		weight = 8,
		value = 90,
		incomePerMinute = 4,
		templeIds = { "TutorialRuins" },
		visual = { kind = "ankh", primary = { 166, 118, 74 }, secondary = { 92, 64, 40 }, glow = false },
	},
	GoldenScarab = {
		name = "Golden Scarab",
		description = "A gilded scarab said to carry the sun across the underworld.",
		rarity = "Common",
		weight = 10,
		value = 140,
		incomePerMinute = 6,
		templeIds = { "TutorialRuins" },
		visual = { kind = "scarab", primary = { 222, 175, 61 }, secondary = { 133, 96, 28 }, glow = false },
	},
	SunstoneIdol = {
		name = "Sunstone Idol",
		description = "A squat idol cut from warm, glassy sunstone.",
		rarity = "Rare",
		weight = 22,
		value = 520,
		incomePerMinute = 18,
		templeIds = { "TutorialRuins", "ForgottenCatacombs" },
		visual = { kind = "idol", primary = { 226, 146, 62 }, secondary = { 110, 58, 26 }, glow = true },
	},
	WhisperingMask = {
		name = "Whispering Mask",
		description = "The hollow eyes seem to follow every visitor in the museum.",
		rarity = "Rare",
		weight = 26,
		value = 650,
		incomePerMinute = 22,
		templeIds = { "TutorialRuins" },
		visual = { kind = "mask", primary = { 108, 168, 148 }, secondary = { 44, 84, 76 }, glow = false },
	},
	ObsidianUrn = {
		name = "Obsidian Urn",
		description = "Volcanic glass etched with a forgotten dynasty's seal.",
		rarity = "Rare",
		weight = 24,
		value = 700,
		incomePerMinute = 24,
		templeIds = { "ForgottenCatacombs" },
		visual = { kind = "urn", primary = { 42, 40, 48 }, secondary = { 108, 214, 206 }, glow = true },
	},
	AnubisRelic = {
		name = "Anubis Relic",
		description = "A jackal-headed guardian statue of black basalt and gold.",
		rarity = "Legendary",
		weight = 40,
		value = 2400,
		incomePerMinute = 70,
		templeIds = { "ForgottenCatacombs" },
		visual = { kind = "jackal", primary = { 38, 34, 32 }, secondary = { 220, 170, 62 }, glow = false },
	},
	VoidCrystal = {
		name = "Void Crystal",
		description = "A humming shard of technology that predates the temples.",
		rarity = "Legendary",
		weight = 44,
		value = 3000,
		incomePerMinute = 90,
		templeIds = { "ForgottenCatacombs" },
		visual = { kind = "crystal", primary = { 68, 214, 220 }, secondary = { 30, 84, 110 }, glow = true },
	},
	HeartOfTheVault = {
		name = "Heart of the Vault",
		description = "A mythic engine core. Its pulse wakes every trap in the temple.",
		rarity = "Mythic",
		weight = 65,
		value = 12000,
		incomePerMinute = 260,
		templeIds = { "ForgottenCatacombs" },
		visual = { kind = "core", primary = { 196, 92, 224 }, secondary = { 68, 30, 96 }, glow = true },
	},
	TideAmulet = {
		name = "Tide Amulet",
		description = "A wave-worn medallion that still drips brine onto the pedestal.",
		rarity = "Rare",
		weight = 20,
		value = 620,
		incomePerMinute = 21,
		templeIds = { "ForgottenCatacombs", "SunkenSanctum" },
		visual = { kind = "crystal", primary = { 62, 150, 210 }, secondary = { 24, 64, 110 }, glow = true },
	},
	SerpentCrown = {
		name = "Serpent Crown",
		description = "A coiled serpent of verdigris and gold, its eyes set with jade.",
		rarity = "Legendary",
		weight = 38,
		value = 2200,
		incomePerMinute = 66,
		templeIds = { "SunkenSanctum" },
		visual = { kind = "mask", primary = { 96, 170, 120 }, secondary = { 196, 150, 60 }, glow = true },
	},
	AbyssalPearl = {
		name = "Abyssal Pearl",
		description = "A sphere of pressure-hardened nacre torn from the drowned deep.",
		rarity = "Legendary",
		weight = 46,
		value = 3200,
		incomePerMinute = 95,
		templeIds = { "SunkenSanctum" },
		visual = { kind = "core", primary = { 120, 200, 230 }, secondary = { 30, 70, 110 }, glow = true },
	},
	SunkenIdol = {
		name = "Sunken Idol",
		description = "A mythic idol of the drowned king. The sanctum trembles when it stirs.",
		rarity = "Mythic",
		weight = 70,
		value = 15000,
		incomePerMinute = 300,
		templeIds = { "SunkenSanctum" },
		visual = { kind = "idol", primary = { 64, 180, 190 }, secondary = { 20, 80, 90 }, glow = true },
	},
	-- Void Citadel (endgame) relics. These are the top of the progression curve:
	-- every one is Legendary or Mythic, heavy, and worth far more than the
	-- Sunken Sanctum haul, so a successful run is the largest single payout.
	-- The three lightest (38 + 44 + 70 = 152) fit a fully upgraded backpack
	-- (160), so requiredRelics = 3 below is always haulable; the Eye (88) is
	-- the greed prize that can only be carried alongside one companion.
	VoidSigil = {
		name = "Void Sigil",
		description = "A black disc that swallows light. The Citadel's wards answer to it.",
		rarity = "Legendary",
		weight = 38,
		value = 4200,
		incomePerMinute = 120,
		templeIds = { "VoidCitadel" },
		visual = { kind = "crystal", primary = { 150, 96, 224 }, secondary = { 36, 20, 64 }, glow = true },
	},
	AbyssalCrown = {
		name = "Abyssal Crown",
		description = "A circlet of pressure-warped gold recovered from the void beyond the sanctum.",
		rarity = "Legendary",
		weight = 44,
		value = 5200,
		incomePerMinute = 150,
		templeIds = { "VoidCitadel" },
		visual = { kind = "mask", primary = { 190, 150, 70 }, secondary = { 60, 30, 90 }, glow = true },
	},
	StarlessIdol = {
		name = "Starless Idol",
		description = "An idol carved in a shape the eye refuses to hold. It is always cold.",
		rarity = "Mythic",
		weight = 70,
		value = 20000,
		incomePerMinute = 380,
		templeIds = { "VoidCitadel" },
		visual = { kind = "idol", primary = { 46, 40, 66 }, secondary = { 128, 64, 200 }, glow = true },
	},
	EyeOfTheVoid = {
		name = "Eye of the Void",
		description = "The Citadel's crown jewel. The endgame prize of the entire collection.",
		rarity = "Mythic",
		weight = 88,
		value = 40000,
		incomePerMinute = 700,
		templeIds = { "VoidCitadel" },
		visual = { kind = "core", primary = { 200, 80, 240 }, secondary = { 40, 10, 70 }, glow = true },
	},
}

GameConfig.Upgrades = {
	SprintBoots = {
		name = "Sprint Boots",
		description = "Reduces the movement penalty caused by carried weight.",
		maxLevel = 5,
		basePrice = 200,
		priceGrowth = 1.75,
		order = 1,
		effect = "weightPenaltyReductionPerLevel",
		perLevel = 0.04,
	},
	Backpack = {
		name = "Reinforced Backpack",
		description = "Adds carrying capacity for heavier relics.",
		maxLevel = 6,
		basePrice = 250,
		priceGrowth = 1.75,
		order = 2,
		effect = "capacityPerLevel",
		perLevel = 20,
	},
	Armor = {
		name = "Reinforced Armor",
		description = "Increases maximum health, improving trap survivability.",
		maxLevel = 5,
		basePrice = 300,
		priceGrowth = 1.75,
		order = 3,
		effect = "maxHealthPerLevel",
		perLevel = 20,
	},
	MuseumFloor = {
		name = "Museum Expansion",
		description = "Expands the exhibition floor, unlocking three pedestals per level.",
		maxLevel = 2,
		basePrice = 800,
		priceGrowth = 2.1,
		order = 4,
		effect = "pedestalsPerLevel",
		perLevel = 3,
	},
	ExtraPedestal = {
		name = "Extra Pedestal",
		description = "Installs one additional display pedestal.",
		maxLevel = 2,
		basePrice = 500,
		priceGrowth = 2.1,
		order = 5,
		effect = "pedestalsPerLevel",
		perLevel = 1,
	},
	-- Museum building enhancements. `effect = "visual"`; these do not change
	-- gameplay numbers, only the fixtures the plot builder renders. They are
	-- bought through the same UpgradeService pipeline as every other upgrade.
	MarblePillars = {
		name = "Marble Colonnade",
		description = "Adds carved marble pillars to every wing.",
		maxLevel = 3,
		basePrice = 400,
		priceGrowth = 1.9,
		order = 6,
		effect = "visual",
		perLevel = 1,
	},
	Lighting = {
		name = "Gallery Lighting",
		description = "Sconces and spotlights brighten the exhibits.",
		maxLevel = 3,
		basePrice = 500,
		priceGrowth = 1.9,
		order = 7,
		effect = "visual",
		perLevel = 1,
	},
	GlassCases = {
		name = "Glass Display Cases",
		description = "Encases each relic behind polished glass.",
		maxLevel = 2,
		basePrice = 700,
		priceGrowth = 2.0,
		order = 8,
		effect = "visual",
		perLevel = 1,
	},
	VelvetRopes = {
		name = "Velvet Ropes",
		description = "Cordons every exhibit with velvet ropes on brass posts.",
		maxLevel = 2,
		basePrice = 650,
		priceGrowth = 2.0,
		order = 9,
		effect = "visual",
		perLevel = 1,
	},
	Chandeliers = {
		name = "Crystal Chandeliers",
		description = "Suspends crystal chandeliers from the ceiling of each wing.",
		maxLevel = 2,
		basePrice = 900,
		priceGrowth = 2.1,
		order = 10,
		effect = "visual",
		perLevel = 1,
	},
}

GameConfig.Temples = {
	TutorialRuins = {
		name = "Tutorial Ruins",
		description = "A short sunlit hall. Learn to steal, carry, and escape.",
		difficulty = 1,
		order = 1,
		minExtractions = 0,
		unlockPrice = 0,
		durationSeconds = 300,
		requiredRelics = 1,
		theme = "sandstone",
		origin = { x = 0, y = 0, z = 300 },
		hall = { width = 56, length = 150, height = 28 },
		spawnOffset = { x = 0, y = 4, z = 16 },
		extractionOffset = { x = 0, y = 4, z = 6 },
		portalOffset = { x = 0, y = 0, z = 70 },
		relicSpawns = {
			{ definitionId = "ClayAnkh", position = { x = -18, y = 4, z = 46 } },
			{ definitionId = "WhisperingMask", position = { x = 22, y = 4, z = 64 } },
			{ definitionId = "GoldenScarab", position = { x = 18, y = 4, z = 82 } },
			{ definitionId = "SunstoneIdol", position = { x = -16, y = 4, z = 122 } },
		},
		obstacles = {
			{ position = { x = 0, y = 3, z = 62 }, size = { x = 10, y = 6, z = 10 } },
			{ position = { x = -14, y = 3, z = 100 }, size = { x = 12, y = 6, z = 8 } },
			{ position = { x = 14, y = 3, z = 100 }, size = { x = 12, y = 6, z = 8 } },
		},
		traps = {
			{
				kind = "dart",
				label = "Dart Trap",
				position = { x = 0, y = 9, z = 72 },
				zone = { x = 52, y = 12, z = 8 },
				interval = 5,
				warning = 1.4,
				active = 0.45,
				damage = 12,
			},
			{
				kind = "boulder",
				label = "Rolling Boulder",
				startOffset = { x = 0, y = 6, z = 140 },
				endOffset = { x = 0, y = 6, z = 30 },
				radius = 7,
				interval = 10.5,
				warning = 2.4,
				travel = 3.5,
				-- Tutorial temple: teaches the dodge rather than punishing a
				-- first-timer. Lower damage and a longer tell than later temples.
				damage = 26,
			},
		},
	},
	ForgottenCatacombs = {
		name = "Forgotten Catacombs",
		description = "Pitch-dark tunnels patrolled by stone and machine alike.",
		difficulty = 2,
		order = 2,
		minExtractions = 1,
		unlockPrice = 500,
		durationSeconds = 360,
		requiredRelics = 2,
		theme = "catacomb",
		origin = { x = 0, y = 0, z = 540 },
		hall = { width = 64, length = 190, height = 26 },
		spawnOffset = { x = 0, y = 4, z = 18 },
		extractionOffset = { x = 0, y = 4, z = 6 },
		portalOffset = { x = 0, y = 0, z = 70 },
		relicSpawns = {
			{ definitionId = "ObsidianUrn", position = { x = -20, y = 4, z = 44 } },
			{ definitionId = "SunstoneIdol", position = { x = 20, y = 4, z = 78 } },
			{ definitionId = "VoidCrystal", position = { x = -18, y = 4, z = 126 } },
			{ definitionId = "AnubisRelic", position = { x = 18, y = 4, z = 160 } },
			{ definitionId = "HeartOfTheVault", position = { x = 0, y = 4, z = 186 } },
		},
		obstacles = {
			{ position = { x = -12, y = 3, z = 58 }, size = { x = 12, y = 6, z = 10 } },
			{ position = { x = 14, y = 3, z = 96 }, size = { x = 14, y = 6, z = 8 } },
			{ position = { x = -14, y = 3, z = 140 }, size = { x = 12, y = 6, z = 10 } },
			{ position = { x = 12, y = 3, z = 170 }, size = { x = 10, y = 6, z = 8 } },
		},
		traps = {
			{
				kind = "dart",
				label = "Dart Trap",
				position = { x = 0, y = 8, z = 70 },
				zone = { x = 60, y = 12, z = 8 },
				interval = 4.2,
				warning = 1.2,
				active = 0.5,
				damage = 16,
			},
			{
				kind = "dart",
				label = "Dart Trap",
				position = { x = 0, y = 8, z = 132 },
				zone = { x = 60, y = 12, z = 8 },
				interval = 4.6,
				warning = 1.2,
				active = 0.5,
				damage = 16,
			},
			{
				kind = "boulder",
				label = "Rolling Boulder",
				startOffset = { x = 0, y = 6, z = 180 },
				endOffset = { x = 0, y = 6, z = 34 },
				radius = 7,
				interval = 11,
				warning = 2.2,
				travel = 4,
				damage = 45,
			},
		},
		guardians = {
			{
				kind = "Guardian",
				label = "Stone Guardian",
				waypoints = {
					{ x = -14, y = 3, z = 60 },
					{ x = -14, y = 3, z = 132 },
					{ x = 14, y = 3, z = 132 },
					{ x = 14, y = 3, z = 60 },
				},
			},
		},
	},
	SunkenSanctum = {
		name = "Sunken Sanctum",
		description = "A flooded vault where spinning blades guard the drowned king's horde.",
		difficulty = 3,
		order = 3,
		minExtractions = 2,
		unlockPrice = 1500,
		durationSeconds = 420,
		requiredRelics = 3,
		theme = "sanctum",
		origin = { x = 0, y = 0, z = 820 },
		hall = { width = 72, length = 220, height = 30 },
		spawnOffset = { x = 0, y = 4, z = 18 },
		extractionOffset = { x = 0, y = 4, z = 6 },
		portalOffset = { x = 0, y = 0, z = 70 },
		relicSpawns = {
			{ definitionId = "TideAmulet", position = { x = -22, y = 4, z = 50 } },
			{ definitionId = "SerpentCrown", position = { x = 22, y = 4, z = 92 } },
			{ definitionId = "AbyssalPearl", position = { x = -20, y = 4, z = 150 } },
			{ definitionId = "SunkenIdol", position = { x = 0, y = 4, z = 208 } },
		},
		obstacles = {
			{ position = { x = -14, y = 3, z = 66 }, size = { x = 12, y = 6, z = 10 } },
			{ position = { x = 14, y = 3, z = 112 }, size = { x = 14, y = 6, z = 8 } },
			{ position = { x = -14, y = 3, z = 168 }, size = { x = 12, y = 6, z = 10 } },
		},
		traps = {
			{
				kind = "blade",
				label = "Whirling Blade",
				position = { x = 0, y = 4, z = 82 },
				length = 30,
				speed = 1.5,
				hitRadius = 3.4,
				damage = 28,
			},
			{
				kind = "dart",
				label = "Dart Trap",
				position = { x = 0, y = 8, z = 132 },
				zone = { x = 66, y = 12, z = 8 },
				interval = 3.8,
				warning = 1.1,
				active = 0.5,
				damage = 18,
			},
			{
				kind = "blade",
				label = "Whirling Blade",
				position = { x = 0, y = 4, z = 176 },
				length = 26,
				speed = 1.9,
				hitRadius = 3.4,
				damage = 30,
			},
			{
				kind = "boulder",
				label = "Rolling Boulder",
				startOffset = { x = 0, y = 6, z = 210 },
				endOffset = { x = 0, y = 6, z = 36 },
				radius = 7,
				interval = 9,
				warning = 2.2,
				travel = 4.6,
				damage = 50,
			},
		},
		guardians = {
			{
				kind = "Guardian",
				label = "Drowned Warden",
				walkSpeed = 13,
				damage = 24,
				waypoints = {
					{ x = -16, y = 3, z = 70 },
					{ x = -16, y = 3, z = 170 },
					{ x = 16, y = 3, z = 170 },
					{ x = 16, y = 3, z = 70 },
				},
			},
			{
				kind = "Guardian",
				label = "Deep Sentinel",
				walkSpeed = 15,
				damage = 26,
				aggroRange = 52,
				bodyColor = { 62, 98, 106 },
				eyeColor = { 96, 226, 232 },
				waypoints = {
					{ x = 0, y = 3, z = 120 },
					{ x = -20, y = 3, z = 200 },
					{ x = 20, y = 3, z = 200 },
					{ x = 0, y = 3, z = 120 },
				},
			},
		},
	},
	VoidCitadel = {
		name = "Void Citadel",
		description = "The endgame. A collapsed star-temple crawling with Void Wardens. Only the very best leave alive.",
		difficulty = 5,
		order = 4,
		minExtractions = 4,
		unlockPrice = 5000,
		durationSeconds = 480,
		requiredRelics = 3,
		theme = "void",
		origin = { x = 0, y = 0, z = 1130 },
		hall = { width = 84, length = 260, height = 34 },
		spawnOffset = { x = 0, y = 4, z = 18 },
		extractionOffset = { x = 0, y = 4, z = 6 },
		portalOffset = { x = 0, y = 0, z = 70 },
		relicSpawns = {
			{ definitionId = "VoidSigil", position = { x = -24, y = 4, z = 54 } },
			{ definitionId = "AbyssalCrown", position = { x = 24, y = 4, z = 100 } },
			{ definitionId = "StarlessIdol", position = { x = -22, y = 4, z = 170 } },
			{ definitionId = "EyeOfTheVoid", position = { x = 0, y = 4, z = 244 } },
		},
		obstacles = {
			{ position = { x = -16, y = 3, z = 74 }, size = { x = 14, y = 6, z = 10 } },
			{ position = { x = 16, y = 3, z = 128 }, size = { x = 16, y = 6, z = 8 } },
			{ position = { x = -16, y = 3, z = 196 }, size = { x = 14, y = 6, z = 10 } },
			{ position = { x = 14, y = 3, z = 224 }, size = { x = 12, y = 6, z = 8 } },
		},
		traps = {
			{
				kind = "dart",
				label = "Void Dart",
				position = { x = 0, y = 8, z = 78 },
				zone = { x = 78, y = 12, z = 8 },
				interval = 3.2,
				warning = 0.9,
				active = 0.55,
				damage = 24,
			},
			{
				kind = "blade",
				label = "Rift Blade",
				position = { x = 0, y = 4, z = 132 },
				length = 34,
				speed = 2.2,
				hitRadius = 3.6,
				damage = 38,
			},
			{
				kind = "dart",
				label = "Void Dart",
				position = { x = 0, y = 8, z = 188 },
				zone = { x = 78, y = 12, z = 8 },
				interval = 3.0,
				warning = 0.8,
				active = 0.55,
				damage = 24,
			},
			{
				kind = "boulder",
				label = "Collapsing Star",
				startOffset = { x = 0, y = 6, z = 250 },
				endOffset = { x = 0, y = 6, z = 40 },
				radius = 8,
				interval = 7.5,
				warning = 1.7,
				travel = 5.2,
				damage = 60,
			},
		},
		guardians = {
			{
				kind = "VoidWarden",
				label = "Void Warden",
				waypoints = {
					{ x = -22, y = 3, z = 80 },
					{ x = -22, y = 3, z = 210 },
					{ x = 22, y = 3, z = 210 },
					{ x = 22, y = 3, z = 80 },
				},
			},
			{
				kind = "VoidWarden",
				label = "Void Warden",
				waypoints = {
					{ x = 0, y = 3, z = 150 },
					{ x = -28, y = 3, z = 240 },
					{ x = 28, y = 3, z = 240 },
					{ x = 0, y = 3, z = 150 },
				},
			},
			{
				kind = "VoidWarden",
				label = "Rift Keeper",
				walkSpeed = 19,
				damage = 36,
				aggroRange = 70,
				bodyColor = { 44, 36, 68 },
				eyeColor = { 210, 96, 255 },
				waypoints = {
					{ x = 0, y = 3, z = 60 },
					{ x = 0, y = 3, z = 250 },
				},
			},
		},
	},
}

GameConfig.Hazards = {
	CollapseDamage = 18,
	CollapseTickSeconds = 1.25,
	DamageInvulnerabilitySeconds = 0.35,
}

-- Guardian enemies (see docs/ADR/0008-guardian-enemies.md). Shared tuning
-- lives here; each temple lists its own guardians. Guardians patrol a route,
-- chase a player they can see within `AggroRange`, and deal contact damage.
--
-- This block was sharpened to drive progression and monetization: guardians
-- detect faster, hold a chase longer once they have seen a player (see
-- `AggroLingerSeconds`), pursue to a player's last-known position when sight is
-- broken (see `HuntSeconds`), and strike more often. Stealth is a narrower
-- margin than it used to be.
GameConfig.Enemies = {
	TickSeconds = 0.08,
	-- How long an aggroed guardian keeps pursuing after losing sight.
	AggroLingerSeconds = 5,
	-- How long a guardian keeps hunting toward a target's last-known position
	-- after line of sight (or stealth) is broken. During this window the chase
	-- state stays active, so ducking behind cover no longer instantly ends it.
	HuntSeconds = 4,
	-- How close the guardian must get to a last-known position to consider the
	-- hunt satisfied and resume its patrol.
	HuntArriveTolerance = 5,
	-- Extra distance beyond `AggroRange` before a chase is dropped.
	DeaggroPadding = 4,
	-- A guardian pauses this long after landing a hit before it can hit again.
	ContactCooldownSeconds = 0.85,
	-- Movement speed while patrolling vs. chasing, as a multiplier of the
	-- guardian's configured walk speed. Chasing guardians move faster now.
	Patrol = {
		WaypointTolerance = 4,
		RepathSeconds = 0.35,
	},
	Chase = {
		RepathSeconds = 0.12,
		SpeedMultiplier = 1.35,
	},
	-- Visual telegraph flashed to nearby players when a guardian first aggros.
	WarnColor = { 255, 96, 80 },
}

-- Damage, speed and reward tuning are data; the domain never hardcodes them.
GameConfig.Enemies.Kinds = {
	Guardian = {
		name = "Stone Guardian",
		health = 1000,
		walkSpeed = 12,
		damage = 24,
		aggroRange = 54,
		-- Narrower than before: a guardian notices a player at a wider radius
		-- and strikes once it is nearly on top of them.
		contactRange = 7,
		attackWindup = 0.4,
		bodyColor = { 96, 88, 76 },
		eyeColor = { 255, 96, 80 },
	},
	-- Endgame guardian for the Void Citadel. Faster, wider aggro, harder hits,
	-- and a shorter windup, so a caught player must react immediately.
	VoidWarden = {
		name = "Void Warden",
		health = 1500,
		walkSpeed = 17,
		damage = 32,
		aggroRange = 64,
		contactRange = 8,
		attackWindup = 0.35,
		bodyColor = { 44, 36, 68 },
		eyeColor = { 210, 96, 255 },
	},
}

GameConfig.RateLimits = {
	ActionBurst = 10,
	ActionPerSecond = 5,
	RelicCollectPerSecond = 2,
	PedestalInteractPerSecond = 3,
	PurchasePerSecond = 2,
}

GameConfig.Networking = {
	RequestStateCooldownSeconds = 1,
}

-- Monetization (see docs/ADR/0007-monetization.md and docs/MONETIZATION.md).
-- IDs of 0 mean "not configured"; services must refuse to prompt or grant when
-- an ID is unset, so the game stays playable before the products exist.
GameConfig.Monetization = {
	OfflineDoubleProductId = 0,
	OfflineDoublePriceRobux = 199,
	OfflineDoubleMultiplier = 2,
	VipPassId = 0,
	VipName = "VIP Pass",
	-- Instant Revive: a one-shot Developer Product offered when a player is
	-- downed inside a hard temple. Buying it revives the player in place and
	-- keeps their carried relics; ignoring it resolves the death normally.
	-- ID 0 = not configured (the prompt is suppressed and deaths resolve).
	InstantReviveProductId = 0,
	InstantRevivePriceRobux = 99,
	-- How long the on-death revive prompt stays open before the death resolves
	-- on its own. Kept short so it never becomes a free pause.
	InstantReviveWindowSeconds = 12,
	-- Temples that can offer the revive prompt. Void Citadel and Sunken Sanctum
	-- are the "hard temples" named in the design brief.
	ReviveTempleIds = { "SunkenSanctum", "VoidCitadel" },
}

-- Accessibility and feedback settings (see docs/HCI_DESIGN.md). `defaults` seeds
-- new profiles; `TextScaleOptions` bounds the allowed text-size values.
GameConfig.Settings = {
	Defaults = {
		soundEnabled = true,
		visualEffects = true,
		reducedMotion = false,
		colorblindMode = false,
		textScale = "Normal",
	},
	TextScaleOptions = { "Normal", "Large", "Huge" },
	TextScaleMultipliers = { Normal = 1, Large = 1.25, Huge = 1.5 },
}

-- Audio feedback (see docs/HCI_DESIGN.md and docs/ASSETS.md). Asset ids default
-- to 0 ("not configured") so the game is silent but playable before sounds are
-- authored. A non-zero id plays through a pooled Sound; `SoundEnabled` settings
-- gate playback. This mirrors the procedural-blockout asset plan.
GameConfig.Audio = {
	Enabled = true,
	MasterVolume = 0.6,
	Sounds = {
		UiClick = { assetId = 0, volume = 0.5 },
		UiOpen = { assetId = 0, volume = 0.5 },
		UiClose = { assetId = 0, volume = 0.4 },
		RelicCollect = { assetId = 0, volume = 0.7 },
		Damage = { assetId = 0, volume = 0.8 },
		ExtractionSuccess = { assetId = 0, volume = 0.8 },
		ExtractionFail = { assetId = 0, volume = 0.7 },
		Warning = { assetId = 0, volume = 0.6 },
		TutorialAdvance = { assetId = 0, volume = 0.6 },
		TutorialComplete = { assetId = 0, volume = 0.8 },
	},
}

-- Data-driven onboarding (see docs/ADR/0009-tutorial-and-ux.md). Steps advance
-- in order as the player performs the action each step teaches. `hint` is shown
-- as a persistent objective; `complete` is a snapshot field the server sets.
-- The server only counts steps the player actually reaches, so this is a guide,
-- never a gate. An empty list disables the tutorial entirely.
GameConfig.Tutorial = {
	Steps = {
		{
			id = "welcome",
			title = "First Heist",
			text = "Steal relics from the Tutorial Ruins, then carry them to the extraction altar before the ground shakes. Only extracted relics are yours to keep.",
			hint = "Enter the Tutorial Ruins portal.",
			complete = "enteredTemple",
		},
		{
			id = "collect",
			title = "Grab the loot",
			text = "Walk up to a glowing relic and take it. Heavier loads slow you down, so watch the weight bar.",
			hint = "Collect a relic.",
			complete = "collectedRelic",
		},
		{
			id = "extract",
			title = "Escape with the goods",
			text = "Return to the extraction altar at the temple entrance and deposit your relics to bank them.",
			hint = "Extract at the altar.",
			complete = "extracted",
		},
		{
			id = "display",
			title = "Put it on display",
			text = "Exhibit an owned relic on a museum pedestal to earn passive income while you are away.",
			hint = "Exhibit a relic at your museum.",
			complete = "exhibited",
		},
	},
}

return GameConfig
