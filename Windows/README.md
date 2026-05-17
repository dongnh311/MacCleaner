# SmartCleanner — Windows

Windows port. Scaffolding starts ngày mai theo [WINDOWS_PORT_PLAN.md](../WINDOWS_PORT_PLAN.md).

## Status

🚧 Not started yet — see Day-1 checklist trong port plan.

## Tech stack (planned)

- WinUI 3 + .NET 8 (C#)
- `Microsoft.Extensions.DependencyInjection` cho DI
- `Microsoft.Data.Sqlite` cho usage trends DB
- `CommunityToolkit.Mvvm` cho `INotifyPropertyChanged` boilerplate
- `H.NotifyIcon.WinUI` cho system tray
- `LibreHardwareMonitorLib` cho sensors

## Scope

23 modules portable từ bản macOS — danh sách đầy đủ + Mac→Win API mapping trong port plan section 2.1.
