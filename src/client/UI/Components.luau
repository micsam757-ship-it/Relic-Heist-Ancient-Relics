--!strict
-- Reusable UI component factory. Produces accessible, consistent Roblox GUI
-- elements (visible focus, readable text, large touch targets).

local TweenService = game:GetService("TweenService")

local Theme = require(script.Parent.Theme)

local Components = {}

local function corner(parent: Instance, radius: UDim)
	local instance = Instance.new("UICorner")
	instance.CornerRadius = radius
	instance.Parent = parent
end

local function stroke(parent: Instance, color: Color3, thickness: number?)
	local instance = Instance.new("UIStroke")
	instance.Color = color
	instance.Thickness = thickness or 1.4
	instance.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	instance.Parent = parent
	return instance
end

function Components.panel(parent: Instance, props)
	local frame = Instance.new("Frame")
	frame.Name = props.Name or "Panel"
	frame.Size = props.Size or UDim2.fromScale(1, 1)
	frame.Position = props.Position or UDim2.fromScale(0, 0)
	frame.AnchorPoint = props.AnchorPoint or Vector2.new(0, 0)
	frame.BackgroundColor3 = props.Color or Theme.Color.Panel
	frame.BackgroundTransparency = props.Transparency or 0
	frame.BorderSizePixel = 0
	frame.ClipsDescendants = props.ClipsDescendants ~= false
	frame.Parent = parent
	corner(frame, props.Radius or Theme.Radius.Medium)
	if props.Stroke ~= false then
		stroke(frame, props.StrokeColor or Theme.Color.Border, props.StrokeThickness)
	end
	return frame
end

function Components.label(parent: Instance, props)
	local label = Instance.new("TextLabel")
	label.Name = props.Name or "Label"
	label.BackgroundTransparency = 1
	label.Size = props.Size or UDim2.fromScale(1, 1)
	label.Position = props.Position or UDim2.fromScale(0, 0)
	label.AnchorPoint = props.AnchorPoint or Vector2.new(0, 0)
	label.Font = props.Font or Theme.Font.Body
	label.Text = props.Text or ""
	label.TextColor3 = props.TextColor or Theme.Color.Text
	label.TextSize = props.TextSize or Theme.TextSize.Body
	label.TextWrapped = props.Wrapped ~= false
	label.TextXAlignment = props.AlignX or Enum.TextXAlignment.Left
	label.TextYAlignment = props.AlignY or Enum.TextYAlignment.Center
	label.RichText = props.RichText == true
	if props.AutomaticSizeY then
		label.AutomaticSize = Enum.AutomaticSize.Y
	end
	label.Parent = parent
	return label
end

function Components.badge(parent: Instance, props)
	local rarity = props.rarity or "Common"
	local color = Theme.Rarity[rarity] or Theme.Rarity.Common
	local frame = Instance.new("Frame")
	frame.Name = "Badge"
	frame.Size = props.Size or UDim2.fromOffset(26, 26)
	frame.Position = props.Position or UDim2.fromScale(0, 0)
	frame.AnchorPoint = props.AnchorPoint or Vector2.new(0, 0)
	frame.BackgroundColor3 = color
	frame.BackgroundTransparency = 0.78
	frame.BorderSizePixel = 0
	frame.Parent = parent
	corner(frame, Theme.Radius.Small)
	stroke(frame, color, 1.5)
	Components.label(frame, {
		Name = "Glyph",
		Text = Theme.RarityShort[rarity] or "?",
		Font = Theme.Font.Heading,
		TextColor = color,
		TextSize = props.TextSize or 16,
		AlignX = Enum.TextXAlignment.Center,
		AlignY = Enum.TextYAlignment.Center,
	})
	return frame
end

function Components.button(parent: Instance, props)
	local button = Instance.new("TextButton")
	button.Name = props.Name or "Button"
	button.Size = props.Size or UDim2.fromOffset(160, 44)
	button.Position = props.Position or UDim2.fromScale(0, 0)
	button.AnchorPoint = props.AnchorPoint or Vector2.new(0, 0)
	button.BackgroundColor3 = props.Color or Theme.Color.PanelRaised
	button.BackgroundTransparency = 0
	button.BorderSizePixel = 0
	button.AutoButtonColor = false
	button.Font = props.Font or Theme.Font.Heading
	button.Text = props.Text or "Button"
	button.TextColor3 = props.TextColor or Theme.Color.Text
	button.TextSize = props.TextSize or Theme.TextSize.Body
	button.TextWrapped = true
	button.Selectable = true
	button.Parent = parent
	corner(button, props.Radius or Theme.Radius.Medium)
	stroke(button, props.StrokeColor or Theme.Color.Border, 1.4)

	local baseColor = button.BackgroundColor3
	local hoverColor = props.HoverColor or baseColor:Lerp(Color3.new(1, 1, 1), 0.12)

	button.MouseEnter:Connect(function()
		if button:GetAttribute("Disabled") then
			return
		end
		TweenService:Create(button, TweenInfo.new(0.12), { BackgroundColor3 = hoverColor }):Play()
	end)
	button.MouseLeave:Connect(function()
		TweenService:Create(button, TweenInfo.new(0.12), { BackgroundColor3 = baseColor }):Play()
	end)
	button.MouseButton1Down:Connect(function()
		TweenService
			:Create(button, TweenInfo.new(0.06), { BackgroundColor3 = baseColor:Lerp(Color3.new(0, 0, 0), 0.2) })
			:Play()
	end)
	button.MouseButton1Up:Connect(function()
		TweenService:Create(button, TweenInfo.new(0.06), { BackgroundColor3 = baseColor }):Play()
	end)

	if props.OnClick then
		button.Activated:Connect(function()
			if button:GetAttribute("Disabled") then
				return
			end
			if props.Cooldown then
				if button:GetAttribute("Cooling") then
					return
				end
				button:SetAttribute("Cooling", true)
				task.delay(props.Cooldown, function()
					button:SetAttribute("Cooling", false)
				end)
			end
			props.OnClick()
		end)
	end

	return button
end

function Components.setDisabled(button: TextButton, disabled: boolean)
	button:SetAttribute("Disabled", disabled)
	button.BackgroundTransparency = disabled and 0.5 or 0
	button.TextTransparency = disabled and 0.35 or 0
end

function Components.textBox(parent: Instance, props)
	local box = Instance.new("TextBox")
	box.Name = props.Name or "TextBox"
	box.Size = props.Size or UDim2.new(1, 0, 0, 40)
	box.Position = props.Position or UDim2.fromScale(0, 0)
	box.AnchorPoint = props.AnchorPoint or Vector2.new(0, 0)
	box.BackgroundColor3 = Theme.Color.Background
	box.BorderSizePixel = 0
	box.Font = props.Font or Theme.Font.Mono
	box.Text = props.Text or ""
	box.PlaceholderText = props.PlaceholderText or ""
	box.PlaceholderColor3 = Theme.Color.TextDim
	box.TextColor3 = Theme.Color.Text
	box.TextSize = props.TextSize or Theme.TextSize.Body
	box.TextXAlignment = Enum.TextXAlignment.Left
	box.ClearTextOnFocus = props.ClearTextOnFocus == true
	box.Parent = parent
	corner(box, Theme.Radius.Small)
	stroke(box, Theme.Color.Border, 1.2)

	local padding = Instance.new("UIPadding")
	padding.PaddingLeft = UDim.new(0, 10)
	padding.PaddingRight = UDim.new(0, 10)
	padding.Parent = box

	return box
end

function Components.bar(parent: Instance, props)
	local frame = Instance.new("Frame")
	frame.Name = props.Name or "Bar"
	frame.Size = props.Size or UDim2.new(1, 0, 0, 16)
	frame.Position = props.Position or UDim2.fromScale(0, 0)
	frame.AnchorPoint = props.AnchorPoint or Vector2.new(0, 0)
	frame.BackgroundColor3 = Theme.Color.Background
	frame.BorderSizePixel = 0
	frame.Parent = parent
	corner(frame, Theme.Radius.Small)
	stroke(frame, Theme.Color.Border, 1)

	local fill = Instance.new("Frame")
	fill.Name = "Fill"
	fill.Size = UDim2.fromScale(0, 1)
	fill.BackgroundColor3 = props.FillColor or Theme.Color.Cyan
	fill.BorderSizePixel = 0
	fill.Parent = frame
	corner(fill, Theme.Radius.Small)

	local text = Components.label(frame, {
		Name = "BarText",
		Text = "",
		Font = Theme.Font.Heading,
		TextSize = props.TextSize or 13,
		TextColor = Theme.Color.Text,
		AlignX = Enum.TextXAlignment.Center,
		AlignY = Enum.TextYAlignment.Center,
		Size = UDim2.fromScale(1, 1),
	})

	local currentTween: Tween? = nil
	local lastRatio = 0
	local lastLabel: string? = nil

	return {
		frame = frame,
		fill = fill,
		text = text,
		set = function(ratio: number, label: string?)
			local clamped = math.clamp(ratio, 0, 1)
			-- The expedition HUD calls this on a timer. Only touch the tween when
			-- the ratio actually moved, otherwise a per-frame caller allocates a
			-- tween every frame and the work never stops between relic pickups.
			if math.abs(clamped - lastRatio) >= 0.002 then
				lastRatio = clamped
				if currentTween then
					currentTween:Cancel()
				end
				currentTween = TweenService:Create(fill, TweenInfo.new(0.2), { Size = UDim2.fromScale(clamped, 1) })
				currentTween:Play()
			end
			if label ~= nil and label ~= lastLabel then
				lastLabel = label
				text.Text = label
			end
		end,
		setColor = function(color: Color3)
			fill.BackgroundColor3 = color
		end,
	}
end

function Components.scroll(parent: Instance, props)
	local frame = Instance.new("ScrollingFrame")
	frame.Name = props.Name or "Scroll"
	frame.Size = props.Size or UDim2.fromScale(1, 1)
	frame.Position = props.Position or UDim2.fromScale(0, 0)
	frame.AnchorPoint = props.AnchorPoint or Vector2.new(0, 0)
	frame.BackgroundTransparency = 1
	frame.BorderSizePixel = 0
	frame.ScrollBarThickness = 6
	frame.ScrollBarImageColor3 = Theme.Color.Bronze
	frame.AutomaticCanvasSize = Enum.AutomaticSize.Y
	frame.CanvasSize = UDim2.new()
	frame.Parent = parent

	local padding = Instance.new("UIPadding")
	padding.PaddingLeft = UDim.new(0, Theme.Padding.S)
	padding.PaddingRight = UDim.new(0, Theme.Padding.S)
	padding.PaddingTop = UDim.new(0, Theme.Padding.S)
	padding.PaddingBottom = UDim.new(0, Theme.Padding.S)
	padding.Parent = frame

	local layout = Instance.new("UIListLayout")
	layout.Padding = UDim.new(0, props.Spacing or Theme.Padding.S)
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Parent = frame

	return frame, layout
end

function Components.divider(parent: Instance, position: UDim2?)
	local line = Instance.new("Frame")
	line.Name = "Divider"
	line.Size = UDim2.new(1, 0, 0, 1)
	line.Position = position or UDim2.fromScale(0, 0)
	line.BackgroundColor3 = Theme.Color.Border
	line.BackgroundTransparency = 0.4
	line.BorderSizePixel = 0
	line.Parent = parent
	return line
end

function Components.modal(host: Instance, props)
	local backdrop = Instance.new("TextButton")
	backdrop.Name = "ModalBackdrop"
	backdrop.Size = UDim2.fromScale(1, 1)
	backdrop.BackgroundColor3 = Theme.Color.Scrim
	backdrop.BackgroundTransparency = 0.45
	backdrop.BorderSizePixel = 0
	backdrop.Text = ""
	backdrop.AutoButtonColor = false
	backdrop.ZIndex = 20
	backdrop.Parent = host

	local frame = Components.panel(backdrop, {
		Name = props.Name or "Modal",
		Size = props.Size or UDim2.fromOffset(520, 420),
		Position = UDim2.fromScale(0.5, 0.5),
		AnchorPoint = Vector2.new(0.5, 0.5),
		Color = Theme.Color.Panel,
		Radius = Theme.Radius.Large,
		ClipsDescendants = true,
	})
	frame.ZIndex = 21

	local title = Components.label(frame, {
		Name = "Title",
		Text = props.Title or "",
		Font = Theme.Font.Title,
		TextSize = Theme.TextSize.Heading,
		TextColor = Theme.Color.Gold,
		Size = UDim2.new(1, -80, 0, 44),
		Position = UDim2.fromOffset(20, 10),
		AlignY = Enum.TextYAlignment.Center,
	})

	local close = Components.button(frame, {
		Name = "Close",
		Text = "X",
		Size = UDim2.fromOffset(38, 38),
		Position = UDim2.new(1, -48, 0, 12),
		Color = Theme.Color.DangerDeep,
		TextColor = Theme.Color.Text,
		OnClick = function()
			backdrop:Destroy()
		end,
	})

	local body = Instance.new("Frame")
	body.Name = "Body"
	body.BackgroundTransparency = 1
	body.Size = UDim2.new(1, -32, 1, -76)
	body.Position = UDim2.fromOffset(16, 62)
	body.Parent = frame

	return {
		backdrop = backdrop,
		frame = frame,
		body = body,
		title = title,
		close = close,
		destroy = function()
			backdrop:Destroy()
		end,
		setTitle = function(text: string)
			title.Text = text
		end,
	}
end

function Components.toast(host: Instance, kind: string, message: string)
	local colors: { [string]: Color3 } = {
		success = Theme.Color.Success,
		error = Theme.Color.Danger,
		warning = Theme.Color.Warning,
		info = Theme.Color.Cyan,
	}
	local accent = colors[kind] or Theme.Color.Cyan

	local frame = Components.panel(host, {
		Name = "Toast",
		Size = UDim2.new(1, 0, 0, 44),
		Color = Theme.Color.Panel,
		Radius = Theme.Radius.Medium,
		StrokeColor = accent,
		ClipsDescendants = true,
	})
	frame.AutomaticSize = Enum.AutomaticSize.Y
	frame.BackgroundTransparency = 0.05

	local sizeConstraint = Instance.new("UISizeConstraint")
	sizeConstraint.MinSize = Vector2.new(0, 44)
	sizeConstraint.Parent = frame

	local strip = Instance.new("Frame")
	strip.Size = UDim2.new(0, 5, 1, 0)
	strip.BackgroundColor3 = accent
	strip.BorderSizePixel = 0
	strip.Parent = frame

	local padding = Instance.new("UIPadding")
	padding.PaddingLeft = UDim.new(0, 16)
	padding.PaddingRight = UDim.new(0, 12)
	padding.PaddingTop = UDim.new(0, 10)
	padding.PaddingBottom = UDim.new(0, 10)
	padding.Parent = frame

	local label = Components.label(frame, {
		Text = message,
		Font = Theme.Font.Body,
		TextSize = Theme.TextSize.Small,
		TextColor = Theme.Color.Text,
		Size = UDim2.new(1, -10, 0, 0),
		Wrapped = true,
		AutomaticSizeY = true,
	})

	task.delay(3, function()
		TweenService:Create(frame, TweenInfo.new(0.25), { BackgroundTransparency = 1 }):Play()
		TweenService:Create(strip, TweenInfo.new(0.25), { BackgroundTransparency = 1 }):Play()
		TweenService:Create(label, TweenInfo.new(0.25), { TextTransparency = 1 }):Play()
		task.wait(0.3)
		frame:Destroy()
	end)

	return frame
end

return Components
