# ADR 0009: Data-driven tutorial and accessibility preferences

- Status: Accepted
- Date: 2026-10-20

## Context

M5 ("UX and cross-platform polish") requires a tutorial, responsive HUD, mobile
controls, gamepad support, audio/visual feedback, and an accessibility review.
The blueprint (see the M5 deliverable) expects onboarding that teaches the
steal/carry/escape loop, plus input parity across mouse, touch, keyboard, and
gamepad.

Two design questions had to be settled before implementation:

1. **How is the tutorial modelled?** A hard-coded sequence of UI prompts would
   drift from gameplay and be hard to rebalance. The project already keeps all
   content and tuning in `GameConfig` (ADR 0005).
2. **Where do accessibility preferences live?** Reduced motion, a colorblind-safe
   palette, and text size must persist across sessions, validate on the server,
   and apply on the client without special cases scattered through the UI.

## Decision

### Tutorial: an ordered, config-driven step sequencer

- `GameConfig.Tutorial.Steps` is an ordered list of steps. Each step has an
  `id`, `title`, `text`, an optional `hint`, and a `complete` action string.
- A pure module `src/shared/Domain/Tutorial.luau` owns the rules:
  `advance(completed, steps, action)` returns the new completed count, and only
  advances when the action matches the *next* step, so out-of-order actions are
  ignored. `view(completed, steps)` returns the current step plus progress.
- `TutorialService` records the highest step reached on the profile
  (`tutorialStep`, added in schema v3) and pushes a `TutorialStep` event on each
  advance, and a `TutorialComplete` event when the last step finishes. The client
  renders the current objective and celebrates completion.
- Teachable actions are reported by the services that own them: `ExpeditionService`
  (`enteredTemple`), `RelicService` (`collectedRelic`), `ExtractionService`
  (`extracted`), and `MuseumService` (`exhibited`). Adding a step is a config
  edit plus, at most, one new call site.
- **The tutorial never gates play.** It is a guide, not a lock: a player who
  ignores it simply stops advancing. An empty `Steps` list disables it entirely.

### Accessibility: validated settings, one client applier

- `PlayerSettings` gains `reducedMotion`, `colorblindMode`, and
  `textScale` (`"Normal" | "Large" | "Huge"`), alongside the existing
  `soundEnabled` and `visualEffects`.
- `SettingsService` validates every field server-side; `textScale` is checked
  against `GameConfig.Settings.TextScaleOptions`, and unknown values are
  rejected rather than stored.
- The client has one applier, `src/client/Preferences.luau`, which forwards the
  snapshot to `Theme.applyPreferences` and exposes read helpers. Effects, audio,
  and UI read the helpers instead of the raw snapshot.
- `Theme` keeps a base palette and a colorblind-safe palette, and a base text
  size with multipliers from config. Redundant encoding (badge glyph + text) is
  preserved so rarity is never color-only.
- Audio is data-driven from `GameConfig.Audio`. Asset ids default to `0`
  ("not configured"), so the game is silent but fully playable until sounds are
  authored; a pooled `SoundController` honors the sound setting and never blocks
  gameplay.

### Cross-platform input

- Keyboard keeps letter shortcuts; touch uses the always-visible top-bar nav
  (device-aware sizing); gamepad gets face-button panel shortcuts plus Roblox's
  native Selectable focus navigation. `Escape` and gamepad `ButtonB` close the
  active panel via `ContextActionService` so the shortcut fires even while a GUI
  has focus.
- A `UIScale` anchored to the viewport keeps the HUD legible from phone to
  desktop, clamped so it never shrinks below a readable floor.

## Consequences

- Adding onboarding content or accessibility toggles is a config change, not a
  code change, matching ADR 0005 and ADR 0002 (pure, testable domain logic).
- Schema v3 adds `tutorialStep` and the new settings; `migrations[2]` fills only
  missing keys and preserves player values. `normalize` clamps the step and
  coerces the new booleans / text scale.
- The client now has a single place (`Preferences`) that reacts to settings
  changes, so a text-size change rebuilds the active panel exactly once.
- Because `prefers-reduced-motion` style behavior is app-level, motion and
  full-screen flashes are opt-out, not opt-in; defaults stay lively but safe.
- Audio remains silent until real asset ids are authored; this is intentional so
  the blockout is playable and the tests are deterministic.

## Alternatives considered

- **Hard-coded tutorial prompts in the client.** Rejected: drifts from gameplay,
  untestable, and not rebalanceable via config.
- **A blocking tutorial that gates progression.** Rejected: contradicts the
  blueprint's "guide, not gate" onboarding and frustrates returning players.
- **Storing accessibility purely client-side.** Rejected: settings must persist
  across sessions and devices and be validated server-side (THREAT_MODEL T-06).
- **Separate remotes per setting.** Rejected: the single `UpdateSettings` action
  already fits the one-remote contract (ADR 0001).
