--!nonstrict
-- Server-authoritative environmental hazards.
--
-- Damage is decided on the server using authoritative character positions and
-- configurable zones. Hazards never rely on Touched events, so high-speed or
-- repeated movement cannot multiply damage (see docs/FR-007 / THREAT_MODEL).

local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local GameConfig = require(ReplicatedStorage.Shared.Config.GameConfig)
local Util = require(ReplicatedStorage.Shared.Utilities.Util)
local PlayerUtil = require(script.Parent.Parent.Utilities.PlayerUtil)
local Logger = require(script.Parent.Parent.Utilities.Logger)

local HazardService = {}

local WARN_COLOR = Color3.fromRGB(255, 176, 64)
local FIRE_COLOR = Color3.fromRGB(255, 80, 64)
local IDLE_COLOR = Color3.fromRGB(255, 96, 80)
local EMITTER_IDLE = Color3.fromRGB(120, 48, 44)
local EMITTER_WARN = Color3.fromRGB(224, 140, 48)

local state = {
	ctx = nil,
	logger = nil,
	lastHit = {},
	collapses = {},
}

function HazardService:Init(ctx)
	state.ctx = ctx
	state.logger = Logger.new("Hazard")
end

local function inZone(position: Vector3, center: Vector3, size: Vector3): boolean
	local delta = position - center
	return math.abs(delta.X) <= size.X / 2 and math.abs(delta.Y) <= size.Y / 2 and math.abs(delta.Z) <= size.Z / 2
end

function HazardService:DamagePlayer(player: Player, amount: number, source: string)
	if not PlayerUtil.isAlive(player) then
		return
	end
	local now = os.clock()
	if now - (state.lastHit[player] or 0) < GameConfig.Hazards.DamageInvulnerabilitySeconds then
		return
	end
	state.lastHit[player] = now

	local humanoid = PlayerUtil.getHumanoid(player)
	if humanoid == nil then
		return
	end
	player:SetAttribute("LastDamageSource", source)
	humanoid:TakeDamage(amount)
	state.ctx.Services.Network:PushEvent(player, "Damage", {
		amount = amount,
		source = source,
		health = humanoid.Health,
		maxHealth = humanoid.MaxHealth,
	})
	state.ctx.Services.Analytics:Track("damage_taken", { source = source })
end

local function broadcast(services, templeId: string, name: string, payload)
	for _, player in services.Expedition:GetPlayersInTemple(templeId) do
		services.Network:PushEvent(player, name, payload)
	end
end

local function hasLineOfSight(from: Vector3, to: Vector3, extraExclude: { Instance }): boolean
	local direction = to - from
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	local exclude = table.clone(extraExclude)
	for _, player in Players:GetPlayers() do
		if player.Character then
			table.insert(exclude, player.Character)
		end
	end
	params.FilterDescendantsInstances = exclude
	local result = workspace:Raycast(from, direction, params)
	if result == nil then
		return true
	end
	return result.Distance >= direction.Magnitude - 1
end

local function startDartTrap(services, templeId: string, trap)
	task.spawn(function()
		while true do
			local cooldown = math.max(0.5, trap.interval - trap.warning - trap.active)
			task.wait(cooldown)

			trap.zonePart.Transparency = 0.6
			trap.beam.Transparency = 0.65
			trap.beam.Color = WARN_COLOR
			for _, emitter in trap.emitters do
				emitter.Color = EMITTER_WARN
			end
			broadcast(services, templeId, "HazardWarning", {
				label = trap.label,
				kind = "dart",
				warningSeconds = trap.warning,
			})

			task.wait(trap.warning)
			trap.beam.Transparency = 0
			trap.beam.Color = FIRE_COLOR
			trap.zonePart.Transparency = 0.35
			for _, emitter in trap.emitters do
				emitter.Color = FIRE_COLOR
			end

			for _, player in services.Expedition:GetPlayersInTemple(templeId) do
				local root = PlayerUtil.getRoot(player)
				if root and inZone(root.Position, trap.center, trap.size) then
					HazardService:DamagePlayer(player, trap.damage, trap.label)
				end
			end
			broadcast(services, templeId, "HazardFired", { label = trap.label, kind = "dart" })

			task.wait(trap.active)
			trap.beam.Transparency = 1
			trap.zonePart.Transparency = 0.88
			trap.beam.Color = IDLE_COLOR
			for _, emitter in trap.emitters do
				emitter.Color = EMITTER_IDLE
			end
		end
	end)
end

local function startBoulderTrap(services, templeId: string, trap)
	task.spawn(function()
		while true do
			local cooldown = math.max(0.5, trap.interval - trap.warning - trap.travel)
			task.wait(cooldown)

			broadcast(services, templeId, "HazardWarning", {
				label = trap.label,
				kind = "boulder",
				warningSeconds = trap.warning,
			})
			task.wait(trap.warning)

			local ball = trap.model
			ball.CFrame = CFrame.new(trap.start)
			ball.Transparency = 0
			ball.CanCollide = true

			local tween = TweenService:Create(
				ball,
				TweenInfo.new(trap.travel, Enum.EasingStyle.Linear),
				{ CFrame = CFrame.new(trap.finish) }
			)
			tween:Play()

			local hit = {}
			while tween.PlaybackState == Enum.PlaybackState.Playing do
				task.wait(0.08)
				local ballPosition = ball.Position
				for _, player in services.Expedition:GetPlayersInTemple(templeId) do
					if not hit[player] then
						local root = PlayerUtil.getRoot(player)
						if root then
							local distance = (root.Position - ballPosition).Magnitude
							if
								distance <= trap.radius + 3 and hasLineOfSight(ballPosition, root.Position, { ball })
							then
								HazardService:DamagePlayer(player, trap.damage, trap.label)
								hit[player] = true
							end
						end
					end
				end
			end
			broadcast(services, templeId, "HazardFired", { label = trap.label, kind = "boulder" })

			ball.Transparency = 1
			ball.CanCollide = false
			ball.CFrame = CFrame.new(trap.start)
		end
	end)
end

local function startBladeTrap(services, templeId: string, trap)
	task.spawn(function()
		local angle = 0
		while true do
			local players = services.Expedition:GetPlayersInTemple(templeId)
			if #players == 0 then
				task.wait(0.5)
			else
				local dt = task.wait(0.05) or 0.05
				angle += trap.speed * dt
				local cframe = CFrame.new(trap.center) * CFrame.Angles(0, angle, 0)
				trap.model:PivotTo(cframe)

				local direction = Vector3.new(math.sin(angle), 0, math.cos(angle))
				local half = trap.length / 2
				for _, player in players do
					local root = PlayerUtil.getRoot(player)
					if root then
						local position = root.Position
						if math.abs(position.Y - trap.center.Y) <= 6 then
							local distance = Util.distanceToSegment2D(
								position.X,
								position.Z,
								trap.center.X - direction.X * half,
								trap.center.Z - direction.Z * half,
								trap.center.X + direction.X * half,
								trap.center.Z + direction.Z * half
							)
							if distance <= trap.hitRadius + 2 then
								HazardService:DamagePlayer(player, trap.damage, trap.label)
							end
						end
					end
				end
			end
		end
	end)
end

function HazardService:StartCollapse(player: Player)
	if state.collapses[player] then
		return
	end
	state.collapses[player] = true
	local services = state.ctx.Services
	task.spawn(function()
		while state.collapses[player] do
			local expedition = services.Expedition:GetState(player)
			if expedition == nil then
				break
			end
			HazardService:DamagePlayer(player, GameConfig.Hazards.CollapseDamage, "Temple Collapse")
			services.Network:PushEvent(player, "HazardWarning", {
				label = "Temple Collapse",
				kind = "collapse",
				warningSeconds = GameConfig.Hazards.CollapseTickSeconds,
			})
			task.wait(GameConfig.Hazards.CollapseTickSeconds)
		end
		state.collapses[player] = nil
	end)
end

function HazardService:StopCollapse(player: Player)
	state.collapses[player] = false
end

function HazardService:Start()
	for templeId, runtime in state.ctx.World.Temples do
		for _, trap in runtime.traps do
			if trap.kind == "dart" then
				startDartTrap(state.ctx.Services, templeId, trap)
			elseif trap.kind == "boulder" then
				startBoulderTrap(state.ctx.Services, templeId, trap)
			elseif trap.kind == "blade" then
				startBladeTrap(state.ctx.Services, templeId, trap)
			end
		end
	end
end

return HazardService
