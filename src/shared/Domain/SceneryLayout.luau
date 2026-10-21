--!strict
-- Pure layout rules for the world footprint and the decorative scenery that
-- frames it: the rounded-rectangle ground shape, the belt of forest that hugs
-- the playable content, and the layered rocky escarpment that closes the
-- horizon just behind the trees.
--
-- No Roblox APIs are used here, so every geometric invariant can be asserted
-- under the standalone Luau CLI (`luau tests/run_tests.luau`). `GroundBuilder`
-- and `SceneryBuilder` consume this module and only turn the returned numbers
-- into parts. The module deliberately requires nothing else, so the same file
-- loads in Studio and in the standalone test runner.
--
-- Conventions
--   * 2D coordinates are (x, z) pairs in the world XZ plane.
--   * A yaw rotation about +Y maps the local +X axis to (cos yaw, -sin yaw) and
--     the local +Z axis to (sin yaw, cos yaw). That is the Roblox
--     `CFrame.Angles(0, yaw, 0)` convention, so a part whose local +X should
--     point along the world vector `u` uses `yaw = math.atan2(-u.z, u.x)`.
--   * `w = (-u.z, u.x)` is the left-hand perpendicular of `u`. On the
--     escarpment ring it points towards the interior of the map.
--
-- Determinism
--   * The grove uses a Park-Miller generator (`state * 16807 mod 2147483647`)
--     seeded from the caller, so a given seed always yields the same forest.
--   * Every candidate draws its values in one pinned order: jitter X, jitter Z,
--     yaw, trunk width, trunk height, canopy width, canopy depth, canopy
--     height. The stream therefore depends only on (seed, band, row, column)
--     and never on how many candidates were rejected earlier.

export type RegionKind = "box" | "disc" | "orientedBox"

-- One area the scenery has to respect. `hard` regions are the playable
-- content itself - the temple halls, the museum plots and the plaza - and
-- measure where the forest belt starts. The soft regions are the paths and the
-- museum forecourt: the forest is allowed to crowd and overhang them.
export type ProtectedRegion = {
	name: string,
	kind: RegionKind,
	-- Box bounds.
	minX: number,
	maxX: number,
	minZ: number,
	maxZ: number,
	-- Disc centre, or the centre of an oriented box.
	centerX: number,
	centerZ: number,
	-- Disc radius.
	radius: number,
	-- Oriented box half sizes: width along the local +X, length along +Z.
	halfWidth: number,
	halfLength: number,
	-- Oriented box yaw, in the Roblox convention.
	yaw: number,
	-- The base exclusion margin. The canopy reach is added to it, so the
	-- canopy edge never comes closer than `margin` to the region.
	margin: number,
	-- True for the playable content the forest belt is measured from.
	hard: boolean,
	-- True for a region that only the forest belt may enter. The museum
	-- court is such a region: the belt may line its edge, but the scattered
	-- trees further out may not wander onto it.
	beltOnly: boolean,
}

-- A rounded rectangle: a rectangle whose four corners are replaced by
-- quarter-circle arcs of `cornerRadius`.
export type RoundedRect = {
	minX: number,
	maxX: number,
	minZ: number,
	maxZ: number,
	cornerRadius: number,
}

export type Point2 = { x: number, z: number }

-- The narrow inputs the layout needs. They are kept flat and explicit so the
-- module never depends on the shape of `GameConfig`, and so the builder and
-- the tests can hand it the same data without guessing.
export type TempleFootprint = {
	id: string,
	originX: number,
	originZ: number,
	hallWidth: number,
	hallLength: number,
}

export type WorldFootprint = {
	ringRadius: number,
	plotCount: number,
	startAngleDegrees: number,
	apronWidth: number,
	apronLength: number,
	apronOffsetZ: number,
	avenueWidth: number,
	plazaRadius: number,
}

export type TreeDef = {
	index: number,
	x: number,
	z: number,
	yaw: number,
	trunkWidth: number,
	trunkHeight: number,
	canopyWidth: number,
	canopyDepth: number,
	canopyHeight: number,
	decorative: boolean,
}

-- One rock block of the rim. `cliff` blocks form the wall itself and
-- `crest` blocks step back on top of it, so the wall reads as layered rock
-- rather than a single extruded ribbon.
export type EscarpmentDef = {
	index: number,
	layer: "cliff" | "crest",
	centerX: number,
	centerZ: number,
	yaw: number,
	length: number,
	depth: number,
	height: number,
	-- The bottom of the block, so a crest block can sit on its cliff block.
	baseY: number,
	uX: number,
	uZ: number,
	wX: number,
	wZ: number,
	decorative: boolean,
}

-- One band of the grove. The band is measured to the edge of the canopy, not
-- to the trunk: a tree whose canopy edge sits `inner` studs beyond the
-- playable content has its centre `inner + canopy reach` studs beyond it.
export type GroveBand = {
	inner: number,
	outer: number?,
	spacing: number,
}

export type GroveSpec = {
	bands: { GroveBand },
	-- How far a tree centre must stay inside the ground footprint.
	groundClearance: number,
	-- The jitter applied to a candidate, as a fraction of its spacing.
	jitterFraction: number,
	-- The closest two tree centres may be.
	minSpacing: number,
}

export type EscarpmentSpec = {
	-- How deep the rocky band reaches inwards from the ground edge.
	depth: number,
	-- How much a block may be shallower than `depth`, so the inner face of the
	-- wall is jagged instead of a clean curve.
	depthVariation: number,
	-- How far each segment runs past the shared vertices, so consecutive
	-- segments overlap instead of meeting on a hairline seam.
	overlap: number,
	-- The target length of one segment along the outline.
	segmentLength: number,
	minHeight: number,
	maxHeight: number,
	-- A crest block is placed on every n-th cliff block.
	crestEvery: number,
	-- How much taller than its cliff block a crest block rises.
	crestHeight: number,
	-- How deep a crest block is.
	crestDepth: number,
}

-- Everything the layout needs, already reduced to plain numbers.
export type SceneryInputs = {
	ground: RoundedRect,
	content: RoundedRect,
	regions: { ProtectedRegion },
	grove: GroveSpec,
	escarpment: EscarpmentSpec,
	seed: number,
}

local SceneryLayout = {}

-- Rounded rectangle ---------------------------------------------------------

-- The centre of the shape.
function SceneryLayout.centre(shape: RoundedRect): Point2
	return {
		x = (shape.minX + shape.maxX) / 2,
		z = (shape.minZ + shape.maxZ) / 2,
	}
end

-- The half-extents along X and Z.
function SceneryLayout.halfExtents(shape: RoundedRect): (number, number)
	return (shape.maxX - shape.minX) / 2, (shape.maxZ - shape.minZ) / 2
end

-- The effective corner radius: never larger than the shorter half-extent, so a
-- degenerate shape cannot invert.
function SceneryLayout.radius(shape: RoundedRect): number
	local halfX, halfZ = SceneryLayout.halfExtents(shape)
	return math.min(shape.cornerRadius, halfX, halfZ)
end

-- Signed distance to the shape: negative inside, positive outside, and the
-- true distance through the corner arcs.
function SceneryLayout.signedDistance(shape: RoundedRect, x: number, z: number): number
	local centre = SceneryLayout.centre(shape)
	local halfX, halfZ = SceneryLayout.halfExtents(shape)
	local radius = SceneryLayout.radius(shape)
	local dx = math.abs(x - centre.x) - (halfX - radius)
	local dz = math.abs(z - centre.z) - (halfZ - radius)
	local outside = math.sqrt((math.max(dx, 0) ^ 2) + (math.max(dz, 0) ^ 2))
	local inside = math.min(math.max(dx, dz), 0)
	return outside + inside - radius
end

-- True when the point lies inside the shape (the boundary counts as inside).
function SceneryLayout.contains(shape: RoundedRect, x: number, z: number): boolean
	return SceneryLayout.signedDistance(shape, x, z) <= 0
end

-- The half-extent of the shape along one axis at a fixed coordinate on the
-- other axis. The ground builder uses this to clip the inlaid grid lines to
-- the footprint so no inlay hangs over the edge.
function SceneryLayout.extentAt(shape: RoundedRect, axis: "x" | "z", coordinate: number): number
	local centre = SceneryLayout.centre(shape)
	local halfX, halfZ = SceneryLayout.halfExtents(shape)
	local radius = SceneryLayout.radius(shape)
	if axis == "x" then
		local over = math.abs(coordinate - centre.x) - (halfX - radius)
		if over <= 0 then
			return halfZ
		end
		return (halfZ - radius) + math.sqrt(math.max(radius * radius - over * over, 0))
	end
	local over = math.abs(coordinate - centre.z) - (halfZ - radius)
	if over <= 0 then
		return halfX
	end
	return (halfX - radius) + math.sqrt(math.max(radius * radius - over * over, 0))
end

-- One piece of the outline: either a straight side or a quarter-circle arc.
type OutlinePiece = {
	kind: string,
	length: number,
	-- Side: the start point and the unit direction.
	startX: number,
	startZ: number,
	directionX: number,
	directionZ: number,
	-- Arc: the centre and the start angle.
	centerX: number,
	centerZ: number,
	startAngle: number,
}

-- The outline of the shape, counter-clockwise, split into sides and arcs.
function SceneryLayout.outline(shape: RoundedRect): { OutlinePiece }
	local centre = SceneryLayout.centre(shape)
	local halfX, halfZ = SceneryLayout.halfExtents(shape)
	local radius = SceneryLayout.radius(shape)
	local innerX = halfX - radius
	local innerZ = halfZ - radius
	local pieces: { OutlinePiece } = {}

	-- Right side, running towards +Z.
	table.insert(pieces, {
		kind = "side",
		length = innerZ * 2,
		startX = centre.x + halfX,
		startZ = centre.z - innerZ,
		directionX = 0,
		directionZ = 1,
		centerX = 0,
		centerZ = 0,
		startAngle = 0,
	})
	-- North-east arc.
	table.insert(pieces, {
		kind = "arc",
		length = radius * math.pi / 2,
		startX = 0,
		startZ = 0,
		directionX = 0,
		directionZ = 0,
		centerX = centre.x + innerX,
		centerZ = centre.z + innerZ,
		startAngle = 0,
	})
	-- Top side, running towards -X.
	table.insert(pieces, {
		kind = "side",
		length = innerX * 2,
		startX = centre.x + innerX,
		startZ = centre.z + halfZ,
		directionX = -1,
		directionZ = 0,
		centerX = 0,
		centerZ = 0,
		startAngle = 0,
	})
	-- North-west arc.
	table.insert(pieces, {
		kind = "arc",
		length = radius * math.pi / 2,
		startX = 0,
		startZ = 0,
		directionX = 0,
		directionZ = 0,
		centerX = centre.x - innerX,
		centerZ = centre.z + innerZ,
		startAngle = math.pi / 2,
	})
	-- Left side, running towards -Z.
	table.insert(pieces, {
		kind = "side",
		length = innerZ * 2,
		startX = centre.x - halfX,
		startZ = centre.z + innerZ,
		directionX = 0,
		directionZ = -1,
		centerX = 0,
		centerZ = 0,
		startAngle = 0,
	})
	-- South-west arc.
	table.insert(pieces, {
		kind = "arc",
		length = radius * math.pi / 2,
		startX = 0,
		startZ = 0,
		directionX = 0,
		directionZ = 0,
		centerX = centre.x - innerX,
		centerZ = centre.z - innerZ,
		startAngle = math.pi,
	})
	-- Bottom side, running towards +X.
	table.insert(pieces, {
		kind = "side",
		length = innerX * 2,
		startX = centre.x - innerX,
		startZ = centre.z - halfZ,
		directionX = 1,
		directionZ = 0,
		centerX = 0,
		centerZ = 0,
		startAngle = 0,
	})
	-- South-east arc.
	table.insert(pieces, {
		kind = "arc",
		length = radius * math.pi / 2,
		startX = 0,
		startZ = 0,
		directionX = 0,
		directionZ = 0,
		centerX = centre.x + innerX,
		centerZ = centre.z - innerZ,
		startAngle = 3 * math.pi / 2,
	})

	return pieces
end

-- The total length of the outline.
function SceneryLayout.perimeterLength(shape: RoundedRect): number
	local total = 0
	for _, piece in SceneryLayout.outline(shape) do
		total += piece.length
	end
	return total
end

-- The outline sampled counter-clockwise every `spacing` studs. The last point
-- repeats the first, so the polyline is a closed loop.
function SceneryLayout.perimeter(shape: RoundedRect, spacing: number): { Point2 }
	local pieces = SceneryLayout.outline(shape)
	local total = SceneryLayout.perimeterLength(shape)
	local count = math.max(8, math.floor(total / math.max(spacing, 1)))
	local step = total / count
	local points: { Point2 } = {}
	local pieceIndex = 1
	local consumed = 0
	for index = 0, count do
		local target = index * step
		while pieceIndex < #pieces and target > consumed + pieces[pieceIndex].length do
			consumed += pieces[pieceIndex].length
			pieceIndex += 1
		end
		local piece = pieces[pieceIndex]
		local along = target - consumed
		if piece.kind == "side" then
			table.insert(points, {
				x = piece.startX + (piece.directionX * along),
				z = piece.startZ + (piece.directionZ * along),
			})
		else
			local angle = piece.startAngle + (along / piece.length) * (math.pi / 2)
			local radius = SceneryLayout.radius(shape)
			table.insert(points, {
				x = piece.centerX + radius * math.cos(angle),
				z = piece.centerZ + radius * math.sin(angle),
			})
		end
	end
	return points
end

-- Polygon helpers -----------------------------------------------------------

-- The signed area of a closed polygon. Positive when the vertices run
-- counter-clockwise in the XZ plane.
function SceneryLayout.polygonArea(poly: { Point2 }): number
	local total = 0
	for index = 1, #poly do
		local a = poly[index]
		local b = poly[(index % #poly) + 1]
		total += (a.x * b.z) - (b.x * a.z)
	end
	return total / 2
end

-- The intersection of two convex polygons, clipped with Sutherland-Hodgman.
-- Both polygons must be convex and wound the same way; the result may be
-- empty when they do not overlap.
function SceneryLayout.clipPolygon(subject: { Point2 }, clip: { Point2 }): { Point2 }
	local output = subject
	for index = 1, #clip do
		local a = clip[index]
		local b = clip[(index % #clip) + 1]
		local edgeX = b.x - a.x
		local edgeZ = b.z - a.z
		-- The clip polygon is counter-clockwise, so its interior is to the left
		-- of every edge: the cross product of the edge and the offset is
		-- negative inside and positive outside.
		local function inside(point: Point2): boolean
			return ((point.x - a.x) * edgeZ) - ((point.z - a.z) * edgeX) <= 0
		end
		local function intersect(p: Point2, q: Point2): Point2
			local dp = (p.x - a.x) * edgeZ - (p.z - a.z) * edgeX
			local dq = (q.x - a.x) * edgeZ - (q.z - a.z) * edgeX
			local t = dp / (dp - dq)
			return { x = p.x + (q.x - p.x) * t, z = p.z + (q.z - p.z) * t }
		end
		local input = output
		output = {}
		if #input == 0 then
			break
		end
		local previous = input[#input]
		for _, current in input do
			local currentInside = inside(current)
			local previousInside = inside(previous)
			if currentInside then
				if not previousInside then
					table.insert(output, intersect(previous, current))
				end
				table.insert(output, current)
			elseif previousInside then
				table.insert(output, intersect(previous, current))
			end
			previous = current
		end
	end
	return output
end

-- The area shared by two convex polygons.
function SceneryLayout.polygonOverlapArea(a: { Point2 }, b: { Point2 }): number
	local clipped = SceneryLayout.clipPolygon(a, b)
	if #clipped < 3 then
		return 0
	end
	return math.abs(SceneryLayout.polygonArea(clipped))
end

-- True when the point lies inside the polygon (the boundary counts as
-- inside).
function SceneryLayout.polygonContainsPoint(poly: { Point2 }, x: number, z: number): boolean
	local inside = false
	local previous = poly[#poly]
	for index = 1, #poly do
		local current = poly[index]
		local crosses = (current.z > z) ~= (previous.z > z)
		if crosses then
			local edgeX = current.x - previous.x
			local edgeZ = current.z - previous.z
			local hit = previous.x + ((z - previous.z) * edgeX / edgeZ)
			if x < hit then
				inside = not inside
			end
		end
		previous = current
	end
	return inside
end

-- Protected regions ---------------------------------------------------------

-- How far the canopy of a tree may reach past its trunk, at the worst. A
-- canopy is a yaw-rotated rectangle, so the half-diagonal of the largest
-- canopy bounds how far a corner can stick out.
SceneryLayout.TREE_CANOPY_HALF_MAX = 15
SceneryLayout.TREE_CANOPY_HALF_DIAGONAL = 15 * math.sqrt(2)
-- The clearance a canopy keeps from the playable content, measured from the
-- canopy edge rather than from the trunk.
SceneryLayout.TREE_CLEARANCE = 24
-- How far a canopy may overhang the edge of a path. The path stays walkable
-- because the canopy is high up, but the forest is allowed to crowd it.
SceneryLayout.PATH_OVERHANG = 4
-- The smallest overlap area two neighbouring escarpment segments may share.
SceneryLayout.ESCARPMENT_MIN_OVERLAP_AREA = 120
-- How far the escarpment band reaches past the ground edge. A small overhang
-- hides the seam between the straight rock segments and the rounded outline.
SceneryLayout.ESCARPMENT_OUTWARD_OVERHANG = 1
-- The hard ceiling on decorative parts for the redesign.
SceneryLayout.PART_BUDGET = 800

local RNG_MODULUS = 2147483647
local RNG_MULTIPLIER = 16807

type RandomState = { state: number }

local function nextRandom(rng: RandomState): number
	rng.state = (rng.state * RNG_MULTIPLIER) % RNG_MODULUS
	return rng.state / RNG_MODULUS
end

local function emptyRegion(name: string): ProtectedRegion
	return {
		name = name,
		kind = "box",
		minX = 0,
		maxX = 0,
		minZ = 0,
		maxZ = 0,
		centerX = 0,
		centerZ = 0,
		radius = 0,
		halfWidth = 0,
		halfLength = 0,
		yaw = 0,
		margin = 0,
		hard = false,
		beltOnly = false,
	}
end

local function boxRegion(
	name: string,
	minX: number,
	maxX: number,
	minZ: number,
	maxZ: number,
	margin: number,
	hard: boolean
): ProtectedRegion
	local region = emptyRegion(name)
	region.kind = "box"
	region.minX = minX
	region.maxX = maxX
	region.minZ = minZ
	region.maxZ = maxZ
	region.margin = margin
	region.hard = hard
	return region
end

local function discRegion(
	name: string,
	centerX: number,
	centerZ: number,
	radius: number,
	margin: number,
	hard: boolean
): ProtectedRegion
	local region = emptyRegion(name)
	region.kind = "disc"
	region.centerX = centerX
	region.centerZ = centerZ
	region.radius = radius
	region.margin = margin
	region.hard = hard
	return region
end

-- A box that is rotated about the Y axis, with its width along the local +X
-- and its length along the local +Z. The museum plots are laid out this way.
local function orientedRegion(
	name: string,
	centerX: number,
	centerZ: number,
	halfWidth: number,
	halfLength: number,
	yaw: number,
	margin: number,
	hard: boolean
): ProtectedRegion
	local region = emptyRegion(name)
	region.kind = "orientedBox"
	region.centerX = centerX
	region.centerZ = centerZ
	region.halfWidth = halfWidth
	region.halfLength = halfLength
	region.yaw = yaw
	region.margin = margin
	region.hard = hard
	-- The axis-aligned bounds, so the region can be tested against a shape.
	local cosYaw = math.abs(math.cos(yaw))
	local sinYaw = math.abs(math.sin(yaw))
	local spanX = (halfWidth * cosYaw) + (halfLength * sinYaw)
	local spanZ = (halfWidth * sinYaw) + (halfLength * cosYaw)
	region.minX = centerX - spanX
	region.maxX = centerX + spanX
	region.minZ = centerZ - spanZ
	region.maxZ = centerZ + spanZ
	return region
end

-- Distance from a point to an axis-aligned box (0 when the point is inside).
function SceneryLayout.distanceToBox(
	minX: number,
	maxX: number,
	minZ: number,
	maxZ: number,
	x: number,
	z: number
): number
	local dx = 0
	if x < minX then
		dx = minX - x
	elseif x > maxX then
		dx = x - maxX
	end
	local dz = 0
	if z < minZ then
		dz = minZ - z
	elseif z > maxZ then
		dz = z - maxZ
	end
	return math.sqrt((dx * dx) + (dz * dz))
end

-- Distance from a point to a disc (0 when the point is inside).
function SceneryLayout.distanceToDisc(centerX: number, centerZ: number, radius: number, x: number, z: number): number
	local dx = x - centerX
	local dz = z - centerZ
	local distance = math.sqrt((dx * dx) + (dz * dz))
	if distance <= radius then
		return 0
	end
	return distance - radius
end

-- Distance from a point to a rotated box (0 when the point is inside).
function SceneryLayout.distanceToOrientedBox(
	centerX: number,
	centerZ: number,
	halfWidth: number,
	halfLength: number,
	yaw: number,
	x: number,
	z: number
): number
	local dx = x - centerX
	local dz = z - centerZ
	local cosYaw = math.cos(yaw)
	local sinYaw = math.sin(yaw)
	-- The local +X axis of a Roblox yaw is (cos yaw, -sin yaw).
	local localX = (dx * cosYaw) - (dz * sinYaw)
	local localZ = (dx * sinYaw) + (dz * cosYaw)
	return SceneryLayout.distanceToBox(-halfWidth, halfWidth, -halfLength, halfLength, localX, localZ)
end

function SceneryLayout.distanceToRegion(region: ProtectedRegion, x: number, z: number): number
	if region.kind == "box" then
		return SceneryLayout.distanceToBox(region.minX, region.maxX, region.minZ, region.maxZ, x, z)
	elseif region.kind == "disc" then
		return SceneryLayout.distanceToDisc(region.centerX, region.centerZ, region.radius, x, z)
	end
	return SceneryLayout.distanceToOrientedBox(
		region.centerX,
		region.centerZ,
		region.halfWidth,
		region.halfLength,
		region.yaw,
		x,
		z
	)
end

-- The point of a region that lies closest to the given point. It is the point
-- the forest belt is measured towards, so the gap between the content and
-- the canopy can be measured exactly.
function SceneryLayout.closestPointOnRegion(region: ProtectedRegion, x: number, z: number): Point2
	if region.kind == "disc" then
		local dx = x - region.centerX
		local dz = z - region.centerZ
		local length = math.sqrt((dx * dx) + (dz * dz))
		if length <= region.radius or length == 0 then
			return { x = region.centerX, z = region.centerZ }
		end
		local scale = region.radius / length
		return { x = region.centerX + (dx * scale), z = region.centerZ + (dz * scale) }
	end

	if region.kind == "box" then
		return {
			x = math.clamp(x, region.minX, region.maxX),
			z = math.clamp(z, region.minZ, region.maxZ),
		}
	end

	local dx = x - region.centerX
	local dz = z - region.centerZ
	local cosYaw = math.cos(region.yaw)
	local sinYaw = math.sin(region.yaw)
	-- The local +X axis of a Roblox yaw is (cos yaw, -sin yaw).
	local localX = (dx * cosYaw) - (dz * sinYaw)
	local localZ = (dx * sinYaw) + (dz * cosYaw)
	local clampedX = math.clamp(localX, -region.halfWidth, region.halfWidth)
	local clampedZ = math.clamp(localZ, -region.halfLength, region.halfLength)
	return {
		x = region.centerX + (clampedX * cosYaw) + (clampedZ * sinYaw),
		z = region.centerZ - (clampedX * sinYaw) + (clampedZ * cosYaw),
	}
end

-- How far the canopy of a tree reaches in one direction. The canopy is a
-- yaw-rotated rectangle, so its support along a direction is the sum of the
-- two half-extents projected onto that direction.
function SceneryLayout.canopySupport(tree: TreeDef, dirX: number, dirZ: number): number
	local cosYaw = math.cos(tree.yaw)
	local sinYaw = math.sin(tree.yaw)
	local axisX = { x = cosYaw, z = -sinYaw }
	local axisZ = { x = sinYaw, z = cosYaw }
	local halfWidth = tree.canopyWidth / 2
	local halfDepth = tree.canopyDepth / 2
	return (halfWidth * math.abs((axisX.x * dirX) + (axisX.z * dirZ)))
		+ (halfDepth * math.abs((axisZ.x * dirX) + (axisZ.z * dirZ)))
end

-- The nearest playable region and the point on it that lies closest to the
-- given position. The distance to that point is the distance to the content,
-- and the direction towards it is the direction the canopy is measured in.
function SceneryLayout.nearestContent(
	regions: { ProtectedRegion },
	x: number,
	z: number
): (ProtectedRegion?, number, number, number)
	local nearest: ProtectedRegion? = nil
	local nearestDistance = math.huge
	local nearestX = x
	local nearestZ = z
	for _, region in regions do
		if region.hard then
			local distance = SceneryLayout.distanceToRegion(region, x, z)
			if distance < nearestDistance then
				nearestDistance = distance
				nearest = region
				local point = SceneryLayout.closestPointOnRegion(region, x, z)
				nearestX = point.x
				nearestZ = point.z
			end
		end
	end
	local dirX = nearestX - x
	local dirZ = nearestZ - z
	local length = math.sqrt((dirX * dirX) + (dirZ * dirZ))
	if length > 0 then
		dirX = dirX / length
		dirZ = dirZ / length
	end
	return nearest, nearestDistance, dirX, dirZ
end

-- The distance from a point to the nearest playable region. This is the
-- surface the forest belt is measured from.
function SceneryLayout.distanceToContent(regions: { ProtectedRegion }, x: number, z: number): number
	local nearest = math.huge
	for _, region in regions do
		if region.hard then
			local distance = SceneryLayout.distanceToRegion(region, x, z)
			if distance < nearest then
				nearest = distance
			end
		end
	end
	return nearest
end

-- Every region a tree may not grow into. The shapes mirror the built world:
-- temple halls and the museum plaza are axis-aligned boxes, the museum plots
-- are rotated boxes that follow their angle on the ring, and the avenues are
-- boxes as well.
function SceneryLayout.protectedRegions(temples: { TempleFootprint }, world: WorldFootprint): { ProtectedRegion }
	local regions: { ProtectedRegion } = {}

	-- Temple halls: the floor spans origin..origin+length in z, the side walls
	-- sit at +/- width/2 with a 2-stud thickness (one stud past width/2), and
	-- the front and back walls add one stud past the origin and the length.
	local firstFrontZ: number? = nil
	for _, temple in temples do
		local halfWidth = temple.hallWidth / 2 + 1
		regions[#regions + 1] = boxRegion(
			temple.id,
			temple.originX - halfWidth,
			temple.originX + halfWidth,
			temple.originZ - 2,
			temple.originZ + temple.hallLength + 1,
			SceneryLayout.TREE_CLEARANCE,
			true
		)
		if firstFrontZ == nil or temple.originZ < firstFrontZ then
			firstFrontZ = temple.originZ
		end
	end

	local plazaRadius = world.plazaRadius
	local approachEndZ = (firstFrontZ or (plazaRadius + 120)) - 40
	local avenueHalf = world.avenueWidth / 2

	-- Hub plaza: a square slab, so its corner radius bounds the whole court.
	regions[#regions + 1] =
		boxRegion("HubPlaza", -plazaRadius, plazaRadius, -plazaRadius, plazaRadius, SceneryLayout.TREE_CLEARANCE, true)

	-- Museum plots: the ground apron of every plot on the ring. Each apron is
	-- laid out along the radius, so the region is a rotated box.
	local plotCount = math.max(1, world.plotCount)
	local angleStep = 360 / plotCount
	for index = 0, plotCount - 1 do
		local angle = math.rad(world.startAngleDegrees + (index * angleStep))
		local centreX = math.cos(angle) * world.ringRadius
		local centreZ = math.sin(angle) * world.ringRadius
		-- The plot looks at the origin, so its local +Z points outwards along
		-- the radius and its local +X runs across.
		local yaw = math.pi / 2 - angle
		regions[#regions + 1] = orientedRegion(
			"PlotApron" .. (index + 1),
			centreX,
			centreZ,
			world.apronWidth / 2,
			world.apronLength / 2,
			yaw,
			SceneryLayout.TREE_CLEARANCE,
			true
		)

		-- The avenue that leads from the plaza to the plot. The forest may
		-- border it and lean over its edge, but the path itself stays open.
		local avenueLength = (world.ringRadius - (world.apronLength / 2) - world.apronOffsetZ + 6) - plazaRadius
		regions[#regions + 1] = orientedRegion(
			"PlotAvenue" .. (index + 1),
			math.cos(angle) * (plazaRadius + avenueLength / 2),
			math.sin(angle) * (plazaRadius + avenueLength / 2),
			avenueHalf,
			avenueLength / 2,
			yaw,
			-SceneryLayout.PATH_OVERHANG,
			false
		)
	end

	-- The museum forecourt between the plaza and the ring. The forest belt
	-- may line its edge, but the scattered trees further out may not wander
	-- onto the open court: the avenues fan across it and the plaza needs its
	-- view.
	local forecourtRadius = world.ringRadius - (world.apronLength / 2) - world.apronOffsetZ
	local forecourt = discRegion("Forecourt", 0, 0, forecourtRadius, 0, false)
	forecourt.beltOnly = true
	regions[#regions + 1] = forecourt

	-- Processional approach avenue: hub rim to the district entrance, six
	-- studs wider than a plot avenue. The forest may crowd it.
	local approachHalf = avenueHalf + 3
	regions[#regions + 1] = boxRegion(
		"ApproachAvenue",
		-approachHalf,
		approachHalf,
		plazaRadius,
		approachEndZ,
		-SceneryLayout.PATH_OVERHANG,
		false
	)
	-- Cross-court at the district entrance.
	regions[#regions + 1] = boxRegion(
		"CrossCourt",
		-60,
		60,
		approachEndZ - avenueHalf,
		approachEndZ + avenueHalf,
		-SceneryLayout.PATH_OVERHANG,
		false
	)

	return regions
end

-- Grove --------------------------------------------------------------------

-- The bounding box a band can possibly occupy.
local function bandBounds(
	content: RoundedRect,
	ground: RoundedRect,
	groundClearance: number,
	outer: number?
): (number, number, number, number)
	local contentCentre = SceneryLayout.centre(content)
	local contentHalfX, contentHalfZ = SceneryLayout.halfExtents(content)
	local reach = outer or (math.max(contentHalfX, contentHalfZ) + groundClearance)
	local minX = math.max(contentCentre.x - contentHalfX - reach, ground.minX + groundClearance)
	local maxX = math.min(contentCentre.x + contentHalfX + reach, ground.maxX - groundClearance)
	local minZ = math.max(contentCentre.z - contentHalfZ - reach, ground.minZ + groundClearance)
	local maxZ = math.min(contentCentre.z + contentHalfZ + reach, ground.maxZ - groundClearance)
	return minX, maxX, minZ, maxZ
end

-- The grove: a deterministic belt of trees that hugs the playable content.
-- Every band is measured to the edge of the canopy, so the first band starts
-- `inner` studs beyond the content and the belt ends `outer` studs beyond it.
function SceneryLayout.trees(
	spec: GroveSpec,
	content: RoundedRect,
	ground: RoundedRect,
	regions: { ProtectedRegion },
	seed: number
): { TreeDef }
	local rng: RandomState = { state = math.abs(seed) % (RNG_MODULUS - 1) + 1 }
	local trees: { TreeDef } = {}

	for _, band in spec.bands do
		local spacing = band.spacing
		local minX, maxX, minZ, maxZ = bandBounds(content, ground, spec.groundClearance, band.outer)
		local rowHeight = spacing * math.sqrt(3) / 2
		local row = 0
		local z = minZ
		while z <= maxZ do
			local x = minX + (row % 2) * spacing / 2
			while x <= maxX do
				-- Pinned draw order: jitter X, jitter Z, yaw, trunk width, trunk
				-- height, canopy width, canopy depth, canopy height.
				local jitterX = (nextRandom(rng) * 2 - 1) * spacing * spec.jitterFraction
				local jitterZ = (nextRandom(rng) * 2 - 1) * spacing * spec.jitterFraction
				local yaw = nextRandom(rng) * 2 * math.pi
				local trunkWidth = 2.6 + (nextRandom(rng) * 1.4)
				local trunkHeight = 20 + (nextRandom(rng) * 8)
				local canopyWidth = 22 + (nextRandom(rng) * 8)
				local canopyDepth = 22 + (nextRandom(rng) * 8)
				local canopyHeight = 16 + (nextRandom(rng) * 8)

				local pointX = x + jitterX
				local pointZ = z + jitterZ

				local tree: TreeDef = {
					index = #trees + 1,
					x = pointX,
					z = pointZ,
					yaw = yaw,
					trunkWidth = trunkWidth,
					trunkHeight = trunkHeight,
					canopyWidth = canopyWidth,
					canopyDepth = canopyDepth,
					canopyHeight = canopyHeight,
					decorative = true,
				}

				-- The worst case reach of the canopy, used for every
				-- exclusion, so a canopy can never enter a protected area
				-- whatever yaw it ends up with.
				local reach = SceneryLayout.canopyReach(tree)
				local accepted = true

				-- The band is measured from the playable content to the edge of
				-- the canopy, in the direction of the content, so the forest
				-- starts exactly `inner` studs beyond the playable world.
				local _, contentDistance, dirX, dirZ = SceneryLayout.nearestContent(regions, pointX, pointZ)
				local gap = contentDistance - SceneryLayout.canopySupport(tree, dirX, dirZ)
				local beyondBelt = band.outer ~= nil and gap > band.outer
				if gap < band.inner or beyondBelt then
					accepted = false
				end

				-- The tree has to stay inside the ground footprint, clear of the
				-- rim that runs along its edge.
				if accepted and SceneryLayout.signedDistance(ground, pointX, pointZ) > -spec.groundClearance then
					accepted = false
				end

				-- The tree has to keep the region's own margin, which is what
				-- keeps the plots and the temples clear and lets the forest
				-- crowd the paths. The open museum court only admits the
				-- belt, so the scattered trees never wander onto it.
				if accepted then
					for _, region in regions do
						local distance = SceneryLayout.distanceToRegion(region, pointX, pointZ)
						if region.beltOnly then
							local isBelt = band.outer ~= nil and gap <= band.outer
							if not isBelt and distance < reach then
								accepted = false
								break
							end
						elseif distance < (region.margin + reach) then
							accepted = false
							break
						end
					end
				end

				if accepted then
					for _, other in trees do
						local dx = pointX - other.x
						local dz = pointZ - other.z
						if math.sqrt((dx * dx) + (dz * dz)) < spec.minSpacing then
							accepted = false
							break
						end
					end
				end

				if accepted then
					trees[#trees + 1] = tree
				end

				x += spacing
			end
			z += rowHeight
			row += 1
		end
	end

	return trees
end

-- The four canopy corners of a tree, in counter-clockwise order.
function SceneryLayout.canopyCorners(tree: TreeDef): { Point2 }
	local cosYaw = math.cos(tree.yaw)
	local sinYaw = math.sin(tree.yaw)
	-- Roblox yaw: local +X maps to (cos yaw, -sin yaw), local +Z to
	-- (sin yaw, cos yaw).
	local axisX = { x = cosYaw, z = -sinYaw }
	local axisZ = { x = sinYaw, z = cosYaw }
	local halfWidth = tree.canopyWidth / 2
	local halfDepth = tree.canopyDepth / 2
	local corners: { Point2 } = {}
	local signs = { { -1, -1 }, { 1, -1 }, { 1, 1 }, { -1, 1 } }
	for _, sign in signs do
		local lx = sign[1] * halfWidth
		local lz = sign[2] * halfDepth
		corners[#corners + 1] = {
			x = tree.x + (lx * axisX.x) + (lz * axisZ.x),
			z = tree.z + (lx * axisX.z) + (lz * axisZ.z),
		}
	end
	return corners
end

-- How far the canopy of a tree reaches from its trunk.
function SceneryLayout.canopyReach(tree: TreeDef): number
	return (math.max(tree.canopyWidth, tree.canopyDepth) / 2) * math.sqrt(2)
end

-- Escarpment ---------------------------------------------------------------

-- The rocky rim that closes the horizon. It follows the ground footprint, so
-- its outer face sits on the ground edge, and every segment runs past the
-- shared vertices so the ring reads as one continuous wall.
--
-- The wall is built in two layers. The cliff blocks form the face: each one
-- has its own depth and height, so the inner face of the wall is jagged and
-- the top steps up and down. Every n-th cliff block carries a crest block
-- that steps back on top of it, which reads as layered rock.
function SceneryLayout.escarpment(ground: RoundedRect, spec: EscarpmentSpec, seed: number): { EscarpmentDef }
	local rng: RandomState = { state = math.abs(seed) % (RNG_MODULUS - 1) + 1 }
	local points = SceneryLayout.perimeter(ground, spec.segmentLength)
	local segments: { EscarpmentDef } = {}
	local count = #points - 1

	for index = 0, count - 1 do
		local a = points[index + 1]
		local b = points[(index + 1) % count + 1]
		local dx = b.x - a.x
		local dz = b.z - a.z
		local chord = math.sqrt((dx * dx) + (dz * dz))
		local uX = dx / chord
		local uZ = dz / chord
		local wX = -uZ
		local wZ = uX
		local yaw = math.atan2(-uZ, uX)

		-- The band reaches inwards from the outline, so the block centre sits
		-- half a depth along the inward normal. The small overhang keeps the
		-- rock flush with the rounded ground edge.
		local depth = spec.depth - (nextRandom(rng) * spec.depthVariation)
		local height = spec.minHeight + (nextRandom(rng) * (spec.maxHeight - spec.minHeight))
		local inset = depth / 2 - SceneryLayout.ESCARPMENT_OUTWARD_OVERHANG
		local centerX = (a.x + b.x) / 2 + (wX * inset)
		local centerZ = (a.z + b.z) / 2 + (wZ * inset)

		segments[#segments + 1] = {
			index = #segments + 1,
			layer = "cliff",
			centerX = centerX,
			centerZ = centerZ,
			yaw = yaw,
			length = chord + (2 * spec.overlap),
			depth = depth,
			height = height,
			baseY = 0,
			uX = uX,
			uZ = uZ,
			wX = wX,
			wZ = wZ,
			decorative = true,
		}

		-- The crest block steps back from the inner face of its cliff block
		-- and sits on top of it, so the wall reads as two courses of rock.
		if spec.crestEvery > 0 and (index % spec.crestEvery) == 0 then
			local crestDepth = math.min(spec.crestDepth, depth - 2)
			-- The crest block sits just inside the inner face of its cliff
			-- block, overlapping it, and rises above it.
			local crestInset = (depth / 2) - 4 - (crestDepth / 2)
			segments[#segments + 1] = {
				index = #segments + 1,
				layer = "crest",
				centerX = centerX + (wX * crestInset),
				centerZ = centerZ + (wZ * crestInset),
				yaw = yaw,
				length = (chord + (2 * spec.overlap)) * 0.85,
				depth = crestDepth,
				height = spec.crestHeight + 2,
				baseY = height - 2,
				uX = uX,
				uZ = uZ,
				wX = wX,
				wZ = wZ,
				decorative = true,
			}
		end
	end

	return segments
end

-- The four world-space corners of an escarpment segment, counter-clockwise in
-- the XZ plane (so the shoelace area is positive).
function SceneryLayout.escarpmentPolygon(segment: EscarpmentDef): { Point2 }
	local halfLength = segment.length / 2
	local halfDepth = segment.depth / 2
	local corners: { Point2 } = {}
	local signs = { { -1, -1 }, { 1, -1 }, { 1, 1 }, { -1, 1 } }
	for _, sign in signs do
		local lx = sign[1] * halfLength
		local lz = sign[2] * halfDepth
		corners[#corners + 1] = {
			x = segment.centerX + (lx * segment.uX) + (lz * segment.wX),
			z = segment.centerZ + (lx * segment.uZ) + (lz * segment.wZ),
		}
	end
	return corners
end

-- The mid-line of the escarpment band: the outline pushed inwards by half the
-- shallowest depth. Sampling it shows whether the band is continuous, because
-- every sample has to land inside one of the segments.
function SceneryLayout.escarpmentMidline(ground: RoundedRect, depth: number, spacing: number): { Point2 }
	local outline = SceneryLayout.perimeter(ground, spacing)
	local centre = SceneryLayout.centre(ground)
	local points: { Point2 } = {}
	for index = 1, #outline - 1 do
		local point = outline[index]
		local dx = centre.x - point.x
		local dz = centre.z - point.z
		local length = math.sqrt((dx * dx) + (dz * dz))
		local scale = (depth / 2) / length
		table.insert(points, {
			x = point.x + (dx * scale),
			z = point.z + (dz * scale),
		})
	end
	return points
end

-- Total decorative parts the scenery builder is allowed to create.
function SceneryLayout.partCount(trees: { TreeDef }, escarpment: { EscarpmentDef }): number
	return (#trees * 2) + #escarpment
end

-- Configuration ------------------------------------------------------------

-- Reduces the game configuration to the plain numbers the layout needs. The
-- configuration is passed in rather than required, so this module keeps no
-- dependency of its own and the world builder and the test suite read the
-- very same numbers.
function SceneryLayout.inputs(config: any): SceneryInputs
	local world = config.World
	local scenery = world.Scenery

	local ground: RoundedRect = {
		minX = world.Ground.MinX,
		maxX = world.Ground.MaxX,
		minZ = world.Ground.MinZ,
		maxZ = world.Ground.MaxZ,
		cornerRadius = world.Ground.CornerRadius,
	}

	local content: RoundedRect = {
		minX = scenery.Content.MinX,
		maxX = scenery.Content.MaxX,
		minZ = scenery.Content.MinZ,
		maxZ = scenery.Content.MaxZ,
		cornerRadius = scenery.Content.CornerRadius,
	}

	local footprints: { TempleFootprint } = {}
	for templeId, temple in config.Temples do
		table.insert(footprints, {
			id = templeId,
			originX = temple.origin.x,
			originZ = temple.origin.z,
			hallWidth = temple.hall.width,
			hallLength = temple.hall.length,
		})
	end

	local regions = SceneryLayout.protectedRegions(footprints, {
		ringRadius = world.RingRadius,
		plotCount = world.MaxPlots,
		startAngleDegrees = world.StartAngleDegrees,
		apronWidth = world.PlotApron.Width,
		apronLength = world.PlotApron.Length,
		apronOffsetZ = world.PlotApron.OffsetZ,
		avenueWidth = world.AvenueWidth,
		plazaRadius = world.Hub.PlazaRadius,
	})

	local bands: { GroveBand } = {}
	for _, band in scenery.Grove.Bands do
		table.insert(bands, {
			inner = band.inner,
			outer = band.outer,
			spacing = band.spacing,
		})
	end

	return {
		ground = ground,
		content = content,
		regions = regions,
		grove = {
			bands = bands,
			groundClearance = scenery.Grove.GroundClearance,
			jitterFraction = scenery.Grove.JitterFraction,
			minSpacing = scenery.Grove.MinSpacing,
		},
		escarpment = {
			depth = scenery.Escarpment.Depth,
			depthVariation = scenery.Escarpment.DepthVariation,
			overlap = scenery.Escarpment.Overlap,
			segmentLength = scenery.Escarpment.SegmentLength,
			minHeight = scenery.Escarpment.MinHeight,
			maxHeight = scenery.Escarpment.MaxHeight,
			crestEvery = scenery.Escarpment.CrestEvery,
			crestHeight = scenery.Escarpment.CrestHeight,
			crestDepth = scenery.Escarpment.CrestDepth,
		},
		seed = scenery.Seed,
	}
end

return SceneryLayout
