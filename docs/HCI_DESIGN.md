# HCI and Visual Design

## Goals

- Communicate the steal/carry/escape loop without a wall of text.
- Keep the moment-to-moment HUD minimal; put the vertical slice's depth in panels.
- Make risk legible: players should always know weight, remaining time, and carry.
- Remain usable by mouse, touch, and keyboard.

## Layout

- **Top bar**: gold (auto-updating), income rate, and six nav buttons
  (`Expeditions`, `Shop`, `Companions`, `Inventory`, `Museum`, `Settings`).
- **Expedition HUD** (left, only during an expedition): temple name, escape
  countdown (or `COLLAPSE`), weight bar with `weight / capacity` and speed
  percent, carried count, stamina bar (hold `Shift`/`L3` to sprint), abandon button.
- **Toast stack** (top center): transient success/warning/error/info notices.
- **Modal host**: one panel open at a time.
- **Summary overlay**: post-expedition results (success, death, abandon).
- **Pedestal prompt**: relic picker or "remove display" for an activated pedestal.
- **Tutorial objective HUD**: when a tutorial step is active, its `title` and
  `hint` show as a persistent objective with `completed / total` progress, and
  the intro card describes the loop on first entry.

## Tutorial

- The tutorial is an ordered, data-driven sequence (`GameConfig.Tutorial.Steps`).
  Each step teaches one action; it advances only when the player performs it, in
  order (see `docs/ADR/0009-tutorial-and-ux.md`).
- It is a guide, not a gate: players can ignore it, and an empty list disables it.
- Completing the final step fires a brief celebration; per-step advances play the
  `TutorialAdvance` cue when audio is configured.

## Visual language

- Warm sandstone/gold palette with cyan accents for "magic/tech".
- Rarity is always encoded twice: a colored badge glyph (`C/R/L/M`) plus text,
  so it is not color-only.
- Buttons disable to a dimmed state; destructive actions use the danger red.
- A destructive reset (Museum Prestige) requires a typed `PRESTIGE` confirmation;
  the confirm button stays disabled until the word matches, and the resets are
  listed in plain language before it can be pressed.
- `Theme.luau` holds all colors, fonts, radii, spacing, and rarity colors. It
  keeps a base palette and a colorblind-safe palette, selected by the player's
  `colorblindMode` setting.
- Text size follows the player's `textScale` (`Normal`/`Large`/`Huge`) via
  multipliers from `GameConfig.Settings`.

## Accessibility

- Settings persist per profile and are server-validated: sound, visual effects,
  reduced motion, colorblind palette, and text size.
- Reduced motion disables HUD bob and full-screen damage flashes; disabling
  visual effects suppresses transient effects entirely.
- Rarity and state are never encoded by color alone (glyph + text), so the
  colorblind-safe palette is a comfort improvement, not a correctness fix.

## Input

- Keyboard: `E` Expeditions, `B` Shop, `C` Companions, `I` Inventory, `M` Museum,
  `O` Settings, hold `Shift` to sprint inside an expedition, `Esc` close.
- Pointer/touch: all of the above are also on-screen buttons, sized for touch on
  touch devices. No feature is keyboard-only.
- Gamepad: `ButtonY` Expeditions, `ButtonX` Shop, `ButtonB` Museum, `ButtonA`
  Inventory; click `L3` to sprint inside an expedition; Roblox's native
  Selectable focus navigation moves between buttons; `ButtonB`/`Escape` close
  the active panel via `ContextActionService`.

## Responsive layout

- A viewport-anchored `UIScale` keeps the HUD legible from phone to desktop,
  clamped so it never shrinks below a readable floor.
- The top bar is the navigation spine on small screens, so panels are always
  reachable without a keyboard.

## Feedback

- Collecting, extracting, purchasing, and dying all produce a toast; extraction
  and death also produce a summary overlay.
- Damage flashes the screen (unless reduced motion or visual effects are off);
  hazard warnings toast with the trap name; guardian windups warn before they hit.
- The weight bar recolors as it fills (cyan -> warning -> danger).
- Museum income is automatic; the top-bar gold eases upward in real time rather
  than stepping, so accumulating wealth reads continuously. Offline earnings
  appear through the Welcome Back modal on join.
- Audio cues are data-driven and silent until asset ids are authored.

## Copy tone

- Short, action-first sentences. Requirements are phrased as "Needs N
  extraction(s)" rather than as opaque locks.

## Open HCI work

- Playtest onboarding clarity and readability at typical 1080p and on mobile
  aspect ratios with representative users (see `docs/TEST_STRATEGY.md`).
- Author real audio asset ids (currently silent-but-playable).
- Consider a radial or minimap aid for locating the altar (currently a labelled
  ProximityPrompt and portals carry the navigation load).
