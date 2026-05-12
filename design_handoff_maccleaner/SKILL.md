# MacCleaner Design System — Skill

You are working with the **MacCleaner** design system. Read `README.md`
in this project root first — it is the canonical brand + content +
visual reference and supersedes anything below.

## Quick orientation

- **Product**: MacCleaner — a native macOS cleaner + system monitor.
  Dense, utility-class, dark-first SwiftUI app. Built by one developer
  for one machine. Modelled after CleanMyMac but rebuilt natively.
- **Source of truth**: the codebase under `MacCleaner/` (mounted) +
  `MacCleaner/docs/UI_SPEC.md`. Everything else here is extracted from
  there.
- **Tokens**: `colors_and_type.css` is the only stylesheet — import it,
  don't duplicate values.

## Reach for these files

| Need | File |
|---|---|
| Brand voice, content rules, casing | `README.md` → CONTENT FUNDAMENTALS |
| Hex values, type scale, spacing/radius | `colors_and_type.css` + `README.md` → VISUAL FOUNDATIONS |
| Per-section accent colours | `README.md` → "Per-section accents" table |
| Module list (31 modules, 7 sections) | `README.md` → ICONOGRAPHY → Module table |
| Card examples (badges, buttons, etc.) | `preview/*.html` |
| Live recreation to lift patterns from | `ui_kits/maccleaner/` |
| Screenshots of the real app | `assets/screenshots/` |

## When generating new MacCleaner UI

1. **Use the unified shell.** Three-column NavigationSplitView
   (sidebar 220px / content / inspector 320px). Every column shares
   the same NSVisualEffectView material — no opaque bars.
2. **Pick the section accent up front.** Scan = violet `#6B52F5`,
   Cleanup = orange `#FF9F0A`, Protection = red `#FF453A`,
   Performance = teal `#64D2FF`, Applications = indigo `#5E5CE6`,
   Files = purple `#BF5AF2`, Tools = pink `#FF375F`. The whole
   module's accent flows from this one choice.
3. **Module skeleton, every time**: ModuleHeader (60pt) → Divider →
   Hero zone (chart/total/scan) → Toolbar (filters + sort) → List →
   Action bar (selection + primary CTA). Don't invent new chrome.
4. **SF Symbols, SF Pro, SF Mono** in spec. On the web, substitute
   Lucide / Inter / JetBrains Mono and *flag the substitution
   inline*.
5. **Tabular numerals** on every live-updating number. SF Mono for
   sizes, percents, paths, sparkline values, menu-bar strip.
6. **Copy is competent-neighbour**: specific over vague, active and
   declarative, no marketing hype, caveats stated openly. See
   README → CONTENT FUNDAMENTALS for the rewrite table.
7. **No emoji.** Glyphs come from SF Symbols. Allowed unicode: `→
   ↑ ↓ °C ✦`.
8. **Threshold tints** (`<60` green, `<85` orange, `≥85` red) drive
   any percentage. Battery flips polarity. Temperature uses 60/80°C.
9. **Cards are flat** with a hairline 0.5px stroke at 6% white and a
   barely-there shadow. The Smart Care pillar tiles are the only
   gradient-filled hero surface — don't add more.
10. **Animation budget**: 150ms ease-out for state changes; spring
    0.30/0.85 for inspector slides. No list re-sort animation, no
    filter pill bounce, no theme fade.

## Voice cheatsheet

> "Caches and logs regenerate as apps run." (✓)
> "Free up gigabytes instantly!" (✗ — hype, no mechanic)

> "Items go to quarantine for 7 days." (✓)
> "Don't worry — it's safe." (✗ — second-person reassurance)

> "Refreshes every second via host_statistics64." (✓)
> "Lightning-fast live updates." (✗ — adjective instead of mechanic)

## Localisation

English primary, Tiếng Việt as second language. Strings live in
`Resources/Localizable.xcstrings`. Sentence-case everywhere; uppercase
eyebrow labels stay uppercase across languages.

## What this system deliberately does NOT include

- No marketing illustrations, mascots, photography.
- No icon font or SVG sprite — SF Symbols on Apple, Lucide on web.
- No light-mode hero — dark is the brand surface; light is supported
  via NSColor adaptation but never marketed.
- No tagline. The app icon is the wordmark.
- No social / app store metadata templates. This is a personal tool.
