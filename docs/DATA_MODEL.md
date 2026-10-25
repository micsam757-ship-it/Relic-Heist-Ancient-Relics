# Data Model

## Storage

- DataStore name: `RelicHeistProfiles`, scope `v1` (see `GameConfig.Save`).
- Key per player: `player_<UserId>`.
- One record per player; written with `UpdateAsync`.

## Profile schema (version 7)

```lua
{
  schemaVersion = 7,
  sessionId = "<guid>",        -- identifies the owning server session
  updatedAt = <unix seconds>,
  gold = 250,
  tutorialComplete = false,
  tutorialStep = 0,            -- highest tutorial step completed
  stats = { extractions = 0, deaths = 0, relicsCollected = 0, incomeClaimed = 0 },
  relics = { ["relic_<guid>"] = { id = "<DefinitionId>", acquiredAt = <unix> } },
  museum = { ["1"] = "relic_<guid>" },        -- pedestalId -> owned relic uid
  training = { strength = 0, stamina = 0, carrying = 0 },  -- passive XP (v5)
  companions = { SunScarab = true },        -- owned companion ids (v6)
  equippedCompanion = "SunScarab",           -- one id, or nil (v6)
  prestigeLevel = 0,                         -- completed prestiges (v7)
  lastPrestigeAt = 0,                        -- unix seconds; 0 = never (v7)
  upgrades = {
    SprintBoots = 0, Backpack = 0, Armor = 0, MuseumFloor = 0, ExtraPedestal = 0,
    -- visual museum-building enhancements (v4)
    MarblePillars = 0, Lighting = 0, GlassCases = 0, VelvetRopes = 0, Chandeliers = 0,
  },
  unlockedTemples = { TutorialRuins = true },
  lastIncomeClaimAt = <unix seconds>,
  pendingOfflineGold = 0,     -- offline payout held for the Welcome Back modal
  vip = false,                -- cached VIP Pass entitlement
  settings = {
    soundEnabled = true,
    visualEffects = true,
    reducedMotion = false,
    colorblindMode = false,
    textScale = "Normal",     -- "Normal" | "Large" | "Huge"
  },
}
```

- `relics` keys are unique instance ids; values reference a config definition.
- `museum` values must exist in `relics`; a uid may appear at most once.

## Invariants (enforced by `Schema.normalize` on load)

- `gold >= 0`, integer.
- `stats.* >= 0`, integers.
- Relics with a missing/non-string `id` are removed.
- Museum entries pointing at missing uids, or reusing a uid, are removed.
- Upgrade levels are non-negative integers; unknown keys are dropped from the
  strict set by the config consumer.
- Training experience is a non-negative integer per attribute, capped at
  `1000000`; non-numeric entries are dropped. Levels are always derived from the
  experience, never stored alongside it.
- The stamina pool itself is runtime state and is never persisted; every
  expedition starts with a full pool resolved from training and upgrades.
- Companion ownership is a `{ [id] = true }` map; entries whose value is not
  exactly `true`, or whose key is not a string, are removed. Unknown ids are
  preserved so data written by a newer build is not destroyed; unknown ids never
  grant a bonus.
- `equippedCompanion` is `nil` unless it is a non-empty string that is also
  owned. At most one companion is equipped (`GameConfig.Companions.MaxEquipped`).
  Companion bonuses and prices are derived from config, never stored.
- Schema v6 adds the companion fields; existing profiles own none and have none
  equipped.
- `prestigeLevel` is a non-negative integer clamped to `1000` for safety. It is
  a count of completed prestiges, not a currency; the income bonus is always
  derived from it.
- `lastPrestigeAt` is an integer clamped to `[0, now]`; `0` means never.
- `lastIncomeClaimAt <= now`.
- `pendingOfflineGold >= 0`, integer.
- `vip` is a boolean.
- `tutorialStep >= 0`, integer (clamped to `#GameConfig.Tutorial.Steps` by the
  consumer; the tutorial module treats out-of-range values as complete).
- Settings booleans default to their config values (`soundEnabled`/`visualEffects`
  `true`, `reducedMotion`/`colorblindMode` `false`); `textScale` is coerced to
  `"Normal"` unless it is one of `Normal`/`Large`/`Huge`.

## Migrations

`Schema.migrate` is forward-only. Version 0 records are back-filled from a
default shell without discarding existing fields. Version 1 records are upgraded
to v2 by `migrations[1]` (seeds `pendingOfflineGold = 0`, `vip = false`). Version
2 records are upgraded to v3 by `migrations[2]`, which adds the accessibility
settings and `tutorialStep` while preserving any values already present. Version
3 records are upgraded to v4 by `migrations[3]`, which seeds the five museum
building enhancement upgrade keys at 0 while preserving existing upgrade levels.
Version 4 records are upgraded to v5 by `migrations[4]`, which seeds the three
training experience attributes at 0 and preserves any experience already stored.
Version 5 records are upgraded to v6 by `migrations[5]`, which seeds an empty
`companions` map and clears `equippedCompanion` when it is not a string, while
preserving any companion data already present. Version 6 records are upgraded to
v7 by `migrations[6]`, which seeds `prestigeLevel = 0` and `lastPrestigeAt = 0`
only when each field is missing, preserving values already present. Records with
a schema version newer than `CURRENT_VERSION` are rejected rather than rewritten.

## Profile size budget

The DataStore value limit is 4 MiB (4,194,304 bytes) per key. The worst-case
profile is bounded by the 100-relic archive cap: 100 relic entries with a
`relic_<guid>` key, a definition id and a timestamp are roughly 10-15 KB
serialized; the 14 museum assignments, settings, upgrades and training add well
under 3 KB. Companion data is at most three boolean keys plus one id (tens of
bytes), and the two prestige fields add a few bytes, so the v6/v7 additions do
not materially change the budget. The
overall worst case is comfortably below 25 KB, about 0.6% of the limit. Re-measure
if the archive cap or stored per-relic data grows.

## Write policy

- A profile is marked `dirty` by `MarkDirty` (which also pushes state).
- A background tick saves dirty, non-ephemeral profiles after a debounce window.
- `UpdateAsync` compares the stored `sessionId`/`updatedAt`. If another session
  wrote more recently, the write is aborted, the profile is marked ephemeral,
  and the player is told their changes will not overwrite the newer data.
- `PlayerRemoving` and `BindToClose` force a save (bounded by a timeout).
- Prestige is transactional: `PlayerDataService:SwapProfile` installs the reset
  copy without marking it dirty, then a forced save must succeed before side
  effects run. A failed save restores the pre-prestige profile, leaving the
  stored record and the live player state unchanged. See `docs/ADR/0014-prestige-reset.md`.

## Not stored

- Carried (in-expedition) relics. These are in-memory only and are lost on death
  or abandon; only extracted relics become persistent.
- Online income. It is deposited straight into `gold` on the server's one-second
  tick; nothing is buffered. The offline portion is computed on join from the
  exhibited relics' per-second rate and `lastIncomeClaimAt`, then stored in
  `pendingOfflineGold` until the Welcome Back modal resolves it (1x or 2x). See
  `docs/ADR/0006-auto-tick-income.md` and `docs/ADR/0007-monetization.md`.
- Pending Instant Revive offers (`MonetizationService.revivePending`). A `ReviveOffer`
  is an in-memory, per-session flag keyed by `UserId`; it is cleared on purchase,
  decline, window expiry, or leave. Nothing about a revive is persisted, so no
  schema change was needed. See `docs/ADR/0011-endgame-temple-and-revive.md`.

## Failure-mode matrix

Every load and save path is classified by the pure `Persist` module so the same
decision is exercised by tests and production. `LIVE`/`NEW` profiles are
writable; `EPHEMERAL` profiles never write; `KICK` disconnects the player.

| Condition | Detection | Live server | Studio | Data safety |
| --- | --- | --- | --- | --- |
| DataStore service unavailable/`GetDataStore` errors | `store == nil` | `EPHEMERAL` | `EPHEMERAL` | Never writes; existing record untouched |
| Record not found | `GetAsync` returns `nil` | `NEW` | `NEW` | Creates a fresh default profile |
| Transient load failure after retries | `GetAsync` errors `MaxLoadRetries` times | `KICK` | `EPHEMERAL` | Fails closed; never writes over unknown data |
| Corrupt record | `Schema.migrate` returns nil | `KICK` | `EPHEMERAL` | Record is never overwritten (T-12) |
| Future-schema record | `schemaVersion > CURRENT_VERSION` | `KICK` | `EPHEMERAL` | Record is never downgraded/overwritten |
| Record migrates cleanly | `migrate` returns a profile | `LIVE` | `LIVE` | Normalized, saved back on next tick |
| Another session wrote more recently | `Persist.canCommit` false in `UpdateAsync` | abort + `EPHEMERAL` | abort + `EPHEMERAL` | Newer record protected (T-11) |
| Save errors transiently | `UpdateAsync` throws | retry `MaxSaveRetries` with backoff | same | Retries; profile stays dirty |
| Save permanently fails | all retries exhausted | profile stays dirty | same | Retried on next tick / next force-save |
| Shutdown with pending writes | `BindToClose` | flush within `BindToCloseTimeoutSeconds` | same | Bounded; never hangs shutdown |
| Player leaves mid-load | `player:IsDescendantOf(Players)` false | discard handle | discard | No orphaned handle |

Retry backoff (both load and save) is `{ 0.6, 1.5, 3 }`
(`GameConfig.Save.RetryBackoffSeconds`); `Persist.retryBackoff` stops after the
last attempt and reuses the final value if the table is shorter than the retry
count.

## Test coverage

- `Persist.loadOutcome` classification for every row above.
- `Persist.canCommit` conflict guard (T-11) and `Persist.retryBackoff` bounds.
- `Schema.migrate`/`normalize` for corrupt, future, and legacy records.
- Schema v6 to v7 migration and prestige normalization clamps.
- Prestige's reset-copy allowlist and survivor fields; the live forced-save
  rollback still requires Studio/API-services verification (Session M).

Live DataStore behaviour (real `GetAsync`/`UpdateAsync` errors) still requires a
Studio API-services session and is listed as unverified in
`docs/PROJECT_STATUS.md`.
