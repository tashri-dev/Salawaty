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

    var hijri: (source: HijriSource, adjustment: Int) {
        (HijriSource(rawValue: hijriSource) ?? .ummAlQura, hijriAdjustment)
    }

    var timeZone: TimeZone { TimeZone(identifier: timeZoneID) ?? .current }

    var calculator: PrayerCalculator {
        PrayerCalculator(method: CalculationMethod(rawValue: method) ?? .mwl,
                         asr: AsrMethod(rawValue: asrMethod) ?? .standard,
                         highLatitude: HighLatitudeRule(rawValue: highLatitudeRule) ?? .angleBased)
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

    /// Comes from the `AppGroupIdentifier` Info.plist key ("<TeamID>.com.yourname.PrayerBar"),
    /// so the Team ID never has to be typed into code.
    static var groupID: String? {
        Bundle.main.object(forInfoDictionaryKey: "AppGroupIdentifier") as? String
    }

    static var defaults: UserDefaults? {
        groupID.flatMap { UserDefaults(suiteName: $0) }
    }

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
