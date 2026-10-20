--!nonstrict
-- Root UI: always-on chrome (top bar, expedition HUD, toasts), the modal host
-- used by all panels, the extraction summary, and the relic selection prompt.

local TweenService = game:GetService("TweenService")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local GameConfig = require(ReplicatedStorage.Shared.Config.GameConfig)
local Theme = require(script.Parent.Theme)
local Components = require(script.Parent.Components)
local Panels = require(script.Parent.Panels)
local State = require(script.Parent.Parent.State)
local Net = require(script.Parent.Parent.Net)
local Preferences = require(script.Parent.Parent.Preferences)
local Audio = require(script.Parent.Parent.Controllers.SoundController)

local UIRoot = {}

local refs = {}
local activePanel = nil
local welcomeBackOpen = false
local timeOffset = 0
local lastHudRefresh = 0
local lastHeartbeat = 0

-- Gold is interpolated client-side between authoritative snapshots so it climbs
-- smoothly instead of stepping once per second. The server stays authoritative:
-- `goldDisplayed` always eases toward the extrapolated target and snaps on a
-- downward correction (a purchase), never inventing gold the server did not grant.
local goldDisplayed = nil
local goldBase = 0
local goldBaseAt = 0
local goldRate = 0

-- The timer only needs whole-second resolution and the weight bar only needs to
-- feel responsive, so 10 Hz is plenty. Refreshing every Heartbeat would spam
-- string formatting and tween creation for no visible benefit.
local HUD_REFRESH_INTERVAL = 0.1

-- Reference resolution the layout is authored against, and the smallest scale we
-- allow before text becomes unreadable (below it, the GUI would be too small).
local RESPONSIVE_BASE_WIDTH = 1280
local RESPONSIVE_BASE_HEIGHT = 720
local RESPONSIVE_MIN_SCALE = 0.62

-- On touch devices the keyboard hint in nav buttons is meaningless, so it is
-- dropped and targets grow slightly for fingers.
local TOUCH_NAV_BUTTON_SIZE = UDim2.fromOffset(96, 44)
local DESKTOP_NAV_BUTTON_SIZE = UDim2.fromOffset(104, 40)

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

	-- Responsive scaling: the layout is authored at a reference width, then the
	-- whole GUI is uniformly scaled down on narrower viewports so modals and the
	-- top bar never overflow on phones or small windows. It only ever shrinks
	-- (never upscales), so desktop stays pixel-crisp at 1.0.
	refs.scale = Instance.new("UIScale")
	refs.scale.Name = "ResponsiveScale"
	refs.scale.Parent = screen

	refs.isTouch = UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled

	local camera = workspace.CurrentCamera
	local function updateScale()
		local viewport = camera and camera.ViewportSize or Vector2.new(1280, 720)
		local widthFactor = viewport.X / RESPONSIVE_BASE_WIDTH
		local heightFactor = viewport.Y / RESPONSIVE_BASE_HEIGHT
		local factor = math.min(widthFactor, heightFactor, 1)
		refs.scale.Scale = math.clamp(factor, RESPONSIVE_MIN_SCALE, 1)
	end
	updateScale()
	if camera then
		camera:GetPropertyChangedSignal("ViewportSize"):Connect(updateScale)
	end

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
		Text = "+0/sec",
		Font = Theme.Font.Body,
		TextSize = Theme.TextSize.Small,
		TextColor = Theme.Color.Cyan,
		Size = UDim2.fromOffset(120, 30),
		Position = UDim2.fromOffset(262, 30),
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
			Text = refs.isTouch and entry.name or string.format("%s [%s]", entry.name, entry.key),
			Size = refs.isTouch and TOUCH_NAV_BUTTON_SIZE or DESKTOP_NAV_BUTTON_SIZE,
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

	-- Persistent tutorial objective: a compact bar under the top bar showing the
	-- current step, its hint, and progress. Hidden when the tutorial is done.
	refs.objective = Components.panel(screen, {
		Name = "TutorialObjective",
		Size = UDim2.fromOffset(340, 60),
		Position = UDim2.new(0.5, 0, 0, 68),
		AnchorPoint = Vector2.new(0.5, 0),
		Color = Theme.Color.Panel,
		Radius = Theme.Radius.Medium,
		StrokeColor = Theme.Color.GoldDeep,
		ClipsDescendants = true,
	})
	refs.objective.Visible = false
	refs.objectiveTitle = Components.label(refs.objective, {
		Name = "StepTitle",
		Text = "",
		Font = Theme.Font.Heading,
		TextSize = Theme.TextSize.Small,
		TextColor = Theme.Color.Gold,
		Size = UDim2.new(1, -20, 0, 20),
		Position = UDim2.fromOffset(10, 6),
	})
	refs.objectiveHint = Components.label(refs.objective, {
		Name = "StepHint",
		Text = "",
		Font = Theme.Font.Body,
		TextSize = Theme.TextSize.Small,
		TextColor = Theme.Color.Text,
		Size = UDim2.new(1, -20, 0, 20),
		Position = UDim2.fromOffset(10, 26),
	})
	refs.objectiveProgress = Components.label(refs.objective, {
		Name = "StepProgress",
		Text = "",
		Font = Theme.Font.Body,
		TextSize = Theme.TextSize.Small,
		TextColor = Theme.Color.TextMuted,
		AlignX = Enum.TextXAlignment.Right,
		Size = UDim2.fromOffset(60, 20),
		Position = UDim2.new(1, -70, 0, 6),
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

	RunService.Heartbeat:Connect(function(deltaTime)
		UIRoot.tick(deltaTime)
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
		Audio.play("UiClose")
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
	Audio.play("UiOpen")
	UIRoot.render(State.get())
end

function UIRoot.render(snapshot)
	if snapshot == nil then
		return
	end
	timeOffset = os.time() - snapshot.serverNow

	-- Apply accessibility/feedback preferences before building any UI so newly
	-- created widgets pick up the current palette and text scale. If the text
	-- scale changed, rebuild the open panel so its labels resize too.
	local textScaleChanged = Preferences.apply(snapshot.settings)
	if textScaleChanged and activePanel then
		local name = activePanel.name
		UIRoot.closePanel()
		UIRoot.openPanel(name)
	end

	UIRoot.renderTutorial(snapshot.tutorial)

	local target = snapshot.gold
	if goldDisplayed == nil or target < goldDisplayed - 0.5 then
		-- First snapshot, or a downward correction (purchase): snap to truth.
		goldDisplayed = target
	elseif target > goldDisplayed then
		-- Server granted a lump (offline income, rewards): ease toward it.
		goldDisplayed = math.min(target, goldDisplayed + (target - goldDisplayed) * 0.5)
	end
	goldBase = target
	goldBaseAt = os.clock()
	goldRate = snapshot.incomePerSecond or 0

	refs.goldLabel.Text = formatNumberShort(goldDisplayed)
	refs.incomeLabel.Text = string.format("+%s/sec", formatNumberShort(goldRate * 10 / 10))

	if activePanel and activePanel.render then
		activePanel.render(snapshot)
	end
end

-- Renders the persistent tutorial objective from the snapshot's `tutorial` view.
function UIRoot.renderTutorial(tutorial)
	if refs.objective == nil then
		return
	end
	if tutorial == nil or not tutorial.active or tutorial.step == nil then
		refs.objective.Visible = false
		return
	end
	refs.objective.Visible = true
	refs.objectiveTitle.Text = tostring(tutorial.step.title or "")
	refs.objectiveHint.Text = tostring(tutorial.step.hint or tutorial.step.text or "")
	refs.objectiveProgress.Text = string.format("%d/%d", tutorial.completed, tutorial.total)
end

-- Called when the server reports a step advance so the player gets a cue.
function UIRoot.tutorialAdvance()
	Audio.play("TutorialAdvance")
end

function UIRoot.tutorialComplete()
	Audio.play("TutorialComplete")
	UIRoot.toast("success", "Tutorial complete!")
end

function UIRoot.tick(deltaTime: number?)
	local snapshot = State.get()
	if snapshot == nil then
		return
	end
	local dt = deltaTime or (os.clock() - lastHeartbeat)
	lastHeartbeat = os.clock()

	if goldDisplayed ~= nil then
		-- Extrapolate the true balance from the last snapshot, then ease the
		-- displayed value toward it so live income reads as a smooth climb.
		local extrapolated = goldBase + goldRate * (os.clock() - goldBaseAt)
		local goal = math.max(goldDisplayed, extrapolated)
		goldDisplayed += (goal - goldDisplayed) * math.min(1, dt * 6)
		refs.goldLabel.Text = formatNumberShort(goldDisplayed)
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

-- Welcome Back offline-earnings modal. The free 1x claim is always offered; the
-- 2x option is a paid Developer Product and is only shown when configured on the
-- server. The client never grants gold; both buttons send a request.
function UIRoot.showWelcomeBack(payload)
	if welcomeBackOpen then
		return
	end
	welcomeBackOpen = true

	local backdrop = Instance.new("TextButton")
	backdrop.Name = "WelcomeBackBackdrop"
	backdrop.Size = UDim2.fromScale(1, 1)
	backdrop.BackgroundColor3 = Theme.Color.Scrim
	backdrop.BackgroundTransparency = 0.4
	backdrop.Text = ""
	backdrop.AutoButtonColor = false
	backdrop.ZIndex = 34
	backdrop.Parent = refs.summaryHost

	local card = Components.panel(backdrop, {
		Size = UDim2.fromOffset(520, 360),
		Position = UDim2.fromScale(0.5, 0.5),
		AnchorPoint = Vector2.new(0.5, 0.5),
		Color = Theme.Color.Panel,
		Radius = Theme.Radius.Large,
		StrokeColor = Theme.Color.Gold,
		ClipsDescendants = true,
	})
	card.ZIndex = 35

	Components.label(card, {
		Text = "Welcome Back",
		Font = Theme.Font.Title,
		TextSize = Theme.TextSize.Title,
		TextColor = Theme.Color.Gold,
		Size = UDim2.new(1, -24, 0, 44),
		Position = UDim2.fromOffset(20, 18),
		AlignX = Enum.TextXAlignment.Center,
	})
	Components.label(card, {
		Text = "Your museum earned gold while you were away.",
		Font = Theme.Font.Body,
		TextSize = Theme.TextSize.Body,
		TextColor = Theme.Color.TextMuted,
		Size = UDim2.new(1, -24, 0, 26),
		Position = UDim2.fromOffset(20, 60),
		AlignX = Enum.TextXAlignment.Center,
	})
	Components.label(card, {
		Name = "Amount",
		Text = string.format("%s gold", formatNumberShort(payload.amount or 0)),
		Font = Theme.Font.Title,
		TextSize = Theme.TextSize.Title,
		TextColor = Theme.Color.Text,
		Size = UDim2.new(1, -24, 0, 48),
		Position = UDim2.fromOffset(20, 92),
		AlignX = Enum.TextXAlignment.Center,
	})

	local capHours = math.floor((payload.capSeconds or 0) / 3600)
	local tierLabel = payload.vip and "VIP Pass: 24h offline window" or string.format("%dh offline window", capHours)
	Components.label(card, {
		Name = "CapNote",
		Text = tierLabel,
		Font = Theme.Font.Body,
		TextSize = Theme.TextSize.Small,
		TextColor = Theme.Color.Cyan,
		Size = UDim2.new(1, -24, 0, 22),
		Position = UDim2.fromOffset(20, 142),
		AlignX = Enum.TextXAlignment.Center,
	})

	local function close()
		backdrop:Destroy()
		welcomeBackOpen = false
	end

	Components.button(card, {
		Name = "ClaimFree",
		Text = "Claim 1x (Free)",
		Size = UDim2.new(1, -40, 0, 44),
		Position = UDim2.new(0, 20, 1, -116),
		Color = Theme.Color.Success,
		TextColor = Theme.Color.Background,
		OnClick = function()
			Net.send("ClaimOfflineIncome")
			close()
		end,
	})

	if payload.purchasable then
		local multiplier = tonumber(payload.multiplier) or 2
		Components.button(card, {
			Name = "ClaimDouble",
			Text = string.format("Claim %dx  (%d Robux)", multiplier, tonumber(payload.priceRobux) or 0),
			Size = UDim2.new(1, -40, 0, 44),
			Position = UDim2.new(0, 20, 1, -64),
			Color = Theme.Color.Gold,
			TextColor = Theme.Color.Background,
			OnClick = function()
				Net.send("PurchaseOfflineDouble")
			end,
		})
	end
end

function UIRoot.closeWelcomeBack()
	if refs.summaryHost then
		local existing = refs.summaryHost:FindFirstChild("WelcomeBackBackdrop")
		if existing then
			existing:Destroy()
		end
	end
	welcomeBackOpen = false
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
	local steps = (GameConfig.Tutorial and GameConfig.Tutorial.Steps) or {}
	local intro = steps[1]
	local title = intro and intro.title or "First Heist"
	local body = intro and intro.text
		or "Enter the Tutorial Ruins, snatch the relics, then carry them to the extraction altar."

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
		Text = title,
		Font = Theme.Font.Title,
		TextSize = Theme.TextSize.Heading,
		TextColor = Theme.Color.Gold,
		Size = UDim2.new(1, -20, 0, 34),
		Position = UDim2.fromOffset(16, 12),
	})
	Components.label(card, {
		Text = body,
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
	if not Preferences.visualEffects() then
		return
	end
	local flash = Instance.new("Frame")
	flash.Name = "DamageFlash"
	flash.Size = UDim2.fromScale(1, 1)
	flash.BackgroundColor3 = Theme.Color.Danger
	flash.BorderSizePixel = 0
	flash.ZIndex = 5
	flash.Parent = refs.screen
	if Preferences.reducedMotion() then
		-- No fade animation: a brief static tint, then clear.
		flash.BackgroundTransparency = 0.9
		task.delay(0.2, function()
			flash:Destroy()
		end)
		return
	end
	flash.BackgroundTransparency = 0.7
	TweenService:Create(flash, TweenInfo.new(0.45), { BackgroundTransparency = 1 }):Play()
	task.delay(0.5, function()
		flash:Destroy()
	end)
end

return UIRoot
