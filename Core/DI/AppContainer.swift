import Foundation
import SwiftUI

@MainActor
final class AppContainer: ObservableObject {

    let db: AppDatabase
    let permissions: PermissionsService
    let sizeCalculator: FileSizeCalculator

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
        Log.app.info("AppContainer initialised")
    }
}
