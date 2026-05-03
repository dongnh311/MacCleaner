import Foundation

struct CleanupRule: Codable, Sendable, Identifiable {
    let id: String
    let name: String
    let description: String
    let paths: [String]
    let exclusions: [String]?
    let category: ItemCategory
    let safetyLevel: SafetyLevel
    let requiresAdmin: Bool
    let minimumAgeDays: Int?
    let mode: ScanMode

    enum ScanMode: String, Codable, Sendable {
        case eachChildAsItem
        case wholePathAsItem
    }
}

struct RuleSet: Codable, Sendable {
    let version: Int
    let rules: [CleanupRule]
}
