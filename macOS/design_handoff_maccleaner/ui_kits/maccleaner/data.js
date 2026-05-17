// ---------------------------------------------------------------
// Fake data for the MacCleaner UI kit. Sized to look real on first
// load; no live updates wired up (these are static snapshots).
// ---------------------------------------------------------------

window.SECTIONS = [
  { id: "scan",         label: "SCAN",         accent: "#6B52F5" },
  { id: "cleanup",      label: "CLEANUP",      accent: "#FF9F0A" },
  { id: "protection",   label: "PROTECTION",   accent: "#FF453A" },
  { id: "performance",  label: "PERFORMANCE",  accent: "#64D2FF" },
  { id: "applications", label: "APPLICATIONS", accent: "#5E5CE6" },
  { id: "files",        label: "FILES",        accent: "#BF5AF2" },
  { id: "tools",        label: "TOOLS",        accent: "#FF375F" },
];

// Module table — { id, section, title, icon (lucide), shortcut }
// Order matches MacCleaner/App/SidebarItem.swift.
window.MODULES = [
  // SCAN
  { id: "smartCare",       section: "scan",         title: "Smart Care",        icon: "sparkles",                       shortcut: "⌘1" },
  { id: "dashboard",       section: "scan",         title: "Dashboard",         icon: "layout-grid",                    shortcut: "⌘2" },
  // CLEANUP
  { id: "quickClean",      section: "cleanup",      title: "Quick Clean",       icon: "zap",                            shortcut: "⌘3" },
  { id: "systemJunk",      section: "cleanup",      title: "System Junk",       icon: "trash-2",                        shortcut: "⌘4" },
  { id: "mailAttachments", section: "cleanup",      title: "Mail Attachments",  icon: "mail",                                                 },
  { id: "photoJunk",       section: "cleanup",      title: "Photo Junk",        icon: "images",                                               },
  { id: "trashBins",       section: "cleanup",      title: "Trash Bins",        icon: "trash",                                                },
  // PROTECTION
  { id: "malware",         section: "protection",   title: "Malware Removal",   icon: "shield-half",                    shortcut: "⌘5" },
  { id: "privacy",         section: "protection",   title: "Privacy",           icon: "eye-off",                                              },
  { id: "appPermissions",  section: "protection",   title: "App Permissions",   icon: "lock-keyhole",                                         },
  // PERFORMANCE
  { id: "maintenance",     section: "performance",  title: "Maintenance",       icon: "wrench",                         shortcut: "⌘6" },
  { id: "loginItems",      section: "performance",  title: "Login Items",       icon: "power",                                                },
  { id: "processMonitor",  section: "performance",  title: "Process Monitor",   icon: "cpu",                                                  },
  { id: "usageTrends",     section: "performance",  title: "Usage Trends",      icon: "trending-up",                                          },
  { id: "memory",          section: "performance",  title: "Memory",            icon: "memory-stick",                                         },
  { id: "battery",         section: "performance",  title: "Battery",           icon: "battery-medium",                                       },
  { id: "sensors",         section: "performance",  title: "Sensors",           icon: "thermometer",                                          },
  { id: "network",         section: "performance",  title: "Network",           icon: "wifi",                                                 },
  { id: "bluetooth",       section: "performance",  title: "Bluetooth",         icon: "bluetooth",                                            },
  { id: "diskMonitor",     section: "performance",  title: "Disk Monitor",      icon: "hard-drive",                                           },
  // APPLICATIONS
  { id: "uninstaller",     section: "applications", title: "Uninstaller",       icon: "package-x",                      shortcut: "⌘7" },
  { id: "updater",         section: "applications", title: "Updater",           icon: "refresh-cw",                                           },
  // FILES
  { id: "spaceLens",       section: "files",        title: "Space Lens",        icon: "pie-chart",                      shortcut: "⌘8" },
  { id: "largeOldFiles",   section: "files",        title: "Large & Old",       icon: "file-search",                                          },
  { id: "duplicates",      section: "files",        title: "Duplicates",        icon: "files",                                                },
  { id: "similarPhotos",   section: "files",        title: "Similar Photos",    icon: "image",                                                },
  // TOOLS
  { id: "shredder",        section: "tools",        title: "Shredder",          icon: "scissors",                                             },
  { id: "quarantine",      section: "tools",        title: "Quarantine",        icon: "archive",                                              },
  { id: "myTools",         section: "tools",        title: "My Tools",          icon: "star",                           shortcut: "⌘9" },
  { id: "clock",           section: "tools",        title: "Clock",             icon: "clock",                                                },
  { id: "paint",           section: "tools",        title: "Paint",             icon: "paintbrush",                                           },
];

window.SECTION_BY_ID = Object.fromEntries(window.SECTIONS.map(s => [s.id, s]));
window.MODULE_BY_ID  = Object.fromEntries(window.MODULES.map(m => [m.id, m]));

// ---- Sample cleanable items ----
window.JUNK_ITEMS = [
  { cat: "Xcode",      group: "DerivedData",    name: "MacCleaner-abcd1234efgh",  path: "~/Library/Developer/Xcode/DerivedData/MacCleaner-abcd1234efgh", size: 4210_000_000, safety: "safe" },
  { cat: "Xcode",      group: "DerivedData",    name: "Sparkle-9zk19hsj",         path: "~/Library/Developer/Xcode/DerivedData/Sparkle-9zk19hsj",      size: 1830_000_000, safety: "safe" },
  { cat: "Xcode",      group: "Simulator",      name: "iOS 17.4 Simulator Cache", path: "~/Library/Developer/CoreSimulator/Caches/dyld",                 size: 1240_000_000, safety: "safe" },
  { cat: "Xcode",      group: "Archives",       name: "MacCleaner 2025-11-02",    path: "~/Library/Developer/Xcode/Archives/2025-11-02/MacCleaner.xcarchive", size: 612_000_000, safety: "review" },
  { cat: "Caches",     group: "User Caches",    name: "com.google.Chrome",        path: "~/Library/Caches/com.google.Chrome",                            size: 982_000_000, safety: "safe" },
  { cat: "Caches",     group: "User Caches",    name: "com.spotify.client",       path: "~/Library/Caches/com.spotify.client",                           size: 510_000_000, safety: "safe" },
  { cat: "Caches",     group: "User Caches",    name: "com.figma.Desktop",        path: "~/Library/Caches/com.figma.Desktop",                            size: 248_000_000, safety: "safe" },
  { cat: "Caches",     group: "Clang Module",   name: "clang module cache",       path: "~/Library/Caches/clang",                                        size: 812_000_000, safety: "safe" },
  { cat: "Logs",       group: "User Logs",      name: "Console diagnostics",      path: "~/Library/Logs/DiagnosticReports",                              size: 84_000_000,  safety: "safe" },
  { cat: "Logs",       group: "System Logs",    name: "ASL archives",             path: "/private/var/log/asl",                                          size: 41_000_000,  safety: "review" },
  { cat: "Homebrew",   group: "Cellar",         name: "Old formulae",             path: "/opt/homebrew/Cellar/_outdated",                                size: 462_000_000, safety: "safe" },
  { cat: "Homebrew",   group: "Downloads",      name: "Bottle downloads",         path: "~/Library/Caches/Homebrew/downloads",                           size: 178_000_000, safety: "safe" },
  { cat: "Node",       group: "npm",            name: "npm cache",                path: "~/.npm/_cacache",                                               size: 921_000_000, safety: "safe" },
  { cat: "Node",       group: "pnpm",           name: "pnpm store",               path: "~/Library/pnpm/store/v3",                                       size: 1380_000_000, safety: "safe" },
  { cat: "Docker",     group: "Volumes",        name: "Unused volumes",           path: "~/Library/Containers/com.docker.docker/Data/vms/0",             size: 3120_000_000, safety: "review" },
];

window.JUNK_CATEGORIES = [
  { id: "Xcode",    icon: "hammer",       label: "Xcode",         rationale: "Build products, DerivedData, simulator caches and old archives. Regenerated on next build." },
  { id: "Caches",   icon: "database",     label: "Application caches", rationale: "Per-app caches under ~/Library/Caches. Apps recreate them on launch." },
  { id: "Logs",     icon: "file-text",    label: "Logs",          rationale: "Diagnostic reports and ASL archives. Useful for crash triage; remove after a clean run." },
  { id: "Homebrew", icon: "beer",         label: "Homebrew",      rationale: "Outdated cellar versions and bottle downloads. `brew cleanup` equivalent." },
  { id: "Node",     icon: "package",      label: "Node / pnpm / yarn", rationale: "Package manager caches. Cold installs will be slower until the cache rebuilds." },
  { id: "Docker",   icon: "container",    label: "Docker",        rationale: "Stopped containers, dangling images, anonymous volumes. Live containers untouched." },
];

// ---- Threats + processes ----
window.THREATS = [
  { name: "com.suspicious.helper.plist", path: "~/Library/LaunchAgents/com.suspicious.helper.plist", severity: "danger", label: "DANGER" },
  { name: "com.mackeeper.helper.plist",  path: "~/Library/LaunchAgents/com.mackeeper.helper.plist",  severity: "review", label: "REVIEW" },
  { name: "AdwareDoctor.app",            path: "/Applications/AdwareDoctor.app",                     severity: "danger", label: "DANGER" },
];

window.PROCESSES = [
  { name: "Xcode",             pid: 17421, cpu:  82, mem: 4_900_000_000 },
  { name: "Slack Helper (Renderer)", pid: 27122, cpu:  18, mem: 1_400_000_000 },
  { name: "Google Chrome",     pid: 18230, cpu:  41, mem: 3_100_000_000 },
  { name: "WebKit Networking", pid: 99821, cpu:   3, mem:   680_000_000 },
  { name: "Figma Desktop",     pid: 64211, cpu:  12, mem:   820_000_000 },
  { name: "node",              pid: 49210, cpu:  68, mem: 1_240_000_000 },
  { name: "WindowServer",      pid:   146, cpu:  22, mem:   910_000_000 },
];

window.SENSORS = [
  { id: "tcpu", group: "CPU",  label: "CPU die",      value: 72, unit: "°C", tint: "warn" },
  { id: "tgpu", group: "GPU",  label: "GPU die",      value: 58, unit: "°C", tint: "ok" },
  { id: "tnand", group: "Storage", label: "NAND",     value: 47, unit: "°C", tint: "ok" },
  { id: "tbat", group: "Battery", label: "Battery",   value: 38, unit: "°C", tint: "ok" },
  { id: "fan1", group: "Fans", label: "Left fan",     value: 2480, unit: "RPM", tint: "ok" },
  { id: "fan2", group: "Fans", label: "Right fan",    value: 2510, unit: "RPM", tint: "ok" },
  { id: "pwrCpu", group: "Power", label: "CPU power", value: 16.4, unit: "W", tint: "warn" },
  { id: "pwrGpu", group: "Power", label: "GPU power", value:  4.2, unit: "W", tint: "ok" },
  { id: "pwrSys", group: "Power", label: "Whole-system", value: 31.8, unit: "W", tint: "warn" },
];

window.MEMORY = {
  totalGB: 32,
  appGB: 11.2,
  wiredGB: 4.1,
  compressedGB: 2.8,
  cachedGB: 8.4,
  freeGB: 5.5,
  pressure: 42, // %
};

window.helpers = {
  fmtBytes(b) {
    if (b < 1024) return b + " B";
    if (b < 1024*1024) return (b/1024).toFixed(0) + " KB";
    if (b < 1024*1024*1024) return (b/1024/1024).toFixed(0) + " MB";
    return (b/1024/1024/1024).toFixed(2) + " GB";
  },
  fmtBytesRound(b) {
    if (b < 1024*1024*1024) return (b/1024/1024).toFixed(0) + " MB";
    return (b/1024/1024/1024).toFixed(1) + " GB";
  },
};
