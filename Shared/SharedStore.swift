import Foundation

/// What the widgets need to calculate prayer times on their own.
/// The app writes it; the widget extension reads it (both via the App Group).
struct WidgetSnapshot: Codable, Equatable {
    var latitude: Double
    var longitude: Double
    var placeName: String
    var timeZoneID: String
    var method: String
    var asrMethod: String
    var highLatitudeRule: String
    var hijriSource: String
    var hijriAdjustment: Int
    /// Per-prayer minute corrections keyed by `Prayer.rawValue`; optional so older data still decodes.
    var adjustments: [String: Int]? = nil

    var hijri: (source: HijriSource, adjustment: Int) {
        (HijriSource(rawValue: hijriSource) ?? .ummAlQura, hijriAdjustment)
    }

    var timeZone: TimeZone { TimeZone(identifier: timeZoneID) ?? .current }

    var calculator: PrayerCalculator {
        PrayerCalculator(method: CalculationMethod(rawValue: method) ?? .mwl,
                         asr: AsrMethod(rawValue: asrMethod) ?? .standard,
                         highLatitude: HighLatitudeRule(rawValue: highLatitudeRule) ?? .angleBased,
                         adjustments: Dictionary(uniqueKeysWithValues: (adjustments ?? [:]).compactMap { k, v in
                             Prayer(rawValue: k).map { ($0, v) }
                         }))
    }

    func schedule(for date: Date) -> PrayerSchedule {
        calculator.schedule(for: date, latitude: latitude, longitude: longitude, timeZone: timeZone)
    }

    /// Used for widget previews / the gallery before the app has run.
    static let sample = WidgetSnapshot(latitude: 30.0444, longitude: 31.2357,
                                       placeName: "القاهرة", timeZoneID: "Africa/Cairo",
                                       method: CalculationMethod.egypt.rawValue,
                                       asrMethod: AsrMethod.standard.rawValue,
                                       highLatitudeRule: HighLatitudeRule.angleBased.rawValue,
                                       hijriSource: HijriSource.ummAlQura.rawValue,
                                       hijriAdjustment: 0)
}

enum SharedStore {
    private static let snapshotKey = "widgetSnapshot"

    /// Used when there's no real App Group: ad-hoc signed release builds have no Team ID.
    /// The sandboxed widget reaches this domain through its
    /// `temporary-exception.shared-preference.read-write` entitlement.
    static let fallbackSuite = "com.yourname.Salawaty.shared"

    /// Comes from the `AppGroupIdentifier` Info.plist key ("<TeamID>.com.yourname.Salawaty"),
    /// so the Team ID never has to be typed into code. Without a Team ID the key resolves to
    /// the bare bundle ID, which UserDefaults rejects as a suite name — use the fallback then.
    static var suiteName: String {
        let id = Bundle.main.object(forInfoDictionaryKey: "AppGroupIdentifier") as? String ?? ""
        let hasTeamPrefix = id.range(of: #"^[A-Z0-9]{10}\."#, options: .regularExpression) != nil
        return hasTeamPrefix ? id : fallbackSuite
    }

    static var defaults: UserDefaults? { UserDefaults(suiteName: suiteName) }

    static func load() -> WidgetSnapshot? {
        guard let data = defaults?.data(forKey: snapshotKey) else { return nil }
        return try? JSONDecoder().decode(WidgetSnapshot.self, from: data)
    }

    /// Returns true only when something changed, so the app reloads widgets sparingly
    /// (macOS limits how often widgets may be refreshed).
    @discardableResult
    static func save(_ snapshot: WidgetSnapshot) -> Bool {
        guard load() != snapshot, let data = try? JSONEncoder().encode(snapshot) else { return false }
        defaults?.set(data, forKey: snapshotKey)
        return true
    }
}
