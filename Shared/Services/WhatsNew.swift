import Foundation

/// One line on the What's New sheet.
struct WhatsNewItem: Identifiable, Sendable {
    let id: String
    let icon: String
    let title: String
    let body: String
    /// Marks the line as membership content, so the sheet can badge it and a
    /// free player can see exactly what the upgrade would hand them.
    let isPlus: Bool

    init(id: String, icon: String, title: String, body: String, isPlus: Bool = false) {
        self.id = id
        self.icon = icon
        self.title = title
        self.body = body
        self.isPlus = isPlus
    }
}

struct WhatsNewRelease: Sendable {
    let version: String
    let headline: String
    let items: [WhatsNewItem]
}

/// Decides whether to show the post-update What's New sheet, and remembers
/// that it has been shown.
///
/// The rule that matters: a FRESH install never sees it. Onboarding already
/// introduces the app, and opening a brand-new download with "here's what
/// changed" is nonsense. Only a player who had an older version installed gets
/// the sheet, once, on the first launch after updating.
enum WhatsNew {

    static let currentVersion: String =
        Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "1.0"

    private static let lastSeenKey = "whatsnew.lastSeenVersion"

    /// Empty until 1.1. A 1.0 app has no previous version to have updated
    /// from, and the sheet is deliberately never shown on a fresh install.
    static let releases: [WhatsNewRelease] = []

    static var currentRelease: WhatsNewRelease? {
        releases.first { $0.version == currentVersion }
    }

    /// True when this launch is the first one after an update and there are
    /// notes to show for the version now running.
    static func shouldPresent(hasOnboarded: Bool, defaults: UserDefaults = .standard) -> Bool {
        #if DEBUG
        if ProcessInfo.processInfo.arguments.contains("-duprIQ.suppressWhatsNew") { return false }
        #endif
        guard hasOnboarded, currentRelease != nil else { return false }
        let lastSeen = defaults.string(forKey: lastSeenKey) ?? ""
        // An empty marker on an onboarded player means they updated from a
        // build that predates this feature. That is exactly the audience.
        return lastSeen != currentVersion
    }

    static func markSeen(defaults: UserDefaults = .standard) {
        defaults.set(currentVersion, forKey: lastSeenKey)
    }

    /// Called when onboarding finishes so a new player is never shown notes
    /// for a version they have only ever run.
    static func markCurrentAsBaseline(defaults: UserDefaults = .standard) {
        defaults.set(currentVersion, forKey: lastSeenKey)
    }
}
