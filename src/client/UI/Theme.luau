--!strict
-- Client design system: colors, typography, spacing, and rarity mapping.
-- See docs/HCI_DESIGN.md for rationale.

local Theme = {}

Theme.Color = {
	Background = Color3.fromRGB(22, 18, 15),
	Scrim = Color3.fromRGB(0, 0, 0),
	Panel = Color3.fromRGB(38, 31, 24),
	PanelAlt = Color3.fromRGB(48, 39, 30),
	PanelRaised = Color3.fromRGB(58, 47, 36),
	Border = Color3.fromRGB(96, 78, 52),
	Gold = Color3.fromRGB(232, 184, 84),
	GoldDeep = Color3.fromRGB(166, 124, 48),
	Bronze = Color3.fromRGB(178, 132, 76),
	Cyan = Color3.fromRGB(84, 214, 220),
	CyanDeep = Color3.fromRGB(38, 118, 128),
	Text = Color3.fromRGB(244, 236, 220),
	TextMuted = Color3.fromRGB(176, 166, 148),
	TextDim = Color3.fromRGB(128, 120, 106),
	Danger = Color3.fromRGB(220, 84, 68),
	DangerDeep = Color3.fromRGB(128, 40, 34),
	Success = Color3.fromRGB(118, 200, 120),
	Warning = Color3.fromRGB(230, 168, 72),
	Overlay = Color3.fromRGB(12, 10, 8),
}

Theme.Font = {
	Title = Enum.Font.GothamBlack,
	Heading = Enum.Font.GothamBold,
	Body = Enum.Font.Gotham,
	Mono = Enum.Font.Code,
}

Theme.Rarity = {
	Common = Color3.fromRGB(196, 178, 140),
	Rare = Color3.fromRGB(78, 160, 220),
	Legendary = Color3.fromRGB(235, 166, 58),
	Mythic = Color3.fromRGB(196, 92, 224),
}

Theme.RarityShort = {
	Common = "C",
	Rare = "R",
	Legendary = "L",
	Mythic = "M",
}

Theme.Radius = {
	Small = UDim.new(0, 6),
	Medium = UDim.new(0, 10),
	Large = UDim.new(0, 16),
	Pill = UDim.new(1, 0),
}

Theme.Padding = {
	XS = 4,
	S = 8,
	M = 12,
	L = 18,
	XL = 26,
}

Theme.TextSize = {
	Small = 14,
	Body = 17,
	Heading = 22,
	Title = 30,
}

return Theme
