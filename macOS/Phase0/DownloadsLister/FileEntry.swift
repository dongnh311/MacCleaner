import Foundation

// `struct` is a value type with automatic memberwise init. Closer to Kotlin's
// `data class` than to a regular `class`. Conformances are explicit:
//   Identifiable -> required by SwiftUI's List / Table for stable row identity
//   Hashable     -> lets us use it as a Set/selection element
//   Sendable     -> tells the Swift 6 concurrency checker this can safely cross
//                   actor boundaries (all stored properties are themselves Sendable).
struct FileEntry: Identifiable, Hashable, Sendable {
    let id: URL                 // URL is unique per file, no need for a separate UUID
    let name: String
    let size: Int64             // bytes
    let modified: Date
    let isDirectory: Bool

    var url: URL { id }

    var formattedSize: String {
        ByteCountFormatter.string(fromByteCount: size, countStyle: .file)
    }
}
