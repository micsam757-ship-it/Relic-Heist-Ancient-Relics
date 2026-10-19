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

### Museum and economy

- **FR-008** Each player is assigned one of 12 museum plots on load, built on
  demand and destroyed on leave.
- **FR-009** Players exhibit owned relics on unlocked pedestals; a relic can be
  on at most one pedestal and a pedestal holds at most one relic.
- **FR-010** Exhibited relics produce passive income, additive across exhibits,
  multiplied by the Museum Expansion bonus and capped by
  `MaxIncomeRatePerMinute`.
- **FR-011** Pending income accrues from `lastIncomeClaimAt` up to the offline
  cap and the `MaxPendingIncome` ceiling, and is claimed explicitly.
- **FR-012** Upgrades are purchasable with gold, priced with geometric growth,
  and capped at each upgrade's `maxLevel`.

### Progression and UX

- **FR-013** Later temples unlock progressively. `ForgottenCatacombs` and
  `SunkenSanctum` each unlock only when the player has at least the configured
  extractions (`minExtractions`) and can pay the unlock price.
- **FR-014** The client displays gold, income rate, pending income, expedition
  timer, carried weight, owned relics, pedestals, temples, and settings.
- **FR-015** A one-time tutorial card appears until `tutorialComplete`.
- **FR-016** Studio-only admin commands exist for development and never run in
  a published server.

## Data requirements

- **FR-017** Profiles are versioned and migrated forward-only; unreadable or
  future-version data is never overwritten.
- **FR-018** Saves are debounced and use a conflict guard so two servers cannot
  blindly overwrite each other.

## Out of scope (this slice)

- Cross-server trading, leaderboards, monetization, cosmetic art, audio assets,
  and persistent per-temple state.
