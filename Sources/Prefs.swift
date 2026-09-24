import Foundation

enum PrefKey {
    static let useDeviceLocation = "useDeviceLocation"
    static let manualLatitude = "manualLatitude"
    static let manualLongitude = "manualLongitude"
    static let manualName = "manualName"
    static let manualTimeZone = "manualTimeZone"

    static let method = "calculationMethod"
    static let asrMethod = "asrMethod"
    static let highLatitudeRule = "highLatitudeRule"

    static let prayerAlerts = "prayerAlerts"
    static let alertMinutesBefore = "alertMinutesBefore"
    static let morningEveningReminder = "morningEveningReminder"

    static let dhikrInterval = "dhikrIntervalMinutes"   // 0 = off
    static let dhikrNotify = "dhikrNotify"
    static let showTranslation = "showTranslation"

    static let menuCountdown = "menuCountdown"
    static let menuArabicNames = "menuArabicNames"
    static let menuIqamahName = "menuIqamahName"   // show prayer name next to the iqamah countdown

    // Hijri date
    static let hijriSource = "hijriSource"
    static let hijriAdjustment = "hijriAdjustment"   // -2...+2 days

    // Adhan audio
    static let adhanSound = "adhanSound"           // "" = automatic
    static let adhanFajrSound = "adhanFajrSound"   // "" = same as adhanSound (uses its _fajr variant if present)
    static let adhanVolume = "adhanVolume"
    static func adhanEnabled(_ p: Prayer) -> String { "adhan.enabled.\(p.rawValue)" }

    // Seasonal audio (Eid takbir, Hajj talbiyah)
    static let seasonalEidSound = "seasonalEidSound"                 // "" = automatic
    static let seasonalIntervalMinutes = "seasonalAudioIntervalMinutes"
    static func seasonalEnabled(_ c: SeasonalCategory) -> String { "seasonal.enabled.\(c.rawValue)" }
    static func seasonalAskedYear(_ c: SeasonalCategory) -> String { "seasonal.askedYear.\(c.rawValue)" }

    // Iqamah
    static let iqamahAlerts = "iqamahAlerts"
    static let jumuahOffset = "iqamah.offset.jumuah"
    static func iqamahOffset(_ p: Prayer) -> String { "iqamah.offset.\(p.rawValue)" }  // minutes, 0 = off
    static func iqamahFixed(_ p: Prayer) -> String { "iqamah.fixed.\(p.rawValue)" }    // minutes after midnight, -1 = not used
}

enum Prefs {
    private static var d: UserDefaults { .standard }

    static func registerDefaults() {
        var defaults: [String: Any] = [
            PrefKey.useDeviceLocation: true,
            PrefKey.method: CalculationMethod.mwl.rawValue,
            PrefKey.asrMethod: AsrMethod.standard.rawValue,
            PrefKey.highLatitudeRule: HighLatitudeRule.angleBased.rawValue,
            PrefKey.prayerAlerts: true,
            PrefKey.alertMinutesBefore: 0,
            PrefKey.morningEveningReminder: true,
            PrefKey.dhikrInterval: 60,
            PrefKey.dhikrNotify: true,
            PrefKey.showTranslation: true,
            PrefKey.menuCountdown: true,
            PrefKey.menuArabicNames: false,
            PrefKey.menuIqamahName: false,
            PrefKey.hijriSource: HijriSource.ummAlQura.rawValue,
            PrefKey.hijriAdjustment: 0,
        ]
        for c in DhikrCategory.allCases { defaults[c.prefKey] = true }

        defaults[PrefKey.adhanSound] = ""
        defaults[PrefKey.adhanFajrSound] = ""
        defaults[PrefKey.adhanVolume] = 0.8
        defaults[PrefKey.seasonalEidSound] = ""
        defaults[PrefKey.seasonalIntervalMinutes] = 60
        defaults[PrefKey.iqamahAlerts] = true
        defaults[PrefKey.jumuahOffset] = Iqamah.defaultJumuahOffset
        for p in Prayer.allCases where p.isPrayer {
            defaults[PrefKey.adhanEnabled(p)] = true
            defaults[PrefKey.iqamahOffset(p)] = Iqamah.defaultOffset(p)
            defaults[PrefKey.iqamahFixed(p)] = -1
        }
        d.register(defaults: defaults)
    }

    static var adhanVolume: Double { d.double(forKey: PrefKey.adhanVolume) }
    static func isAdhanEnabled(_ p: Prayer) -> Bool { p.isPrayer && d.bool(forKey: PrefKey.adhanEnabled(p)) }
    static var iqamahAlerts: Bool { d.bool(forKey: PrefKey.iqamahAlerts) }
    static var jumuahOffset: Int { d.integer(forKey: PrefKey.jumuahOffset) }
    static func iqamahOffsetMinutes(_ p: Prayer) -> Int { d.integer(forKey: PrefKey.iqamahOffset(p)) }
    static func iqamahFixedMinutes(_ p: Prayer) -> Int? {
        let v = d.integer(forKey: PrefKey.iqamahFixed(p))
        return v >= 0 ? v : nil
    }

    static var useDeviceLocation: Bool { d.bool(forKey: PrefKey.useDeviceLocation) }
    static var method: CalculationMethod { CalculationMethod(rawValue: d.string(forKey: PrefKey.method) ?? "") ?? .mwl }
    static var asrMethod: AsrMethod { AsrMethod(rawValue: d.string(forKey: PrefKey.asrMethod) ?? "") ?? .standard }
    static var highLatitudeRule: HighLatitudeRule {
        HighLatitudeRule(rawValue: d.string(forKey: PrefKey.highLatitudeRule) ?? "") ?? .angleBased
    }
    static var prayerAlerts: Bool { d.bool(forKey: PrefKey.prayerAlerts) }
    static var alertMinutesBefore: Int { d.integer(forKey: PrefKey.alertMinutesBefore) }
    static var morningEveningReminder: Bool { d.bool(forKey: PrefKey.morningEveningReminder) }
    static var dhikrInterval: Int { d.integer(forKey: PrefKey.dhikrInterval) }
    static var dhikrNotify: Bool { d.bool(forKey: PrefKey.dhikrNotify) }
    static var showTranslation: Bool { d.bool(forKey: PrefKey.showTranslation) }
    static var menuCountdown: Bool { d.bool(forKey: PrefKey.menuCountdown) }
    static var menuArabicNames: Bool { d.bool(forKey: PrefKey.menuArabicNames) }
    static var menuIqamahName: Bool { d.bool(forKey: PrefKey.menuIqamahName) }
    static var hijriSource: HijriSource { HijriSource(rawValue: d.string(forKey: PrefKey.hijriSource) ?? "") ?? .ummAlQura }
    static var hijriAdjustment: Int { min(max(d.integer(forKey: PrefKey.hijriAdjustment), -2), 2) }
    static var enabledCategories: Set<DhikrCategory> {
        Set(DhikrCategory.allCases.filter { d.bool(forKey: $0.prefKey) })
    }

    static var seasonalEidSound: String { d.string(forKey: PrefKey.seasonalEidSound) ?? "" }
    static var seasonalIntervalMinutes: Int { d.integer(forKey: PrefKey.seasonalIntervalMinutes) }
    static func isSeasonalEnabled(_ c: SeasonalCategory) -> Bool { d.bool(forKey: PrefKey.seasonalEnabled(c)) }
    static func setSeasonalEnabled(_ c: SeasonalCategory, _ value: Bool) { d.set(value, forKey: PrefKey.seasonalEnabled(c)) }
    static func seasonalAskedYear(_ c: SeasonalCategory) -> Int { d.integer(forKey: PrefKey.seasonalAskedYear(c)) }
    static func setSeasonalAskedYear(_ c: SeasonalCategory, _ year: Int) { d.set(year, forKey: PrefKey.seasonalAskedYear(c)) }
}

enum Format {
    private static var timeFormatters: [String: DateFormatter] = [:]

    static func time(_ date: Date, _ tz: TimeZone) -> String {
        let f: DateFormatter
        if let cached = timeFormatters[tz.identifier] {
            f = cached
        } else {
            f = DateFormatter()
            f.timeZone = tz
            f.dateStyle = .none
            f.timeStyle = .short
            timeFormatters[tz.identifier] = f
        }
        return f.string(from: date)
    }

    static func gregorian(_ date: Date, _ tz: TimeZone) -> String {
        let f = DateFormatter()
        f.timeZone = tz
        f.setLocalizedDateFormatFromTemplate("EEEE d MMMM")
        return f.string(from: date)
    }

    /// Uses the chosen source + moon-sighting adjustment.
    static func hijri(_ date: Date, _ tz: TimeZone) -> String {
        HijriCalendar.day(for: date, timeZone: tz,
                          source: Prefs.hijriSource, adjustment: Prefs.hijriAdjustment).long
    }

    /// "1h 23m" / "12m" for the menu bar.
    static func shortCountdown(_ seconds: TimeInterval) -> String {
        let m = max(0, Int((seconds / 60).rounded(.up)))
        return m >= 60 ? "\(m / 60)h \(m % 60)m" : "\(m)m"
    }

    /// "12:34" (or "1:02:03" past an hour) for the menu bar iqamah countdown.
    static func minSec(_ seconds: TimeInterval) -> String {
        let t = max(0, Int(seconds.rounded(.up)))
        if t >= 3600 { return String(format: "%d:%02d:%02d", t / 3600, (t / 60) % 60, t % 60) }
        return String(format: "%d:%02d", t / 60, t % 60)
    }

    /// "1:23:45" for the popover.
    static func clock(_ seconds: TimeInterval) -> String {
        let t = max(0, Int(seconds))
        return String(format: "%d:%02d:%02d", t / 3600, (t / 60) % 60, t % 60)
    }
}
