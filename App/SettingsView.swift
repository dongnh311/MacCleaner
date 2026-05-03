import SwiftUI

struct SettingsView: View {
    var body: some View {
        TabView {
            Text("General")
                .tabItem { Label("General", systemImage: "gear") }
            Text("Scanning")
                .tabItem { Label("Scanning", systemImage: "magnifyingglass") }
            Text("Quarantine")
                .tabItem { Label("Quarantine", systemImage: "tray.full") }
            Text("Schedule")
                .tabItem { Label("Schedule", systemImage: "calendar") }
            Text("Notifications")
                .tabItem { Label("Notifications", systemImage: "bell") }
            Text("Advanced")
                .tabItem { Label("Advanced", systemImage: "slider.horizontal.3") }
        }
        .frame(width: 520, height: 360)
    }
}
