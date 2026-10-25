# API Contracts

## Remotes (ReplicatedStorage.Remotes)

| Remote | Type | Direction | Purpose |
| --- | --- | --- | --- |
| `Request` | RemoteEvent | client -> server | All actions, one channel |
| `State` | RemoteEvent | server -> client | Full/partial snapshots |
| `Event` | RemoteEvent | server -> client | Discrete named events |

### `Request` payload

```lua
{ action = "ActionName", data = <table|nil> }
```

The server drops payloads that are not tables or lack a string `action`, applies
a global limiter, then a per-action limiter, then calls the handler inside
`pcall`. Handlers return `(boolean, string?)`; a `false` result toasts the string
as an error, a `true` result toasts it as success.

### Registered actions

The canonical registry is `src/shared/Net/Contracts.luau`; a test asserts it
matches this table exactly, so the two cannot drift. Each handler validates its
`data` through `Contracts.check(action, data)`.

| Action | Data | Notes |
| --- | --- | --- |
| `RequestState` | - | Re-send a snapshot; allowed before profile load |
| `EnterExpedition` | `{ templeId }` | Must be near the hub |
| `AbandonExpedition` | - | Lose carried relics |
| `SetSprint` | `{ state }` | Sprint intent; `state` is `sprint` or `walk`. Only applies inside an expedition |
| `BuyUpgrade` | `{ upgradeId }` | |
| `BuyCompanion` | `{ companionId }` | Spend gold; the first companion auto-equips |
| `EquipCompanion` | `{ companionId }` | Must be owned; replaces the current companion |
| `UnequipCompanion` | - | Clears the single equipped slot |
| `Prestige` | `{ confirm = "PRESTIGE" }` | Resets the museum after a forced save; rejects during an expedition or an ephemeral session |
| `UnlockTemple` | `{ templeId }` | |
| `UpdateSettings` | `{ soundEnabled?, visualEffects?, reducedMotion?, colorblindMode?, textScale? }` | `textScale` must be `Normal`/`Large`/`Huge` |
| `PlaceRelic` | `{ pedestalId, uid }` | Near the pedestal |
| `RemoveRelic` | `{ pedestalId }` | Near the pedestal |
| `ClaimOfflineIncome` | - | Free 1x claim of `pendingOfflineGold` |
| `PurchaseOfflineDouble` | - | Prompt the 199-Robux 2x Developer Product |
| `PurchaseInstantRevive` | - | Prompt the Instant Revive Developer Product (only while the revive window is open) |
| `DeclineInstantRevive` | - | Skip the revive and resolve the death immediately |

### `State` snapshot (client-facing)

```lua
{
  serverNow, gold, incomePerSecond,
  relics = { { uid, id, name, rarity, weight, value, incomePerSecond, acquiredAt, exhibited } },
  displayed = { [pedestalId] = uid },
  pedestals = { { id, unlocked, uid } },
  pedestalCount, exhibitedCount,
  upgrades = { SprintBoots, Backpack, Armor, MuseumFloor, ExtraPedestal },
  capacity, armorLevel,
  stamina = nil | { current, max, sprinting, exhausted },
  training = { [attribute] = { level, maxLevel, xp, intoLevel, neededForNext, ratio, maxed } },
  companions = {
    owned = { [companionId] = true },
    equipped = nil | companionId,
    maxEquipped,
    goldMultiplier,
  },
  prestige = {
    level, rank = nil | string, bonus, nextBonus, incomeMultiplier,
    canPrestige,
    requirements = { { id, label, detail, met } },
    resets = { "<human-readable reset line>" },
  },
  temples = { { id, name, description, difficulty, order, unlocked, requirementsMet, canUnlock, minExtractions, unlockPrice, requiredRelics, durationSeconds, relicCount } },
  expedition = nil | { templeId, templeName, startedAt, endsAt, collapsing, carried, weight, capacity, speedMultiplier, requiredRelics, durationSeconds, remainingRelics },
  stats, settings, tutorialComplete,
  tutorial = { active, total, completed, step = nil | { id, title, text, hint, complete } },
  plotIndex, ephemeral,
  maxCarried, offlineCapSeconds,
  vip, pendingOfflineGold,
  offlineDouble = { multiplier, priceRobux, purchasable },
}
```

### `Event` payload

```lua
{ name = "EventName", data = <table> }
```

| Name | Data | Meaning |
| --- | --- | --- |
| `Toast` | `{ kind, message }` | Transient notice |
| `OpenPanel` | `{ panel }` | Hub kiosk opened a panel |
| `ExpeditionStarted` | `{ templeId, templeName, endsAt, durationSeconds, requiredRelics }` | |
| `ExpeditionWarning` | `{ remaining, level }` | `medium`/`high`/`critical`/`collapse` |
| `ExpeditionSummary` | `{ success, credited?, title, subtitle, lines, relics?, lostRelics?, goldEarned? }` | `credited` = run counted toward `minExtractions` |
| `PedestalSelected` | `{ pedestalId, plotIndex }` | Empty pedestal activated |
| `RelicCollected` | `{ definitionId, rarity }` | |
| `Stamina` | `{ current, max, sprinting, exhausted }` | Stamina pool while it changes |
| `Damage` | `{ amount, source, health, maxHealth }` | |
| `HazardWarning` | `{ label, kind, warningSeconds }` | Telegraph before a trap fires |
| `HazardFired` | `{ label, kind }` | Trap resolved |
| `WelcomeBack` | `{ amount, multiplier, priceRobux, purchasable, vip, capSeconds }` | Offline income pending; open the modal |
| `WelcomeBackClosed` | `{}` | Claim resolved; close the modal |
| `TutorialStep` | `{ completed, total, active, step }` | A tutorial step advanced; update the objective |
| `TutorialComplete` | `{}` | The final tutorial step finished |

## Error and validation rules

- Unknown action names are logged and dropped.
- Handlers must tolerate `nil`/missing `data` and return `false, reason` instead
  of erroring. An uncaught handler error is logged and shown as a generic toast.
