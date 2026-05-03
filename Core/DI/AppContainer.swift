import Foundation
import SwiftUI

@MainActor
final class AppContainer: ObservableObject {

    let db: AppDatabase
    let permissions: PermissionsService
    let sizeCalculator: FileSizeCalculator
    let ruleEngine: RuleEngine
    let quarantine: QuarantineService
    let systemJunkScanner: SystemJunkScanner
    let trashBinScanner: TrashBinScanner
    let hierarchicalScanner: HierarchicalScanner
    let largeFilesScanner: LargeFilesScanner
    let duplicateDetector: DuplicateDetector
    let imageSimilarity: ImageSimilarity

    init() {
        let database: AppDatabase
        do {
            database = try AppDatabase.makeShared()
        } catch {
            Log.db.error("Failed to open shared database, falling back to in-memory: \(error.localizedDescription, privacy: .public)")
            do {
                database = try AppDatabase.inMemory()
            } catch {
                Log.db.fault("Even in-memory database failed: \(error.localizedDescription, privacy: .public)")
                preconditionFailure("Cannot create database: \(error)")
            }
        }
        self.db = database
        self.permissions = PermissionsService()
        self.sizeCalculator = FileSizeCalculator()

        let ruleEngine = RuleEngine()
        let quarantine = QuarantineService()
        self.ruleEngine = ruleEngine
        self.quarantine = quarantine
        self.systemJunkScanner = SystemJunkScanner(ruleEngine: ruleEngine, quarantine: quarantine)
        self.trashBinScanner = TrashBinScanner(quarantine: quarantine)
        self.hierarchicalScanner = HierarchicalScanner()
        self.largeFilesScanner = LargeFilesScanner()
        self.duplicateDetector = DuplicateDetector()
        self.imageSimilarity = ImageSimilarity()

        Log.app.info("AppContainer initialised")

        Task { [ruleEngine, quarantine] in
            do {
                try await ruleEngine.loadSystemJunkRules()
            } catch {
                Log.scanner.error("Failed to load rules: \(error.localizedDescription, privacy: .public)")
            }
            await quarantine.purgeOld()
        }
    }
}
