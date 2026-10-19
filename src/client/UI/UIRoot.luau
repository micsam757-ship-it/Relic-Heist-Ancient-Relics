--!nonstrict
-- Root UI: always-on chrome (top bar, expedition HUD, toasts), the modal host
-- used by all panels, the extraction summary, and the relic selection prompt.

local TweenService = game:GetService("TweenService")
local RunService = game:GetService("RunService")

local Theme = require(script.Parent.Theme)
local Components = require(script.Parent.Components)
local Panels = require(script.Parent.Panels)
local State = require(script.Parent.Parent.State)
local Net = require(script.Parent.Parent.Net)

local UIRoot = {}

local refs = {}
local activePanel = nil
local timeOffset = 0
local lastHudRefresh = 0

-- The timer only needs whole-second resolution and the weight bar only needs to
-- feel responsive, so 10 Hz is plenty. Refreshing every Heartbeat would spam
-- string formatting and tween creation for no visible benefit.
local HUD_REFRESH_INTERVAL = 0.1

local PANEL_TITLES = {
	Expeditions = "Expeditions",
	Shop = "Museum Shop",
	Inventory = "Relic Inventory",
	Museum = "Museum Layout",
	Settings = "Settings",
}

local function formatNumberShort(value: number): string
	local n = math.floor(value + 0.5)
	if n >= 1000000 then
		return string.format("%.1fM", n / 1000000)
	elseif n >= 1000 then
		return string.format("%.1fK", n / 1000)
	end
	return tostring(n)
end

UIRoot.formatNumberShort = formatNumberShort

local function formatClock(seconds: number): string
	local clamped = math.max(0, math.floor(seconds + 0.5))
	local minutes = math.floor(clamped / 60)
	local secs = clamped % 60
	return string.format("%d:%02d", minutes, secs)
end

function UIRoot.build(playerGui: Instance)
	local screen = Instance.new("ScreenGui")
	screen.Name = "RelicHeistUI"
	screen.ResetOnSpawn = false
	screen.IgnoreGuiInset = true
	screen.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	screen.Parent = playerGui
	refs.screen = screen

	local topBar = Components.panel(screen, {
		Name = "TopBar",
		Size = UDim2.new(1, 0, 0, 60),
		Color = Theme.Color.Panel,
		Radius = Theme.Radius.Small,
		StrokeColor = Theme.Color.GoldDeep,
		ClipsDescendants = false,
	})
	topBar.BackgroundTransparency = 0.08

	Components.label(topBar, {
		Name = "GameTitle",
		Text = "RELIC HEIST",
		Font = Theme.Font.Title,
		TextSize = Theme.TextSize.Heading,
		TextColor = Theme.Color.Gold,
		Size = UDim2.fromOffset(200, 60),
		Position = UDim2.fromOffset(18, 0),
	})

	Components.label(topBar, {
		Name = "GoldIcon",
		Text = "GOLD",
		Font = Theme.Font.Heading,
		TextSize = 12,
		TextColor = Theme.Color.GoldDeep,
		Size = UDim2.fromOffset(60, 60),
		Position = UDim2.fromOffset(210, 0),
	})
	refs.goldLabel = Components.label(topBar, {
		Name = "Gold",
		Text = "0",
		Font = Theme.Font.Heading,
		TextSize = Theme.TextSize.Body,
		TextColor = Theme.Color.Gold,
		Size = UDim2.fromOffset(120, 60),
		Position = UDim2.fromOffset(262, 0),
	})

	refs.incomeLabel = Components.label(topBar, {
		Name = "Income",
		Text = "+0/min",
		Font = Theme.Font.Body,
		TextSize = Theme.TextSize.Small,
		TextColor = Theme.Color.Cyan,
		Size = UDim2.fromOffset(120, 30),
		Position = UDim2.fromOffset(262, 30),
	})

	refs.claimButton = Components.button(topBar, {
		Name = "Claim",
		Text = "Claim Income",
		Size = UDim2.fromOffset(150, 40),
		Position = UDim2.fromOffset(388, 10),
		Color = Theme.Color.CyanDeep,
		Cooldown = 1,
		OnClick = function()
			Net.send("ClaimIncome")
		end,
	})

	local nav = Instance.new("Frame")
	nav.Name = "Nav"
	nav.BackgroundTransparency = 1
	nav.Size = UDim2.fromOffset(560, 44)
	nav.Position = UDim2.new(1, -580, 0, 8)
	nav.Parent = topBar
	local navLayout = Instance.new("UIListLayout")
	navLayout.FillDirection = Enum.FillDirection.Horizontal
	navLayout.Padding = UDim.new(0, 8)
	navLayout.HorizontalAlignment = Enum.HorizontalAlignment.Right
	navLayout.VerticalAlignment = Enum.VerticalAlignment.Center
	navLayout.Parent = nav

	local navEntries = {
		{ name = "Expeditions", key = "E" },
		{ name = "Shop", key = "B" },
		{ name = "Inventory", key = "I" },
		{ name = "Museum", key = "M" },
		{ name = "Settings", key = "O" },
	}
	for _, entry in navEntries do
		Components.button(nav, {
			Name = entry.name,
			Text = string.format("%s [%s]", entry.name, entry.key),
			Size = UDim2.fromOffset(104, 40),
			Color = Theme.Color.PanelRaised,
			OnClick = function()
				UIRoot.togglePanel(entry.name)
			end,
		})
	end

	refs.toastHost = Instance.new("Frame")
	refs.toastHost.Name = "ToastHost"
	refs.toastHost.BackgroundTransparency = 1
	refs.toastHost.Size = UDim2.fromOffset(340, 0)
	refs.toastHost.Position = UDim2.new(0.5, 0, 0, 72)
	refs.toastHost.AnchorPoint = Vector2.new(0.5, 0)
	refs.toastHost.AutomaticSize = Enum.AutomaticSize.Y
	refs.toastHost.Parent = screen
	local toastPadding = Instance.new("UIPadding")
	toastPadding.PaddingBottom = UDim.new(0, 6)
	toastPadding.Parent = refs.toastHost
	local toastLayout = Instance.new("UIListLayout")
	toastLayout.Padding = UDim.new(0, 6)
	toastLayout.SortOrder = Enum.SortOrder.LayoutOrder
	toastLayout.Parent = refs.toastHost

	refs.hud = Components.panel(screen, {
		Name = "ExpeditionHud",
		Size = UDim2.fromOffset(300, 168),
		Position = UDim2.fromOffset(18, 74),
		Color = Theme.Color.Panel,
		Radius = Theme.Radius.Medium,
	})
	refs.hud.Visible = false

	refs.hudTemple = Components.label(refs.hud, {
		Text = "",
		Font = Theme.Font.Heading,
		TextSize = Theme.TextSize.Body,
		TextColor = Theme.Color.Gold,
		Size = UDim2.new(1, -24, 0, 26),
		Position = UDim2.fromOffset(12, 8),
	})
	refs.hudTimer = Components.label(refs.hud, {
		Text = "0:00",
		Font = Theme.Font.Mono,
		TextSize = Theme.TextSize.Heading,
		TextColor = Theme.Color.Text,
		Size = UDim2.new(1, -24, 0, 26),
		Position = UDim2.fromOffset(12, 34),
	})
	refs.hudWeightBar = Components.bar(refs.hud, {
		Size = UDim2.new(1, -24, 0, 18),
		Position = UDim2.fromOffset(12, 66),
		FillColor = Theme.Color.Cyan,
	})
	Components.label(refs.hud, {
		Name = "WeightCaption",
		Text = "Carried Weight",
		Font = Theme.Font.Body,
		TextSize = 12,
		TextColor = Theme.Color.TextMuted,
		Size = UDim2.new(1, -24, 0, 16),
		Position = UDim2.fromOffset(12, 86),
	})
	refs.hudCarried = Components.label(refs.hud, {
		Text = "",
		Font = Theme.Font.Body,
		TextSize = Theme.TextSize.Small,
		TextColor = Theme.Color.Text,
		Size = UDim2.new(1, -24, 0, 20),
		Position = UDim2.fromOffset(12, 104),
	})
	Components.button(refs.hud, {
		Name = "Abandon",
		Text = "Abandon Expedition",
		Size = UDim2.new(1, -24, 0, 34),
		Position = UDim2.fromOffset(12, 128),
		Color = Theme.Color.DangerDeep,
		OnClick = function()
			Net.send("AbandonExpedition")
		end,
	})

	refs.modalHost = Instance.new("Frame")
	refs.modalHost.Name = "ModalHost"
	refs.modalHost.BackgroundTransparency = 1
	refs.modalHost.Size = UDim2.fromScale(1, 1)
	refs.modalHost.ZIndex = 15
	refs.modalHost.Parent = screen

	refs.summaryHost = Instance.new("Frame")
	refs.summaryHost.Name = "SummaryHost"
	refs.summaryHost.BackgroundTransparency = 1
	refs.summaryHost.Size = UDim2.fromScale(1, 1)
	refs.summaryHost.ZIndex = 30
	refs.summaryHost.Parent = screen

	refs.tutorialHost = Instance.new("Frame")
	refs.tutorialHost.Name = "TutorialHost"
	refs.tutorialHost.BackgroundTransparency = 1
	refs.tutorialHost.Size = UDim2.fromScale(1, 1)
	refs.tutorialHost.ZIndex = 40
	refs.tutorialHost.Active = false
	refs.tutorialHost.Parent = screen

	State.onChanged(function(snapshot)
		UIRoot.render(snapshot)
	end)

	RunService.Heartbeat:Connect(function()
		UIRoot.tick()
	end)
end

function UIRoot.toast(kind: string, message: string)
	if refs.toastHost == nil then
		return
	end
	Components.toast(refs.toastHost, kind, message)
end

function UIRoot.togglePanel(name: string)
	if activePanel and activePanel.name == name then
		UIRoot.closePanel()
		return
	end
	UIRoot.openPanel(name)
end

function UIRoot.closePanel()
	if activePanel then
		activePanel.destroy()
		activePanel = nil
	end
end

function UIRoot.openPanel(name: string)
	UIRoot.closePanel()
	local builder = Panels[name]
	if builder == nil then
		return
	end
	local modal = Components.modal(refs.modalHost, {
		Title = PANEL_TITLES[name] or name,
		Size = UDim2.fromOffset(560, 460),
	})
	local render = builder(modal.body, {
		close = function()
			UIRoot.closePanel()
		end,
		toast = UIRoot.toast,
	})
	activePanel = {
		name = name,
		render = render,
		destroy = modal.destroy,
	}
	UIRoot.render(State.get())
end

function UIRoot.render(snapshot)
	if snapshot == nil then
		return
	end
	timeOffset = os.time() - snapshot.serverNow

	refs.goldLabel.Text = formatNumberShort(snapshot.gold)
	refs.incomeLabel.Text = string.format("+%s/min", formatNumberShort(snapshot.incomePerMinute))

	local claimable = snapshot.pendingIncome >= 1
	Components.setDisabled(refs.claimButton, not claimable)
	refs.claimButton.Text = claimable and string.format("Claim %s", formatNumberShort(snapshot.pendingIncome))
		or "Claim Income"

	if activePanel and activePanel.render then
		activePanel.render(snapshot)
	end
end

function UIRoot.tick()
	local snapshot = State.get()
	if snapshot == nil then
		return
	end
	local expedition = snapshot.expedition
	if expedition then
		local now = os.clock()
		if now - lastHudRefresh < HUD_REFRESH_INTERVAL then
			return
		end
		lastHudRefresh = now
		refs.hud.Visible = true
		refs.hudTemple.Text = expedition.templeName
		local remaining = expedition.endsAt - (os.time() - timeOffset)
		refs.hudTimer.Text = expedition.collapsing and string.format("COLLAPSE %s", formatClock(remaining))
			or string.format("Escape in %s", formatClock(remaining))
		local ratio = expedition.capacity > 0 and (expedition.weight / expedition.capacity) or 0
		refs.hudWeightBar.set(
			ratio,
			string.format(
				"%d / %d  •  %.0f%% speed",
				math.floor(expedition.weight),
				expedition.capacity,
				expedition.speedMultiplier * 100
			)
		)
		refs.hudWeightBar.setColor(
			ratio > 0.85 and Theme.Color.Danger or (ratio > 0.6 and Theme.Color.Warning or Theme.Color.Cyan)
		)
		refs.hudCarried.Text = string.format("Relics: %d / %d", expedition.remainingRelics, snapshot.maxCarried)
	elseif refs.hud.Visible then
		refs.hud.Visible = false
	end
end

function UIRoot.showSummary(payload)
	local backdrop = Instance.new("TextButton")
	backdrop.Name = "SummaryBackdrop"
	backdrop.Size = UDim2.fromScale(1, 1)
	backdrop.BackgroundColor3 = Theme.Color.Scrim
	backdrop.BackgroundTransparency = 0.4
	backdrop.Text = ""
	backdrop.AutoButtonColor = false
	backdrop.ZIndex = 31
	backdrop.Parent = refs.summaryHost

	local success = payload.success == true
	local accent = success and Theme.Color.Success or Theme.Color.Danger
	local card = Components.panel(backdrop, {
		Size = UDim2.fromOffset(520, 400),
		Position = UDim2.fromScale(0.5, 0.5),
		AnchorPoint = Vector2.new(0.5, 0.5),
		Color = Theme.Color.Panel,
		Radius = Theme.Radius.Large,
		StrokeColor = accent,
		ClipsDescendants = true,
	})
	card.ZIndex = 32

	Components.label(card, {
		Text = payload.title or "Expedition",
		Font = Theme.Font.Title,
		TextSize = Theme.TextSize.Title,
		TextColor = accent,
		Size = UDim2.new(1, -24, 0, 44),
		Position = UDim2.fromOffset(20, 16),
		AlignX = Enum.TextXAlignment.Center,
	})
	Components.label(card, {
		Text = payload.subtitle or "",
		Font = Theme.Font.Body,
		TextSize = Theme.TextSize.Body,
		TextColor = Theme.Color.TextMuted,
		Size = UDim2.new(1, -24, 0, 26),
		Position = UDim2.fromOffset(20, 60),
		AlignX = Enum.TextXAlignment.Center,
	})

	local scroll, layout = Components.scroll(card, {
		Size = UDim2.new(1, -32, 1, -170),
		Position = UDim2.fromOffset(16, 92),
	})
	layout.Padding = UDim.new(0, 6)

	for _, line in payload.lines or {} do
		local row = Components.panel(scroll, {
			Size = UDim2.new(1, 0, 0, 30),
			Color = Theme.Color.PanelAlt,
			ClipsDescendants = true,
		})
		Components.label(row, {
			Text = line,
			TextSize = Theme.TextSize.Small,
			Size = UDim2.new(1, -16, 1, 0),
			Position = UDim2.fromOffset(10, 0),
		})
	end
	for _, relic in payload.relics or {} do
		local row = Components.panel(scroll, {
			Size = UDim2.new(1, 0, 0, 34),
			Color = Theme.Color.PanelAlt,
			ClipsDescendants = true,
		})
		Components.badge(row, { rarity = relic.rarity, Position = UDim2.fromOffset(8, 4) })
		Components.label(row, {
			Text = relic.name,
			TextSize = Theme.TextSize.Small,
			Size = UDim2.new(1, -140, 1, 0),
			Position = UDim2.fromOffset(42, 0),
		})
		Components.label(row, {
			Text = string.format("%s g", formatNumberShort(relic.value)),
			TextColor = Theme.Color.Gold,
			TextSize = Theme.TextSize.Small,
			AlignX = Enum.TextXAlignment.Right,
			Size = UDim2.fromOffset(90, 1),
			Position = UDim2.new(1, -100, 0, 0),
			AlignY = Enum.TextYAlignment.Center,
		})
	end

	Components.button(card, {
		Text = "Continue",
		Size = UDim2.new(1, -40, 0, 44),
		Position = UDim2.new(0, 20, 1, -56),
		Color = accent,
		TextColor = Theme.Color.Background,
		OnClick = function()
			backdrop:Destroy()
		end,
	})
end

function UIRoot.showPedestalPrompt(payload)
	local backdrop = Instance.new("TextButton")
	backdrop.Size = UDim2.fromScale(1, 1)
	backdrop.BackgroundColor3 = Theme.Color.Scrim
	backdrop.BackgroundTransparency = 0.5
	backdrop.Text = ""
	backdrop.AutoButtonColor = false
	backdrop.ZIndex = 25
	backdrop.Parent = refs.modalHost

	local card = Components.panel(backdrop, {
		Name = "PedestalPrompt",
		Size = UDim2.fromOffset(480, 420),
		Position = UDim2.fromScale(0.5, 0.5),
		AnchorPoint = Vector2.new(0.5, 0.5),
		Color = Theme.Color.Panel,
		Radius = Theme.Radius.Large,
		StrokeColor = Theme.Color.GoldDeep,
		ClipsDescendants = true,
	})
	card.ZIndex = 26

	local occupied = payload.currentUid ~= nil
	Components.label(card, {
		Text = string.format("Pedestal %s", payload.pedestalId),
		Font = Theme.Font.Title,
		TextSize = Theme.TextSize.Heading,
		TextColor = Theme.Color.Gold,
		Size = UDim2.new(1, -24, 0, 40),
		Position = UDim2.fromOffset(20, 14),
	})

	Components.label(card, {
		Text = occupied and "This pedestal is occupied." or "Select a relic to display.",
		Font = Theme.Font.Body,
		TextSize = Theme.TextSize.Small,
		TextColor = Theme.Color.TextMuted,
		Size = UDim2.new(1, -200, 0, 24),
		Position = UDim2.fromOffset(20, 52),
	})

	local scroll = Components.scroll(card, {
		Size = UDim2.new(1, -32, 1, -140),
		Position = UDim2.fromOffset(16, 84),
	})

	local function refresh()
		for _, child in scroll:GetChildren() do
			if child:IsA("GuiObject") then
				child:Destroy()
			end
		end
		local snapshot = State.get()
		if snapshot == nil then
			return
		end
		for _, relic in snapshot.relics do
			if not relic.exhibited then
				local row = Components.button(scroll, {
					Name = relic.uid,
					Text = string.format("%s  (%s)", relic.name, relic.rarity),
					Size = UDim2.new(1, 0, 0, 36),
					Color = Theme.Color.PanelAlt,
					TextColor = Theme.Color.Text,
					OnClick = function()
						Net.send("PlaceRelic", { pedestalId = payload.pedestalId, uid = relic.uid })
						backdrop:Destroy()
					end,
				})
				Components.badge(row, { rarity = relic.rarity, Position = UDim2.new(1, -38, 0, 5) })
			end
		end
	end

	refresh()
	local connection
	connection = State.onChanged(function()
		refresh()
	end)
	backdrop.Destroying:Connect(function()
		if connection then
			connection:Disconnect()
		end
	end)

	Components.button(card, {
		Name = "Remove",
		Text = "Remove Display",
		Size = UDim2.fromOffset(150, 40),
		Position = UDim2.new(0, 20, 1, -52),
		Color = Theme.Color.DangerDeep,
		OnClick = function()
			Net.send("RemoveRelic", { pedestalId = payload.pedestalId })
			backdrop:Destroy()
		end,
	})
	Components.setDisabled(card:FindFirstChild("Remove"), not occupied)

	Components.button(card, {
		Name = "Cancel",
		Text = "Cancel",
		Size = UDim2.fromOffset(120, 40),
		Position = UDim2.new(1, -140, 1, -52),
		OnClick = function()
			backdrop:Destroy()
		end,
	})
end

function UIRoot.showTutorial()
	if refs.tutorialHost:FindFirstChild("TutorialCard") then
		return
	end
	local card = Components.panel(refs.tutorialHost, {
		Name = "TutorialCard",
		Size = UDim2.fromOffset(420, 180),
		Position = UDim2.fromScale(0.5, 0.62),
		AnchorPoint = Vector2.new(0.5, 0.5),
		Color = Theme.Color.Overlay,
		Radius = Theme.Radius.Large,
		StrokeColor = Theme.Color.GoldDeep,
	})
	card.BackgroundTransparency = 0.15
	Components.label(card, {
		Text = "First Heist",
		Font = Theme.Font.Title,
		TextSize = Theme.TextSize.Heading,
		TextColor = Theme.Color.Gold,
		Size = UDim2.new(1, -20, 0, 34),
		Position = UDim2.fromOffset(16, 12),
	})
	Components.label(card, {
		Text = "Side with the Tutorial Ruins portal, snatch the relics, then carry them to the extraction altar before the ground shakes. Only extracted relics are yours to keep.",
		Font = Theme.Font.Body,
		TextSize = Theme.TextSize.Small,
		TextColor = Theme.Color.Text,
		Size = UDim2.new(1, -32, 1, -70),
		Position = UDim2.fromOffset(16, 46),
	})
	Components.button(card, {
		Text = "Understood",
		Size = UDim2.new(1, -32, 0, 38),
		Position = UDim2.fromOffset(16, 128),
		Color = Theme.Color.GoldDeep,
		OnClick = function()
			card:Destroy()
		end,
	})
end

function UIRoot.damageFlash()
	if refs.screen == nil then
		return
	end
	local flash = Instance.new("Frame")
	flash.Name = "DamageFlash"
	flash.Size = UDim2.fromScale(1, 1)
	flash.BackgroundColor3 = Theme.Color.Danger
	flash.BackgroundTransparency = 0.7
	flash.BorderSizePixel = 0
	flash.ZIndex = 5
	flash.Parent = refs.screen
	TweenService:Create(flash, TweenInfo.new(0.45), { BackgroundTransparency = 1 }):Play()
	task.delay(0.5, function()
		flash:Destroy()
	end)
end

function UIRoot.setTutorialVisible(visible: boolean)
	if refs.tutorialHost then
		refs.tutorialHost.Visible = visible
	end
end

return UIRoot
