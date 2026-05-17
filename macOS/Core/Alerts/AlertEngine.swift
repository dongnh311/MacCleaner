import Foundation
import UserNotifications
import AppKit

/// Per-tick alert evaluator. Receives an AlertSnapshot from the menu-bar
/// loop, runs each enabled rule, and posts a UNUserNotification when any
/// rule fires (respecting per-rule cooldown). The engine is opt-in — until
/// `requestAuthorizationIfNeeded()` succeeds, evaluations are no-ops.
@MainActor
final class AlertEngine: ObservableObject {

    static let shared = AlertEngine()

    @Published private(set) var hasNotificationAuthorization: Bool = false
    /// Last time each rule actually fired. Read by Settings to show
    /// "fired X ago" — Settings isn't open during the 99% of alert fires,
    /// so the @Published cascade is wasted work on every status tick. Plain
    /// dictionary; the next Settings re-render picks up the freshest value.
    var lastFiredAt: [String: Date] = [:]

    private var states: [String: AlertState] = [:]
    /// In-memory cooldown tracker: rule.id → next-allowed timestamp.
    private var nextAllowed: [String: Date] = [:]

    private init() {
        Task { await refreshAuthorizationState() }
    }

    // MARK: - Configuration

    /// Master switch — when off, the evaluator skips everything. Persisted
    /// so users keep their pref between launches.
    var isEnabled: Bool {
        get { UserDefaults.standard.bool(forKey: DefaultsKeys.alertsEnabled) }
        set { UserDefaults.standard.set(newValue, forKey: DefaultsKeys.alertsEnabled) }
    }

    func isRuleEnabled(_ id: String) -> Bool {
        let key = DefaultsKeys.alertsRulePrefix + id
        // Default ON for every builtin so a fresh user gets useful alerts
        // immediately after they grant notification permission.
        if UserDefaults.standard.object(forKey: key) == nil { return true }
        return UserDefaults.standard.bool(forKey: key)
    }

    func setRule(_ id: String, enabled: Bool) {
        UserDefaults.standard.set(enabled, forKey: DefaultsKeys.alertsRulePrefix + id)
    }

    // MARK: - Authorization

    func requestAuthorizationIfNeeded() async {
        let already = await Self.isAuthorized()
        if already {
            hasNotificationAuthorization = true
            return
        }
        do {
            let granted = try await UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound])
            hasNotificationAuthorization = granted
        } catch {
            hasNotificationAuthorization = false
        }
    }

    private func refreshAuthorizationState() async {
        hasNotificationAuthorization = await Self.isAuthorized()
    }

    /// Must be `nonisolated` — the UN framework delivers the result on its
    /// own dispatch queue, and resuming a `@MainActor`-isolated continuation
    /// from there triggers `swift_task_isCurrentExecutor` to abort.
    /// Reading just the status field and passing back a Bool is Sendable-safe.
    private nonisolated static func isAuthorized() async -> Bool {
        await withCheckedContinuation { (cont: CheckedContinuation<Bool, Never>) in
            UNUserNotificationCenter.current().getNotificationSettings { settings in
                let ok = settings.authorizationStatus == .authorized
                      || settings.authorizationStatus == .provisional
                cont.resume(returning: ok)
            }
        }
    }

    // MARK: - Evaluation

    /// Called once per status-tick by `MenuBarStatusModel`. Cheap when off.
    func evaluate(_ snap: AlertSnapshot) {
        guard isEnabled, hasNotificationAuthorization else { return }
        let now = snap.timestamp
        for rule in AlertCatalog.builtins where isRuleEnabled(rule.id) {
            if let nextOK = nextAllowed[rule.id], now < nextOK { continue }
            var state = states[rule.id] ?? AlertState()
            let fired = rule.evaluate(snap, &state)
            states[rule.id] = state
            if fired {
                postNotification(for: rule, snap: snap)
                nextAllowed[rule.id] = now.addingTimeInterval(rule.cooldown)
                lastFiredAt[rule.id] = now
            }
        }
    }

    private func postNotification(for rule: AlertRule, snap: AlertSnapshot) {
        let content = UNMutableNotificationContent()
        content.title = rule.title
        content.body = rule.detail
        content.sound = .default
        // Categorise so a future Notifications page can filter.
        content.categoryIdentifier = "MacCleaner.alert"
        content.userInfo = ["ruleID": rule.id]
        let req = UNNotificationRequest(identifier: rule.id + "-" + UUID().uuidString,
                                        content: content,
                                        trigger: nil)
        // Pass no completion handler — supplying one inherits this method's
        // `@MainActor` isolation, and UN dispatches the callback from its
        // own queue, which crashes Swift 6's executor assertion.
        UNUserNotificationCenter.current().add(req)
    }
}
