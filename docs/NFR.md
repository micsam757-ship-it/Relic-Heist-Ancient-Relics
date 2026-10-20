# Non-Functional Requirements

- **NFR-001 Server authority.** No client message can grant gold, relics,
  ownership, pedestal placement, unlocks, or damage. The client only renders.
- **NFR-002 Input validation.** Every action validates types, ids, and ranges
  before use; unexpected shapes are rejected without erroring the handler.
- **NFR-003 Abuse resistance.** Global and per-action token-bucket rate limits
  bound request frequency. Repeated or malformed requests are dropped.
- **NFR-004 No blind persistence writes.** A failed load never creates-and-saves
  over existing data; a session conflict disables further writes to protect the
  newer record.
- **NFR-005 Bounded shutdown.** `BindToClose` attempts a flush within a fixed
  deadline so shutdown cannot hang indefinitely.
- **NFR-006 Data safety in Studio.** When API access is unavailable, profiles run
  ephemerally and the player is told progress will not be saved.
- **NFR-007 Testability.** Game rules live in pure modules runnable without
  Roblox, so they can be unit-tested and type-checked in CI.
- **NFR-008 Readability.** Consistent module layout (`Init`/`Start`, `ctx`
  injection), Stylua-enforced formatting, and Selene-clean statically.
- **NFR-009 Determinism of rules.** Reward, price, and damage math is pure and
  side-effect free, so identical inputs yield identical outputs.
- **NFR-010 Performance budget.** No per-frame server work over all players; the
  server loops are the 1s income tick, the 0.5s expedition timer, and the save
  tick, with per-frame cosmetic tweening on the client only. VIP entitlement is
  cached on join and never checked per-tick.
- **NFR-011 Accessibility.** All interactions are reachable by pointer/touch;
  no action is keyboard-only. Text has contrast, and labels are textual.
- **NFR-012 Configurability.** Balance values live in one config module with no
  logic, so tuning does not require code changes elsewhere.
