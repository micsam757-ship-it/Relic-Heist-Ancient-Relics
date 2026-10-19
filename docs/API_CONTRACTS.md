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

| Action | Data | Notes |
| --- | --- | --- |
| `RequestState` | - | Re-send a snapshot; allowed before profile load |
| `ClaimIncome` | - | Claim pending income |
| `EnterExpedition` | `{ templeId }` | Must be near the hub |
| `AbandonExpedition` | - | Lose carried relics |
| `BuyUpgrade` | `{ upgradeId }` | |
| `UnlockTemple` | `{ templeId }` | |
| `UpdateSettings` | `{ soundEnabled?, visualEffects? }` | |
| `PlaceRelic` | `{ pedestalId, uid }` | Near the pedestal |
| `RemoveRelic` | `{ pedestalId }` | Near the pedestal |

### `State` snapshot (client-facing)

```lua
{
  serverNow, gold, incomePerMinute, pendingIncome, lastIncomeClaimAt,
  relics = { { uid, id, name, rarity, weight, value, incomePerMinute, acquiredAt, exhibited } },
  displayed = { [pedestalId] = uid },
  pedestals = { { id, unlocked, uid } },
  pedestalCount, exhibitedCount,
  upgrades = { SprintBoots, Backpack, Armor, MuseumFloor, ExtraPedestal },
  capacity, armorLevel,
  temples = { { id, name, description, difficulty, order, unlocked, requirementsMet, canUnlock, minExtractions, unlockPrice, requiredRelics, durationSeconds, relicCount } },
  expedition = nil | { templeId, templeName, startedAt, endsAt, collapsing, carried, weight, capacity, speedMultiplier, requiredRelics, durationSeconds, remainingRelics },
  stats, settings, tutorialComplete, plotIndex, ephemeral,
  maxCarried, offlineCapSeconds,
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
| `ExpeditionSummary` | `{ success, title, subtitle, lines, relics?, lostRelics?, goldEarned? }` | |
| `PedestalSelected` | `{ pedestalId, plotIndex }` | Empty pedestal activated |
| `RelicCollected` | `{ definitionId, rarity }` | |
| `Damage` | `{ amount, source, health, maxHealth }` | |
| `HazardWarning` | `{ label, kind, warningSeconds }` | Telegraph before a trap fires |
| `HazardFired` | `{ label, kind }` | Trap resolved |

## Error and validation rules

- Unknown action names are logged and dropped.
- Handlers must tolerate `nil`/missing `data` and return `false, reason` instead
  of erroring. An uncaught handler error is logged and shown as a generic toast.
