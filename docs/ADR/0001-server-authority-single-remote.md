# ADR 0001: Server authority via one request remote

- Status: Accepted
- Date: 2026-10-19

## Context

Roblox clients are fully untrusted. The game grants gold, relic ownership, and
damage outcomes, all of which are attractive to exploit. Multiple dedicated
remotes for each verb would multiply the validation surface and invite ad-hoc,
inconsistent checks.

## Decision

All client-to-server actions travel through a single `Request` `RemoteEvent` as
`{ action: string, data: table? }`. A central `NetworkService` validates the
payload shape, enforces global and per-action rate limits, looks up a registered
handler, and runs it in `pcall`. Handlers recompute every outcome from server
state and config; the client never supplies an authoritative amount or id list.

Server-to-client uses two streams: `State` (full profile snapshots) and `Event`
(named, transient notifications such as toasts and summaries).

## Consequences

- One place to audit validation and rate limiting.
- Adding an action is a `RegisterAction` call plus a handler; no new remote.
- `State` snapshots must stay small; large collections are sent as part of the
  snapshot the player is entitled to see.
- Per-action limits must be tuned deliberately (see `docs/THREAT_MODEL.md`).

## Alternatives considered

- One remote per action: more remotes, more drift, no shared validation.
- Passing delta patches over the wire: premature complexity for this scale.
