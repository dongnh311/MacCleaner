# Mac Cleaner — UI Specification

> **Companion to:** `MAC_CLEANER_SPEC.md`
> **Design direction:** Pro/utility (info-dense, minimal animation)
> **Theme:** Auto-follow system (light + dark)
> **Animation:** Moderate — Lottie for scan, particles for clean completion
> **Target:** macOS 13+ (Apple Silicon)

---

## 1. Design Philosophy

### 1.1 Core principles
- **Information density over whitespace.** Show data, paths, sizes upfront. No "hero sections" that waste a screen of pixels.
- **Native first.** Use system materials (`.regularMaterial`, `.thickMaterial`), system fonts (SF Pro, SF Mono), system controls. Customize sparingly.
- **Predictable layouts.** Every module follows the same skeleton: header → progress/summary → list → action bar.
- **Inspector-driven.** Click any item → details appear in right panel without navigation. Power users hate dialogs.
- **Keyboard first.** Every action has a shortcut. Cmd-A select all, Space preview, Delete = remove from list.

### 1.2 Visual references
- **Stats** (`exelban/stats`) — menu bar density, monochrome charts
- **Bartender 5** — sidebar pattern, settings layout
- **Apple Settings** (Ventura+) — three-column layout, inspector usage
- **Activity Monitor** — table-heavy data presentation
- **DaisyDisk** — Space Lens visualization (one feature where we DO go visual)

---

## 2. Design Tokens

### 2.1 Color system

Use **semantic colors** that auto-adapt to system appearance. Never hardcode hex.

```swift
extension Color {
    // Surfaces
    static let surfacePrimary    = Color(NSColor.windowBackgroundColor)
    static let surfaceSecondary  = Color(NSColor.controlBackgroundColor)
    static let surfaceTertiary   = Color(NSColor.underPageBackgroundColor)

    // Text
    static let textPrimary       = Color(NSColor.labelColor)
    static let textSecondary     = Color(NSColor.secondaryLabelColor)
    static let textTertiary      = Color(NSColor.tertiaryLabelColor)
    static let textQuaternary    = Color(NSColor.quaternaryLabelColor)

    // Separators
    static let separator         = Color(NSColor.separatorColor)
    static let divider           = Color(NSColor.gridColor)

    // Accent (custom — semantic)
    static let accent            = Color.accentColor   // user system accent
    static let success           = Color(NSColor.systemGreen)
    static let warning           = Color(NSColor.systemOrange)
    static let danger            = Color(NSColor.systemRed)
    static let info              = Color(NSColor.systemBlue)

    // Category colors (file types in Space Lens)
    static let categoryDocs      = Color(NSColor.systemBlue)
    static let categoryMedia     = Color(NSColor.systemPurple)
    static let categoryCode      = Color(NSColor.systemTeal)
    static let categoryArchive   = Color(NSColor.systemBrown)
    static let categoryApp       = Color(NSColor.systemIndigo)
    static let categoryOther     = Color(NSColor.systemGray)
}
```

**Light vs dark behavior:** all the above auto-flip. Never write `.colorScheme == .dark ? ... : ...` for primary surfaces. Use it only for special cases (e.g., custom shadows).

### 2.2 Typography

Use SF Pro (default) and SF Mono (monospaced data).

| Token | Font | Size | Weight | Use |
|---|---|---|---|---|
| `.titleLarge` | SF Pro | 22pt | semibold | Module headers |
| `.titleMedium` | SF Pro | 17pt | semibold | Section headers |
| `.titleSmall` | SF Pro | 13pt | semibold | Subsection labels |
| `.bodyLarge` | SF Pro | 15pt | regular | Primary content |
| `.bodyMedium` | SF Pro | 13pt | regular | Standard list rows |
| `.bodySmall` | SF Pro | 11pt | regular | Captions, metadata |
| `.numericLarge` | SF Mono | 22pt | semibold | Big size numbers ("12.4 GB") |
| `.numericMedium` | SF Mono | 13pt | regular | Inline sizes, percentages |
| `.path` | SF Mono | 11pt | regular | File paths (with text-tail truncation) |

```swift
extension Font {
    static let titleLarge    = Font.system(size: 22, weight: .semibold)
    static let titleMedium   = Font.system(size: 17, weight: .semibold)
    static let numericLarge  = Font.system(size: 22, weight: .semibold, design: .monospaced)
    static let path          = Font.system(size: 11, design: .monospaced)
    // ...
}
```

### 2.3 Spacing scale

8pt grid system. Don't use arbitrary values.

```swift
enum Spacing {
    static let xxs: CGFloat = 2
    static let xs:  CGFloat = 4
    static let sm:  CGFloat = 8
    static let md:  CGFloat = 12
    static let lg:  CGFloat = 16
    static let xl:  CGFloat = 24
    static let xxl: CGFloat = 32
}
```

### 2.4 Corner radius

```swift
enum Radius {
    static let sm: CGFloat = 4    // chips, badges
    static let md: CGFloat = 6    // buttons
    static let lg: CGFloat = 8    // cards, list rows
    static let xl: CGFloat = 12   // panels
}
```

### 2.5 Iconography

**Use SF Symbols exclusively.** Free, native, auto-flips for dark mode, supports hierarchical/multicolor variants.

Standard sizes: 14pt (inline), 16pt (sidebar), 24pt (module headers), 48pt (empty states).

Hierarchical rendering for module icons (`renderingMode(.hierarchical)`) — gives subtle depth without custom artwork.

| Module | SF Symbol |
|---|---|
| Smart Care | `sparkles` |
| System Junk | `trash.circle` |
| Mail | `envelope.badge` |
| Photo Junk | `photo.stack` |
| Trash | `trash` |
| Malware | `shield.lefthalf.filled` |
| Privacy | `eye.slash` |
| Permissions | `lock.shield` |
| Maintenance | `wrench.and.screwdriver` |
| Login Items | `power` |
| Process Monitor | `cpu` |
| Memory | `memorychip` |
| Battery | `battery.75percent` |
| Uninstaller | `xmark.bin` |
| Updater | `arrow.triangle.2.circlepath` |
| Space Lens | `chart.pie` |
| Large Files | `doc.text.magnifyingglass` |
| Duplicates | `doc.on.doc` |
| Similar Photos | `photo.on.rectangle.angled` |
| Shredder | `scissors` |

---

## 3. Layout Architecture

### 3.1 Three-column NavigationSplitView

```swift
NavigationSplitView(columnVisibility: $columnVisibility) {
    Sidebar()
        .navigationSplitViewColumnWidth(min: 200, ideal: 220, max: 280)
} content: {
    ModuleContent()
        .navigationSplitViewColumnWidth(min: 480, ideal: 640)
} detail: {
    Inspector()
        .navigationSplitViewColumnWidth(min: 280, ideal: 320, max: 400)
}
.navigationSplitViewStyle(.balanced)
```

### 3.2 Sidebar structure

```
[Logo + name]                       <- 44pt height, fixed
─────────────────────────
SCAN
  ◉ Smart Care                      <- always at top, accented
  □ Dashboard
─────────────────────────
CLEANUP
  □ System Junk          12.4 GB    <- right-aligned size (mono)
  □ Mail Attachments      2.1 GB
  □ Photo Junk             840 MB
  □ Trash Bins             2.0 GB
─────────────────────────
PROTECTION
  □ Malware Removal
  □ Privacy
  □ App Permissions
─────────────────────────
PERFORMANCE
  □ Maintenance
  □ Login Items
  □ Process Monitor       45% CPU   <- live indicator
  □ Memory                8.2/24 GB
  □ Battery                  87%
─────────────────────────
APPLICATIONS
  □ Uninstaller
  □ Updater                  3 ⓘ    <- update count badge
─────────────────────────
FILES
  □ Space Lens
  □ Large & Old
  □ Duplicates
  □ Similar Photos
─────────────────────────
TOOLS
  □ Shredder
  □ My Tools (custom)
─────────────────────────
                                    <- spacer pushes settings to bottom
[Free space: 142 GB / 512 GB] [⚙]   <- footer: disk indicator + settings
```

**Sidebar implementation:**
- Use `List` with `Section` headers (not `OutlineGroup` — cleaner)
- Section headers in SF Pro 11pt, semibold, uppercase, `.textTertiary`
- Selected row: accent color background with `.tint` modifier
- Right-aligned size labels in `.numericMedium` `.textSecondary`
- Live indicators (CPU%, RAM) update via `Timer.publish(every: 2)`

### 3.3 Module content area

Every module follows the same 4-zone skeleton:

```
┌─────────────────────────────────────────────┐
│ [Icon] Module Name              [Last scan] │  <- Header (60pt)
│        Subtitle / status                    │
├─────────────────────────────────────────────┤
│                                             │
│        [Hero zone — varies by module]       │  <- 80–200pt
│        Could be: total size, chart,         │
│        scan button, status card             │
│                                             │
├─────────────────────────────────────────────┤
│ [Filter pills]  [Search]      [Sort ▾]      │  <- Toolbar (36pt)
├─────────────────────────────────────────────┤
│ ☑ Item 1 ────────── path ────── 1.2 GB  ⓘ  │
│ ☑ Item 2 ────────── path ────── 845 MB  ⓘ  │  <- List (flexible)
│ ☐ Item 3 ────────── path ────── 320 MB  ⓘ  │
│ ...                                         │
├─────────────────────────────────────────────┤
│ 12 of 47 selected • 2.4 GB    [Clean ▸]     │  <- Action bar (52pt)
└─────────────────────────────────────────────┘
```

### 3.4 Inspector panel

Collapsible right panel (toggle: `Cmd+Opt+I`). Shows context for selected item:

```
[Preview: QLPreviewView or icon]
─────────────────────────────────
Item name (titleMedium, truncating)
Path (path font, line-limit 3, selectable)
─────────────────────────────────
SIZE        1.24 GB
MODIFIED    Apr 28, 2026
ACCESSED    Apr 28, 2026
TYPE        Cache file
CATEGORY    System Junk
─────────────────────────────────
SAFETY      ● Safe to delete
            macOS will regenerate
            this file as needed.
─────────────────────────────────
[Reveal in Finder]
[Show Why It's Listed]
```

For multi-selection: show aggregated stats (total size, item count, common parent) instead of single-file details.

---

## 4. Component Library

### 4.1 Buttons

```swift
// Primary action — Clean, Scan, Confirm
Button("Clean 2.4 GB") { ... }
    .buttonStyle(PrimaryButtonStyle())   // accent fill, white text, 32pt height

// Secondary — Cancel, Skip, View Details
Button("View Details") { ... }
    .buttonStyle(SecondaryButtonStyle()) // border, accent text

// Tertiary — link-style, in headers/inspector
Button("Reveal in Finder") { ... }
    .buttonStyle(.link)

// Destructive — Force Quit, Permanent Delete
Button("Permanent Delete") { ... }
    .buttonStyle(DestructiveButtonStyle()) // red fill
```

Use `.controlSize(.large)` for action bar, `.regular` for inline, `.small` for inspector.

### 4.2 List row variants

**Standard scan row (most common):**
```
[☑] [icon] Item name                              1.2 GB  [ⓘ]
           ~/Library/Caches/com.example/data
```
- 44pt height
- Hover: subtle background fill (`.surfaceSecondary` at 50% opacity)
- Selected: accent border-left 3pt + tinted background
- Right-click context menu: Reveal, Quick Look, Add to Exclusions, Show Rule

**Compact data row (process monitor, login items):**
```
[icon] Process name    PID    CPU%   MEM      USER          [×]
```
- 28pt height
- Monospaced numbers, right-aligned
- Sortable column headers

**App row (uninstaller):**
```
[app icon 32pt] App Name                                    [⋯]
                Version 4.2.1 • 124 MB • Last opened 14d ago
                [Find Leftovers]    [Reset]    [Uninstall]
```
- 64pt height, more breathing room
- Action buttons inline (only for apps — high-stakes actions deserve visibility)

### 4.3 Cards

Used in Dashboard and module hero zones.

```swift
struct StatCard: View {
    let title: String
    let value: String
    let unit: String
    let trend: Trend?

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.xs) {
            Text(title).font(.bodySmall).foregroundStyle(.secondary)
            HStack(alignment: .firstTextBaseline, spacing: Spacing.xxs) {
                Text(value).font(.numericLarge)
                Text(unit).font(.bodyMedium).foregroundStyle(.secondary)
            }
            if let trend { TrendBadge(trend: trend) }
        }
        .padding(Spacing.md)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.surfaceSecondary)
        .clipShape(RoundedRectangle(cornerRadius: Radius.lg))
    }
}
```

### 4.4 Progress indicators

**Scan progress (linear):**
- Use `ProgressView(value:)` with custom track color
- Show current path being scanned (truncated, monospaced) below bar
- ETA when computable

**Determinate ring (Smart Care hero):**
- Custom `Circle().trim(from:to:)` with stroke
- Lottie ring for animated state (see §6)

**Indeterminate (initial enumeration):**
- System `ProgressView()` with caption "Indexing… (47k items)"

### 4.5 Empty states

Three variants, always center-aligned in module content area:

| State | Icon (48pt) | Title | Action |
|---|---|---|---|
| Never scanned | module SF Symbol | "Run a scan to begin" | "Start Scan" button |
| Nothing found | `checkmark.seal.fill` (success color) | "Nothing to clean" | "Rescan" link |
| Permission missing | `lock.fill` (warning color) | "Full Disk Access required" | "Open System Settings" |

### 4.6 Toolbar pills (filters)

For modules with categorical results (System Junk: User Cache / System Cache / Logs / Xcode):
```
[All 47] [Caches 23] [Logs 12] [Xcode 8] [Other 4]
```
- 24pt height pills
- Selected: filled with accent
- Unselected: bordered
- Count badges in mono font

### 4.7 Inline confirmations (no modals where possible)

Replace destructive modals with inline confirm bars:

```
┌─────────────────────────────────────────────────┐
│ ⚠ Delete 12 items (2.4 GB)?                     │
│   Items go to quarantine for 7 days.            │
│                          [Cancel]  [Delete ▸]   │
└─────────────────────────────────────────────────┘
```
- Slides down from action bar
- Auto-dismiss on Esc
- Modal only for truly irreversible actions (Shredder, Permanent Delete)

---

## 5. Screen-by-Screen Specs

### 5.1 First launch / Onboarding

3-step flow, full-window (no sidebar):

```
Step 1: Welcome
  Big icon + "Welcome to MacCleaner"
  Brief description
  [Get Started]

Step 2: Permissions
  List of permissions with status (granted/needed)
  • Full Disk Access     [Open Settings]
  • Accessibility        [Open Settings]
  • Privileged Helper    [Install]
  [Continue] (enabled when minimum perms granted)

Step 3: First Scan
  "Run Smart Care now?"
  [Skip]  [Start Scan]
```

Skip button always available. Don't gate the app behind perms — degrade gracefully (modules requiring missing perms show banner with "Grant" CTA).

### 5.2 Smart Care (default landing)

```
┌──────────────────────────────────────────────────────┐
│ ✦ Smart Care                                         │
│   Run all five core scans                            │
├──────────────────────────────────────────────────────┤
│                                                      │
│              ╭────────────────╮                      │
│              │                │                      │
│              │    [Lottie     │   12.4 GB to clean   │
│              │     ring or    │   3 threats found    │
│              │     scan icon] │   2 updates available│
│              │                │   ─────────────────  │
│              │                │   Last scan: 2h ago  │
│              ╰────────────────╯                      │
│                                                      │
│                     [Scan]                           │
│                                                      │
├──────────────────────────────────────────────────────┤
│  RESULTS                                             │
│  ┌──────────────────────────────────────────────┐    │
│  │ ✓ System Junk            12.4 GB    [Review] │    │
│  │ ⚠ Malware                  1 item   [Review] │    │
│  │ ✓ Performance              5 issues [Review] │    │
│  │ ✓ Updates                  3 apps   [Review] │    │
│  │ ✓ Trash                  2.0 GB    [Review] │    │
│  └──────────────────────────────────────────────┘    │
│                                                      │
│  [Clean All Safe Items (14.4 GB)]    [Review Each]   │
└──────────────────────────────────────────────────────┘
```

**"Clean All Safe Items"** only includes `.safe` safety level. `.review` and `.dangerous` items always require manual review — this is the trust contract.

### 5.3 Dashboard

Grid of live stat cards (resizable, drag-to-reorder):

```
┌─────────────┬─────────────┬─────────────┐
│  CPU        │  MEMORY     │  DISK       │
│  23%        │  8.2/24 GB  │  142 GB free│
│  [sparkline]│  [sparkline]│  [pie]      │
├─────────────┼─────────────┼─────────────┤
│  BATTERY    │  NETWORK    │  HEALTH     │
│  87%        │  ↓2.4 MB/s  │  ✓ Good     │
│  cycle 142  │  ↑0.1 MB/s  │  3 issues   │
├─────────────┴─────────────┴─────────────┤
│  TOP PROCESSES (live, 5 rows)            │
│  Xcode      28% CPU   2.1 GB             │
│  Chrome     12% CPU   3.4 GB             │
│  ...                                      │
└──────────────────────────────────────────┘
```

Sparklines: 60-second rolling window, monochrome (use `Chart` framework, macOS 13+).

### 5.4 Space Lens (the one "hero" visual)

```
┌──────────────────────────────────────────────┐
│  Volume: Macintosh HD ▾    Path breadcrumbs  │
├──────────────────────────────────────────────┤
│                                              │
│   ┌──────────┬─────┬───────┐                 │
│   │          │     │       │                 │
│   │ Library  │ Apps│ Users │                 │
│   │  84 GB   │ 42GB│ 28 GB │  ← Treemap      │
│   │          ├─────┼───────┤                 │
│   │          │ ... │  ...  │                 │
│   └──────────┴─────┴───────┘                 │
│                                              │
├──────────────────────────────────────────────┤
│  Path: /Library                              │
│  ├─ Caches              42 GB                │
│  ├─ Application Support 28 GB                │
│  └─ ...                                      │
└──────────────────────────────────────────────┘
```

**Implementation:** Custom SwiftUI `Canvas` with squarified treemap algorithm. Click rectangle = drill in. Right-click = show in Finder. Color by category (use `Color.categoryDocs`, `.categoryMedia`, etc.).

Don't use D3/WebView — adds 200MB Electron-equivalent runtime baggage. SwiftUI Canvas is fast enough for ~10k rectangles.

### 5.5 Process Monitor

Pure table layout (most info-dense screen):

```
┌─────────────────────────────────────────────────────────────┐
│ Search [______________]    [All ▾] [Sort: CPU desc ▾]       │
├─────────────────────────────────────────────────────────────┤
│ Process              PID    CPU%   MEM     USER     ENERGY  │
├─────────────────────────────────────────────────────────────┤
│ ⓘ Xcode             1247   28.4%  2.14 GB  dong     High    │
│ ⓘ Chrome Helper     8821   12.1%  3.45 GB  dong     Medium  │
│ ⓘ kernel_task          0    8.0%  1.20 GB  root     —       │
│ ...                                                         │
└─────────────────────────────────────────────────────────────┘
```

- Refresh every 2s
- Right-click row: Quit, Force Quit, Reveal in Finder, Inspect
- Sortable by any column (NSTableView via `NSViewRepresentable` if SwiftUI `Table` proves too limiting)

---

## 6. Animation & Motion

### 6.1 Where to animate (and where NOT)

| Use animation | Don't animate |
|---|---|
| Sidebar collapse/expand | List re-sort (jarring) |
| Inspector slide in/out | Filter pill changes (instant) |
| Scan ring (Lottie) | File row hover (instant) |
| Clean completion (particles) | Numeric counter updates (instant) |
| Progress bar fill | Theme switching (instant) |
| Inline confirm slide-down | Tab switching |

Default: **150ms ease-out** for UI state changes. Anything longer feels sluggish in a utility app.

### 6.2 Lottie integration

**Library:** `lottie-spm` (Airbnb, official Swift Package).

**Two animations needed:**

1. **Scan ring** (`scan_ring.json`)
   - Loop while scanning
   - Subtle rotation + pulse on inner glow
   - Length: 2s, seamless loop
   - Where to source: LottieFiles ("scanning ring" tag, free MIT-licensed packs) or commission for $50

2. **Clean burst** (`clean_burst.json`)
   - One-shot on completion
   - Particles emanating from center, fade out
   - Length: 1.2s
   - Trigger: when cleanup finishes, overlay on action bar briefly

```swift
LottieView(animation: .named("scan_ring"))
    .playing(loopMode: .loop)
    .frame(width: 120, height: 120)
```

### 6.3 Particle effect (no Lottie alternative)

For clean-complete burst, can also use SwiftUI's native `TimelineView` + `Canvas`:

```swift
TimelineView(.animation) { timeline in
    Canvas { context, size in
        // Draw N particles at computed positions based on timeline.date
    }
}
```

Slightly less polished than Lottie but no dependency. Pick one based on time budget.

### 6.4 Spring choreography

For inspector slide:
```swift
.transition(.move(edge: .trailing).combined(with: .opacity))
.animation(.spring(response: 0.35, dampingFraction: 0.85), value: showInspector)
```

For confirm bar:
```swift
.transition(.move(edge: .bottom).combined(with: .opacity))
.animation(.spring(response: 0.3, dampingFraction: 0.9), value: pendingConfirm)
```

---

## 7. Theme Handling

### 7.1 System sync

```swift
@Environment(\.colorScheme) var colorScheme  // auto from system
```

Don't override unless user explicitly chooses light/dark in Settings. Default = follow system.

### 7.2 Settings option

```
Appearance:
  ◉ Match System
  ○ Light
  ○ Dark
```

Implement via `NSApp.appearance = NSAppearance(named: ...)` for app-wide override.

### 7.3 Test matrix

Every screen tested in 4 states:
- Light + default accent (blue)
- Dark + default accent
- Light + custom accent (e.g., purple)
- Dark + custom accent

Use Xcode preview variants:
```swift
#Preview("Light") { ContentView().preferredColorScheme(.light) }
#Preview("Dark")  { ContentView().preferredColorScheme(.dark) }
```

---

## 8. Menu Bar App

Separate `NSStatusItem` lifecycle, runs even when main window closed.

### 8.1 Status item icon

- Template image (auto-tints for menu bar)
- Compact mode: just icon
- Stats mode (optional): icon + tiny CPU% number, monospaced

### 8.2 Dropdown popover

```
┌────────────────────────────┐
│ MacCleaner                 │
├────────────────────────────┤
│ CPU       [▁▂▃▅▇▆▄▂] 23%  │
│ Memory    [▃▃▃▃▄▄▄▄] 8.2GB│
│ Disk      142 GB free      │
│ Battery   87% • 2h 14m     │
├────────────────────────────┤
│ ⚡ Free Memory             │
│ ✦ Run Smart Care           │
│ ⌧ Hide Menu Bar Apps       │
├────────────────────────────┤
│ Open MacCleaner...      ⌘O │
│ Settings...             ⌘, │
│ Quit                    ⌘Q │
└────────────────────────────┘
```

**Implementation:** `NSPopover` with SwiftUI content. 280pt wide. Refresh stats every 1s while open, pause when closed (battery!).

---

## 9. Keyboard Shortcuts

| Shortcut | Action |
|---|---|
| `⌘1`–`⌘9` | Jump to module by sidebar order |
| `⌘N` | New scan (current module) |
| `⌘F` | Focus search |
| `⌘A` | Select all results |
| `⌘D` | Deselect all |
| `Space` | Quick Look selected item |
| `⌘R` | Reveal in Finder |
| `⌘⌫` | Move to quarantine |
| `⌘⇧⌫` | Permanent delete (Shredder confirm) |
| `⌘⌥I` | Toggle inspector |
| `⌘⌥S` | Toggle sidebar |
| `⌘,` | Settings |
| `⌘.` | Cancel running scan |

Document in Help menu.

---

## 10. Accessibility

Even for personal tool, do the basics — they're cheap and improve general UX:

- **VoiceOver:** All buttons have `.accessibilityLabel`. Custom controls (treemap rectangles) have `.accessibilityValue` describing size.
- **Dynamic Type:** Respect via `Font.system` (auto-scales). Test at largest accessibility size.
- **Reduce Motion:** Disable Lottie/particles when `accessibilityReduceMotion` is true. Show static icon instead.
- **Increase Contrast:** Use semantic colors (already covered by system).
- **Keyboard navigation:** Every action reachable without mouse. Tab through controls in logical order.

---

## 11. Settings Window

Separate window (not in main app). Use SwiftUI `Settings` scene (macOS 13+) — gives free toolbar tabs.

Tabs:
1. **General** — Launch at login, theme override, default scan on launch
2. **Scanning** — Cleanup rules toggles, exclusion list (drag folders to exclude)
3. **Quarantine** — Retention days, location, "Empty Quarantine Now"
4. **Schedule** — Daily/weekly/monthly auto-scans (uses `NSBackgroundActivityScheduler`)
5. **Notifications** — Threshold alerts (low disk, malware found)
6. **Advanced** — Privileged helper status, log location, reset all

---

## 12. Implementation Phases (UI-specific)

Aligned with main spec roadmap, but UI-focused:

| Phase | UI deliverable |
|---|---|
| 1 — Foundation | NavigationSplitView shell, Sidebar, design tokens, light/dark switching |
| 2 — Cleanup | Standard module skeleton, list rows, action bar, inspector, inline confirm |
| 3 — Files | Space Lens treemap, Duplicate Finder side-by-side, Similar Photos grid |
| 4 — Applications | App row variant, leftover detection UI |
| 5 — Performance | Process Monitor table, Battery details, sparklines |
| 6 — Protection | Threat list, browser tabs, permissions matrix |
| 7 — Polish | Lottie integration, particles, menu bar app, onboarding, settings |

---

## 13. Reusable SwiftUI snippets

### 13.1 Module shell

```swift
struct ModuleShell<Hero: View, Content: View>: View {
    let title: String
    let subtitle: String?
    let icon: String
    @ViewBuilder var hero: () -> Hero
    @ViewBuilder var content: () -> Content

    var body: some View {
        VStack(spacing: 0) {
            ModuleHeader(title: title, subtitle: subtitle, icon: icon)
            Divider()
            hero()
                .padding(.horizontal, Spacing.lg)
                .padding(.vertical, Spacing.md)
            Divider()
            content()
        }
    }
}
```

### 13.2 Smart action bar

```swift
struct ActionBar: View {
    let selectedCount: Int
    let totalCount: Int
    let selectedSize: Int64
    let primaryAction: () -> Void

    var body: some View {
        HStack {
            Text("\(selectedCount) of \(totalCount) selected • \(selectedSize.formattedBytes)")
                .font(.bodyMedium)
                .foregroundStyle(.secondary)
            Spacer()
            Button("Clean \(selectedSize.formattedBytes)") { primaryAction() }
                .buttonStyle(PrimaryButtonStyle())
                .disabled(selectedCount == 0)
                .keyboardShortcut(.return)
        }
        .padding(.horizontal, Spacing.lg)
        .padding(.vertical, Spacing.md)
        .background(.regularMaterial)
        .overlay(Divider(), alignment: .top)
    }
}
```

---

## 14. Don't-do list

- ❌ Custom titlebars or window chrome — use system
- ❌ Splash screens — direct to main window
- ❌ Modal dialogs for routine actions — use inline bars
- ❌ Custom checkboxes/radios — system controls match the OS
- ❌ Animated GIFs — Lottie or none
- ❌ Localized fonts — SF Pro everywhere (English-only personal tool)
- ❌ Skeuomorphic icons — flat SF Symbols
- ❌ Branded "loading…" screens — show real progress or nothing
- ❌ Tooltips with marketing copy — just show useful info on hover

---

**End of UI spec.**
