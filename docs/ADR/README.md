# Architecture Decision Records

Short records of decisions that are expensive to reverse. Format: Context,
Decision, Consequences, Alternatives.

| ADR | Title | Status |
| --- | --- | --- |
| [0001](0001-server-authority-single-remote.md) | Server authority via one request remote | Accepted |
| [0002](0002-pure-domain-modules.md) | Pure, Roblox-free domain modules | Accepted |
| [0003](0003-on-demand-income.md) | On-demand passive income from a timestamp | Superseded by 0006 |
| [0004](0004-rojo-init-script-layout.md) | Rojo init-script directory layout | Accepted |
| [0005](0005-data-driven-config.md) | Content and balance live in GameConfig | Accepted |
| [0006](0006-auto-tick-income.md) | Auto-tick live income, keep offline accrual | Accepted (offline grant superseded by 0007) |
| [0007](0007-monetization.md) | Welcome Back offline claim and VIP Pass | Accepted |
| [0008](0008-guardian-enemies.md) | Guardian enemies (patrol + aggro chase) | Accepted |
| [0009](0009-tutorial-and-ux.md) | Data-driven tutorial and accessibility preferences | Accepted |
| [0010](0010-museum-expansion.md) | Expanding museum wings and building enhancements | Accepted |
| [0011](0011-endgame-temple-and-revive.md) | Endgame Void Citadel, difficulty ramp, and Instant Revive | Accepted |
| [0012](0012-stamina-stats-training.md) | Sprint stamina, one stat resolver, and passive training | Accepted |
| [0013](0013-companions.md) | Relic Companions MVP | Accepted |

Add a new ADR (next number) whenever a change alters architecture, security,
persistence, or a public contract. Never edit an accepted ADR's decision; add a
superseding ADR instead.
