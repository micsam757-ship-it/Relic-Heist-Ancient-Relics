# Vision

## Audience

- **Primary:** Roblox players who enjoy short high-tension risk/reward loops
  (steal, carry, escape) and light tycoon progression (passive income, upgrades).
- **Secondary:** collectors who want to build and show off a museum of finds.
- **Tertiary:** social players who want to see other players' museums and
  leaderboard-style wealth comparisons.

Age and session profile: broad Roblox audience; designed around 3-8 minute
expedition sessions that can be chained in a 15-30 minute play sitting.

## Product goals

1. **A legible risk loop.** At any moment a player knows: what they carry, how
   much time remains, and what they lose if they fail. See `docs/HCI_DESIGN.md`.
2. **Server-authoritative by construction.** The client cannot fabricate rewards,
   ownership, or damage. See `docs/THREAT_MODEL.md`.
3. **Data-driven content.** Temples, relics, upgrades, and economy constants live
   in `GameConfig`; new content is data, not code. See `docs/DATA_MODEL.md`.
4. **A foundation that scales.** Add temples, relics, and systems without an
   architecture rewrite. See `docs/ARCHITECTURE.md`.
5. **Honest engineering.** Implemented, tested, validated, and planned work are
   reported distinctly. See `docs/PROJECT_STATUS.md`.

## Gameplay identity

- **Fantasy:** you are a museum-owner-turned-raider. Risk your body and your loot
  to grow the collection; the collection pays you while you are away.
- **Tension:** the escape timer and environmental hazards, not combat, are the
  antagonist. The catacombs turn the timer up and the lights down.
- **Reward:** extraction converts effort into tangible, titled exhibits that raise
  a visible income number.
- **Loop:** hub -> expedition -> collect under encumbrance -> escape or lose it ->
  exhibit -> earn -> upgrade -> unlock -> repeat.

## Non-goals (for the current slice)

- No player-versus-player stealing of other players' relics.
- No combat/enemies beyond environmental hazards.
- No trading, premium currency, or monetization.
- No procedurally infinite temples; temples are authored config.

## Success signals (post-slice)

- A new player completes the tutorial loop unaided.
- Players return to bank loot after reaching high encumbrance rather than dying
  repeatedly with full bags.
- Income growth visibly motivates the next upgrade purchase.
