--!nonstrict
-- Composes the player-facing state snapshot sent to clients.
-- Clients receive definition ids and resolve display data from shared config,
-- keeping payloads small and preventing the client from inventing values.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local GameConfig = require(ReplicatedStorage.Shared.Config.GameConfig)
local Encumbrance = require(ReplicatedStorage.Shared.Domain.Encumbrance)
local Economy = require(ReplicatedStorage.Shared.Domain.Economy)
local Inventory = require(ReplicatedStorage.Shared.Domain.Inventory)
local MuseumBuilder = require(ReplicatedStorage.Shared.Domain.MuseumBuilder)
local Progression = require(ReplicatedStorage.Shared.Domain.Progression)
local Tutorial = require(ReplicatedStorage.Shared.Domain.Tutorial)

local ViewService = {}

local state = { ctx = nil }

function ViewService:Init(ctx)
	state.ctx = ctx
end

local function countExhibited(profile): (number, number)
	local incomePerMinute = 0
	local count = 0
	for _, uid in profile.museum do
		local owned = profile.relics[uid]
		local definition = owned and GameConfig.Relics[owned.id]
		if definition then
			incomePerMinute += definition.incomePerMinute
			count += 1
		end
	end
	return incomePerMinute, count
end

function ViewService:Build(player: Player)
	local services = state.ctx.Services
	local profile = services.PlayerData:GetProfile(player)
	if profile == nil then
		return nil
	end

	local now = os.time()
	local upgrades = profile.upgrades
	local movement = GameConfig.Movement
	local maxPedestals = GameConfig.Museum.MaxPedestals or 8

	local backpackLevel = upgrades.Backpack or 0
	local bootsLevel = upgrades.SprintBoots or 0
	local armorLevel = upgrades.Armor or 0
	local floorLevel = upgrades.MuseumFloor or 0
	local pedestalLevel = upgrades.ExtraPedestal or 0

	local capacity = Encumbrance.capacity(movement, backpackLevel)
	local pedestalCount = Economy.pedestalCount(
		movement.BasePedestals,
		floorLevel,
		GameConfig.Upgrades.MuseumFloor.perLevel,
		pedestalLevel,
		GameConfig.Upgrades.ExtraPedestal.perLevel,
		maxPedestals
	)

	local exhibitedIncome, exhibitedCount = countExhibited(profile)
	local incomeRate = Economy.incomeRatePerSecond(
		exhibitedIncome,
		floorLevel,
		GameConfig.Museum.IncomePerMinuteFloorBonus,
		GameConfig.Museum.MaxIncomeRatePerMinute
	)

	local relics = {}
	for uid, owned in profile.relics do
		local definition = GameConfig.Relics[owned.id]
		if definition then
			table.insert(relics, {
				uid = uid,
				id = owned.id,
				name = definition.name,
				rarity = definition.rarity,
				weight = definition.weight,
				value = definition.value,
				incomePerSecond = definition.incomePerMinute / 60,
				acquiredAt = owned.acquiredAt,
				exhibited = Inventory.isExhibited(profile, uid),
			})
		end
	end
	table.sort(relics, function(a, b)
		if a.acquiredAt == b.acquiredAt then
			return a.uid < b.uid
		end
		return a.acquiredAt > b.acquiredAt
	end)

	local displayed = table.clone(profile.museum)

	local allWings = GameConfig.MuseumBuilding.Wings
	local placements = MuseumBuilder.placements(allWings)
	local placementById: { [string]: MuseumBuilder.Placement } = {}
	for _, placement in placements do
		placementById[placement.id] = placement
	end

	local pedestals = {}
	for index = 1, maxPedestals do
		local id = tostring(index)
		local placement = placementById[id]
		local uid = profile.museum[id]
		local owned = uid and profile.relics[uid]
		local definition = owned and GameConfig.Relics[owned.id]
		local tier = MuseumBuilder.tierForRarity(
			GameConfig.MuseumBuilding.PedestalTiers,
			definition and definition.rarity or nil
		)
		table.insert(pedestals, {
			id = id,
			unlocked = index <= pedestalCount,
			uid = uid,
			wingId = placement and placement.wingId or nil,
			wingName = placement and placement.wingName or nil,
			tier = tier and tier.tier or nil,
		})
	end

	local wings = {}
	for _, wing in allWings do
		table.insert(wings, {
			id = wing.id,
			name = wing.name,
			description = wing.description,
			unlocked = floorLevel >= (wing.unlockLevel or 0),
			unlockLevel = wing.unlockLevel,
			pedestalCount = #wing.pedestalSlots,
		})
	end

	local enhancements = {}
	local featureLevels =
		MuseumBuilder.featureLevels(GameConfig.MuseumBuilding.Enhancements, GameConfig.Upgrades, profile.upgrades)
	for feature, level in featureLevels do
		table.insert(enhancements, { feature = feature, level = level })
	end

	local temples = {}
	for templeId, config in GameConfig.Temples do
		local unlocked = Progression.isUnlocked(profile.unlockedTemples, templeId)
		local requirementsMet = profile.stats.extractions >= config.minExtractions
		local canUnlock = (not unlocked) and requirementsMet and profile.gold >= config.unlockPrice
		table.insert(temples, {
			id = templeId,
			name = config.name,
			description = config.description,
			difficulty = config.difficulty,
			order = config.order,
			unlocked = unlocked,
			requirementsMet = requirementsMet,
			canUnlock = canUnlock,
			minExtractions = config.minExtractions,
			unlockPrice = config.unlockPrice,
			requiredRelics = config.requiredRelics,
			durationSeconds = config.durationSeconds,
			relicCount = #config.relicSpawns,
		})
	end
	table.sort(temples, function(a, b)
		return a.order < b.order
	end)

	local expedition = nil
	local expeditionState = services.Expedition:GetState(player)
	if expeditionState then
		local temple = GameConfig.Temples[expeditionState.templeId]
		local carried = {}
		local totalWeight = 0
		for _, item in expeditionState.carried do
			local definition = GameConfig.Relics[item.definitionId]
			if definition then
				totalWeight += definition.weight
				table.insert(carried, {
					uid = item.uid,
					id = item.definitionId,
					name = definition.name,
					rarity = definition.rarity,
					weight = definition.weight,
					value = definition.value,
				})
			end
		end
		local reduction = bootsLevel * GameConfig.Upgrades.SprintBoots.perLevel
		local multiplier = Encumbrance.multiplier(totalWeight, movement, reduction)
		expedition = {
			templeId = expeditionState.templeId,
			templeName = temple and temple.name or expeditionState.templeId,
			startedAt = expeditionState.startedAt,
			endsAt = expeditionState.endsAt,
			collapsing = expeditionState.collapsing,
			carried = carried,
			weight = totalWeight,
			capacity = capacity,
			speedMultiplier = multiplier,
			requiredRelics = temple and temple.requiredRelics or 1,
			durationSeconds = temple and temple.durationSeconds or 0,
			remainingRelics = #expeditionState.carried,
		}
	end

	local plot = services.Plot:GetPlot(player)
	local ephemeral = services.PlayerData:IsEphemeral(player)

	return {
		serverNow = now,
		gold = profile.gold,
		incomePerSecond = incomeRate,
		relics = relics,
		displayed = displayed,
		pedestals = pedestals,
		pedestalCount = pedestalCount,
		exhibitedCount = exhibitedCount,
		wings = wings,
		enhancements = enhancements,
		upgrades = {
			SprintBoots = bootsLevel,
			Backpack = backpackLevel,
			Armor = armorLevel,
			MuseumFloor = floorLevel,
			ExtraPedestal = pedestalLevel,
		},
		capacity = capacity,
		armorLevel = armorLevel,
		temples = temples,
		expedition = expedition,
		stats = profile.stats,
		settings = profile.settings,
		tutorialComplete = profile.tutorialComplete,
		tutorial = Tutorial.view(profile.tutorialStep or 0, (GameConfig.Tutorial and GameConfig.Tutorial.Steps) or {}),
		plotIndex = plot and plot.index or nil,
		ephemeral = ephemeral,
		maxCarried = GameConfig.Economy.MaxCarriedRelics,
		offlineCapSeconds = GameConfig.Economy.OfflineCapSeconds,
		vip = profile.vip == true,
		pendingOfflineGold = math.max(0, math.floor(profile.pendingOfflineGold or 0)),
		offlineDouble = {
			multiplier = GameConfig.Monetization.OfflineDoubleMultiplier,
			priceRobux = GameConfig.Monetization.OfflineDoublePriceRobux,
			purchasable = type(GameConfig.Monetization.OfflineDoubleProductId) == "number"
				and GameConfig.Monetization.OfflineDoubleProductId > 0,
		},
	}
end

return ViewService
