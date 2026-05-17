# MacCleaner → Windows Port Plan

> Mục tiêu: port bản macOS sang Windows, **chỉ giữ những module có thể chạy native trên Windows**. Module phụ thuộc đặc thù macOS (Apple Mail, Apple Photos, TCC, launchd, periodic scripts) sẽ bỏ.

---

## 1. Tech stack

**Đề xuất:** **WinUI 3 + .NET 8 (C#)**

| Lý do | Chi tiết |
|---|---|
| Mô hình UI gần SwiftUI nhất | XAML declarative, data binding, MVVM map 1-1 với `@Published` + `ObservableObject` |
| Win32 P/Invoke đầy đủ | `windows-csharp` / `CsWin32` source-generated bindings cho mọi API hệ thống cần |
| Modern Fluent design | Mica/Acrylic, theme tự động, không lệ thuộc Windows 10 styling cũ |
| Single-file deploy | `dotnet publish -r win-x64 -p:PublishSingleFile=true` ra 1 exe ~80–150MB |
| Dev velocity | Hot reload XAML, debugger tốt, ecosystem nuget rộng |

**Alternative ngắn gọn (nếu muốn đổi):**
- **WPF + .NET 8** — ổn định nhất, UI hơi cổ. Pick nếu cần ship gấp và sợ rủi ro WinUI 3.
- **Avalonia** — cross-platform, có thể chia code với bản Mac sau này, nhưng community nhỏ hơn.

> Quyết định cuối: ngày mai chốt, mặc định trong plan là WinUI 3.

---

## 2. Feature inventory — KEEP / DROP

### 2.1 KEEP (23 modules + system tray + onboarding)

| # | Module | macOS source | Windows mapping |
|---|---|---|---|
| **Performance** ||||
| 1 | **Dashboard** | `Features/Dashboard` | `PerformanceCounter`, `Win32_PerfFormattedData_*` (CPU/RAM/Disk/Net), `GetPerformanceInfo`, NVAPI/ADL hoặc DXGI cho GPU |
| 2 | **Process Monitor** | `Features/Performance/ProcessMonitor` | `Process.GetProcesses()` + `Win32_Process` cho CPU% / mem / user / start time, `EnumProcessModules` cho path |
| 3 | **Usage Trends** | `Features/Performance/UsageTrends` (90-day) | Sampler chạy nền + SQLite (`Microsoft.Data.Sqlite`) — logic time-series không đổi |
| 4 | **Memory** | `Features/Performance/MemoryRelease` | `GlobalMemoryStatusEx`. "Release" không có equivalent system-wide; thay bằng "Empty working set" per-process (`EmptyWorkingSet`) hoặc bỏ nút |
| 5 | **Battery** | `Features/Performance/BatteryMonitor` | `GetSystemPowerStatus` + `Win32_Battery` (design capacity, cycle count, health) |
| 6 | **Sensors** | `Features/Performance/Sensors` | `MSAcpi_ThermalZoneTemperature` (WMI) + LibreHardwareMonitor lib cho CPU/GPU temps. **Warning:** spotty across OEM, hiển thị only-if-available |
| 7 | **Network** | `Features/Performance/Network` | `NetworkInterface.GetAllNetworkInterfaces()`, `IPGlobalProperties`, `Win32_PerfFormattedData_Tcpip_NetworkInterface`. Per-app bandwidth → ETW provider Microsoft-Windows-Kernel-Network |
| 8 | **Bluetooth** | `Features/Performance/Bluetooth` | `Windows.Devices.Bluetooth.BluetoothLEDevice`, `BluetoothDevice` (WinRT), pin device qua `BluetoothApis.h` |
| 9 | **Disk Monitor** | `Features/Performance/DiskMonitor` | `Win32_PerfFormattedData_PerfDisk_PhysicalDisk` (R/W bytes/sec, queue depth), `Win32_LogicalDisk` (free space), SMART qua `IOCTL_ATA_PASS_THROUGH` |
| 10 | **Login Items** | `Features/Performance/LoginItems` | `HKCU\Software\Microsoft\Windows\CurrentVersion\Run` + `HKLM\...\Run`, `%APPDATA%\Microsoft\Windows\Start Menu\Programs\Startup`, Task Scheduler `\Microsoft\Windows\...` |
| **Applications** ||||
| 11 | **Uninstaller** | `Features/Applications/Uninstaller` | `HKLM\Software\Microsoft\Windows\CurrentVersion\Uninstall` + `HKLM\...\Wow6432Node\...` + `HKCU` mirror, MSI `MsiEnumProducts`, MSIX qua `PackageManager.FindPackages` |
| 12 | **Updater** | `Features/Applications/Updater` | `winget` CLI wrapper (`winget upgrade --include-unknown`), hoặc `Microsoft.WindowsPackageManager.ComInterop` để gọi trực tiếp |
| **Cleanup** ||||
| 13 | **Quick Clean** | `Features/Cleanup/QuickClean` + một phần của `SystemJunk` | Scan locations: `%TEMP%`, `%LOCALAPPDATA%\Temp`, `C:\Windows\Temp`, `C:\Windows\SoftwareDistribution\Download`, browser caches (Chrome/Edge/Firefox profile paths), Recycle Bin, Windows.old, prefetch (`C:\Windows\Prefetch`), thumbnail cache (`%LOCALAPPDATA%\Microsoft\Windows\Explorer\thumbcache_*.db`), DirectX shader cache, crash dumps |
| 14 | **Recycle Bin** | `Features/Cleanup/TrashBins` | `SHQueryRecycleBin` (per-drive size/count), `SHEmptyRecycleBin` |
| **Files** ||||
| 15 | **Space Lens** | `Features/Files/SpaceLens` (treemap) | `FindFirstFile/FindNextFile` walk hoặc USN journal qua `DeviceIoControl(FSCTL_ENUM_USN_DATA)` cho speed; treemap render = `Microsoft.UI.Xaml.Shapes` |
| 16 | **Large & Old** | `Features/Files/LargeOldFiles` | Directory walk + size/mtime filter (giống Mac, đổi `FileManager` → `DirectoryInfo.EnumerateFiles`) |
| 17 | **Duplicates** | `Features/Files/DuplicateFinder` | SHA256 streaming hash với `System.IO.Hashing` + size pre-filter — logic không đổi |
| 18 | **Similar Photos** | `Features/Files/SimilarPhotos` | Perceptual hash (pHash) qua `System.Drawing` hoặc `SkiaSharp`. Mac dùng Vision framework, Win đổi qua `ImageHash` nuget hoặc port pHash thủ công |
| **Tools** ||||
| 19 | **Shredder** | `Features/Shredder` | Overwrite N pass với `FileStream.Write` + flush + delete. Note: SSD trim làm overwrite vô nghĩa — hiển thị disclaimer giống bản Mac |
| 20 | **Quarantine** | `Features/Quarantine` | Move-to-managed-folder + restore. Cờ ZoneIdentifier ADS (`:Zone.Identifier`) đánh dấu file đã quarantine |
| 21 | **My Tools** | `Features/MyTools` | Pinned shortcuts — pure UI, JSON state, không phụ thuộc OS |
| 22 | **Clock** | `Features/Tools/Clock` | `TimeZoneInfo.GetSystemTimeZones()` — không phụ thuộc OS đặc thù |
| 23 | **Paint** | `Features/Tools/Paint` | `Win2D` hoặc `SkiaSharp` cho canvas; brush/layer model port nguyên |
| 24 | **Scroll Denoiser** | `Features/ScrollDenoiser` | Port từ `scroll_denoiser.ahk` đã có — refactor thành service C# với `SetWindowsHookEx(WH_MOUSE_LL)` thay vì AHK |
| **Cross-cutting** ||||
| 25 | **System Tray** | `Features/MenuBar` | `NotifyIcon` (WinForms hosted) hoặc `H.NotifyIcon.WinUI` nuget, popover = `TaskbarIcon.ContextFlyout` |
| 26 | **Onboarding** | `Features/Onboarding` | Permission/intro wizard — port view, đổi UAC prompt cho admin-required modules |

### 2.2 DROP (8 modules)

| Module | Lý do bỏ |
|---|---|
| **Smart Care** | Wrapper 3-pillar dựa vào Cleanup + Protection (đã trim) — không còn ý nghĩa. Có thể tái xuất hiện ở v2 nếu chốt được scope Windows-flavored. |
| **Maintenance** | `periodic`, repair disk permissions, reindex Spotlight — toàn lệnh macOS. Windows có SFC / DISM / chkdsk / Storage Sense nhưng khác hoàn toàn về UX và đã có sẵn trong Settings; không cần build lại. |
| **System Junk** | Trùng phạm vi với Quick Clean trên Windows (cùng quét `%TEMP%`, caches…) — gộp vào Quick Clean. |
| **Mail Attachments** | Phụ thuộc Apple Mail `~/Library/Mail` schema. Outlook / Thunderbird trên Windows có schema khác hoàn toàn, ROI thấp. |
| **Photo Junk** | Phụ thuộc Apple Photos library (`Photos.sqlite`). Windows không có thư viện ảnh hệ thống tương đương. |
| **Malware Removal** | Heuristic của bản Mac quét LaunchAgents / LaunchDaemons / kext. Windows malware persistence (services, scheduled tasks, registry Run keys, WMI subs, COM hijack) là một domain riêng — Windows Defender đã cover, không cần re-build. |
| **Privacy** | Bản Mac clear lịch sử Safari + Chrome + Firefox. Windows không có Safari; còn lại Chrome/Edge/Firefox đã có "Clear browsing data" UI built-in. ROI thấp. |
| **App Permissions** | Mac TCC database queryable. Windows Privacy categories (Camera/Mic/Location…) live trong registry `HKLM\Software\Microsoft\Windows\CurrentVersion\CapabilityAccessManager\ConsentStore` nhưng UI Settings của Windows đã trực quan — không có nhiều lợi thế khi tự build. |

---

## 3. Architecture mapping

### 3.1 Core services (Mac → Win)

| Mac (`Core/`) | Windows (.NET 8) |
|---|---|
| `Core/DI/AppContainer.swift` (singleton, `ObservableObject`) | `Microsoft.Extensions.DependencyInjection` host + `App.xaml.cs` resolve |
| `Core/Storage/DefaultsKeys.swift` + `UserDefaults` | `Microsoft.Extensions.Configuration` + `appsettings.json` cho schema, registry/AppData JSON cho user state |
| `Core/Database/*` (GRDB sqlite cho usage trends) | `Microsoft.Data.Sqlite` — driver khác, SQL gần như giữ nguyên |
| `Core/Permissions/PermissionsService` (Accessibility + Full Disk Access) | UAC elevation check (`WindowsIdentity.GetCurrent().Owner == BUILTIN\Administrators`) + `IsUserAnAdmin()`. Một số tác vụ cần restart với manifest `requireAdministrator` |
| `Core/Performance/SystemMetrics` (host_statistics64, vm_stats) | `PerformanceCounter("Processor", "% Processor Time", "_Total")` + `Win32_PerfFormattedData_PerfOS_Memory` |
| `Core/Performance/DiskIOService` | `Win32_PerfFormattedData_PerfDisk_*` hoặc `IOCTL_DISK_PERFORMANCE` |
| `Core/Network/*` | `NetworkInterface` + ETW Realtime session cho per-app |
| `Core/FileSystem/*` (Spotlight `mdfind`, NSMetadataQuery) | Windows Search SQL (`SystemIndex` qua OLE DB) hoặc directory walk fallback |
| `Core/Applications/AppMetadataResolver` (bundle plist, icon từ NSWorkspace) | Đọc icon từ `SHGetFileInfo` / `ExtractAssociatedIcon`, version qua `FileVersionInfo` |
| `Core/UI/DesignTokens` (Spacing/Radius/cardStyle/refreshTask) | XAML resources + `Thickness` styles + DispatcherTimer wrapper hoặc `IAsyncEnumerable` polling helper |
| `Core/UI/ModuleHeader` | XAML UserControl |
| `Core/Logging/Log` | `Microsoft.Extensions.Logging` + `ILogger<T>` |
| `Core/Alerts/AlertEngine` | `ToastNotification` (WinRT `Windows.UI.Notifications`) |
| `Core/Cleanup/CleanupEngine` | Logic giữ; thay scan locations theo Section 2.1 #13 |

### 3.2 Threading / async model

- SwiftUI `@MainActor` → WinUI `DispatcherQueue.TryEnqueue(...)`
- Swift `async/await` + `Task` → C# `async/await` + `Task` (semantics gần như identical)
- `@Published` → `INotifyPropertyChanged` (dùng `CommunityToolkit.Mvvm` `[ObservableProperty]` để generate boilerplate)
- `View.refreshTask(every:)` → extension method dùng `DispatcherQueueTimer` hoặc `PeriodicTimer` async loop

### 3.3 Permissions / privilege model

| Tác vụ | Windows yêu cầu |
|---|---|
| Đọc system metrics, list processes của user | Standard user |
| List ALL processes (system) | Admin token (UAC) |
| Empty Recycle Bin, xoá `C:\Windows\Temp`, Windows.old | Admin |
| Đọc `HKLM\Software\...` cho uninstall scan | Standard read; **xoá** registry uninstall key → admin |
| Sửa Login Items `HKCU\...\Run` | Standard |
| Sửa Login Items `HKLM\...\Run` | Admin |
| `SetWindowsHookEx(WH_MOUSE_LL)` cho Scroll Denoiser | Standard (không cần admin nhưng UIPI giới hạn với app elevated khác) |
| `EmptyWorkingSet`, `SetProcessWorkingSetSize` | Standard cho process của mình, admin cho process khác |

→ App manifest dùng `asInvoker` (standard), nâng quyền on-demand qua **separate elevated helper process** chỉ khi user nhấn nút cần admin (giống pattern của Sysinternals / Process Explorer).

---

## 4. Phased roadmap

### Phase 0 — Bootstrap (1–2 ngày)
- [ ] Solution `MacCleaner.Win` + projects: `App` (WinUI 3), `Core` (class library), `Tests`
- [ ] Setup CI: GitHub Actions Windows runner, `dotnet build` + `dotnet test` + `dotnet publish` artifact
- [ ] Design system: port `Spacing`/`Radius`/`Color` sang `App.xaml` ResourceDictionary; tạo `ModuleHeader` UserControl + `Card` style
- [ ] DI bootstrap, logging, basic Navigation View với sidebar cứng (chưa wire feature nào)

### Phase 1 — Core infrastructure (3–5 ngày)
- [ ] `SystemMetricsService` (CPU/RAM/Disk/Net counters)
- [ ] `ProcessService`
- [ ] `DriveService` (DriveInfo + WMI hybrid)
- [ ] `RegistryService` (typed wrappers cho Run keys + Uninstall keys)
- [ ] `SqliteService` cho usage trends DB
- [ ] `ToastService` cho notifications
- [ ] `NotifyIconHost` system tray + popover skeleton

### Phase 2 — Performance modules (1 tuần)
- Dashboard, Process Monitor, Memory, Battery, Network, Disk Monitor — đều dựa trên Core services Phase 1
- Bluetooth (WinRT), Sensors (vendor-specific, ship "best effort")
- Login Items

### Phase 3 — Applications (3–4 ngày)
- Uninstaller (registry + MSI + MSIX scan)
- Updater (winget wrapper)
- Usage Trends (DB từ Phase 1, view layer)

### Phase 4 — Files (1 tuần)
- Space Lens (directory walk + treemap render)
- Large & Old
- Duplicates (SHA256 + size pre-filter)
- Similar Photos (pHash)

### Phase 5 — Cleanup (3–5 ngày)
- Quick Clean (scan locations đã liệt kê) + Recycle Bin

### Phase 6 — Tools (1 tuần)
- Shredder, Quarantine
- My Tools (UI + JSON state)
- Clock
- Scroll Denoiser (port từ AHK script → C# service với WH_MOUSE_LL)
- Paint (lớn nhất — `Win2D` canvas, brush/layer/history)

### Phase 7 — Onboarding + polish (3–5 ngày)
- Onboarding wizard
- Settings/About
- Code signing setup (SignTool + EV cert nếu có)
- Installer: MSIX hoặc Inno Setup

**Tổng:** ~6–8 tuần cho 1 dev full-time. Tăng tốc nếu Paint cắt scope.

---

## 5. Rủi ro & mitigation

| Rủi ro | Mitigation |
|---|---|
| WinUI 3 packaging quirks (unpackaged vs packaged) | Start với **unpackaged self-contained** — đơn giản nhất, ship như exe + installer. Chuyển packaged sau nếu cần MSIX Store. |
| Sensors thiếu API thống nhất trên Windows | Dùng LibreHardwareMonitorLib — license MPL-2.0, OK cho closed-source nếu giữ nó dưới dạng dll riêng. Hiển thị "Not available" nếu sensor nào không đọc được. |
| GPU metrics: NVIDIA/AMD/Intel khác nhau | DXGI `IDXGIAdapter3::QueryVideoMemoryInfo` đủ cho VRAM. Utilization → `D3DKMT_QUERYSTATISTICS` (undoc but stable) hoặc Performance Counter `\GPU Engine(*)\Utilization Percentage` (Win10+). |
| ETW per-app bandwidth cần admin | Fallback: total network counter + show "Run as admin để xem per-app". Same Windows Task Manager UX. |
| UAC fatigue khi nhiều thao tác cần admin | Single elevated helper process khởi động on-demand, không elevate cả app. |
| Code signing cert đắt | Initial release dùng SmartScreen reputation grace — sau vài tuần SmartScreen warning sẽ dịu. EV cert ($300/yr) loại bỏ warning ngay. |
| Paint module phức tạp (Win2D layer compositing) | Ship Paint ở Phase 6, scope tối thiểu (brush + layers, không undo lịch sử đầy đủ). Polish sau release. |
| Per-process working-set "release" gây UX khó hiểu | Bỏ nút "Free RAM" hoặc đổi thành "Trim working sets" với explainer rõ ràng — đừng quảng cáo nó như free RAM. |

---

## 6. Day-1 checklist (ngày mai)

```
□ git init MacCleaner.Win
□ dotnet new sln -n MacCleaner.Win
□ dotnet new winui3 -n App
□ dotnet new classlib -n Core
□ dotnet new xunit -n Tests
□ dotnet sln add App Core Tests
□ Add nugets: CommunityToolkit.Mvvm, CsWin32, Microsoft.Data.Sqlite,
              H.NotifyIcon.WinUI, LibreHardwareMonitorLib
□ Port DesignTokens (Spacing/Radius/Color) → App.xaml
□ Stub ModuleHeader UserControl
□ NavigationView với 5 categories + 23 stub pages
□ Commit "scaffold: WinUI 3 skeleton with sidebar navigation"
```

---

## 7. Repo layout (đề xuất)

```
MacCleaner.Win/
├── App/                    # WinUI 3 entry point + Views
│   ├── App.xaml
│   ├── MainWindow.xaml
│   ├── Views/              # Per-feature XAML pages
│   ├── Controls/           # ModuleHeader, Card, StatusBadge
│   └── Resources/          # Themes, styles, icons
├── Core/                   # OS-agnostic-ish business logic
│   ├── Performance/
│   ├── Applications/
│   ├── Cleanup/
│   ├── Files/
│   ├── Tools/
│   ├── Storage/            # SettingsKeys.cs, SqliteContext.cs
│   ├── Permissions/
│   └── Logging/
├── Native/                 # P/Invoke + WinRT wrappers
│   ├── Win32Interop.cs
│   ├── WmiQueries.cs
│   └── EtwSession.cs
├── Tests/
└── Installer/              # Inno Setup script
```

---

## 8. Map cross-reference

Bản Mac giữ nguyên trong repo `MacCleaner` hiện tại. Bản Windows nên ở repo **riêng** (`MacCleaner.Win`) để tránh nhiễu Xcode/.NET build artifacts. Hai repo cùng version-bump khi release song song.
