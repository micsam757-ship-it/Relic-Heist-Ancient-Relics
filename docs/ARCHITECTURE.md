# Architecture

## Runtime shape

```
Roblox client                         Roblox server
-----------------                     --------------------------
StarterPlayerScripts/Client           ServerScriptService/Server
  init.client.luau                      init.server.luau  (bootstrap)
  Net.luau      <--- Request --->         Services/NetworkService   (dispatch + rate limit)
  State.luau    <--- State  ----          Services/ViewService      (snapshot builder)
  UI/          <--- Event  ---->          Services/* (domain logic)
  Controllers/                            World/*    (procedural geometry)
                                          Security/RateLimiter
ReplicatedStorage
  Shared/ (Config, Domain, Utilities, Types)
  Remotes/ Request, State, Event
```

The client is a **renderer**. It sends requests and draws the last authoritative
snapshot. It never computes rewards, prices, damage, or ownership.

## Layers

1. **Shared / Config** (`src/shared/Config/GameConfig.luau`) - all balance and
   content data. Contains no Roblox API calls and is required by both sides.

2. **Shared / Domain** (`src/shared/Domain/*`) - pure functions with no Roblox
   APIs. These are the single source of truth for rules:
   - `Economy` - upgrade cost, income rate, offline income, extraction bonus.
   - `Encumbrance` - carry capacity, walk-speed multiplier, capacity checks.
   - `Inventory` - owned-relic and pedestal-assignment transitions.
    - `Progression` - temple unlock rules.
    - `RunRules` - expedition spawn plan, extraction credit, and the relic
      haulability invariant.
    - `Schema` - profile shape, versioned migrations, normalization.
    - `Stamina` - sprint pool, drain/recovery and exhaustion rules.
    - `Stats` - the single effective-stat resolver (capacity, weight penalty,
      maximum health, stamina pool/drain, sprint multiplier, gold multiplier)
      fed by upgrades, training and companion bonuses.
    - `Training` - passive experience curve and derived attribute levels.
    - `Companions` - companion ownership/equip rules and bonus aggregation for
      the stat resolver.
   - `MuseumBuilder` - museum wing layout, pedestal placement/tiering, and
     building-enhancement levels (see `docs/ADR/0010-museum-expansion.md`).
   - `SceneryLayout` - the shape of the world: the rounded-rectangle geometry,
     the protected regions (temple halls, hub plaza, museum plot ring, plot
     avenues, approach avenue, district cross-court), the forest bands measured
     to the canopy edge, and the layered escarpment that closes the horizon.
     It reads the configuration through `SceneryLayout.inputs`, so the world
     builder and the test suite always agree on the horizon.
   Being pure, they run under the standalone Luau CLI for tests.

3. **Shared / Utilities** - `Signal` (isolated synchronous events) and `Util`
   (deep copy, number/duration formatting).

4. **Server / Services** - one responsibility each. Services receive a shared
   `ctx` (`{ Config, Services, World, Signals, Logger }`) and expose `Init(ctx)`
   and `Start()`. `MonetizationService` owns the Welcome Back offline claim, the
   VIP Pass, and the Instant Revive product (see `docs/MONETIZATION.md`).
   `RelicService` scopes relic pools to temple occupancy — spawned when the
   first player enters (`ExpeditionService:RequestEnter` calls
   `OnExpeditionStarted`) and destroyed when the last leaves (`clearExpedition`
   calls `OnExpeditionEnded`) — so expeditions are replayable and a shared
   temple never shows stacked duplicate pickups.
   `StaminaService` owns the runtime sprint pool (the server resolves the pool
   and speed from `Stats`, never from client input) and `TrainingService` awards
   passive experience on relic pickups, successful hauls, and time spent inside
   a temple. Every derived number comes from `StatsUtil.forProfile`, which
   converts stored training experience into the levels the `Stats` resolver
   consumes and adds the equipped companion's bonuses.
   `CompanionService` owns companion purchases and the single equipped slot.
   It validates and rate-limits the `BuyCompanion`/`EquipCompanion`/
   `UnequipCompanion` actions, moves gold through `Economy:Spend`, re-applies
   health/stamina/movement effects, and never computes a companion stat itself:
   the resolver does that from the equipped id.

5. **Server / World** - builds the unified ground, hub, temples, connecting
   avenues, museum plots and the horizon scenery at runtime from `GameConfig`
   and returns typed handles (portals, traps, pedestals). `GameConfig.World`
   holds the shared layout constants (plot ring radius/start angle, ground top
   height, plaza radius, avenue width) so the hub, plots and temples stay
   physically linked: `WorldBuilder.Build()` runs `GroundBuilder.Build` (a
   rounded-rectangle ground slab flush with every structure), then
   `HubBuilder.Build` and `TempleBuilder.Build`, then `PathBuilder.Build`
   (marble avenues from the hub to each plot and temple), then
   `SceneryBuilder.Build` (the decorative grove and the rocky escarpment).

6. **Server / Security** - token-bucket `RateLimiter` used per player and per
   action.

7. **Client** - `Net` (remotes), `State` (observable snapshot), `UI/`
   (`Theme`, `Components`, `UIRoot`, `Panels`), `Controllers/` (input, effects).

## Boot sequence

`init.server.luau` performs, in order:

1. `WorldBuilder.Build()` - geometry and runtime handles.
2. `Init(ctx)` for every service, in dependency order:
   `Network, Analytics, View, PlayerData, Monetization, Economy, Upgrade,
   Progression, Settings, Tutorial, Training, Companion, Plot, Museum, Relic,
   Expedition, Hazard, Guardian, Extraction, Stamina, Admin`.
3. Signal wiring: `ProfileLoaded/ProfileChanged/PlotAssigned/PlotReleased` push
   fresh state; hub kiosk prompts push `OpenPanel` events.
4. `Start()` in dependency order:
   `Network, Analytics, Monetization, Economy, Upgrade, Progression, Settings,
   Tutorial, Training, Plot, Museum, Hazard, Guardian, Extraction, Stamina,
   Expedition, Companion, Admin`
   (`RelicService` has no `Start()`; its pools spawn lazily on first entry).
   Monetization starts before Economy so the cached VIP entitlement is known when
   the offline cap is computed; Guardian starts after Hazard because it routes
   contact damage through `HazardService:DamagePlayer`; Companion starts after
   Expedition so equip effects can recalculate movement.
5. `PlayerDataService:Start()` last, so every `ProfileLoaded` listener exists
   before any player profile finishes loading.

Ordering matters: `Plot` assigns a plot on `ProfileLoaded`, and `Museum` listens
for `PlotAssigned`, so `Museum` must start before `Plot` begins loading players.

## State flow

- Mutations call `PlayerDataService:MarkDirty(player)`, which fires
  `ProfileChanged`, which pushes a new `State` snapshot to that client.
- `ViewService:Build(player)` composes the snapshot from config + profile +
  expedition + plot. Clients resolve names, colors, and rarity locally.
- `NetworkService:PushEvent` carries discrete events (`Toast`,
  `ExpeditionSummary`, `PedestalSelected`, `Damage`, `HazardWarning`,
  `OpenPanel`, ...).

## Persistence

`PlayerDataService` owns profiles. See `docs/DATA_MODEL.md` and
`docs/THREAT_MODEL.md` for the schema and safety rules (no blind overwrite,
`UpdateAsync` session-conflict guard, debounced writes, `BindToClose` timeout,
Studio-only ephemeral fallback).

## Key constants

- Museum ring: 12 plots, radius 380, 30 degrees apart, start angle 105 (offset
  from the temple lane on +Z). Each wing fits a 90 x 90 box; three wings stack
  with a slim 8-stud gap (human-scale ceilings 14-16 studs, 1.5-stud walls, 2x2
  pillars).
- Temples: `TutorialRuins` (z=300, free), `ForgottenCatacombs` (z=540,
  1 extraction + 500 gold), `SunkenSanctum` (z=820, 2 extractions + 4000 gold),
  and the endgame `VoidCitadel` (z=1130, 4 extractions + 10000 gold, `void` theme,
  `VoidWarden` guardians). Hub portals place up to five temples around fixed slots.
- Player base walk speed 19 studs/s (`GameConfig.Movement.BaseWalkSpeed`).
- Pedestals capped at 14 (6 base + 3 per Museum Expansion level + 1 per Extra
  Pedestal level), spread across three wings: Grand Foyer (ids 1-6), Exhibition
  Hall (7-10), Secure Vault (11-14). Pedestal platforms are low (waist/chest
  height, ~3.2 studs) rather than tall pillars.
