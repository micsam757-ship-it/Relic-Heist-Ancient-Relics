# Data Model

## Storage

- DataStore name: `RelicHeistProfiles`, scope `v1` (see `GameConfig.Save`).
- Key per player: `player_<UserId>`.
- One record per player; written with `UpdateAsync`.

## Profile schema (version 3)

```lua
{
  schemaVersion = 3,
  sessionId = "<guid>",        -- identifies the owning server session
  updatedAt = <unix seconds>,
  gold = 250,
  tutorialComplete = false,
  tutorialStep = 0,            -- highest tutorial step completed
  stats = { extractions = 0, deaths = 0, relicsCollected = 0, incomeClaimed = 0 },
  relics = { ["relic_<guid>"] = { id = "<DefinitionId>", acquiredAt = <unix> } },
  museum = { ["1"] = "relic_<guid>" },        -- pedestalId -> owned relic uid
  upgrades = { SprintBoots = 0, Backpack = 0, Armor = 0, MuseumFloor = 0, ExtraPedestal = 0 },
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
settings and `tutorialStep` while preserving any values already present. Records
with a schema version newer than `CURRENT_VERSION` are rejected rather than
rewritten.

## Write policy

- A profile is marked `dirty` by `MarkDirty` (which also pushes state).
- A background tick saves dirty, non-ephemeral profiles after a debounce window.
- `UpdateAsync` compares the stored `sessionId`/`updatedAt`. If another session
  wrote more recently, the write is aborted, the profile is marked ephemeral,
  and the player is told their changes will not overwrite the newer data.
- `PlayerRemoving` and `BindToClose` force a save (bounded by a timeout).

## Not stored

- Carried (in-expedition) relics. These are in-memory only and are lost on death
  or abandon; only extracted relics become persistent.
- Online income. It is deposited straight into `gold` on the server's one-second
  tick; nothing is buffered. The offline portion is computed on join from the
  exhibited relics' per-second rate and `lastIncomeClaimAt`, then stored in
  `pendingOfflineGold` until the Welcome Back modal resolves it (1x or 2x). See
  `docs/ADR/0006-auto-tick-income.md` and `docs/ADR/0007-monetization.md`.

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

Live DataStore behaviour (real `GetAsync`/`UpdateAsync` errors) still requires a
Studio API-services session and is listed as unverified in
`docs/PROJECT_STATUS.md`.
