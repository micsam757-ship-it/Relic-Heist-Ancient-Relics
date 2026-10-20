# Threat Model

Assets and the mitigations implemented in code.

## Assets

- Player profiles (gold, owned relics, progression).
- In-memory carried relics (the prize of the core loop).
- Server integrity (no player should be able to fabricate rewards).

## Threats and mitigations

| ID | Threat | Mitigation |
| --- | --- | --- |
| T-01 | Client fires `Request` with fabricated reward/purchase data | The server ignores client-supplied amounts. Gold, ownership, price, and damage are computed server-side from config and profile. |
| T-02 | Client spams actions to multiply effects | Global and per-action token-bucket rate limits; duplicate-sensitive actions are idempotent (e.g. extraction clears state before granting). Token-bucket behaviour is unit tested (`RateLimiter`). |
| T-03 | Malformed payload crashes a handler | Payload shape validated up front by the pure `Validate` module (unit tested); handlers run in `pcall`; failures produce a generic toast and a server log line. |
| T-04 | Collecting relics without being in the temple | `RelicService.TryCollect` requires an active expedition for that exact temple and a proximity check. |
| T-05 | Collecting beyond carry capacity | `Encumbrance.checkCapacity` enforces both weight and count limits server-side. |
| T-06 | Duplicating a relic | Relics are unique uids; `Inventory.addOwned` rejects existing uids; a uid can be on at most one pedestal. |
| T-07 | Placing a relic without owning it / on a locked pedestal | `Inventory.exhibit` validates ownership, pedestal range, and emptiness; `MuseumService` adds a proximity check. |
| T-08 | Removing/placing another player's relic | Museum actions operate only on the requesting player's own plot and profile. |
| T-09 | Damage multiplication via high-speed or repeated touches | Hazards use authoritative positions and zones, never `Touched`, plus a per-player invulnerability window. Boulders hit each player at most once per roll. |
| T-10 | Line-of-sight abuse around cover | Boulder hits require a server raycast; traps broadcast warnings so the client can react to telegraphs, not hidden state. |
| T-11 | Save corruption from concurrent servers | `UpdateAsync` session/`updatedAt` guard (`Persist.canCommit`, unit tested) aborts stale writes and marks the profile ephemeral to protect the newer record. |
| T-12 | Overwriting a corrupt or future record | Unreadable/future-schema data is never overwritten; the player is kicked (live) or made ephemeral (Studio). The decision is made by the pure `Persist.loadOutcome` (unit tested) so corrupt, future, and transient-failure paths all fail closed. |
| T-13 | Exploiting Studio-only admin commands in production | `AdminService` connects nothing unless `RunService:IsStudio()`. |
| T-14 | Shutdown data loss / hang | `PlayerRemoving` saves immediately; `BindToClose` flushes within a bounded timeout. |
| T-15 | Information leakage of hidden state | The snapshot exposes only what the player is entitled to see; hazard telegraphs are broadcast as events, not embedded in world objects the client could inspect. |
| T-16b | Kiting or exploiting guardian contact damage (repeated hits, high-speed passthrough) | Guardians use server positions + LOS raycasts, never `Touched`, and damage is gated by the shared per-player invulnerability window (`HazardService:DamagePlayer`). The post-windup re-check prevents hits on players who leave range. |
| T-16c | Client spoofing guardian positions/damage | Guardians are server-owned models; the client renders replicated motion only and never decides hits. |
| T-16 | Claiming the 2x payout without paying | The 2x grant runs only from `ProcessReceipt`, keyed to the receipt's `ProductId` and `PlayerId`. The client cannot request a multiplier; `ClaimOfflineIncome` is hard-coded to 1x. |
| T-17 | Double-granting a purchase / claim replay | `ClaimPending` drains `pendingOfflineGold` in one server-side step, so replaying the action or a receipt finds nothing to grant. |
| T-18 | Spoofing VIP status to farm a larger window | VIP is read server-side with `UserOwnsGamePassAsync` and cached; the client cannot set `profile.vip`. |

## Residual risks / open work

- Rate-limit tuning is not yet validated against real play patterns.
- Position checks rely on replicated character positions; extreme latency could
  cause false rejections (fail-closed, which is the safe direction).
- No anti-alt/botting controls yet (out of scope for the slice).
