import Foundation

/// The product's name, in one place, so a rename is one edit here plus
/// `CFBundleDisplayName` in Info.plist and the store metadata.
enum AppBrand {
    static let name = "Third Shot"
    static let proName = "\(name) Pro"
    static let disclaimer = "Independent. Not affiliated with any pickleball rating system or governing body, and it never calculates or reports a rating."
}
