# Software Requirements Specification

Scope: single-server, session-based Roblox experience. IDs are stable and are
referenced by `docs/traceability/requirements-matrix.md`.

## Actors

- **Player** - steals relics, carries them, escapes, exhibits them, upgrades.
- **Server** - the only authority over rewards, ownership, and damage.
- **Developer** - uses Studio-only admin commands and analytics counters.

## Functional requirements

### Core loop

- **FR-001** A player enters a temple through a hub portal or the Expeditions
  panel. Entry is server-validated (alive, unlocked, near the portal if prompt
  based, not already on an expedition).
- **FR-002** Temples spawn configured relics with ProximityPrompts. Collecting a
  relic is server-validated (in the correct temple, not collapsing, within
  range, under rate limit, within weight and count capacity).
- **FR-003** Carried weight reduces walk speed via `Encumbrance.multiplier`,
  clamped to `MinSpeedMultiplier`.
- **FR-004** An expedition has a countdown. At thresholds the server fires
  60/30/10-second warnings; at zero it begins collapse damage.
- **FR-005** Extraction at the temple altar is the only way to convert carried
  relics into owned relics. Extraction requires being on an expedition for that
  temple and within range of the altar, and is idempotent.
- **FR-006** Dying or abandoning loses all carried relics and increments the
  death statistic.
- **FR-007** Hazards (dart, boulder, blade, collapse) deal server-side damage
  using authoritative positions; they never rely on `Touched`.
- **FR-007b** Guardian enemies patrol a configured route, chase a player they can
  see within aggro range, and deal contact damage after a visible windup. All
  targeting and damage are server-authoritative; they share the hazard damage
  pipeline and never rely on `Touched`. See `docs/ADR/0008-guardian-enemies.md`.

### Museum and economy

- **FR-008** Each player is assigned one of 12 museum plots on load, built on
  demand and destroyed on leave.
- **FR-009** Players exhibit owned relics on unlocked pedestals; a relic can be
  on at most one pedestal and a pedestal holds at most one relic.
- **FR-010** Exhibited relics produce passive income, additive across exhibits,
  multiplied by the Museum Expansion bonus and capped by
  `MaxIncomeRatePerMinute`.
- **FR-011** Passive income is deposited automatically into the gold balance on
  a one-second server tick while online. While offline it accrues from
  `lastIncomeClaimAt` up to the offline cap (4h standard, 24h for VIP Pass
  holders) and the pending ceiling (`MaxPendingIncome`, raised for VIP). The
  offline balance is held in `pendingOfflineGold` and resolved through the
  Welcome Back modal (FR-019), not granted silently on join.
- **FR-012** Upgrades are purchasable with gold, priced with geometric growth,
  and capped at each upgrade's `maxLevel`.

### Progression and UX

- **FR-013** Later temples unlock progressively. `ForgottenCatacombs` and
  `SunkenSanctum` each unlock only when the player has at least the configured
  extractions (`minExtractions`) and can pay the unlock price.
- **FR-014** The client displays gold, income rate, expedition
  timer, carried weight, owned relics, pedestals, temples, and settings.
- **FR-015** A data-driven tutorial guides the player through ordered steps
  defined in `GameConfig.Tutorial.Steps`. Each step advances only when the player
  performs the action it teaches, in order; the server records the highest step
  reached and pushes progress to the client. The tutorial never gates play, and an
  empty step list disables it. See `docs/ADR/0009-tutorial-and-ux.md`.
- **FR-016** Studio-only admin commands exist for development and never run in
  a published server.
- **FR-020** The HUD is responsive across phone, tablet, and desktop viewports,
  scaling to stay legible while never shrinking below a readable floor.
- **FR-021** All core actions are reachable with keyboard, pointer/touch, and
  gamepad. Touch uses on-screen nav; gamepad uses face-button shortcuts plus
  native GUI focus navigation; `Escape` and gamepad `ButtonB` close the active
  panel even while a GUI is focused.
- **FR-022** Accessibility preferences persist per profile and are validated
  server-side: sound on/off, visual effects on/off, reduced motion, a
  colorblind-safe palette, and text size (`Normal`/`Large`/`Huge`). Applying a
  change re-themes the client from a single applier.
- **FR-023** Audio and visual feedback are data-driven from `GameConfig.Audio` and
  honor the sound and reduced-motion settings. Unconfigured asset ids play
  nothing, so the game is silent but fully playable.

### Monetization

- **FR-019** On join, if offline gold is pending, a Welcome Back modal offers a
  free **Claim 1x** (grants the pending payout) and a **Claim 2x** option that
  doubles *that one payout* via a 199-Robux Developer Product. All grants are
  server-authoritative and validated through `ProcessReceipt`; the free option is
  always available. A VIP Pass (Game Pass) extends the offline window to 24h and
  raises the pending ceiling. Unconfigured product/pass IDs disable only the paid
  offers, never the free claim. See `docs/MONETIZATION.md`.

## Data requirements

- **FR-017** Profiles are versioned and migrated forward-only; unreadable or
  future-version data is never overwritten.
- **FR-018** Saves are debounced and use a conflict guard so two servers cannot
  blindly overwrite each other.

## Out of scope (this slice)

- Cross-server trading, leaderboards, cosmetic art, audio assets, persistent
  per-temple state, and monetization beyond the Welcome Back offer and VIP Pass
  (documented in `docs/MONETIZATION.md`).
