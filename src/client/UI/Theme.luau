--!strict
-- Client design system: colors, typography, spacing, and rarity mapping.
-- See docs/HCI_DESIGN.md for rationale.
--
-- `Theme.applyPreferences` re-points the palette and text scale at runtime from
-- the player's settings (colorblind mode, text size), so widgets that read
-- `Theme.Color`/`Theme.TextSize` at build time pick up the values in effect when
-- they are created. Panels rebuild on every snapshot, so a change applies on the
-- next push.

local Theme = {}

local BASE_COLOR = {
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

-- Colorblind-safe variants. Red/green cues (danger/success) become blue/orange,
-- which stay distinguishable under deuteranopia/protanopia. Gold/cyan already
-- separate on the blue-yellow axis and are left alone.
local COLORBLIND_COLOR = table.clone(BASE_COLOR)
COLORBLIND_COLOR.Danger = Color3.fromRGB(84, 150, 230)
COLORBLIND_COLOR.DangerDeep = Color3.fromRGB(38, 74, 140)
COLORBLIND_COLOR.Success = Color3.fromRGB(240, 160, 48)
COLORBLIND_COLOR.Warning = Color3.fromRGB(232, 200, 64)

local BASE_RARITY = {
	Common = Color3.fromRGB(196, 178, 140),
	Rare = Color3.fromRGB(78, 160, 220),
	Legendary = Color3.fromRGB(235, 166, 58),
	Mythic = Color3.fromRGB(196, 92, 224),
}

-- Rarity is also cued by the letter badge (C/R/L/M), so a colorblind palette
-- only needs the hues to remain mutually distinct.
local COLORBLIND_RARITY = {
	Common = Color3.fromRGB(205, 205, 205),
	Rare = Color3.fromRGB(90, 170, 235),
	Legendary = Color3.fromRGB(245, 195, 70),
	Mythic = Color3.fromRGB(235, 235, 255),
}

local BASE_TEXT_SIZE = {
	Small = 14,
	Body = 17,
	Heading = 22,
	Title = 30,
}

local TEXT_SCALE_MULTIPLIERS = {
	Normal = 1,
	Large = 1.25,
	Huge = 1.5,
}

Theme.Color = BASE_COLOR
Theme.Rarity = BASE_RARITY
Theme.TextSize = BASE_TEXT_SIZE

Theme.Font = {
	Title = Enum.Font.GothamBlack,
	Heading = Enum.Font.GothamBold,
	Body = Enum.Font.Gotham,
	Mono = Enum.Font.Code,
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

local currentTextScale = "Normal"

-- Applies the player's accessibility preferences to the shared palette and text
-- sizes. Safe to call repeatedly (e.g. on every snapshot).
function Theme.applyPreferences(settings)
	local colorblind = settings and settings.colorblindMode == true
	Theme.Color = colorblind and COLORBLIND_COLOR or BASE_COLOR
	Theme.Rarity = colorblind and COLORBLIND_RARITY or BASE_RARITY

	local scale = "Normal"
	if settings and type(settings.textScale) == "string" and TEXT_SCALE_MULTIPLIERS[settings.textScale] then
		scale = settings.textScale
	end
	if scale ~= currentTextScale then
		currentTextScale = scale
		local multiplier = TEXT_SCALE_MULTIPLIERS[scale]
		Theme.TextSize = {
			Small = math.floor(BASE_TEXT_SIZE.Small * multiplier),
			Body = math.floor(BASE_TEXT_SIZE.Body * multiplier),
			Heading = math.floor(BASE_TEXT_SIZE.Heading * multiplier),
			Title = math.floor(BASE_TEXT_SIZE.Title * multiplier),
		}
	end
end

function Theme.textScaleMultiplier(): number
	return TEXT_SCALE_MULTIPLIERS[currentTextScale] or 1
end

return Theme
