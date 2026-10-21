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

-- Creates a purely decorative part: anchored, non-colliding, non-queryable,
-- non-touchable and unable to cast shadows. Used for horizon scenery that must
-- never affect gameplay, raycasts or the lighting cost of the world.
function BuilderUtil.decorative(props: PartProps): Part
	return BuilderUtil.part({
		Name = props.Name,
		Size = props.Size,
		CFrame = props.CFrame,
		Position = props.Position,
		Color = props.Color,
		Material = props.Material,
		Anchored = true,
		CanCollide = false,
		CanQuery = false,
		CanTouch = false,
		CastShadow = false,
		Transparency = props.Transparency,
		Shape = props.Shape,
		Reflectance = props.Reflectance,
		Parent = props.Parent,
	})
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
