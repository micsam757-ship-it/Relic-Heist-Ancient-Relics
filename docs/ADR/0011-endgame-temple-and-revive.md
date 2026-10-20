# ADR 0011: Endgame temple, difficulty ramp, and Instant Revive

- Status: Accepted
- Date: 2026-10-20

## Context

The economy and progression curves currently top out at **Sunken Sanctum**
(`order` 3, difficulty 3), whose best relic (Sunken Idol, 15,000 gold) is the
largest single payout. The design brief asks for a third and final temple that
raises the ceiling, a global difficulty ramp so the endgame feels earned, and a
monetization hook ("Instant Revive") tied to getting caught in hard temples.

Monetization is normally out of scope without explicit direction (blueprint line
1004). The product owner explicitly requested the Instant Revive Developer
Product, so it is in scope, alongside the existing Welcome Back / VIP products
(ADR 0007).

## Decision

### Endgame temple: Void Citadel

- A fourth temple, **Void Citadel**, is added to `GameConfig.Temples` with
  `order = 4`, `difficulty = 5`, `minExtractions = 4`, `unlockPrice = 5000`, and a
  480-second timer. Because the world, hub portals, and progression are all
  data-driven over `GameConfig.Temples`, the temple builds, unlocks, and appears
  on a hub portal with no new system code.
- It is themed `void` (a new palette in `TempleBuilder.THEMES`: dark stone, slate
  walls, marble pillars, violet accent/light).
- Its relic pool is four **Abyssal** relics — all Legendary or Mythic, each tied
  only to `VoidCitadel` — including `EyeOfTheVoid` (Mythic, 40,000 gold, 700/min).
  This makes a successful Citadel run the largest single payout in the game.

### Difficulty ramp

- Global `GameConfig.Enemies` tuning is sharpened: a longer `AggroLingerSeconds`
  (5s), a new `HuntSeconds` window so guardians pursue a last-known position
  through broken line of sight, a tighter `ContactCooldownSeconds` (0.85s), a
  faster `Chase.SpeedMultiplier` (1.35), and a shorter `TickSeconds` (0.08s).
- The base `Guardian` kind gets a wider `aggroRange` (54) and shorter windup
  (0.4s). Every temple's guardians thus become more aggressive without per-temple
  edits.
- A new **`VoidWarden`** enemy kind (health 1500, speed 17, damage 32, aggro 64,
  windup 0.35) backs the Citadel's guardians, plus one faster `Rift Keeper`
  override. `TempleBuilder` already resolves every field from config with kind
  fallback, so no builder change is needed.

### Guardian chase through broken line of sight

- `GuardianService` now tracks a `lastKnownPosition` whenever a target is seen.
  When the target is lost but the hunt window is open, the guardian keeps its
  aggro visual and moves to that position at chase speed; it only returns to
  patrol once the window lapses or the position is reached. This is the concrete
  "chase stays active when players break stealth" behaviour.

### Instant Revive (Developer Product)

- `GameConfig.Monetization` gains `InstantReviveProductId` (0 = unconfigured),
  `InstantRevivePriceRobux` (99), `InstantReviveWindowSeconds` (12), and
  `ReviveTempleIds` (`SunkenSanctum`, `VoidCitadel`).
- On death inside a hard temple, `ExpeditionService` asks
  `MonetizationService:CanOfferRevive`. If eligible, it holds the death in a
  `pendingRevive` state (carried relics intact) and pushes a `ReviveOffer` event;
  a server-side `task.delay` resolves the death if the window lapses.
- The client shows a modal with a **Revive Now** button (sends
  `PurchaseInstantRevive`) and a **Let me perish** button (sends
  `DeclineInstantRevive`). The client never grants anything.
- The revive is granted **only** from `ProcessReceipt`: `grantRevive` calls
  `ExpeditionService:RevivePlayer`, which restores health, returns the character
  to the temple spawn, and keeps the expedition alive. A late receipt with no
  pending offer is not granted.
- An unconfigured product id suppresses the offer entirely, so the game remains
  fully playable — matching the ADR 0007 rule.

## Consequences

- The SRS gains FR-026 (Void Citadel), FR-027 (aggressive chase), and FR-028
  (Instant Revive). `docs/GAME_BALANCE.md`, `DATA_MODEL.md`, and the traceability
  matrix are updated.
- The revive flow adds two network actions (`PurchaseInstantRevive`,
  `DeclineInstantRevive`) to `Contracts`; the contract-drift test now documents
  12 actions.
- Death is no longer guaranteed to be terminal in hard temples: the player's
  choices (buy, decline, or time out) decide, and a purchase funds a second
  chance at the current haul.
- Because revives are only offered when the product is configured and the temple
  is listed, difficulty tuning and monetization stay decoupled: the ramp applies
  regardless of whether the product exists.

## Alternatives considered

- **A global revive product.** Rejected: the brief ties it to hard temples, and
  gating it keeps the tutorial and early game free of prompts.
- **Client-driven revive.** Rejected: monetization grants must be
  server-authoritative through `ProcessReceipt` (ADR 0001).
- **A separate "Health Crystals" hazard mechanic.** Rejected as scope creep; the
  Instant Revive reuses the existing death pipeline with a single defer point.
