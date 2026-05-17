# MacCleaner UI Kit

High-fidelity HTML/JSX recreation of the **MacCleaner** macOS app — one
product, one window. Modelled on the real SwiftUI source in
`MacCleaner/App/` + `MacCleaner/Features/`.

## What's in here

| File | Notes |
|---|---|
| `index.html` | Click-through prototype. Boots into Smart Care; pick any of the 31 modules from the sidebar. |
| `app.jsx` | Mounts the React app. |
| `data.js` | Fake CleanableItems, threats, processes, sensor readings. |
| `Window.jsx` | macOS traffic-light chrome + unified `NSVisualEffectView` backdrop. |
| `Sidebar.jsx` | 7-section sidebar with per-section accent tints. Mirrors `SidebarItem.swift`. |
| `Chrome.jsx` | `ModuleHeader`, `Eyebrow`, `Chip`, `Badge`, `Button`, `Sparkline`, `Toggle`. |
| `SmartCare.jsx` | Idle / Scanning / Ready states + three Pillar cards + floating Clean button. |
| `SystemJunk.jsx` | Master / detail with categories, subgroups, safety badges, confirm-bar, action-bar. |
| `Memory.jsx` | RAM breakdown bar + per-process top list, refreshing sparkline. |
| `Sensors.jsx` | Temperature / fan / power tile grid. |
| `ModulePlaceholder.jsx` | Generic placeholder rendered for the 27 modules we don't fully recreate. |
| `Menubar.jsx` | Menu-bar status strip (rendered as an extra preview row at the top). |

## Substitutions

- **SF Pro / SF Mono** → Inter / JetBrains Mono on non-Apple OSes.
- **SF Symbols** → **Lucide** via CDN (same stroke weight, regular).
  Some glyphs are close-but-not-identical (`bolt-circle` ≠
  `bolt.circle`); flagged inline as comments.

## Not recreated

We deliberately stop after four full modules. The remaining 27 sidebar
items render through `ModulePlaceholder` so you can navigate the whole
sidebar but only the four flagship surfaces are pixel-real.

> If you need another module recreated, point at it in the codebase
> and I'll build it the same way.
