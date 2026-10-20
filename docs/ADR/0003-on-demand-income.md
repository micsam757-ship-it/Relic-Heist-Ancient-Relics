# ADR 0003: On-demand passive income from a timestamp

- Status: Superseded by [ADR 0006](0006-auto-tick-income.md)
- Date: 2026-10-19

## Context

Museum income accrues while the player is in the session and (up to a cap) while
they are away. A naive design writes to the DataStore on every income tick, which
is expensive and exposes the profile to save races.

## Decision

The profile stores `lastIncomeClaimAt` and the set of exhibits. Income is a pure
function of the exhibits and the elapsed time since the last claim, clamped to an
8-hour offline window and a `MaxPendingIncome` ceiling. The server computes pending
income on demand; nothing is written until a claim or another meaningful action
marks the profile dirty.

## Consequences

- No per-tick DataStore writes; saves are event-driven and debounced.
- Offline income is automatically correct across sessions and servers.
- The elapsed-time calculation must be resilient to a wrong client/server clock;
  it uses server time only.
- The claim action is idempotent against double-fire because it resets the
  timestamp in the same authoritative step.

## Alternatives considered

- Timer writes to the store: expensive, race-prone.
- Client-side accrual: trivially exploitable.
