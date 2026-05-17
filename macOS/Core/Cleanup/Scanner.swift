import Foundation

enum ScanError: Error, LocalizedError, Sendable {
    case ruleLoadFailed(String)
    case accessDenied(URL)
    case other(String)

    var errorDescription: String? {
        switch self {
        case .ruleLoadFailed(let msg):  return "Could not load rules: \(msg)"
        case .accessDenied(let url):    return "No permission to access \(url.path)"
        case .other(let msg):           return msg
        }
    }
}

struct CleanFailure: Sendable {
    let item: CleanableItem
    let reason: String
}

struct CleanResult: Sendable {
    let removed: [CleanableItem]
    let failed: [CleanFailure]
    let totalBytesFreed: Int64
}

protocol CleanupScanner: Sendable {
    var id: String { get }
    var displayName: String { get }
    func scan() async throws -> [CleanableItem]
    func clean(_ items: [CleanableItem], onProgress: CleanProgressHandler?) async -> CleanResult
}

extension CleanupScanner {
    func clean(_ items: [CleanableItem]) async -> CleanResult {
        await clean(items, onProgress: nil)
    }
}
