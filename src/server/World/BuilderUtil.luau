--!strict
-- Shared helpers for constructing blockout world geometry.

local BuilderUtil = {}

export type PartProps = {
	Name: string?,
	Size: Vector3,
	CFrame: CFrame?,
	Position: Vector3?,
	Color: Color3,
	Material: Enum.Material?,
	Anchored: boolean?,
	CanCollide: boolean?,
	CanQuery: boolean?,
	CanTouch: boolean?,
	CastShadow: boolean?,
	Transparency: number?,
	Shape: Enum.PartType?,
	Reflectance: number?,
	Parent: Instance?,
}

function BuilderUtil.part(props: PartProps): Part
	local instance = Instance.new("Part")
	instance.Name = props.Name or "Part"
	instance.Anchored = props.Anchored ~= false
	instance.CanCollide = props.CanCollide ~= false
	instance.CanQuery = props.CanQuery ~= false
	instance.CanTouch = props.CanTouch ~= false
	instance.CastShadow = props.CastShadow ~= false
	instance.Size = props.Size
	instance.CFrame = props.CFrame or CFrame.new(props.Position or Vector3.zero)
	instance.Color = props.Color
	instance.Material = props.Material or Enum.Material.SmoothPlastic
	instance.Transparency = props.Transparency or 0
	instance.Reflectance = props.Reflectance or 0
	instance.TopSurface = Enum.SurfaceType.Smooth
	instance.BottomSurface = Enum.SurfaceType.Smooth
	if props.Shape then
		instance.Shape = props.Shape
	end
	if props.Parent then
		instance.Parent = props.Parent
	end
	return instance
end

function BuilderUtil.pointLight(parent: BasePart, color: Color3, brightness: number, range: number): PointLight
	local light = Instance.new("PointLight")
	light.Color = color
	light.Brightness = brightness
	light.Range = range
	light.Shadows = false
	light.Parent = parent
	return light
end

function BuilderUtil.billboard(
	adornee: BasePart,
	text: string,
	color: Color3,
	width: number,
	height: number,
	parent: Instance?
): BillboardGui
	local gui = Instance.new("BillboardGui")
	gui.Name = "Label"
	gui.Size = UDim2.fromOffset(width, height)
	gui.StudsOffsetWorldSpace = Vector3.new(0, height / 40, 0)
	gui.AlwaysOnTop = false
	gui.MaxDistance = 250
	gui.Adornee = adornee

	local label = Instance.new("TextLabel")
	label.BackgroundTransparency = 1
	label.Size = UDim2.fromScale(1, 1)
	label.Font = Enum.Font.GothamBold
	label.Text = text
	label.TextColor3 = color
	label.TextScaled = true
	label.TextWrapped = true
	label.Parent = gui

	gui.Parent = parent or adornee
	return gui
end

return BuilderUtil
