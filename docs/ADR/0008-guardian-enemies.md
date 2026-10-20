# ADR 0008: Guardian enemies

- Status: Accepted
- Date: 2026-10-20

## Context

The blueprint requires "Guardian enemies" (FR-007 and the M4 deliverable "more
hazards and enemies"), and a scalable temple framework with per-temple "enemy
encounters". Until now the project had no enemies: `docs/VISION.md` listed
"no combat/enemies beyond environmental hazards" as a non-goal.

Guardians are the first mobile threat. They must stay server-authoritative,
avoid `Touched`-based damage, work with the existing hazard damage pipeline, and
be data-driven like every other piece of content.

## Decision

- **One new service, one new builder.** `TempleBuilder.buildGuardian` constructs
  a blockout rig (Model + Humanoid + welded parts) at a temple's first waypoint;
  `GuardianService` runs the behaviour. Guardians are declared per temple in
  `GameConfig.Temples[*].guardians`, with shared defaults in
  `GameConfig.Enemies.Kinds.Guardian` and global tuning in `GameConfig.Enemies`.
- **Patrol + aggro chase, no pathfinding.** A guardian walks its waypoint loop.
  When a player is within `aggroRange` *and* has line of sight, it chases at
  `walkSpeed * Chase.SpeedMultiplier` using `Humanoid:MoveTo`. If the player
  breaks line of sight or stealths, the guardian keeps hunting toward the
  player's last-known position for `HuntSeconds` (or until it arrives, within
  `HuntArriveTolerance`) before resuming patrol, so ducking behind cover no
  longer instantly ends the chase. Aggro additionally lingers for
  `AggroLingerSeconds` after the target is lost.
- **Contact damage with a windup.** Inside `contactRange`, the guardian warns
  nearby players (`HazardWarning` with `kind = "guardian"`), waits
  `attackWindup`, then re-checks the target is still in range before dealing
  damage. A player who dodges during the tell is not hit. Hits share
  `HazardService:DamagePlayer`, so the invulnerability window, analytics, and
  client flash are identical to traps.
- **Cleanup and idling.** With no players in the temple a guardian idles on its
  route; the loop exits and destroys the model when the character/model is gone.
- **Balance is data.** Damage, speed, health, aggro/contact ranges, and colours
  live in config. Offsets are per-temple, so the tutorial stays safe and later
  temples get faster, harder guardians.

## Consequences

- VISION's "no enemies" non-goal is superseded; the SRS gains FR-007b.
- A generous `aggroRange` plus LOS raycasts add a small per-tick cost, bounded by
  `Enemies.TickSeconds` (0.1s) and only while a temple has players. No per-frame
  server work is introduced.
- Killing a guardian is not a mechanic (no reward, no loot); guardians are a
  positional hazard, which keeps them within the existing encumbrance/escape
  loop rather than adding a combat system.
- No pathfinding means a guardian can be blocked by geometry. This is acceptable
  for blockout halls with open lanes; a future ADR can adopt `PathfindingService`
  if authored levels need it.

## Alternatives considered

- **Hazard-zone "guardian" with no movement.** Rejected: the blueprint calls for
  enemy encounters, and a stationary zone duplicates existing traps.
- **Full `PathfindingService` chase.** Rejected for now: heavier and unnecessary
  for open blockout halls; can be added behind the same config later.
- **`Touched`-based contact damage.** Rejected: the project bans `Touched` for
  critical gameplay (FR-007) because of repeated/high-speed events.
