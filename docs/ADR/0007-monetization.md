# ADR 0007: Welcome Back offline claim and VIP Pass

- Status: Accepted
- Date: 2026-10-20
- Supersedes: the on-join auto-grant portion of ADR 0006

## Context

ADR 0006 held offline income on `lastIncomeClaimAt` and granted it automatically
on join. The product owner now wants a "Welcome Back" modal that shows the
offline earnings and offers two ways to collect them:

- **Claim 1x (Free)** — the standard payout.
- **Claim 2x** — double *this* payout, purchased with a 199-Robux Developer
  Product.

They also want the offline window to be 4 hours by default, expandable to 24
hours with a VIP Pass (a Roblox Game Pass).

This is the project's first monetization. The blueprint (`Relic Heist
blueprit.md`, line ~1004) says not to implement monetization automatically and,
when it is proposed later, to use transparent pricing, comply with Roblox
policies, protect gameplay fairness, and document random-reward mechanics before
implementation. The owner has explicitly confirmed they want it in scope; this
ADR and `docs/MONETIZATION.md` are the required documentation.

## Decision

- **Offline gold is held, not auto-granted.** On join, `EconomyService` computes
  the offline payout (bounded by the offline window and ceiling), stores it in
  `profile.pendingOfflineGold`, and advances `lastIncomeClaimAt`. Live income
  still auto-deposits on the 1-second tick (ADR 0006) — only the *offline* lump
  is held for the modal.
- **The free path is always available.** `ClaimOfflineIncome` releases the
  pending balance at 1x. Nothing about the free experience is gated.
- **The 2x path doubles one payout.** `PurchaseOfflineDouble` prompts the
  Developer Product. `ProcessReceipt` validates the purchase and releases the
  pending balance at 2x. If a receipt arrives with no pending balance, a token is
  remembered so the next claim is doubled. This is a one-time payout double — not
  a permanent multiplier — so it does not create a persistent power gap.
- **VIP Pass extends the window and ceiling.** A Game Pass (`VipPassId`) is
  checked once on join via `UserOwnsGamePassAsync` (cached, never per-tick) and
  mirrored onto `profile.vip`. VIP holders get a 24h window and a higher
  `MaxPendingIncome` (see `GameConfig.Economy`).
- **Unconfigured IDs disable the offer safely.** Product/Pass IDs default to `0`.
  While unset, the store prompt is suppressed and the purchase action refuses, so
  the game is fully playable before the products exist in the Creator Dashboard.
  The free claim works regardless.
- **All amounts are server-decided.** The client sends only intents
  (`ClaimOfflineIncome`, `PurchaseOfflineDouble`); the server owns validation,
  the pending balance, and the grant.

## Consequences

- `Schema` bumps to v2 with `pendingOfflineGold` and `vip`; a forward migration
  seeds both for existing profiles.
- A new `MonetizationService` owns `ProcessReceipt`, VIP caching, and the claim
  actions. It starts before `Economy` so VIP status is known when the offline cap
  is computed.
- New remote events `WelcomeBack` / `WelcomeBackClosed`; new snapshot fields
  `pendingOfflineGold`, `vip`, and `offlineDouble`.
- Monetization is now in scope and must be reflected in the SRS, threat model,
  data model, and API contracts.

## Alternatives considered

- **Grant offline income as before and make 2x a button that grants extra.** Rejected:
  the extra would be granted without a second, receipt-backed purchase check.
- **Permanent account-wide 2x income.** Rejected: creates an ongoing power gap and
  makes the VIP value proposition overlap; the owner chose a one-time double.
- **Per-tick VIP checks.** Rejected: `UserOwnsGamePassAsync` is a network call;
  caching on join is required.
- **Block all monetization until IDs exist.** Rejected: a config-gated stubbed
  offer lets the flow ship and be reviewed now, with real IDs dropped in later.
