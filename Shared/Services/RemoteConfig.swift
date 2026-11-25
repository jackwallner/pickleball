import Foundation

import RevenueCat

// What RevenueCat can change without a release, read from the current
// offering's metadata (a running Experiment's variant included). Every
// variant ships in the binary; a missing or unknown value is the control,
// which is exactly the copy from before this reader. Keys a switch reads
// must be set the same on every offering, or an Experiment arm would flip
// them as a side effect.
//
// DEBUG builds can pin any key for captures: `-pickleball.rc.<key> <value>`.

/// The paywall's trial button, shown only to an account StoreKit says is
/// eligible for the free week.
enum TrialCTA: String, CaseIterable, Sendable {
    static let metadataKey = "trial_cta"

    /// Control: "Start free trial", the button's copy before the test.
    case sevenDay = "seven_day"
    case my
    case your

    static func from(metadata: [String: Any]?) -> TrialCTA {
        RemoteConfig.value(metadataKey, in: metadata, default: .sevenDay)
    }

    var title: String {
        switch self {
        case .sevenDay: return "Start free trial"
        case .my: return "Start my free trial"
        case .your: return "Start your free trial"
        }
    }

    /// An account that already used its free week, or whose eligibility is
    /// unknown, is charged at confirmation, so its button promises no trial
    /// (3.1.2). That wording is the same in every arm.
    func title(trialEligible: Bool) -> String {
        trialEligible ? title : "Subscribe"
    }
}

/// Remote off switches. On unless the metadata says "off".
enum RemoteSwitch: String, CaseIterable, Sendable {
    /// Apple's rating prompt after a good run.
    case ratingPrompt = "rating_prompt"
}

enum RemoteConfig {
    /// The value for `key`, or `fallback` when it is missing, not a string,
    /// or not one of the shipped variants.
    static func value<T: RawRepresentable>(_ key: String, in metadata: [String: Any]?, default fallback: T) -> T
    where T.RawValue == String {
        #if DEBUG
        if let pinned = launchOverride(key).flatMap(T.init(rawValue:)) { return pinned }
        #endif
        guard let raw = metadata?[key] as? String else { return fallback }
        return T(rawValue: raw) ?? fallback
    }

    static func isOn(_ remoteSwitch: RemoteSwitch, in metadata: [String: Any]?) -> Bool {
        #if DEBUG
        if let pinned = launchOverride(remoteSwitch.rawValue) { return pinned != "off" }
        #endif
        return (metadata?[remoteSwitch.rawValue] as? String) != "off"
    }

    #if DEBUG
    private static func launchOverride(_ key: String) -> String? {
        let args = ProcessInfo.processInfo.arguments
        guard let index = args.firstIndex(of: "-pickleball.rc.\(key)"), index + 1 < args.count else { return nil }
        return args[index + 1]
    }
    #endif
}

extension SubscriptionService {
    private var remoteMetadata: [String: Any]? { offerings?.current?.metadata }

    var trialCTA: TrialCTA { TrialCTA.from(metadata: remoteMetadata) }

    func isOn(_ remoteSwitch: RemoteSwitch) -> Bool {
        RemoteConfig.isOn(remoteSwitch, in: remoteMetadata)
    }
}
