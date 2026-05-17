# MacCleaner Design System

> Brand + UI foundations for **MacCleaner** — a personal macOS cleaner +
> system monitor written in SwiftUI + Swift 6. Single-user tool by
> developer **Đông (dongnh311)**, modelled after MacPaw's CleanMyMac
> family of utilities but rebuilt as a native, ad-hoc-signed app for
> one machine.

## Source materials

This system was extracted from a single attached codebase. There is no
Figma file or marketing site; the app is the product.

| Source | Where | Notes |
|---|---|---|
| Codebase | `MacCleaner/` (mounted) | SwiftUI app, Swift 6, macOS 13+ |
| GitHub | `dongnh311/MacCleaner` | Same codebase mirror |
| Specs | `MacCleaner/docs/SPEC.md`, `UI_SPEC.md` | Original product + UI specs |
| Design tokens | `MacCleaner/Core/UI/DesignTokens.swift` | Spacing, radius, fonts, threshold tints |
| Module chrome | `MacCleaner/Core/UI/ModuleHeader.swift`, `UnifiedBackground.swift` | Three-column shell |
| Sidebar map | `MacCleaner/App/SidebarItem.swift` | 31 modules, 7 sections, per-section accents |
| Screenshots | `MacCleaner/docs/screenshots/` (copied to `assets/screenshots/`) | Live captures of each module |
| App icon source | `MacCleaner/Tools/generate_icon.swift` | Programmatically-drawn sparkle glyph |
| Accent colour | `MacCleaner/Resources/Assets.xcassets/AccentColor.colorset/Contents.json` | sRGB `(0.42, 0.32, 0.96)` = `#6B52F5` |

---

## The product in one paragraph

MacCleaner is a **utility-class macOS app**, not a marketing-driven
SaaS. The UI is dense, native, and unapologetically Mac-flavoured:
three-column NavigationSplitView, system materials, SF Symbols for
every glyph, SF Pro + SF Mono throughout. It surfaces **31 modules**
across seven sidebar sections — **Scan, Cleanup, Protection,
Performance, Applications, Files, Tools** — and a separate menu-bar
agent with live CPU / RAM / GPU / network / sensor strip. The visual
identity is a violet→cyan-blue sparkle, with each sidebar section
carrying its own NSColor system tint.

---

## CONTENT FUNDAMENTALS

### Voice — *competent neighbour, not marketing*

Copy throughout the app is written like a developer talking to
themselves at the terminal. Honest about limitations, specific about
mechanics, never breathless.

| In | Out |
|---|---|
| "Run Smart Care to scan your Mac" | "Optimize your machine with one click!" |
| "Caches and logs regenerate as apps run." | "Free up gigabytes of space instantly." |
| "Honest about SSD limitations (TRIM-managed flash makes overwrites less meaningful)." | "Military-grade secure delete." |
| "Click Scan to list installed apps" | "Get started in seconds." |

### Tone rules

1. **Specific over vague.** Numbers, paths, units. "12.4 GB" not "lots
   of space". "~/Library/Caches/com.apple.dt.Xcode" not "Xcode files".
2. **Active, declarative.** "Removes unneeded junk." "Quarantines
   selected threats." No "Let's…" / "Don't worry…" / "You're all set!"
3. **No second-person hype.** "you" appears, but as in "*you* hate
   dialogs", not "*you'll* love this feature".
4. **Reassure with mechanics, not adjectives.** Instead of "safe" we
   say "Items go to quarantine for 7 days." Instead of "fast" we say
   "refreshes every second."
5. **Caveats are explicit.** "Mostly unnecessary on SSD." "Limited on
   modern macOS, mostly informational." This is part of the brand.

### Casing

- **Sentence case for everything** — buttons, headings, menu items.
  ("Quick Clean", "Run Smart Care", "Reveal in Finder".)
- **UPPERCASE eyebrow labels** for column / section headers in dense
  views (`CLEANUP`, `PROTECTION`, `TOP PROCESSES`, `DETAILS`,
  `LEFTOVERS`). Tracked +0.5/+0.06em, 11pt semibold, tertiary text.
- **Product / proper nouns kept exactly** — *Mac, MacCleaner, Smart
  Care, Quick Clean, Space Lens, Xcode, Homebrew*.

### Emoji + iconography in copy

**No emoji.** The brand uses **SF Symbols** for every glyph (see
`ICONOGRAPHY` below). The closest you'll see is the sparkle symbol
`✦` in the menu-bar strip (rendered as a glyph, not a UI element).

### Sample copy lifted from the app

- "Alright, here's what I've found." (Smart Care headline when items found)
- "Your Mac is in great shape." (Smart Care headline when clean)
- "Some items need your attention." (when threats present)
- "Cleanup removes junk, Protection neutralises threats, Speed quits heavy apps. Review each, then hit Run."
- "Caches, logs and trash — safe to delete, will regenerate"
- "Live RAM breakdown via host_statistics64"
- "Live SMC readings — temperatures, fans, power, voltage"
- "Live IOKit power source data"
- "Quarantine retention 7 days"
- "Persistence inspector available"

Note the recurring pattern: **what it does + how it does it**, in one
breath. The implementation detail *is* the marketing.

### Localization

- English (primary) + Tiếng Việt. Strings live in
  `Resources/Localizable.xcstrings`. Vietnamese translations are
  sentence-case, no honorifics; uppercase eyebrow labels stay
  uppercase ("CLEANUP" → "DỌN").

---

## VISUAL FOUNDATIONS

### Theme

- **Dark is primary.** Every screenshot the developer captured is in
  dark mode. Light is supported through NSColor semantic adaptation
  but the brand identity lives in dark.
- **Theme picker:** Match System (default) / Light / Dark.
  Implementation via `NSApp.appearance` override.
- **No hardcoded hex in Swift.** All surfaces flow through
  `Color(NSColor.*)`. The HTML system in `colors_and_type.css`
  approximates that palette for non-native use.

### Colour

| Role | Token | Value |
|---|---|---|
| Brand accent | `--brand-accent` | `#6B52F5` (sRGB 0.42, 0.32, 0.96) |
| Brand gradient | `--brand-gradient` | `#6B52F5 → #199EF5` (violet→cyan-blue) |
| Window bg (dark) | `--surface-window` | `#1E2230` over `NSVisualEffectView` |
| Card | `--surface-card` | `#2A2F3E` |
| Per-section tint | `--section-*` | orange / red / teal / indigo / purple / pink |

**Per-section accents** are the heartbeat of the sidebar — every
module's hierarchical SF Symbol carries its section colour, and the
window backdrop tints subtly toward that colour when you switch
sections (`unifiedBackdrop` in `RootView.swift`).

| Section | Accent | NSColor |
|---|---|---|
| Scan | `#6B52F5` | `.accentColor` |
| Cleanup | `#FF9F0A` | `.systemOrange` |
| Protection | `#FF453A` | `.systemRed` |
| Performance | `#64D2FF` | `.systemTeal` |
| Applications | `#5E5CE6` | `.systemIndigo` |
| Files | `#BF5AF2` | `.systemPurple` |
| Tools | `#FF375F` | `.systemPink` |

**Threshold tints** auto-color percent values: green <60, orange <85,
red ≥85. Battery flips the polarity (low % = bad). Temperatures use
60/80°C breakpoints.

### Type

- **SF Pro** for everything UI. **SF Mono** for sizes, percentages,
  paths, top-process tables, sparkline numbers, menu-bar strip.
- **Tabular numerals** (`font-variant-numeric: tabular-nums`)
  everywhere a number changes live so the layout doesn't jitter.
- **Type scale** (UI_SPEC §2.2): 22 / 17 / 13 / 11pt for titles, 15
  body, 11 caption / path. No arbitrary sizes.

### Spacing & radius

- **8pt grid.** Tokens `xxs 2 / xs 4 / sm 8 / md 12 / lg 16 / xl 24 /
  xxl 32`. Don't invent values.
- **Radii** sm 4 (chips/badges), md 6 (buttons), lg 10 (cards/rows),
  xl 14 (panels), pill = 999. The chunky-but-not-rounded look ties to
  macOS Ventura window chrome.

### Backgrounds

- **One canvas, not opaque bars.** `UnifiedBackground` wraps
  `NSVisualEffectView` (`underWindowBackground` material,
  `behindWindow` blending) in every column so the three-pane shell
  reads as a single material. A `LinearGradient` of the current
  section accent (18% → 4% opacity) is layered on top.
- **Module hero backdrops** use the same gradient at lower opacity
  behind a 28×28 SF Symbol, clipped to `Radius.lg`.
- No full-bleed photos, no hand-drawn illustrations, no repeating
  patterns. The visual interest comes from **live data** — sparklines,
  treemaps, sensor sparks — not decoration.

### Animation

- **Default 150ms ease-out** for state changes (UI_SPEC §6.1).
- Spring `response: 0.30–0.35, dampingFraction: 0.85–0.90` for
  inspector / confirm-bar slides.
- **Lottie** is approved for two specific spots only: scan-ring loop
  and clean-burst one-shot. Everything else is system-native.
- **No** list re-sort animation, **no** filter pill bounce, **no**
  theme-switch fade. Routine state updates are instant.

### Hover / press / selection

| State | Treatment |
|---|---|
| Row hover | Background → `surface-card-hover` (~3% white overlay) |
| Selected row | 3pt accent left-border + tinted background |
| Button hover | Slight darken (≈8% black overlay on accent) |
| Button press | Shrink (`scale(0.98)`) + darker tint |
| Focus | Native focus ring (NSColor.keyboardFocusIndicatorColor) |

### Borders + shadows

- **Hairline borders** at `rgba(255,255,255,0.06–0.10)` are the
  default card edge. A 0.5px stroke at 6% white is enough — heavier
  borders feel un-Mac.
- **Card shadow** is barely-there: `0 1px 4px rgba(0,0,0,0.05)`.
  Performance monitors (e.g. Memory, Battery panels) opt out via
  `cardStyle(withShadow: false)` because they sit in dense grids.
- **Popovers** get a real shadow + 1px inset highlight at the top.

### Transparency + blur

- **`NSVisualEffectView` everywhere** for window chrome. Never solid
  fills on the root.
- **No backdrop-filter shenanigans** inside cards — the blur lives at
  the window root; cards are flat.
- **Bars** (footer, menu-bar popover frame) use `.bar` material —
  semi-transparent with system blur.

### Cards

```
┌───────────────────────────┐
│ surface-card (#2A2F3E)    │
│ + 0.5px stroke 6% white   │
│ + shadow 0 1 4 rgba 0.05  │
│ + radius 10               │
└───────────────────────────┘
```

The Smart Care **pillar tiles** are the one exception — vibrant
diagonal gradients (Cleanup violet→blue, Protection green, Speed
orange→red), centred white SF Symbol, no border. They are the
brand's hero visual.

### Layout

- **Fixed three-column shell.** Sidebar 200–280pt, content
  480–640pt, inspector 280–400pt (collapsible via `⌘⌥0`).
- **Module skeleton** (every feature view):
  1. `ModuleHeader` (60pt) — icon backdrop + title + subtitle + trailing slot
  2. `Divider`
  3. Hero zone (80–200pt) — chart / total / scan button
  4. Toolbar (36pt) — filter pills + search + sort
  5. List (flex)
  6. Action bar (52pt) — selection count + primary CTA
- **Information density beats whitespace.** Show paths, sizes,
  timestamps upfront. No "hero sections" wasting a screen.

---

## ICONOGRAPHY

### System: **SF Symbols, full stop.**

Every glyph in the app comes from Apple's SF Symbol catalog. They're
free, native, auto-flip for dark mode, support hierarchical /
multicolor rendering, and ship with macOS — no asset pipeline.

**Standard sizes:** 14pt inline · 16pt sidebar · 22pt module header ·
24pt menu-bar tiles · 48–56pt empty states.

**Default rendering:** `.symbolRenderingMode(.hierarchical)` with a
section accent tint. Multicolour reserved for the AppIcon and Smart
Care pillar tiles.

### Module → symbol map (from `SidebarItem.swift`)

| Module | SF Symbol |
|---|---|
| Smart Care | `sparkles` |
| Dashboard | `square.grid.2x2` |
| Quick Clean | `bolt.circle` |
| System Junk | `trash.circle` |
| Mail Attachments | `envelope.badge` |
| Photo Junk | `photo.stack` |
| Trash Bins | `trash` |
| Malware Removal | `shield.lefthalf.filled` |
| Privacy | `eye.slash` |
| App Permissions | `lock.shield` |
| Maintenance | `wrench.and.screwdriver` |
| Login Items | `power` |
| Process Monitor | `cpu` |
| Usage Trends | `chart.line.uptrend.xyaxis` |
| Memory | `memorychip` |
| Battery | `battery.75percent` |
| Sensors | `thermometer.medium` |
| Network | `wifi` |
| Bluetooth | `dot.radiowaves.left.and.right` |
| Disk Monitor | `internaldrive` |
| Uninstaller | `xmark.bin` |
| Updater | `arrow.triangle.2.circlepath` |
| Space Lens | `chart.pie` |
| Large & Old | `doc.text.magnifyingglass` |
| Duplicates | `doc.on.doc` |
| Similar Photos | `photo.on.rectangle.angled` |
| Shredder | `scissors` |
| Quarantine | `archivebox` |
| My Tools | `star` |
| Clock | `clock` |
| Paint | `paintbrush.pointed` |

### On the web

SF Symbols are **not free to redistribute** outside Apple platforms.
For HTML mockups and the UI kit in this design system we substitute
**Lucide icons** via CDN — closest stroke weight / fill style match
to SF Symbols Regular weight. **Flagged substitution**: an HTML
mockup using `lucide-sparkles` is visually close but not pixel-equal
to `sparkles` in SwiftUI. For production, always use the real SF
Symbol API.

```html
<script src="https://unpkg.com/lucide@latest/dist/umd/lucide.min.js"></script>
```

### Other assets

- **AppIcon** — a four-pointed sparkle, filled with the brand violet
  →blue gradient, two smaller accent sparkles. Drawn programmatically
  by `Tools/generate_icon.swift`. PNG renders @ 16/32/128/256/512 +2x.
  Copies in `assets/AppIcon-{32,128,256,512}.png`. **No tile/back-
  drop** — transparent canvas, glyph reads on its own like Trash.
- **No marketing illustrations, no stock photos, no mascots.** The
  product imagery *is* the running app — see `assets/screenshots/`.
- **No custom icon font, no SVG sprite.** Nothing to load.
- **Emoji**: not used anywhere in UI strings.
- **Unicode glyphs in copy:** `→` (link arrows), `↑ ↓` (network
  direction), `°C / °F`, the inline `✦` in the menu-bar strip.
  Avoid `✓ ✕ ⚠` — use SF Symbols instead.

---

## Index — what's in this folder

| Path | What |
|---|---|
| `README.md` | This file — brand context, content + visual foundations |
| `SKILL.md` | Agent Skill entrypoint — short instructions for invocation |
| `colors_and_type.css` | CSS vars: brand, surfaces, semantic, type scale |
| `assets/` | App icon renders, accent colour spec, screenshots |
| `assets/screenshots/` | 12 dark-mode captures lifted from `docs/screenshots/` |
| `preview/` | Design System cards rendered as small HTML files |
| `ui_kits/maccleaner/` | High-fidelity HTML/JSX recreation of the macOS app |

### Caveats / substitutions you should know about

1. **SF Pro + SF Mono** are not redistributable. On non-Apple OSes
   the HTML falls back to **Inter** + **JetBrains Mono** from Google
   Fonts. The metrics differ slightly; production should ship the
   real system fonts.
2. **SF Symbols** are substituted with **Lucide** (CDN-linked) in the
   UI kit. Visually close, not identical. Flagged at every use site.
3. There is **no marketing site, no slide deck, no Figma file**. This
   system is reverse-engineered from the codebase + UI_SPEC.md + 12
   screenshots.
4. The window chrome (red/yellow/green traffic lights, NSVisualEffectView
   blur) is approximated in HTML; the real app uses the system
   compositor.
