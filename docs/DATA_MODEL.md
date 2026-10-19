# Data Model

## Storage

- DataStore name: `RelicHeistProfiles`, scope `v1` (see `GameConfig.Save`).
- Key per player: `player_<UserId>`.
- One record per player; written with `UpdateAsync`.

## Profile schema (version 1)

```lua
{
  schemaVersion = 1,
  sessionId = "<guid>",        -- identifies the owning server session
  updatedAt = <unix seconds>,
  gold = 250,
  tutorialComplete = false,
  stats = { extractions = 0, deaths = 0, relicsCollected = 0, incomeClaimed = 0 },
  relics = { ["relic_<guid>"] = { id = "<DefinitionId>", acquiredAt = <unix> } },
  museum = { ["1"] = "relic_<guid>" },        -- pedestalId -> owned relic uid
  upgrades = { SprintBoots = 0, Backpack = 0, Armor = 0, MuseumFloor = 0, ExtraPedestal = 0 },
  unlockedTemples = { TutorialRuins = true },
  lastIncomeClaimAt = <unix seconds>,
  settings = { soundEnabled = true, visualEffects = true },
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
- Settings booleans default to `true`.

## Migrations

`Schema.migrate` is forward-only. Version 0 records are back-filled from a
default shell without discarding existing fields. Records with a schema version
newer than `CURRENT_VERSION` are rejected rather than rewritten.

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
- Pending income. It is derived on demand from `incomePerMinute` and
  `lastIncomeClaimAt`, so no per-tick writes are required.
