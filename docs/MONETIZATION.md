# Monetization Policy

This document satisfies the blueprint's requirement that monetization be
documented before implementation (see `docs/ADR/0007-monetization.md`).

## Scope

The only monetized element is the **Welcome Back** offline-earnings flow:

| Offer | Type | Price | Effect |
| --- | --- | --- | --- |
| Claim 1x | Free | 0 | Grants the pending offline payout. |
| Claim 2x | Developer Product | 199 Robux | Grants **2x** the pending offline payout, once. |
| VIP Pass | Game Pass | (set in Dashboard) | Offline window 4h → 24h and a higher pending ceiling. |

There are **no loot boxes, no random paid rewards, and no paid currency**. The
premium currency is Robux, handled entirely by Roblox.

## Fairness principles

1. **The free option always exists.** The 1x claim grants the full legitimate
   offline earnings. Paying is never required to progress.
2. **No permanent power gap.** The 2x product doubles a single payout, not the
   income rate, so a paying player is not permanently ahead.
3. **VIP is convenience, not advantage.** VIP only extends how long offline
   income accrues; it does not raise the income rate or grant exclusive relics.
4. **Server-authoritative.** All grants are decided server-side from validated
   `ProcessReceipt` callbacks or validated free-claim requests.

## Roblox policy compliance

- **Developer Products** use `MarketplaceService:ProcessReceipt`, returning
  `PurchaseGranted` only after the grant succeeds, and `NotProcessedYet` when the
  player is gone or the grant fails (so Roblox retries). See
  `src/server/Services/MonetizationService.luau`.
- **Game Passes** are read with `UserOwnsGamePassAsync`, cached on join.
- **Transparent pricing.** The modal shows the exact Robux price and multiplier;
  no dark patterns, no countdown pressure, no forced store opens.
- **No real-money references** appear in-game beyond Roblox's own purchase UI.

## Configuration and rollout

`GameConfig.Monetization` holds the IDs and price:

```lua
GameConfig.Monetization = {
    OfflineDoubleProductId = 0,      -- set from the Creator Dashboard
    OfflineDoublePriceRobux = 199,   -- display only; the Dashboard is authoritative
    OfflineDoubleMultiplier = 2,
    VipPassId = 0,                   -- set from the Creator Dashboard
    VipName = "VIP Pass",
}
```

While an ID is `0` (unset):

- the 2x button is hidden and `PurchaseOfflineDouble` refuses;
- VIP checks resolve to `false` (standard 4h window);
- the free 1x claim is unaffected.

**Before release:** create the Developer Product (199 Robux) and the VIP Game
Pass in the Creator Dashboard, paste their IDs into `GameConfig.Monetization`,
and playtest a real purchase and refund.

## Analytics

Emissions for review (aggregate counters only): `offline_pending`,
`offline_modal_shown`, `offline_claim`, `product_purchased`. No personal data.

## Open items

- Real Product/Pass IDs must be supplied by the owner; they cannot be created
  from this repository.
- Refund/chargeback handling relies on Roblox's standard receipt retry behavior;
  the grant is idempotent per receipt because it drains the pending balance.
- Region-specific pricing and any future offers require a fresh policy review.
