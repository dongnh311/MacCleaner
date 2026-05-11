import Foundation

/// Central registry of every UserDefaults key the app reads or writes.
/// Anchoring them here makes it possible to audit (or migrate) the full
/// set in one place — important when a settings format changes and we
/// have to ship a one-shot migrator. Each value is wrapped in a versioned
/// suffix (`.v1`) where the data is encoded, so a future schema bump can
/// keep both keys alive during the migration window.
enum DefaultsKeys {
    /// Master alert toggle. v1 = bool.
    static let alertsEnabled = "Alerts.enabled.v1"
    /// Prefix — append the rule ID for per-rule on/off bool.
    static let alertsRulePrefix = "Alerts.rule."

    /// Saved timezone list for the world-clock view. v1 = JSON-encoded array.
    static let clockTimezones = "ClockService.timezones.v1"
    /// 24-hour vs 12-hour toggle for the clock.
    static let clockUse24Hour = "ClockService.use24Hour"

    /// Menu-bar metric pill enablement set. v1 = JSON-encoded array.
    static let menuBarEnabledMetrics = "MenuBarConfig.enabledMetrics.v1"

    /// Pinned MyTools entries — JSON-encoded array.
    static let myToolsPinned = "myTools.pinned"

    /// One-shot onboarding wizard completion flag.
    static let onboardingCompleted = "onboarding.completed"

    /// Opt-in public-IP lookup. Off by default for privacy.
    static let publicIPEnabled = "PublicIPService.enabled"
}
