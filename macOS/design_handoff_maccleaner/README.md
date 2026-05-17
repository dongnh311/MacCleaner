# Handoff: MacCleaner Design System

## Overview

This bundle packages the **MacCleaner design system** for Claude Code
to use while extending the SwiftUI app at `dongnh311/MacCleaner`.

The system was reverse-engineered from the existing codebase
(`MacCleaner/`) + `docs/UI_SPEC.md` + 12 in-app screenshots. It is
canonical: when adding new modules, refactoring chrome, or restyling
existing surfaces, treat the files in this bundle as the source of
truth.

## About the design files

The HTML files in `ui_kits/maccleaner/` are **design references** — a
clickable React/HTML recreation of the macOS app, not production code
to copy. The task in the real codebase is to keep SwiftUI views
faithful to these references using the project's existing patterns
(NavigationSplitView, NSVisualEffectView, SF Symbols, NSColor semantic
tokens, DesignTokens.swift). Do **not** introduce a web rendering
layer.

## Fidelity

**High-fidelity.** Colors, typography, spacing, component anatomy, and
copy in this bundle are final. Lift exact values from
`colors_and_type.css` and `README.md` → VISUAL FOUNDATIONS. The four
recreated modules (Smart Care, System Junk, Memory, Sensors) are
pixel-real and should match the SwiftUI rendering one-to-one.

## Working agreement for Claude Code

1. **Read first**: `README.md`, then `SKILL.md`, then the relevant
   `preview/*.html` card, then the corresponding SwiftUI source under
   `MacCleaner/Features/`.
2. **Don't invent tokens.** All colors flow through
   `Core/UI/DesignTokens.swift` + `NSColor` semantic names. All
   spacing is the 8pt grid. All radii are sm/md/lg/xl.
3. **Module skeleton, every time**: `ModuleHeader` → `Divider` → hero
   zone → toolbar (filters/sort) → list → action bar. Don't deviate.
4. **Per-section accent flows from `SidebarItem.section.accent`.** When
   you add a module, register it in `App/SidebarItem.swift` first; the
   accent + window backdrop tint follow automatically.
5. **SF Symbols only.** No custom glyphs, no SVG sprites, no emoji.
   Use `.symbolRenderingMode(.hierarchical)` with the section tint.
6. **Tabular numerals** on every live number (sizes, percents,
   sparkline values, top-process tables, menu-bar strip).
7. **Copy voice = competent neighbour.** Specific over vague, caveats
   stated openly, no marketing hype. See `README.md` → CONTENT
   FUNDAMENTALS for the rewrite table.
8. **Animation budget**: 150ms ease-out for state changes, spring
   0.30/0.85 for inspector slides. No list re-sort or filter-pill
   animation.

## Screens / views recreated in detail

| Module | Reference | SwiftUI target |
|---|---|---|
| Smart Care | `ui_kits/maccleaner/SmartCare.jsx` | `Features/SmartCare/SmartCareView.swift` |
| System Junk | `ui_kits/maccleaner/SystemJunk.jsx` | `Features/Cleanup/CleanupModuleView.swift` (instance "systemJunk") |
| Memory | `ui_kits/maccleaner/Memory.jsx` | `Features/Performance/MemoryView.swift` |
| Sensors | `ui_kits/maccleaner/Sensors.jsx` | `Features/Performance/SensorsView.swift` |

The other 27 modules render as `ModulePlaceholder` in the web kit —
follow the four reference modules' layout grammar when implementing or
revisiting them in SwiftUI.

## Design tokens

See `colors_and_type.css`. Highlights:

| Token | Value | Notes |
|---|---|---|
| `--brand-accent` | `#6B52F5` | sRGB (0.42, 0.32, 0.96) — matches `AccentColor.colorset` |
| `--brand-gradient` | `#6B52F5 → #199EF5` | Smart Care Cleanup pillar, AppIcon |
| Cleanup accent | `#FF9F0A` | `NSColor.systemOrange` |
| Protection accent | `#FF453A` | `NSColor.systemRed` |
| Performance accent | `#64D2FF` | `NSColor.systemTeal` |
| Applications accent | `#5E5CE6` | `NSColor.systemIndigo` |
| Files accent | `#BF5AF2` | `NSColor.systemPurple` |
| Tools accent | `#FF375F` | `NSColor.systemPink` |
| Threshold tints | green<60, orange<85, red≥85 | Battery flips polarity |
| Radii | 4 / 6 / 10 / 14 | sm / md / lg / xl |
| Spacing | 2 / 4 / 8 / 12 / 16 / 24 / 32 | 8pt grid |
| Type scale | 22 / 17 / 13 / 11 (SF Pro); SF Mono for numerics | tabular-nums |

## Assets

- `assets/AppIcon-*.png` — programmatically drawn via
  `Tools/generate_icon.swift`. Don't redraw; regenerate from that
  script.
- `assets/screenshots/` — 12 dark-mode captures of the live app.
- `assets/accent-color.json` — the `AccentColor.colorset` spec.

## Files included in this bundle

| Path | Purpose |
|---|---|
| `README.md` | Full brand, content, visual spec |
| `SKILL.md` | Short agent entrypoint (read this first if context-budgeted) |
| `colors_and_type.css` | All design tokens as CSS vars |
| `preview/*.html` | 26 design-system reference cards |
| `ui_kits/maccleaner/*` | Clickable React/HTML recreation |
| `assets/*` | Icon renders, color spec, screenshots |

## What's deliberately NOT in this bundle

- No marketing illustrations, mascots, stock photos.
- No light-mode hero (dark is the brand surface; light is supported
  via NSColor adaptation but not designed for hero).
- No web component library or build tooling — the HTML kit is a
  reference, not a dependency.
- No tagline / App Store metadata / social templates. This is a
  single-developer tool.

## How to invoke from Claude Code

```
Use the MacCleaner Design System bundle at design_handoff_maccleaner/.
Read SKILL.md first, then README.md, then implement <feature> in
SwiftUI following the module skeleton.
```
