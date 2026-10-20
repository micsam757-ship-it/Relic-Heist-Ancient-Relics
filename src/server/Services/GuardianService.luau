--!nonstrict
-- Server-authoritative guardian enemies (see docs/ADR/0008-guardian-enemies.md).
--
-- Each guardian patrols a configured route. When a player enters aggro range
-- with line of sight, it pursues and, on contact, telegraphs a windup then deals
-- contact damage. If it loses sight (the player breaks line of sight or stealths),
-- it keeps chasing toward the player's last-known position for
-- `Enemies.HuntSeconds` before resuming its patrol, so cover no longer instantly
-- ends a chase. All targeting, damage and state live on the server; the client
-- only sees replicated motion and `HazardWarning`/`Damage` events.
--
-- Damage is applied through HazardService:DamagePlayer so it shares the same
-- invulnerability window, analytics, and client feedback as traps.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local GameConfig = require(ReplicatedStorage.Shared.Config.GameConfig)
local PlayerUtil = require(script.Parent.Parent.Utilities.PlayerUtil)
local Logger = require(script.Parent.Parent.Utilities.Logger)

local GuardianService = {}

local state = {
	ctx = nil,
	logger = nil,
}

-- Casts from the guardian's eye to the target. `ownModel` must be excluded: the
-- guardian's `HumanoidRootPart` is queryable and sits below the eye, so without
-- this the ray self-hits the guardian and line of sight is never established.
local function hasLineOfSight(from: Vector3, to: Vector3, ownModel: Instance?): boolean
	local direction = to - from
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	local exclude: { Instance } = {}
	if ownModel then
		table.insert(exclude, ownModel)
	end
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

local function nearestVisiblePlayer(services, templeId: string, guardian): (Player?, number)
	local origin = guardian.root.Position
	local best: Player? = nil
	local bestDistance = math.huge
	for _, player in services.Expedition:GetPlayersInTemple(templeId) do
		local root = PlayerUtil.getRoot(player)
		if root and PlayerUtil.isAlive(player) then
			local distance = (root.Position - origin).Magnitude
			if distance <= guardian.aggroRange and distance < bestDistance then
				local eye = guardian.head.Position
				if hasLineOfSight(eye, root.Position + Vector3.new(0, 2, 0), guardian.model) then
					best = player
					bestDistance = distance
				end
			end
		end
	end
	return best, bestDistance
end

local function setAggroVisual(guardian, chasing: boolean)
	local warn = GameConfig.Enemies.WarnColor
	if chasing then
		guardian.eye.Color = guardian.eyeColor
	else
		guardian.eye.Color = guardian.eyeColor
		local warnColor = Color3.fromRGB(warn[1], warn[2], warn[3])
		guardian.eye.Color = warnColor:Lerp(guardian.eyeColor, 0.35)
	end
end

local function telegraph(services, templeId: string, guardian)
	for _, player in services.Expedition:GetPlayersInTemple(templeId) do
		services.Network:PushEvent(player, "HazardWarning", {
			label = guardian.label,
			kind = "guardian",
			warningSeconds = guardian.attackWindup,
		})
	end
end

-- Runs one guardian for as long as its temple exists.
local function runGuardian(services, templeId: string, guardian)
	task.spawn(function()
		local humanoid = guardian.humanoid
		local root = guardian.root
		local waypoints = guardian.waypoints

		-- A mis-assembled rig cannot be moved by MoveTo; surface it once instead
		-- of silently idling so the next playtest is diagnosable.
		if humanoid.RootPart == nil and state.logger then
			state.logger:warn("Guardian '%s' has no RootPart; it will not move", tostring(guardian.label))
		end
		local waypointIndex = 1
		local contactReadyAt = 0
		local lastAggroAt = 0
		-- Position the guardian last saw / is hunting toward. Kept so the chase
		-- state survives losing line of sight (stealth) instead of snapping
		-- straight back to patrol.
		local lastKnownPosition: Vector3? = nil
		local lastSeenAt = 0

		while root.Parent ~= nil and humanoid.Health > 0 do
			local now = os.clock()
			local playersInTemple = services.Expedition:GetPlayersInTemple(templeId)
			if #playersInTemple == 0 then
				-- Idle: reset to the patrol route without burning cycles.
				humanoid:MoveTo(root.Position)
				lastKnownPosition = nil
				task.wait(GameConfig.Enemies.Patrol.WaypointTolerance * 0.1 + 0.4)
				continue
			end

			-- `nearestVisiblePlayer` only returns targets inside aggro range.
			local target, _ = nearestVisiblePlayer(services, templeId, guardian)
			if target ~= nil then
				local seenRoot = PlayerUtil.getRoot(target)
				if seenRoot then
					lastKnownPosition = seenRoot.Position
				end
				lastAggroAt = now
				lastSeenAt = now
			end

			-- The chase stays active while a target is visible, or while the
			-- hunt window toward its last-known position is still open. This is
			-- what makes guardians aggressive through a broken line of sight.
			local hunting = lastKnownPosition ~= nil and (now - lastSeenAt) <= GameConfig.Enemies.HuntSeconds
			local lingering = (now - lastAggroAt) <= GameConfig.Enemies.AggroLingerSeconds
			local chasing = target ~= nil or lingering or hunting

			if target ~= nil then
				local targetRoot = PlayerUtil.getRoot(target)
				if targetRoot then
					setAggroVisual(guardian, true)
					local toTarget = targetRoot.Position - root.Position
					local flatDistance = (Vector3.new(toTarget.X, 0, toTarget.Z)).Magnitude

					local chaseSpeed = guardian.walkSpeed * GameConfig.Enemies.Chase.SpeedMultiplier
					humanoid.WalkSpeed = chaseSpeed
					humanoid:MoveTo(targetRoot.Position)

					if flatDistance <= guardian.contactRange and now >= contactReadyAt then
						contactReadyAt = now + GameConfig.Enemies.ContactCooldownSeconds
						telegraph(services, templeId, guardian)
						task.wait(guardian.attackWindup)
						-- Re-check the target is still in range after the windup
						-- so a player who dodges during the tell is not hit.
						local stillThere = PlayerUtil.getRoot(target)
						if
							stillThere
							and (stillThere.Position - root.Position).Magnitude <= guardian.contactRange + 1
						then
							services.Hazard:DamagePlayer(target, guardian.damage, guardian.label)
						end
					end
				end
			elseif chasing and lastKnownPosition ~= nil then
				-- Lost sight of the player but still hunting. Keep the aggro
				-- visual and drive toward where they were last seen; only give
				-- up once the hunt window closes or the spot is reached.
				setAggroVisual(guardian, true)
				humanoid.WalkSpeed = guardian.walkSpeed * GameConfig.Enemies.Chase.SpeedMultiplier
				humanoid:MoveTo(lastKnownPosition)
				local flat = Vector3.new(
					root.Position.X - lastKnownPosition.X,
					0,
					root.Position.Z - lastKnownPosition.Z
				).Magnitude
				if flat <= GameConfig.Enemies.HuntArriveTolerance then
					lastKnownPosition = nil
				end
			else
				-- Patrol to the next waypoint.
				setAggroVisual(guardian, false)
				humanoid.WalkSpeed = guardian.walkSpeed
				lastKnownPosition = nil
				local waypoint = waypoints[waypointIndex]
				if waypoint then
					local flat = Vector3.new(root.Position.X - waypoint.X, 0, root.Position.Z - waypoint.Z).Magnitude
					if flat <= GameConfig.Enemies.Patrol.WaypointTolerance then
						waypointIndex = waypointIndex % #waypoints + 1
						waypoint = waypoints[waypointIndex]
					end
					if waypoint then
						humanoid:MoveTo(waypoint)
					end
				end
			end

			task.wait(GameConfig.Enemies.TickSeconds)
		end

		if guardian.model then
			guardian.model:Destroy()
		end
	end)
end

function GuardianService:Init(ctx)
	state.ctx = ctx
	state.logger = Logger.new("Guardian")
end

function GuardianService:Start()
	local total = 0
	for templeId, runtime in state.ctx.World.Temples do
		for _, guardian in runtime.guardians or {} do
			total += 1
			runGuardian(state.ctx.Services, templeId, guardian)
		end
	end
	if total > 0 then
		state.logger:info("Running %d guardian(s)", total)
	end
end

return GuardianService
