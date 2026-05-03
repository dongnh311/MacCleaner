import Foundation
import AppKit
import ApplicationServices

actor PermissionsService {

    private(set) var statuses: [PermissionType: PermissionStatus] = [:]

    func refreshAll() async -> [PermissionType: PermissionStatus] {
        var result: [PermissionType: PermissionStatus] = [:]
        for type in PermissionType.allCases {
            result[type] = check(type)
        }
        statuses = result
        Log.permissions.info("statuses refreshed: \(result.mapValues { "\($0)" }, privacy: .public)")
        return result
    }

    func check(_ type: PermissionType) -> PermissionStatus {
        switch type {
        case .fullDiskAccess: return checkFullDiskAccess()
        case .accessibility:  return checkAccessibility()
        }
    }

    private func checkFullDiskAccess() -> PermissionStatus {
        let probes = ["Library/Safari", "Library/Mail", "Library/Messages"]
        for relative in probes {
            let path = (NSHomeDirectory() as NSString).appendingPathComponent(relative)
            guard FileManager.default.fileExists(atPath: path) else { continue }
            do {
                _ = try FileManager.default.contentsOfDirectory(atPath: path)
                return .granted
            } catch {
                let err = error as NSError
                if err.domain == NSCocoaErrorDomain && err.code == NSFileReadNoPermissionError {
                    return .denied
                }
            }
        }
        return .unknown
    }

    private func checkAccessibility() -> PermissionStatus {
        AXIsProcessTrusted() ? .granted : .denied
    }

    @MainActor
    static func openSettings(for type: PermissionType) {
        NSWorkspace.shared.open(type.settingsURL)
    }
}
