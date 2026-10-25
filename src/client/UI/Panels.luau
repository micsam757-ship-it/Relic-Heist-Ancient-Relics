--!nonstrict
-- Panel content builders. Each builder populates a modal body and returns a
-- render(snapshot) function invoked on every authoritative state update.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Theme = require(script.Parent.Theme)
local Components = require(script.Parent.Components)
local Net = require(script.Parent.Parent.Net)

local GameConfig = require(ReplicatedStorage.Shared.Config.GameConfig)
local Economy = require(ReplicatedStorage.Shared.Domain.Economy)
local Util = require(ReplicatedStorage.Shared.Utilities.Util)

local Panels = {}

local function clear(container: Instance)
	for _, child in container:GetChildren() do
		if child:IsA("GuiObject") then
			child:Destroy()
		end
	end
end

local function statRow(parent: Instance, label: string, value: string)
	local row = Components.panel(parent, {
		Size = UDim2.new(1, 0, 0, 28),
		Color = Theme.Color.PanelAlt,
		ClipsDescendants = true,
	})
	Components.label(row, {
		Text = label,
		TextSize = Theme.TextSize.Small,
		TextColor = Theme.Color.TextMuted,
		Size = UDim2.new(1, -12, 1, 0),
		Position = UDim2.fromOffset(8, 0),
	})
	Components.label(row, {
		Text = value,
		TextSize = Theme.TextSize.Small,
		TextColor = Theme.Color.Text,
		AlignX = Enum.TextXAlignment.Right,
		Size = UDim2.fromOffset(120, 1),
		Position = UDim2.new(1, -128, 0, 0),
		AlignY = Enum.TextYAlignment.Center,
	})
	return row
end

function Panels.Expeditions(body)
	local scroll = Components.scroll(body, { Size = UDim2.fromScale(1, 1) })
	return function(snapshot)
		clear(scroll)
		local onExpedition = snapshot.expedition ~= nil
		for _, temple in snapshot.temples do
			local row = Components.panel(scroll, {
				Size = UDim2.new(1, 0, 0, 118),
				Color = Theme.Color.PanelAlt,
				ClipsDescendants = true,
			})
			Components.label(row, {
				Text = temple.name,
				Font = Theme.Font.Heading,
				TextSize = Theme.TextSize.Body,
				TextColor = temple.unlocked and Theme.Color.Gold or Theme.Color.TextMuted,
				Size = UDim2.new(1, -160, 0, 26),
				Position = UDim2.fromOffset(12, 8),
			})
			Components.label(row, {
				Text = string.format(
					"Difficulty %d  •  %d relic(s)  •  %d:%02d",
					temple.difficulty,
					temple.relicCount,
					math.floor(temple.durationSeconds / 60),
					temple.durationSeconds % 60
				),
				TextSize = 13,
				TextColor = Theme.Color.TextMuted,
				Size = UDim2.new(1, -160, 0, 18),
				Position = UDim2.fromOffset(12, 32),
			})
			Components.label(row, {
				Text = temple.description,
				TextSize = Theme.TextSize.Small,
				TextColor = Theme.Color.TextDim,
				Size = UDim2.new(1, -160, 0, 44),
				Position = UDim2.fromOffset(12, 52),
				AlignY = Enum.TextYAlignment.Top,
			})

			local action
			if temple.unlocked then
				action = Components.button(row, {
					Text = "Enter",
					Size = UDim2.fromOffset(130, 40),
					Position = UDim2.new(1, -142, 0, 16),
					Color = Theme.Color.CyanDeep,
					OnClick = function()
						Net.send("EnterExpedition", { templeId = temple.id })
					end,
				})
				Components.setDisabled(action, onExpedition)
			elseif temple.canUnlock then
				Components.button(row, {
					Text = string.format("Unlock %s g", tostring(temple.unlockPrice)),
					Size = UDim2.fromOffset(130, 40),
					Position = UDim2.new(1, -142, 0, 16),
					Color = Theme.Color.GoldDeep,
					TextColor = Theme.Color.Background,
					OnClick = function()
						Net.send("UnlockTemple", { templeId = temple.id })
					end,
				})
			else
				local requirements = {}
				local extractions = (snapshot.stats and snapshot.stats.extractions) or 0
				if not temple.requirementsMet then
					local remaining = math.max(1, (temple.minExtractions or 0) - extractions)
					requirements[#requirements + 1] =
						string.format("%d/%d extractions (%d to go)", extractions, temple.minExtractions, remaining)
				end
				if snapshot.gold < temple.unlockPrice then
					requirements[#requirements + 1] =
						string.format("%s more gold", Util.formatNumber(temple.unlockPrice - snapshot.gold))
				end
				Components.label(row, {
					Text = #requirements > 0 and ("Need " .. table.concat(requirements, "\n"))
						or string.format("Unlock %s g", Util.formatNumber(temple.unlockPrice)),
					TextSize = 13,
					TextColor = Theme.Color.Danger,
					AlignX = Enum.TextXAlignment.Right,
					Size = UDim2.fromOffset(170, 60),
					Position = UDim2.new(1, -182, 0, 16),
					AlignY = Enum.TextYAlignment.Center,
				})
			end
		end
	end
end

function Panels.Shop(body)
	local scroll = Components.scroll(body, { Size = UDim2.fromScale(1, 1) })
	return function(snapshot)
		clear(scroll)
		local definitions = {}
		for id, definition in GameConfig.Upgrades do
			table.insert(definitions, { id = id, definition = definition })
		end
		table.sort(definitions, function(a, b)
			return a.definition.order < b.definition.order
		end)

		for _, entry in definitions do
			local definition = entry.definition
			local level = snapshot.upgrades[entry.id] or 0
			local price = Economy.upgradeCost(definition, level)
			local row = Components.panel(scroll, {
				Size = UDim2.new(1, 0, 0, 96),
				Color = Theme.Color.PanelAlt,
				ClipsDescendants = true,
			})
			Components.label(row, {
				Text = string.format("%s  (%d/%d)", definition.name, level, definition.maxLevel),
				Font = Theme.Font.Heading,
				TextSize = Theme.TextSize.Body,
				TextColor = Theme.Color.Gold,
				Size = UDim2.new(1, -160, 0, 26),
				Position = UDim2.fromOffset(12, 8),
			})
			Components.label(row, {
				Text = definition.description,
				TextSize = Theme.TextSize.Small,
				TextColor = Theme.Color.TextMuted,
				Size = UDim2.new(1, -160, 0, 40),
				Position = UDim2.fromOffset(12, 36),
				AlignY = Enum.TextYAlignment.Top,
			})
			if price == nil then
				local maxed = Components.button(row, {
					Text = "Maxed",
					Size = UDim2.fromOffset(130, 40),
					Position = UDim2.new(1, -142, 0, 16),
					Color = Theme.Color.PanelRaised,
				})
				Components.setDisabled(maxed, true)
			else
				local button = Components.button(row, {
					Text = string.format("Buy %s g", tostring(price)),
					Size = UDim2.fromOffset(130, 40),
					Position = UDim2.new(1, -142, 0, 16),
					Color = Theme.Color.GoldDeep,
					TextColor = Theme.Color.Background,
					OnClick = function()
						Net.send("BuyUpgrade", { upgradeId = entry.id })
					end,
				})
				Components.setDisabled(button, snapshot.gold < price)
			end
		end
	end
end

function Panels.Companions(body)
	local scroll = Components.scroll(body, { Size = UDim2.fromScale(1, 1) })
	return function(snapshot)
		clear(scroll)
		local companionView = snapshot.companions or { owned = {}, equipped = nil }
		local owned = companionView.owned or {}
		local equipped = companionView.equipped

		local definitions = {}
		for id, definition in GameConfig.Companions.Definitions do
			table.insert(definitions, { id = id, definition = definition })
		end
		table.sort(definitions, function(a, b)
			if a.definition.cost == b.definition.cost then
				return a.id < b.id
			end
			return a.definition.cost < b.definition.cost
		end)

		for _, entry in definitions do
			local definition = entry.definition
			local isOwned = owned[entry.id] == true
			local isEquipped = equipped == entry.id
			local row = Components.panel(scroll, {
				Size = UDim2.new(1, 0, 0, 110),
				Color = Theme.Color.PanelAlt,
				ClipsDescendants = true,
			})
			Components.badge(row, {
				rarity = definition.rarity,
				Position = UDim2.fromOffset(12, 10),
			})
			Components.label(row, {
				Text = string.format("%s%s", definition.name, isEquipped and "  (Equipped)" or ""),
				Font = Theme.Font.Heading,
				TextSize = Theme.TextSize.Body,
				TextColor = isEquipped and Theme.Color.Gold or Theme.Color.Text,
				Size = UDim2.new(1, -200, 0, 26),
				Position = UDim2.fromOffset(46, 8),
			})
			Components.label(row, {
				Text = definition.summary,
				TextSize = Theme.TextSize.Small,
				TextColor = Theme.Color.Cyan,
				Size = UDim2.new(1, -200, 0, 18),
				Position = UDim2.fromOffset(46, 32),
			})
			Components.label(row, {
				Text = definition.description,
				TextSize = Theme.TextSize.Small,
				TextColor = Theme.Color.TextMuted,
				Size = UDim2.new(1, -200, 0, 44),
				Position = UDim2.fromOffset(46, 52),
				AlignY = Enum.TextYAlignment.Top,
			})

			if isOwned then
				local label = isEquipped and "Unequip" or "Equip"
				Components.button(row, {
					Text = label,
					Size = UDim2.fromOffset(130, 40),
					Position = UDim2.new(1, -142, 0, 30),
					Color = isEquipped and Theme.Color.PanelRaised or Theme.Color.CyanDeep,
					OnClick = function()
						if isEquipped then
							Net.send("UnequipCompanion")
						else
							Net.send("EquipCompanion", { companionId = entry.id })
						end
					end,
				})
			else
				local button = Components.button(row, {
					Text = string.format("Recruit %s g", Util.formatNumber(definition.cost)),
					Size = UDim2.fromOffset(130, 40),
					Position = UDim2.new(1, -142, 0, 30),
					Color = Theme.Color.GoldDeep,
					TextColor = Theme.Color.Background,
					OnClick = function()
						Net.send("BuyCompanion", { companionId = entry.id })
					end,
				})
				Components.setDisabled(button, snapshot.gold < definition.cost)
			end
		end
	end
end

function Panels.Inventory(body, helpers)
	local scroll = Components.scroll(body, { Size = UDim2.fromScale(1, 1) })
	return function(snapshot)
		clear(scroll)
		if #snapshot.relics == 0 then
			Components.label(scroll, {
				Text = "Your archive is empty. Extract relics from a temple to own them.",
				TextColor = Theme.Color.TextMuted,
				Size = UDim2.new(1, 0, 0, 40),
			})
			return
		end
		for _, relic in snapshot.relics do
			local color = GameConfig.Rarities[relic.rarity]
					and Color3.fromRGB(
						GameConfig.Rarities[relic.rarity].color[1],
						GameConfig.Rarities[relic.rarity].color[2],
						GameConfig.Rarities[relic.rarity].color[3]
					)
				or Theme.Color.Text
			local row = Components.panel(scroll, {
				Size = UDim2.new(1, 0, 0, 64),
				Color = Theme.Color.PanelAlt,
				ClipsDescendants = true,
			})
			Components.badge(
				row,
				{ rarity = relic.rarity, Position = UDim2.fromOffset(10, 10), Size = UDim2.fromOffset(28, 28) }
			)
			Components.label(row, {
				Text = relic.name,
				Font = Theme.Font.Heading,
				TextSize = Theme.TextSize.Body,
				TextColor = color,
				Size = UDim2.new(1, -220, 0, 22),
				Position = UDim2.fromOffset(48, 8),
			})
			Components.label(row, {
				Text = string.format(
					"Wt %d  •  %d g  •  +%s/sec",
					relic.weight,
					relic.value,
					Util.formatNumber(relic.incomePerSecond * 10 / 10)
				),
				TextSize = 13,
				TextColor = Theme.Color.TextMuted,
				Size = UDim2.new(1, -220, 0, 18),
				Position = UDim2.fromOffset(48, 32),
			})
			if relic.exhibited then
				Components.label(row, {
					Text = "On display",
					TextSize = 13,
					TextColor = Theme.Color.Success,
					AlignX = Enum.TextXAlignment.Right,
					Size = UDim2.fromOffset(150, 1),
					Position = UDim2.new(1, -162, 0, 0),
					AlignY = Enum.TextYAlignment.Center,
				})
			else
				Components.button(row, {
					Text = "Auto-Display",
					Size = UDim2.fromOffset(150, 34),
					Position = UDim2.new(1, -162, 0, 15),
					Color = Theme.Color.CyanDeep,
					OnClick = function()
						local current = snapshot
						for _, pedestal in current.pedestals do
							if pedestal.unlocked and pedestal.uid == nil then
								Net.send("PlaceRelic", { pedestalId = pedestal.id, uid = relic.uid })
								return
							end
						end
						if helpers and helpers.toast then
							helpers.toast("warning", "No empty pedestal. Expand your museum or remove a display.")
						end
					end,
				})
			end
		end
	end
end

function Panels.Museum(body)
	local header = Components.label(body, {
		Text = "",
		TextSize = Theme.TextSize.Small,
		TextColor = Theme.Color.TextMuted,
		Size = UDim2.new(1, 0, 0, 22),
		Position = UDim2.fromOffset(0, 0),
	})
	local scroll = Components.scroll(body, {
		Size = UDim2.new(1, 0, 1, -28),
		Position = UDim2.fromOffset(0, 26),
	})
	return function(snapshot)
		header.Text = string.format(
			"Pedestals unlocked: %d / %d  •  Exhibits: %d",
			snapshot.pedestalCount,
			#snapshot.pedestals,
			snapshot.exhibitedCount
		)
		clear(scroll)

		local function relicFor(uid)
			if not uid then
				return nil
			end
			for _, owned in snapshot.relics do
				if owned.uid == uid then
					return owned
				end
			end
			return nil
		end

		local function pedestalRow(pedestal)
			local row = Components.panel(scroll, {
				Size = UDim2.new(1, 0, 0, 52),
				Color = pedestal.unlocked and Theme.Color.PanelAlt or Theme.Color.Panel,
				ClipsDescendants = true,
			})
			local occupied = pedestal.uid
			local relic = relicFor(occupied)
			local nameText = string.format("Pedestal %s", pedestal.id)
			if pedestal.tier then
				nameText = string.format("%s  •  %s", nameText, pedestal.tier)
			end
			Components.label(row, {
				Text = nameText,
				Font = Theme.Font.Heading,
				TextSize = 15,
				TextColor = pedestal.unlocked and Theme.Color.Gold or Theme.Color.TextDim,
				Size = UDim2.fromOffset(180, 1),
				Position = UDim2.fromOffset(12, 0),
				AlignY = Enum.TextYAlignment.Center,
			})
			Components.label(row, {
				Text = not pedestal.unlocked and "Locked"
					or (relic and (relic.name .. "  •  " .. relic.rarity) or "Empty"),
				TextSize = Theme.TextSize.Small,
				TextColor = relic and Theme.Color.Text or Theme.Color.TextMuted,
				Size = UDim2.new(1, -320, 1, 0),
				Position = UDim2.fromOffset(200, 0),
			})
			if pedestal.unlocked and occupied then
				Components.button(row, {
					Text = "Remove",
					Size = UDim2.fromOffset(100, 34),
					Position = UDim2.new(1, -112, 0, 9),
					Color = Theme.Color.DangerDeep,
					OnClick = function()
						Net.send("RemoveRelic", { pedestalId = pedestal.id })
					end,
				})
			end
		end

		-- Group pedestals by wing so the layout mirrors the physical building.
		local wings = snapshot.wings or {}
		local grouped = {}
		for _, pedestal in snapshot.pedestals do
			local key = pedestal.wingId or "Foyer"
			grouped[key] = grouped[key] or {}
			table.insert(grouped[key], pedestal)
		end

		for _, wing in wings do
			local wingPedestals = grouped[wing.id]
			if wingPedestals and #wingPedestals > 0 then
				Components.label(scroll, {
					Text = string.format("%s%s", wing.name, wing.unlocked and "" or "  (locked)"),
					Font = Theme.Font.Heading,
					TextSize = Theme.TextSize.Body,
					TextColor = wing.unlocked and Theme.Color.Gold or Theme.Color.TextDim,
					Size = UDim2.new(1, 0, 0, 24),
				})
				Components.label(scroll, {
					Text = wing.description,
					TextSize = Theme.TextSize.Small,
					TextColor = Theme.Color.TextMuted,
					Size = UDim2.new(1, 0, 0, 18),
				})
				for _, pedestal in wingPedestals do
					pedestalRow(pedestal)
				end
			end
		end
	end
end

function Panels.Settings(body)
	local scroll = Components.scroll(body, { Size = UDim2.fromScale(1, 1) })
	return function(snapshot)
		clear(scroll)
		local settings = snapshot.settings

		local function toggle(label: string, value: boolean, apply)
			local row = Components.panel(scroll, {
				Size = UDim2.new(1, 0, 0, 46),
				Color = Theme.Color.PanelAlt,
				ClipsDescendants = true,
			})
			Components.label(row, {
				Text = label,
				TextSize = Theme.TextSize.Body,
				Size = UDim2.new(1, -140, 1, 0),
				Position = UDim2.fromOffset(12, 0),
			})
			Components.button(row, {
				Text = value and "On" or "Off",
				Size = UDim2.fromOffset(110, 34),
				Position = UDim2.new(1, -122, 0, 6),
				Color = value and Theme.Color.CyanDeep or Theme.Color.PanelRaised,
				OnClick = function()
					apply(not value)
				end,
			})
		end

		local function options(label: string, current: string, choices: { string }, apply)
			local row = Components.panel(scroll, {
				Size = UDim2.new(1, 0, 0, 46),
				Color = Theme.Color.PanelAlt,
				ClipsDescendants = true,
			})
			Components.label(row, {
				Text = label,
				TextSize = Theme.TextSize.Body,
				Size = UDim2.new(1, -140, 1, 0),
				Position = UDim2.fromOffset(12, 0),
			})
			Components.button(row, {
				Text = current,
				Size = UDim2.fromOffset(110, 34),
				Position = UDim2.new(1, -122, 0, 6),
				Color = Theme.Color.PanelRaised,
				OnClick = function()
					local index = table.find(choices, current) or 1
					apply(choices[index % #choices + 1])
				end,
			})
		end

		Components.label(scroll, {
			Text = "Feedback",
			Font = Theme.Font.Heading,
			TextSize = Theme.TextSize.Body,
			TextColor = Theme.Color.Gold,
			Size = UDim2.new(1, 0, 0, 30),
		})
		toggle("Sound", settings.soundEnabled ~= false, function(next)
			Net.send("UpdateSettings", { soundEnabled = next })
		end)
		toggle("Visual effects", settings.visualEffects ~= false, function(next)
			Net.send("UpdateSettings", { visualEffects = next })
		end)
		toggle("Reduced motion", settings.reducedMotion == true, function(next)
			Net.send("UpdateSettings", { reducedMotion = next })
		end)

		Components.label(scroll, {
			Text = "Accessibility",
			Font = Theme.Font.Heading,
			TextSize = Theme.TextSize.Body,
			TextColor = Theme.Color.Gold,
			Size = UDim2.new(1, 0, 0, 30),
		})
		options("Text size", settings.textScale or "Normal", { "Normal", "Large", "Huge" }, function(next)
			Net.send("UpdateSettings", { textScale = next })
		end)
		toggle("Colorblind palette", settings.colorblindMode == true, function(next)
			Net.send("UpdateSettings", { colorblindMode = next })
		end)

		Components.label(scroll, {
			Text = "Progress",
			Font = Theme.Font.Heading,
			TextSize = Theme.TextSize.Body,
			TextColor = Theme.Color.Gold,
			Size = UDim2.new(1, 0, 0, 30),
		})
		statRow(scroll, "Extractions", tostring(snapshot.stats.extractions))
		statRow(scroll, "Relics collected", tostring(snapshot.stats.relicsCollected))
		statRow(scroll, "Deaths", tostring(snapshot.stats.deaths))
		statRow(scroll, "Museum income", string.format("+%.1f / sec", snapshot.incomePerSecond))
		statRow(scroll, "Carry capacity", tostring(snapshot.capacity))

		Components.label(scroll, {
			Text = "Training",
			Font = Theme.Font.Heading,
			TextSize = Theme.TextSize.Body,
			TextColor = Theme.Color.Gold,
			Size = UDim2.new(1, 0, 0, 30),
		})
		Components.label(scroll, {
			Text = "Earned by collecting relics and extracting hauls.",
			TextSize = Theme.TextSize.Small,
			TextColor = Theme.Color.TextMuted,
			Size = UDim2.new(1, 0, 0, 20),
		})
		local trainingLabels = {
			strength = "Strength",
			stamina = "Stamina",
			carrying = "Carrying",
		}
		if snapshot.training then
			for _, attribute in { "strength", "stamina", "carrying" } do
				local progress = snapshot.training[attribute]
				if progress then
					local value = progress.maxed and string.format("Lv %d (max)", progress.level)
						or string.format(
							"Lv %d/%d  •  %d/%d xp",
							progress.level,
							progress.maxLevel,
							progress.intoLevel,
							progress.neededForNext
						)
					statRow(scroll, trainingLabels[attribute] or attribute, value)
				end
			end
		end

		if snapshot.ephemeral then
			Components.label(scroll, {
				Text = "Studio preview: progress is not saved to a DataStore.",
				TextSize = 13,
				TextColor = Theme.Color.Warning,
				Size = UDim2.new(1, 0, 0, 34),
			})
		end
	end
end

return Panels
