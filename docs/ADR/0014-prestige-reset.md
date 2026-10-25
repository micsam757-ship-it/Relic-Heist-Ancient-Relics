# ADR 0014: Museum Prestige reset and schema v7

- Status: Accepted
- Date: 2026-10-25
- Prerequisite for: Phase 3 (Museum Prestige)
- Implementation: schema v7, pure `Prestige` rules, `PrestigeService`, and the
  Museum panel confirmation flow.

## Context

Phase 3 gives experienced players a long-term objective after the museum is fully
developed. The design calls for optional prestige with permanent rewards. The
blueprint's persistence safeguards require three things before reset code exists:

1. a written schema migration plan;
2. an explicit whitelist of what survives a reset;
3. migration and regression tests.

The profile was schema v6 at the time this decision was written
(`docs/DATA_MODEL.md`). Saves are debounced and
can fail, and `Schema.migrate` rejects profiles newer than the running build.
Prestige is the most destructive operation in the game, so the plan must bound
what it can erase and what happens when the confirming save fails.

This ADR was written before implementation and deliberately did not add fields,
actions, config, or UI; the implementation section below records what was added
after acceptance.

## Decision

### 1. Eligibility

Prestige is optional, player-initiated, and available only when the museum is
fully developed:

- `MuseumFloor` is at its configured `maxLevel` (2).
- `ExtraPedestal` is at its configured `maxLevel` (2).
- Every upgrade listed in `GameConfig.MuseumBuilding.Enhancements` is at its
  configured `maxLevel` (`MarblePillars` 3, `Lighting` 3, `GlassCases` 2,
  `VelvetRopes` 2, `Chandeliers` 2).
- Every pedestal the layout provides is occupied by an owned relic
  (`MuseumBuilder.totalPedestals(GameConfig.MuseumBuilding.Wings)`, currently
  14).
- The player is not on an expedition.
- The profile is persistent (not `ephemeral`).
- At least `GameConfig.Prestige.MinSecondsBetween` seconds have passed since the
  previous prestige (`60s`).

Eligibility lives in the pure `Prestige.canPrestige(profile, config, wings)`
function so the server and tests share one rule set. The server still checks the
expedition and persistence conditions, which depend on runtime state.

### 2. Reset allowlist: what changes

Only the keys in this table are modified. Everything else is copied through
unchanged.

| Profile field | After prestige |
| --- | --- |
| `gold` | `GameConfig.Economy.StartingGold` (250) |
| `relics` | `{}` (the collection is donated) |
| `museum` | `{}` (the reset empty pedestals rely on this) |
| `upgrades.MuseumFloor` | `0` |
| `upgrades.ExtraPedestal` | `0` |
| `upgrades.MarblePillars` | `0` |
| `upgrades.Lighting` | `0` |
| `upgrades.GlassCases` | `0` |
| `upgrades.VelvetRopes` | `0` |
| `upgrades.Chandeliers` | `0` |
| `pendingOfflineGold` | `0` |
| `lastIncomeClaimAt` | `now` |
| `prestigeLevel` | `prestigeLevel + 1` |
| `lastPrestigeAt` | `now` |

The museum upgrade ids come from a single config list
(`GameConfig.Prestige.ResetUpgradeIds`) so eligibility, reset, and tests cannot
drift. A config-integrity test asserts that this list contains exactly
`MuseumFloor`, `ExtraPedestal`, and every value of
`GameConfig.MuseumBuilding.Enhancements`, and that each id exists in
`GameConfig.Upgrades`.

Unknown upgrade ids are preserved. Known gameplay upgrades that are not museum
related (`SprintBoots`, `Backpack`, `Armor`) are preserved. A reset never walks
the whole `upgrades` table and clears it.

`relics` is cleared together with `museum` so no dangling pedestal reference can
survive normalization. Relic uids are session-scoped and are never reused.

### 3. Survivor allowlist: what is guaranteed to survive

The reset replaces only the fields in Section 2. These fields are explicitly
preserved and covered by tests:

| Profile field | Reason |
| --- | --- |
| `schemaVersion` | Set by migration/save, never reset |
| `sessionId`, `updatedAt` | Owned by persistence |
| `tutorialComplete`, `tutorialStep` | Completion is not museum progress |
| `stats` (all lifetime counters) | Historical record; gates already earned |
| `training` (experience) | Earned by play, not bought; Phase 2 promise |
| `companions`, `equippedCompanion` | Bought with gold; player property |
| `unlockedTemples` | Avoids re-buying temples at M2 prices |
| `vip` | Marketplace entitlement, not gameplay progress |
| `settings` | Accessibility must never be destroyed by gameplay |
| `prestigeLevel`, `lastPrestigeAt` | The reward itself |
| Any unknown profile key | Forward compatibility with a newer build |

Rationale: prestige is a museum donation, so it gives up the museum economy and
the collection, not the hunter. Training, companions, gear and temple access
represent time and gold the player already committed outside the museum. Keeping
them also keeps the post-prestige loop shorter than the first run and avoids
punishing players for supporting earlier phases.

### 4. Rewards

- **Museum income bonus.** `+5%` per prestige level, additive, capped at `+50%`
  (`10` effective levels). The bonus is always derived from
  `prestigeLevel`; it is never stored.
- **Rank.** A derived cosmetic title: level 1-4 `Curator`, 5-9 `Master Curator`,
  10+ `Grand Curator`. Displayed in the Museum panel and snapshot.
- **Permanent marker.** A foyer plaque showing the current rank is planned, but
  it is a follow-up; prestige does not depend on new geometry.
- **Future expedition gate.** Phase 4 may read `prestigeLevel` for advanced
  expeditions. No gate is added now.
- No gold payout, no free companion, and no extraction multiplier. Prestige must
  not create a self-funding loop.

### 5. Economy and balance model

Current full-collection museum income is `465/min`. Each prestige level adds
`+5%`, about `+23.25/min` at full collection; the `+50%` cap is
`+232.5/min` at level 10, before the Sun Scarab's `+10%`.

The full museum upgrade path costs about `16,729` gold. Prestige refunds nothing,
resets gold to `250`, and clears the collection, so the player must re-exhibit to
earn the bonus. Non-museum gear (`SprintBoots`/`Backpack`/`Armor`, about `15,406`
gold by current prices) survives, which keeps repeat cycles from becoming a full
restart.

The existing resolution path stays authoritative:

- `Stats` gains one field, `museumIncomeMultiplier`, computed as
  `clamp(1 + companionGoldBonus + prestigeBonus, 1, 2)`.
- `goldMultiplier` remains the companion-only multiplier used by the extraction
  stipend, so prestige does not accelerate expeditions.
- `EconomyService:GetIncomeRate` uses `museumIncomeMultiplier`; no service
  computes the prestige bonus itself.
- At the cap with Sun Scarab equipped, museum income is `1.6x`; the `2.0x`
  ceiling leaves room for later content without removing the safety bound.

### 6. Schema v7 and migration

Add two first-class profile fields:

```lua
prestigeLevel = 0,       -- integer, 0 = never prestiged
lastPrestigeAt = 0,      -- unix seconds, 0 = never
```

Migration `migrations[6]` upgrades v6 to v7:

- if `prestigeLevel` is missing, seed `0`; otherwise preserve it;
- if `lastPrestigeAt` is missing, seed `0`; otherwise preserve it;
- do not touch any other field.

`Schema.createDefault` seeds both at `0`. `Schema.normalize` clamps
`prestigeLevel` to a non-negative integer (safety bound `1000`) and
`lastPrestigeAt` to an integer clamped to `[0, now]`. `Schema.CURRENT_VERSION`
becomes `7`, and `Types.PlayerProfile` gains both fields.

Size impact is tens of bytes, far inside the existing under-25 KB worst-case
budget in `docs/DATA_MODEL.md`.

The snapshot adds:

```lua
prestige = {
  level = 0,
  rank = nil,             -- nil until level 1
  incomeMultiplier = 1,
  canPrestige = false,
  requirements = { ... },  -- readable checklist for the UI
  resets = { ... },        -- display copy of the reset summary
}
```

`canPrestige` and the checklist are server-computed for display only; the
server re-checks them on the request.

**Rollback constraint:** `Schema.migrate` rejects a profile whose version is
newer than the running build. Once a live profile is saved at v7, rolling the
game back to a v6 build will kick that player rather than corrupt their data.
Deploy v7 only after the checks and Studio session pass; a rollback after a live
migration requires a forward-compatible hotfix, not an older build.

### 7. Server action and save safety

Add one action:

| Action | Data | Behaviour |
| --- | --- | --- |
| `Prestige` | `{ confirm = "PRESTIGE" }` | Validate, build a reset copy, persist, then apply side effects |

The action is rate-limited to one request per 5 seconds and validated through
`Contracts.check`. The literal confirmation string prevents a single stray
request from resetting an account.

Sequence:

1. Read `profile`; reject if no profile, ephemeral, in an expedition, cooling
   down, or not eligible.
2. Build `next` with pure `Prestige.apply(profile, config, museum, now)`, which
   deep-copies the profile and changes only Section 2 fields. `profile` is not
   mutated.
3. On success, keep the original profile as the rollback copy, set the handle's
   profile to `next`, and call `PlayerDataService:SaveAsync(player, true)`
   synchronously.
4. If the forced save returns `true`, fire a single `PrestigeApplied` signal,
   rebuild the museum plot once, refresh persisted displays, apply upgrade
   effects, push state, analytics, and toast.
5. If the forced save returns `false`, restore the original profile in memory,
   mark it dirty if needed, and return `false` with "Prestige could not be saved.
   Nothing was reset." No side effects and no state push run.

This makes the persisted reset the commit point. A crash after a successful save
leaves the player correctly prestiged. A failed save leaves the old profile
intact. The residual risk is a process crash between the in-memory swap and the
forced save: the old profile has not been mutated, and the debounced save has
not been triggered, so the stored record is unchanged.

`PrestigeApplied` is a new server signal so the plot is rebuilt once. Firing
seven `UpgradePurchased` signals would rebuild the plot seven times.

### 8. Client and confirmation flow

- The Museum panel gains a Prestige section: current level/rank, next bonus, the
  eligibility checklist, and the reset summary ("You keep: training, companions,
  gear upgrades, temples, settings").
- The Prestige button is disabled until `canPrestige` is true.
- Pressing it opens a modal that requires typing `PRESTIGE` (the client
  uppercases the input and the server requires the exact string) before the
  confirm button enables.
- The server is the only authority; the client never computes rewards or resets.
- The modal explains that gold and relics are cleared and that the reset cannot
  be undone.

### 9. Tests (required before merge)

Pure/domain and config tests:

- `Prestige.canPrestige` is false for each missing requirement and true only when
  all are satisfied.
- `Prestige.apply` changes exactly the Section 2 fields and preserves every
  Section 3 field, including unknown keys.
- Known non-museum upgrades and unknown upgrade ids survive.
- Gold becomes `GameConfig.Economy.StartingGold`; pending offline gold is `0`;
  `lastIncomeClaimAt` is `now`.
- Level increments by one and `lastPrestigeAt` becomes `now` on every repeat.
- A second call without rebuilding the museum fails eligibility; applying the
  reset is deterministic.
- Schema v6 to v7 migration seeds both fields and preserves all v6 data.
- `normalize` clamps invalid prestige values and preserves unknown fields.
- Config integrity: `ResetUpgradeIds` exactly covers the museum upgrade set and
  every id exists; the bonus cap is positive and bounded.
- `Stats.museumIncomeMultiplier` adds companion and prestige bonuses, clamps at
  `2`, and leaves `goldMultiplier` unchanged for extraction.
- `EconomyService` income uses the combined museum multiplier; extraction does
  not.
- `Contracts` registry and `docs/API_CONTRACTS.md` agree on the new action
  (17 actions), and the payload requires the confirmation string.
- Snapshot shape includes level, rank, multiplier, eligibility, and reset copy.

Service behaviour that the pure harness cannot cover is verified in Studio
Session M:

- forced-save failure restores the old profile and applies no reset;
- an active expedition blocks prestige;
- a second request during cooldown is rejected;
- a v7 profile rejoins with the correct level and survivors.

### 10. Rollout gates

1. Review and accept this ADR, including the open questions below.
2. Implement schema v7, `Prestige`, config, and pure tests. No reset action yet.
3. Add the stats/economy integration and tests.
4. Add the server action, forced-save rollback, signal, and confirmation UI.
5. Run `scripts/check.ps1` and Studio Session M.
6. Only then enable prestige in a live build. Record the live DataStore version
   history/backup step in the release notes.

## Consequences

- Prestige is safe to reason about: the reset is a named allowlist, the survivors
  are explicit, and derived bonuses are never stored.
- The museum layer becomes replayable without erasing accessibility settings,
  purchased companions, earned training, or temple unlocks.
- One new action and one new stat field keep the surface small.
- A v7 profile cannot be loaded by a v6 build; rollback needs care.

## Alternatives

- **Reset every upgrade (including SprintBoots, Backpack, Armor):** rejected.
  It turns prestige into a full restart and punishes gear the museum does not
  use.
- **Reset training and companions:** rejected. Those are earned or bought
  outside the museum; erasing them would make prestige feel like a penalty.
- **Clear relics but keep the museum upgrade levels:** rejected. The museum would
  have empty wings and the reset would not create a replay loop.
- **Keep gold:** rejected. It would let the player instantly re-buy the museum
  and nullify the loop.
- **Automatic or passive prestige:** rejected. The blueprint requires optional,
  clearly explained prestige.
- **A separate prestige currency/shop:** deferred; it adds a second economy
  before the first cycle is playtested.
- **Compounding bonuses:** rejected. Additive with a hard cap keeps the income
  ceiling bounded.
- **Store a derived multiplier:** rejected. It would drift from the resolver.
- **Bump the schema without a migration by writing v7 on save:** rejected. Older
  v6 code would reject the record with no migration path.

## Open questions for review

1. Preserve gear upgrades (proposed) or reset all upgrades for a longer loop?
2. Is `+5%` per level capped at `+50%` the right reward curve, given full
   collection is `465/min` and the museum re-buy costs about `16,729` gold?
3. Reset gold to `250` (proposed) or to `0`?
4. Require all `14` pedestals filled (proposed) or only the upgrade levels?
5. Preserve training, companions, and temple unlocks (proposed) or reset any of
   them?
6. Add the cosmetic foyer plaque now, or defer it and show level/rank in the UI only?
