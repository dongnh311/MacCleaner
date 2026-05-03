import SwiftUI

// Phase 0 deliverable (spec §9): toy app listing ~/Downloads with sizes.
// Goal of this target is purely to learn Swift / SwiftUI / Concurrency / FileManager.
// The real cleaner code lives in the MacCleaner target.
//
// Kotlin -> Swift mental map (high level):
//   data class      -> struct (value type, automatic Equatable/Hashable conformances)
//   suspend fun     -> async func
//   coroutineScope  -> withTaskGroup / withThrowingTaskGroup (structured concurrency)
//   Mutex/sync      -> actor (compiler enforces serial access to internal state)
//   sealed class    -> enum with associated values
//   companion obj   -> static members
//   extension fn    -> extension (same idea, but works on any type incl. structs)

@main
struct DownloadsListerApp: App {
    var body: some Scene {
        WindowGroup("Downloads Lister — Phase 0") {
            ContentView()
                .frame(minWidth: 720, minHeight: 480)
        }
    }
}
