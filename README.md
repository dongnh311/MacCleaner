# MacCleaner

A personal macOS cleaner — system junk, malware persistence inspector,
uninstaller with leftover detection, performance dashboard with realtime
metrics, and a Quick Clean shortcut. Built with SwiftUI + Swift 6 strict
concurrency, targeting macOS 13+.

Not for distribution. Single-user, ad-hoc signed.

## Requirements

- macOS 13 (Ventura) or newer
- Xcode 15+ — `xcodebuild` is the build driver
- [XcodeGen](https://github.com/yonaskolb/XcodeGen) — generates the
  `.xcodeproj` from `project.yml`

## Setup on a fresh machine

```bash
# 1. install Xcode from the App Store, then accept the license
sudo xcodebuild -license accept

# 2. install xcodegen via Homebrew
brew install xcodegen

# 3. clone
git clone https://github.com/dongnh311/MacCleaner.git
cd MacCleaner

# 4. generate the Xcode project
xcodegen generate

# 5. open in Xcode and run, OR build from CLI
open MacCleaner.xcodeproj
# — or —
xcodebuild -scheme MacCleaner -destination 'platform=macOS' build
```

The first build resolves the GRDB Swift Package automatically.

### Permissions

Several modules need Full Disk Access to enumerate caches under
`~/Library/Caches`, scan Mail attachments, read TCC entries, etc. The
app prompts on first launch via the onboarding wizard; if you skip it,
add `MacCleaner.app` to **System Settings → Privacy & Security → Full
Disk Access** manually.

Accessibility access is optional, used only by the Process Monitor
window-level inspection.

## Running

After building from Xcode, just hit Run. The app installs a menu bar
extra (`✦`) showing live CPU / RAM / network in/out, plus the main
window with the sidebar. Closing the main window keeps the menu bar
extra alive — quit via the menu bar's power icon or `⌘Q`.

### Headless smoke test

There's a built-in smoke test that exercises every scanner / service
without touching the UI:

```bash
MACCLEANER_SMOKE_TEST=1 \
  /path/to/build/Debug/MacCleaner.app/Contents/MacOS/MacCleaner
```

Each line is `[smoke] PASS|FAIL <Module> <duration> — <summary>`. A
clean run ends with `[smoke] OK — all checks passed`.

## Project structure

```
App/                      SwiftUI scenes — RootView, SidebarView, MenuBarExtra
Core/                     Reusable services
  Cleanup/                CleanableItem, RuleEngine, QuarantineService, WhitelistGuard
  Database/               GRDB-backed scan_history + exclusion tables
  DI/                     AppContainer (DI root)
  FileSystem/             Bytes formatting, size calculator
  Performance/            Memory, Battery, ProcessMonitor, NetworkSpeed, LoginItems
  Protection/             MalwareScanner, PrivacyCleaner
  UI/                     Design tokens, ModuleHeader, EmptyStateView, badges
Features/                 Per-module SwiftUI views
  Cleanup/                System Junk, Quick Clean, Mail, Photo Junk, Trash
  Applications/           Uninstaller, Updater (Homebrew + Sparkle)
  Performance/            Login Items, Maintenance, Process Monitor, Memory, Battery
  Protection/             Malware, Privacy, App Permissions
  Files/                  Space Lens, Large & Old, Duplicates, Similar Photos
  MenuBar/                MenuBarStatusModel, MenuBarStatusLabel, popover
  SmartCare/              Orchestrator + 3-pillar scan view
  Quarantine/             Sessions list + restore manager
  Dashboard/              Realtime hero + sparklines
  Shredder/, MyTools/     misc tools
Resources/
  CleanupRules/           system_junk.json — declarative rule packs
  MalwareSignatures/      future-use signature DB
  Assets.xcassets/        AppIcon, AccentColor
Tools/
  generate_icon.swift     one-shot script that regenerates the AppIcon PNGs
docs/
  SPEC.md, UI_SPEC.md     original design specs
```

## Quarantine

Anything moved by a cleaner / uninstaller / login-items delete lands in
`~/.MacCleanerQuarantine/<timestamp>/` with a `manifest.json` recording
the original path. Sessions are auto-purged after 7 days. The
**Tools → Quarantine** view lists every session and restores items in
one click. Direct delete is reserved for cache items that the OS
regenerates anyway (Quick Clean).

## Regenerating the app icon

The icon is rendered procedurally — no Photoshop file. To tweak:

```bash
# edit Tools/generate_icon.swift (gradient, glyph, etc.)
swift Tools/generate_icon.swift
xcodegen generate
xcodebuild -scheme MacCleaner build
```

After changing icon bytes, macOS Dock / Finder may keep cached
thumbnails. Force a refresh:

```bash
/System/Library/Frameworks/CoreServices.framework/Versions/Current/Frameworks/LaunchServices.framework/Versions/Current/Support/lsregister \
  -kill -r -domain local -domain system -domain user
killall Dock Finder
```

## Smoke test coverage

`MACCLEANER_SMOKE_TEST=1` runs 21 checks: RuleEngine,
PermissionsService, FileSizeCalculator, SystemJunkScanner,
TrashBinScanner, HierarchicalScanner, LargeFilesScanner, AppScanner,
LeftoverDetector, HomebrewUpdater, ProcessMonitor, LoginItemsService,
MemoryService, BatteryService, MalwareScanner, PrivacyCleaner,
MailAttachmentsScanner, PhotoJunkScanner, PermissionsReader,
SystemMetrics, SmartCareOrchestrator. Run before every push.
