# ADR 0012: Sprint stamina, one stat resolver, and passive training

- Status: Accepted
- Date: 2026-10-23

## Context

Movement, carry capacity and health were each computed ad hoc from upgrade
levels in several services. Sprinting did not exist, so there was no way to
trade a burst of speed for a resource, and every permanent bonus was bought with
gold. The design asks for a stamina-based sprint inside expeditions and for
training that rewards actually playing (collecting relics and extracting
hauls), without adding a second progression currency to buy.

## Decision

### One effective-stat resolver

- `src/shared/Domain/Stats.luau` is the single pure resolver for capacity, the
  weight speed penalty, maximum health, the stamina pool/drain, and the sprint
  multiplier. It combines shop upgrades, training levels and optional companion
  bonuses, and clamps the weight-penalty reduction at 80% across all sources.
- `StatsUtil.forProfile` is the only bridge from a stored profile (which stores
  training *experience*) to the resolver (which consumes derived *levels*).
  `UpgradeService`, `ViewService`, `RelicService`, `ExpeditionService` and
  `StaminaService` all read it, so no two systems can disagree about a number.
- `Encumbrance` keeps the capacity *check* (weight/count rejection) but no longer
  owns the capacity or walk-speed formulas.

### Server-authoritative sprint stamina

- `src/shared/Domain/Stamina.luau` holds the pool rules: start/stop sprint,
  drain while sprinting, recover otherwise, and an exhaustion lockout that
  requires 30% of the pool before sprinting resumes.
- `StaminaService` owns the runtime pool per player. The pool is never
  persisted; it is rebuilt from the resolved stats at the start of every
  expedition (full) and on a training level-up (keeping its fill ratio).
- The client sends only intent through the `SetSprint` action (`sprint`/`walk`,
  bound to Shift and gamepad L3). The server decides whether that intent becomes
  movement: it ignores sprint outside an expedition, requires actual movement,
  and refuses to sprint while exhausted. The server is the only writer of the
  character's walk speed.
- Leaving a run (extraction, abandon, death) restores the default walk speed, so
  an expedition speed can never leak into the hub or museum.
- The expedition HUD adds a stamina bar; the server pushes a `Stamina` event
  while the pool changes (throttled to 4 Hz) and the snapshot carries the pool.

### Passive training

- `GameConfig.Training` declares three attributes (Strength, Stamina, Carrying)
  with a max level and per-level effects, plus the XP awarded for relics and
  extractions. XP is only ever earned by playing; there is no purchase path.
- `src/shared/Domain/Training.luau` holds the curve (level 1 costs 100 XP, each
  further level costs 50 more), derived levels, and capped awarding. Only
  experience is stored (schema v5); a level is always derived, so the two can
  never disagree.
- `TrainingService` awards XP from `RelicService` (on collect) and
  `ExtractionService` (on a successful haul), announces level-ups, and exposes
  the level/XP view used by the client's Settings panel.
- The effects flow through the stat resolver: Strength reduces the weight
  penalty, Stamina grows the pool and lowers the drain, Carrying adds capacity.

## Consequences

- The SRS gains FR-029 (sprint stamina) and FR-030 (passive training).
  `DATA_MODEL.md` moves to schema v5 with a `training` map and a v4→v5
  migration; `API_CONTRACTS.md` gains `SetSprint`, the `Stamina` event and the
  `training` snapshot field; `GAME_BALANCE.md` lists the stamina and training
  tuning.
- The contract-drift test now documents 13 actions (12 + `SetSprint`).
- Sprinting is a positional tool, not combat: it helps cross a temple or escape
  a guardian but cannot be held forever, and a heavy haul still moves slower
  than an empty sprint.
- Training is deliberately slow and capped at 20 levels per attribute; a full
  Carrying track adds 160 capacity, but the weight and 10-relic caps still bound
  a haul. Because levels are derived from experience, a future rebalance of the
  curve applies retroactively to every stored profile.

## Alternatives considered

- **Client-side sprint speed.** Rejected: any client-set speed is a movement
  exploit; the server must own the pool and the applied speed (ADR 0001).
- **Persisting the stamina pool.** Rejected: the pool is a per-run resource, and
  persisting it would let players log out to refill or carry an empty pool into
  the next run. Every run starts full instead.
- **Buying training with gold.** Rejected: the point is to reward active play.
  Gold already buys the permanent upgrades; training is the play-earned track.
- **A separate stats service.** Rejected: derived numbers are pure rules and
  belong in a domain module so the test suite can prove them without Roblox.
