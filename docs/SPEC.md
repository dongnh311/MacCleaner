# Mac Cleaner — Personal Tool Specification

> **Project type:** Internal tool, single-user (developer's personal Mac)
> **Distribution:** Local build only — NO App Store, NO sandbox restrictions
> **Owner:** Đông (Senior Mobile Dev, Android background → learning Swift)
> **Reference:** CleanMyMac 5 (MacPaw) — feature parity goal
> **Spec version:** 1.0
> **Date:** 2026-05-03

---

## 1. Executive Summary

A native macOS application replicating the full feature set of CleanMyMac 5, built for personal use without commercial constraints. Because this is an internal tool, the app can leverage:

- **Full Disk Access** without going through MAS sandbox approval
- **Locally-signed binary** (Developer ID or self-signed for personal machine)
- **Direct shell command execution** (`sudo`, `launchctl`, `pmset`, `purge`)
- **Aggressive system inspection** (system logs, kernel extensions, daemons)

This frees the implementation from ~70% of the constraints CleanMyMac itself faces.

---

## 2. Architecture Overview

### 2.1 Tech Stack

| Layer | Choice | Rationale |
|---|---|---|
| Language | **Swift 6** | Native, modern, required for system APIs |
| UI Framework | **SwiftUI + AppKit interop** | SwiftUI for views, AppKit for menu bar / advanced windows |
| Architecture | **Clean Architecture + MVVM** | Familiar to Đông (matches Walkin/BLoC mental model) |
| DI | **Factory** or manual DI | Lightweight, no overkill |
| Persistence | **SQLite (GRDB.swift)** + UserDefaults | Scan history, app metadata cache |
| Concurrency | **Swift Concurrency (async/await + Actors)** | All scanning is I/O bound |
| Background work | **NSBackgroundActivityScheduler** | For scheduled scans |
| Privileged ops | **SMAppService + Helper Tool (XPC)** | Anything requiring root |

### 2.2 Module Structure

```
MacCleaner/
├── App/                          # App entry, AppDelegate, root window
├── Core/
│   ├── DI/                       # Dependency container
│   ├── FileSystem/               # FileManager wrappers, size calculation
│   ├── Permissions/              # FDA, Accessibility, Automation checks
│   ├── PrivilegedHelper/         # XPC client for root operations
│   └── Logging/                  # Unified logging
├── Features/
│   ├── SmartCare/                # Smart Scan orchestrator
│   ├── Cleanup/
│   │   ├── SystemJunk/
│   │   ├── MailAttachments/
│   │   ├── PhotoJunk/
│   │   ├── iTunesJunk/
│   │   └── TrashBins/
│   ├── Protection/
│   │   ├── MalwareScanner/
│   │   ├── PrivacyCleaner/
│   │   └── AppPermissions/
│   ├── Performance/
│   │   ├── Maintenance/
│   │   ├── LoginItems/
│   │   ├── ProcessMonitor/
│   │   ├── MemoryRelease/
│   │   └── BatteryMonitor/
│   ├── Applications/
│   │   ├── Uninstaller/
│   │   └── Updater/
│   ├── Files/
│   │   ├── SpaceLens/
│   │   ├── LargeOldFiles/
│   │   ├── DuplicateFinder/
│   │   └── SimilarPhotos/
│   ├── Shredder/
│   ├── MenuBar/                  # Status item app
│   └── Dashboard/                # Health overview
├── Resources/
│   ├── CleanupRules/             # JSON definitions for what to scan
│   └── MalwareSignatures/        # Local YARA rules / hash DB
└── PrivilegedHelper/             # Separate target — runs as root
```

---

## 3. Feature Specification

### 3.1 Smart Care (Smart Scan)

**Purpose:** One-click orchestrator running 5 sub-scans in parallel.

**Sub-tasks:**
1. System junk scan
2. Malware quick scan
3. Performance check (login items, heavy processes)
4. Software update check
5. Trash bins detection

**Implementation notes:**
- Use `TaskGroup` for parallel execution
- Each sub-scanner conforms to `Scanner` protocol returning `ScanResult`
- Aggregate results into single review screen
- User confirms before any deletion

**Protocol:**
```swift
protocol Scanner {
    var id: ScannerID { get }
    func scan(progress: AsyncStream<Progress>.Continuation) async throws -> ScanResult
    func clean(items: [CleanableItem]) async throws -> CleanResult
}
```

### 3.2 Cleanup Module

#### 3.2.1 System Junk
**Targets:**
- `~/Library/Caches/*` (user caches)
- `/Library/Caches/*` (system caches — needs admin)
- `~/Library/Logs/*`
- `/private/var/log/*` (admin)
- Xcode derived data: `~/Library/Developer/Xcode/DerivedData/*`
- iOS Simulator caches: `~/Library/Developer/CoreSimulator/Caches/*`
- Old iOS device support: `~/Library/Developer/Xcode/iOS DeviceSupport/*`
- Homebrew cache: `~/Library/Caches/Homebrew/*`
- npm/yarn/pnpm caches
- Gradle/Maven caches (relevant for Đông's Android work)
- Docker dangling images (offer command, don't auto-run)
- Broken downloads (`.crdownload`, `.part`)

**Rules engine:**
- JSON-defined rules in `Resources/CleanupRules/system_junk.json`
- Each rule: `{ id, name, paths[], requiresAdmin, dangerLevel, description }`
- User can disable specific rules

#### 3.2.2 Mail Attachments
- Mail.app stores downloaded attachments in `~/Library/Mail/V*/MailData/`
- Safe to delete — Mail re-downloads on demand
- Show size per account

#### 3.2.3 Photo Junk
- iPhoto/Photos library cache: `~/Pictures/Photos Library.photoslibrary/resources/cache/`
- Faces cache, thumbnails

#### 3.2.4 Trash Bins
- Main trash: `~/.Trash`
- Per-volume trashes: `/Volumes/*/.Trashes/`
- iCloud trash detection

**All cleanup targets:** Must support **dry-run mode** (compute size without deleting).

### 3.3 Protection Module

#### 3.3.1 Malware Scanner
**Approach (realistic for personal tool):**
- Use **YARA** rules (open-source, available via Homebrew)
- Pull rules from public repos: `Yara-Rules/rules`, `Neo23x0/signature-base`
- Hash-based check against:
  - Public macOS malware hash DBs (Objective-See's KnockKnock data, malware-bazaar)
  - Quarantine extended attributes (`com.apple.quarantine`)
- Scan locations:
  - `/Applications`, `~/Applications`
  - `~/Library/LaunchAgents`, `/Library/LaunchAgents`, `/Library/LaunchDaemons`
  - Browser extensions
  - Login items / persistence locations
- **Don't try to build a real AV engine** — that's months of work. Use existing rule sets.

**Library:** `libyara` via Swift Package wrapper (or shell out to `yara` CLI).

#### 3.3.2 Privacy Cleaner
**Per-browser cleanup:**
- **Safari:** History, cookies, cache, downloads list, autofill (`~/Library/Safari/`, `~/Library/Containers/com.apple.Safari/`)
- **Chrome:** `~/Library/Application Support/Google/Chrome/*/History`, cookies
- **Firefox:** SQLite databases under `~/Library/Application Support/Firefox/Profiles/`
- **Brave, Edge, Arc:** Same Chromium pattern

**Other privacy items:**
- Recent items (per-app `.sfl2` files in `~/Library/Application Support/com.apple.sharedfilelist/`)
- WiFi networks list (preserved networks) — needs admin
- Chat app caches (Slack, Discord, Telegram)

**Implementation:** Browser must be closed before cleanup (lock conflict on SQLite). Detect with `NSWorkspace.runningApplications`.

#### 3.3.3 App Permissions
- Read TCC database (`~/Library/Application Support/com.apple.TCC/TCC.db` and `/Library/Application Support/com.apple.TCC/TCC.db`)
- Display which apps have: Camera, Mic, Full Disk Access, Accessibility, Screen Recording, Location
- **Note:** TCC.db is SIP-protected — read-only access. Modifying requires disabling SIP. For personal tool, just **display** permissions and link to System Settings.

### 3.4 Performance Module

#### 3.4.1 Maintenance Scripts
**Tasks (most need admin via helper):**
- Run macOS daily/weekly/monthly periodic scripts: `sudo periodic daily weekly monthly`
- Repair disk permissions (limited on modern macOS, mostly informational)
- Verify startup disk: `diskutil verifyVolume /`
- Reindex Spotlight: `sudo mdutil -E /`
- Flush DNS cache: `sudo dscacheutil -flushcache; sudo killall -HUP mDNSResponder`
- Rebuild Launch Services database: `lsregister -kill -r -domain local -domain system -domain user`
- Free up purgeable space: `tmutil thinlocalsnapshots / 9999999999 4`

#### 3.4.2 Login Items / Launch Agents
- List items from:
  - `~/Library/LaunchAgents/`
  - `/Library/LaunchAgents/`
  - `/Library/LaunchDaemons/` (admin)
  - `~/Library/Application Support/com.apple.backgroundtaskmanagementagent/backgrounditems.btm` (modern login items)
  - SMAppService registered items (macOS 13+)
- Allow disable/enable via `launchctl` (or removal of plist)
- Show what each agent does (parse `Program`, `ProgramArguments`)

#### 3.4.3 Process Monitor
- Use `host_processor_info`, `proc_pidinfo`, or shell out to `ps`
- Show CPU%, RAM, energy impact per process
- Allow `kill -9` on selected processes
- Highlight processes consuming >X% CPU for >Y seconds

#### 3.4.4 Memory Release
- macOS auto-manages memory; this feature is **largely cosmetic** but expected
- Real action: `sudo purge` (clears disk cache, frees inactive memory)
- Show before/after via `vm_stat`

#### 3.4.5 Battery Monitor (laptops only)
- Read battery info via `IOKit` (`IOPSCopyPowerSourcesInfo`)
- Show: cycle count, max capacity %, current charge, wattage in/out
- Detect battery-draining apps via `pmset -g log` parsing
- Show condition (Normal / Replace Soon / Service)

### 3.5 Applications Module

#### 3.5.1 Uninstaller
**Detection:**
- Scan `/Applications` and `~/Applications`
- For each `.app`, find leftovers using bundle identifier:
  - `~/Library/Application Support/{bundleID}/`
  - `~/Library/Caches/{bundleID}/`
  - `~/Library/Preferences/{bundleID}.plist`
  - `~/Library/Logs/{bundleID}/`
  - `~/Library/Saved Application State/{bundleID}.savedState/`
  - `~/Library/Containers/{bundleID}/`
  - `~/Library/Group Containers/group.{bundleID}/` (heuristic match)
  - `~/Library/HTTPStorages/{bundleID}/`
  - `~/Library/WebKit/{bundleID}/`
  - LaunchAgents/Daemons matching the bundle

**Categories:** All apps, App Store, Other, 32-bit (deprecated detection), Unused (no launch in 90 days — read from LaunchServices).

**Reset feature:** Clear app data without uninstalling.

#### 3.5.2 Updater
**Approach for personal tool:**
- For App Store apps: shell out to `mas` CLI (Mac App Store CLI)
- For Homebrew casks: `brew outdated --cask`
- For Sparkle-enabled apps: parse `SUFeedURL` from Info.plist, fetch appcast XML, compare versions
- Don't try to build a custom updater catalog like CleanMyMac — too much maintenance

### 3.6 Files Module

#### 3.6.1 Space Lens
- Build interactive treemap of disk usage
- Recursive directory walk with `FileManager.enumerator`
- Use **D3-style treemap** rendered in SwiftUI Canvas, OR embed `WKWebView` with d3.js
- Cache results in SQLite (rescan on demand)
- Performance: parallelize at top-level directories using `TaskGroup`
- Skip: `/System`, `/private/var/db`, mounted network volumes (configurable)

#### 3.6.2 Large & Old Files
- Filters: size threshold, age threshold, file type
- Sort by size desc / date asc
- Quick preview via `NSWorkspace`

#### 3.6.3 Duplicate Finder
**Algorithm (efficient):**
1. Group files by **size** first (cheap)
2. For groups with >1 file, compute **first 4KB hash** (xxHash)
3. For matching first-block hashes, compute **full SHA-256**
4. Confirmed duplicates = same full hash

Skip files <1KB by default (too many false positives).

#### 3.6.4 Similar Photos
**Algorithm:**
- **Perceptual hashing (pHash)** via `Vision` framework or `dHash` algorithm
- Compute 64-bit hash per image
- Hamming distance < threshold = "similar"
- Cluster by similarity, show side-by-side comparison

**Library:** Use Apple's `Vision` framework (`VNGenerateImageFeaturePrintRequest`) for state-of-the-art similarity.

### 3.7 Shredder
- Overwrite file with random bytes N times before unlink
- macOS `srm` was removed; implement manually
- Warn user this is mostly unnecessary on SSD (TRIM makes it ineffective)
- For HDDs: 3-pass random write
- For SSDs: single-pass + offer FileVault reminder

### 3.8 Dashboard / Menu Bar
**Menu bar status item showing:**
- CPU %
- RAM usage
- Disk free space
- Battery (if laptop)
- Network up/down speed
- Quick actions: "Free RAM", "Run Smart Care", "Open Cleaner"

**Implementation:** `NSStatusItem` + `NSMenu` + timer-based refresh (1s for CPU/RAM, 30s for disk).

### 3.9 My Tools (Pinned Shortcuts)
- User pins favorite tools to a custom dashboard
- Drag-and-drop reorder
- Stored in UserDefaults

---

## 4. Privileged Helper Tool

### 4.1 Why Needed
Many operations require root:
- Reading `/Library/Caches`, `/private/var/log`
- Running `purge`, `periodic`, `mdutil`
- Modifying `/Library/LaunchDaemons`
- Reading TCC.db (system-level)

### 4.2 Architecture
- Separate XPC service registered via `SMAppService.daemon(plistName:)` (macOS 13+)
- Communicates with main app via `NSXPCConnection`
- Defines protocol with whitelisted commands
- **Never accept arbitrary shell commands from main app** — only enumerated operations

```swift
@objc protocol PrivilegedHelperProtocol {
    func runMaintenanceScript(type: MaintenanceType, reply: @escaping (Bool, String?) -> Void)
    func deleteSystemPaths(_ paths: [String], reply: @escaping (Bool, [String]) -> Void)
    func purgeMemory(reply: @escaping (Bool) -> Void)
    // ... explicitly enumerated
}
```

### 4.3 Authorization
- First run: prompt admin password via `SMJobBless` flow (or `SMAppService` modern equivalent)
- Helper persists across reboots
- Code-sign helper with same Developer ID as main app

---

## 5. Permissions Required

| Permission | Why | When |
|---|---|---|
| Full Disk Access | Read `~/Library/Mail`, browser data, TCC.db | First launch |
| Accessibility | Quit running apps before cleanup, app automation | First launch |
| Automation (System Events) | Trigger maintenance via AppleScript | Optional |
| Screen Recording | Not needed | — |
| Files & Folders | Per-folder fallback if FDA denied | Granular |

UI flow: Show a permissions wizard on first launch with "Open System Settings" buttons.

---

## 6. Data Models (Sketch)

```swift
struct CleanableItem: Identifiable, Hashable {
    let id: UUID
    let path: URL
    let size: Int64
    let category: ItemCategory
    let safetyLevel: SafetyLevel    // .safe, .review, .dangerous
    let lastModified: Date?
    let description: String
    let metadata: [String: String]
}

enum ScanResult {
    case empty
    case found(items: [CleanableItem], totalSize: Int64)
    case error(ScanError)
}

struct CleanupRule: Codable {
    let id: String
    let name: String
    let paths: [String]              // supports glob: ~/Library/Caches/**
    let exclusions: [String]
    let requiresAdmin: Bool
    let safetyLevel: SafetyLevel
    let category: ItemCategory
    let minimumAge: TimeInterval?    // skip recent files
}
```

---

## 7. Safety & Reliability

### 7.1 Hard Rules
1. **Never delete without explicit user confirmation** (even in "Smart Scan").
2. **Always show what will be deleted** with sizes and paths.
3. **Quarantine before delete** for non-cache items: move to a hidden `~/.MacCleanerQuarantine/<timestamp>/` for 7 days, then purge.
4. **Whitelist guard:** maintain a list of paths that must NEVER be touched (`/System`, `/usr` outside `/usr/local`, `~/Documents`, `~/Desktop`, `~/Downloads` files less than 7 days old, etc.).
5. **Lock detection:** if a target file is open by another process (`lsof` check), skip it.

### 7.2 Logging
- Every deletion logged to `~/Library/Logs/MacCleaner/cleanup-{date}.log`
- Format: `timestamp | rule_id | path | size | result`
- Retain 90 days

### 7.3 Undo
- For quarantined items: 1-click restore from quarantine UI
- For non-quarantined (caches): no undo (acceptable since macOS regenerates)

---

## 8. Build & Distribution

### 8.1 Targets
- `MacCleaner.app` — main app
- `com.dong.MacCleaner.Helper` — privileged helper (XPC service)

### 8.2 Code Signing (personal use)
- Get free Apple Developer account (no $99 needed for local install)
- Self-sign with Developer ID Application certificate
- For privileged helper: must be signed with same team identifier
- Disable Gatekeeper warnings: `sudo spctl --master-disable` (or right-click → Open first time)

### 8.3 No Notarization Needed
- Notarization is for distribution outside MAS to others
- Personal install: can run unnotarized after first manual approval

### 8.4 CI/CD (Optional)
- GitHub Actions on macOS runner
- Build, test, archive, output `.dmg`
- Self-hosted: just use Xcode locally

---

## 9. Development Roadmap

> Realistic timeline assuming Đông codes part-time (10–15 hrs/week) while learning Swift in parallel.

### Phase 0 — Swift Onboarding (3–4 weeks)
- Swift language fundamentals (skip basics — Kotlin transfer is high)
- SwiftUI tutorials (build 2–3 toy apps)
- Concurrency: `async/await`, `Actor`, `Task`, `TaskGroup`
- File system APIs: `FileManager`, `URL`, `FileHandle`
- **Deliverable:** Toy app that lists `~/Downloads` with sizes

### Phase 1 — Foundation (3–4 weeks)
- Project skeleton, DI, navigation shell
- Permissions wizard (FDA, Accessibility)
- File system utilities (recursive size calc, directory enumeration with progress)
- SQLite setup with GRDB
- Logging infrastructure
- **Deliverable:** App launches, requests permissions, can scan a directory and show results

### Phase 2 — Core Cleanup (4–6 weeks)
- Cleanup rule engine (JSON-driven)
- System Junk module (full)
- Trash bins
- Mail attachments
- Photo junk
- Quarantine system
- **Deliverable:** Functional system cleaner saving real GBs

### Phase 3 — Files Module (3–4 weeks)
- Space Lens (treemap visualization)
- Large & Old Files
- Duplicate Finder
- Similar Photos (using Vision)
- **Deliverable:** Disk analysis tools complete

### Phase 4 — Applications (2–3 weeks)
- Uninstaller with leftover detection
- Updater (Homebrew + Sparkle parsing)
- **Deliverable:** App management complete

### Phase 5 — Performance (3–4 weeks)
- Privileged Helper Tool + XPC bridge
- Maintenance scripts
- Login Items / Launch Agents manager
- Process monitor
- Memory release
- Battery monitor
- **Deliverable:** Performance suite complete

### Phase 6 — Protection (3–4 weeks)
- YARA integration
- Malware scanner
- Privacy cleaner (browser data)
- App permissions viewer
- **Deliverable:** Security suite complete

### Phase 7 — Polish (2–3 weeks)
- Smart Care orchestrator
- Menu bar app
- Dashboard
- My Tools (pinned shortcuts)
- Onboarding flow
- **Deliverable:** v1.0 release

**Total: ~6–8 months part-time.**

---

## 10. Key Risks & Mitigations

| Risk | Mitigation |
|---|---|
| Accidentally deleting important files | Whitelist guard + quarantine + dry-run + 7-day retention |
| macOS API changes between versions | Use availability checks (`@available`), test on multiple macOS versions in VM |
| Performance on large filesystems | Async streams + cancellation tokens + cached results |
| Privileged helper compromise | Whitelist commands only, no shell passthrough, code-sign verification |
| YARA false positives | User reviews before quarantine, never auto-delete malware |
| Swift learning curve while building | Phase 0 mandatory, don't skip; use Claude Code with Swift MCP for assistance |

---

## 11. References & Resources

### Open-source projects to study
- **AppCleaner** (Freemacsoft) — uninstaller logic
- **Onyx** (Titanium Software) — maintenance scripts approach
- **Stats** (`exelban/stats`) — menu bar resource monitor (Swift, MIT)
- **DaisyDisk** behavior — Space Lens UX inspiration
- **KnockKnock / BlockBlock** (Objective-See) — persistence detection patterns
- **rmlint** — duplicate detection algorithms

### macOS dev resources
- Apple's `FileManager`, `IOKit`, `NSWorkspace` docs
- WWDC sessions: "What's new in SwiftUI", "Privileged helper tools"
- Howard Oakley's blog (`eclecticlight.co`) — deep macOS internals
- Objective-See blog — security/persistence on macOS

### Libraries
- GRDB.swift (SQLite)
- SwiftYARA (or shell out to yara CLI)
- Sparkle source (for parsing appcasts — don't include framework, just logic)

---

## 12. Out of Scope (v1.0)

Explicitly NOT building:
- Cloud cleanup (Dropbox, OneDrive, iCloud Drive deep clean)
- Real-time malware monitoring (just on-demand scans)
- Custom AV engine (use YARA + hash DBs only)
- Multi-Mac sync
- iOS device cleanup (separate problem)
- Localization (English only — personal tool)

May add in v2.0 if useful.

---

## 13. Open Questions for Đông

Before starting implementation, decide:

1. **macOS version target:** macOS 13+ (modern APIs) or macOS 11+ (broader compat)? Recommended: **13+**.
2. **MacBook M4 Pro is Apple Silicon only:** target arm64 only or universal? Recommended: **arm64-only** (personal tool).
3. **Swift learning approach:** structured course (Hacking with Swift, 100 Days of SwiftUI) or build-while-learning? Recommended: **2 weeks structured, then build**.
4. **Use Claude Code with Swift MCP** for implementation? (Đông already uses Claude Code with Dart MCP — same workflow applies.)

---

**End of spec.**
