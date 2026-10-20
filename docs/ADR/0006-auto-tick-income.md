# ADR 0006: Auto-tick live income, keep offline accrual

- Status: Accepted (the offline auto-grant on join is superseded by ADR 0007)
- Date: 2026-10-20

## Context

ADR 0003 modeled all museum income as pending value derived from
`lastIncomeClaimAt`, collected through an explicit `ClaimIncome` action. That
keeps saves event-driven, but it makes the HUD show a static number that only
moves when the player clicks Claim. Playtest feedback asked for income to
deposit automatically and for the top-bar gold to climb in real time.

## Decision

- **Live income auto-deposits.** `EconomyService` runs a one-second server tick
  that computes each online player's per-second rate and adds the whole gold to
  `gold`. A fractional carry per player preserves exactness for rates below
  1/sec, so no income is lost to rounding.
- **Offline income is retained.** `lastIncomeClaimAt` stays in the profile.
  While online the tick advances it each second; on join the offline balance
  accrued since the stored timestamp is granted once (with a toast). This keeps
  ADR 0003's biggest win (correct income across sessions/servers) while removing
  the claim step.
- **No claim action.** The `ClaimIncome` remote, the top-bar claim button, and
  the `C` shortcut are removed.
- **The client interpolates, the server authoritates.** The snapshot exposes
  `gold` and `incomePerSecond`; the client eases its displayed gold toward the
  extrapolated value between snapshots. Downward corrections from purchases snap
  rather than tween, so the client never shows gold it does not have.

## Consequences

- Income now drives frequent profile writes. The existing debounced saver (4s
  debounce, 3s tick) absorbs this; the tick itself does not write per second.
- The offline window cap and `MaxPendingIncome` ceiling still bound away income.
- The display is cosmetic; all gold amounts are decided server-side, so a client
  cannot fabricate balance by interpolating faster.

## Alternatives considered

- **Keep the claim button (hybrid).** Rejected: two income UX paths for one
  number is confusing; the user asked to remove the claim requirement.
- **Drop offline income entirely.** Rejected: it is a balance regression and
  throws away ADR 0003's cross-session correctness.
- **Per-second DataStore writes.** Rejected: expensive and race-prone; the tick
  marks dirty and the debouncer coalesces writes.
