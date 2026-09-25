import Foundation

/// A single trackable act of worship shown in the tracking widgets.
enum TrackableItem: String, CaseIterable, Identifiable, Codable {
    case fajr, dhuhr, asr, maghrib, isha
    case quran
    case adhkarMorning, adhkarEvening, adhkarSleep
    case sunnahFajr, sunnahDhuhrBefore, sunnahDhuhrAfter, sunnahMaghrib, sunnahIsha
    case witr, duha, qiyam

    var id: String { rawValue }

    enum Section { case prayer, reading, sunnah, nawafil }

    var section: Section {
        switch self {
        case .fajr, .dhuhr, .asr, .maghrib, .isha: return .prayer
        case .quran, .adhkarMorning, .adhkarEvening, .adhkarSleep: return .reading
        case .sunnahFajr, .sunnahDhuhrBefore, .sunnahDhuhrAfter, .sunnahMaghrib, .sunnahIsha: return .sunnah
        case .witr, .duha, .qiyam: return .nawafil
        }
    }

    /// The underlying prayer, for the five prayer items.
    var prayer: Prayer? {
        switch self {
        case .fajr: return .fajr
        case .dhuhr: return .dhuhr
        case .asr: return .asr
        case .maghrib: return .maghrib
        case .isha: return .isha
        default: return nil
        }
    }

    var arabicName: String {
        switch self {
        case .fajr: return "الفجر"
        case .dhuhr: return "الظهر"
        case .asr: return "العصر"
        case .maghrib: return "المغرب"
        case .isha: return "العشاء"
        case .quran: return "القرآن"
        case .adhkarMorning: return "أذكار الصباح"
        case .adhkarEvening: return "أذكار المساء"
        case .adhkarSleep: return "أذكار النوم"
        case .sunnahFajr: return "سنة الفجر"
        case .sunnahDhuhrBefore: return "قبل الظهر"
        case .sunnahDhuhrAfter: return "بعد الظهر"
        case .sunnahMaghrib: return "سنة المغرب"
        case .sunnahIsha: return "سنة العشاء"
        case .witr: return "الوتر"
        case .duha: return "الضحى"
        case .qiyam: return "القيام"
        }
    }

    var symbol: String {
        switch self {
        case .fajr, .dhuhr, .asr, .maghrib, .isha: return prayer!.symbol
        case .quran: return "book.closed"
        case .adhkarMorning: return "sun.max"
        case .adhkarEvening: return "cloud.sun"
        case .adhkarSleep: return "moon.zzz"
        case .sunnahFajr, .sunnahDhuhrBefore, .sunnahDhuhrAfter, .sunnahMaghrib, .sunnahIsha: return "sparkles"
        case .witr: return "moon.stars"
        case .duha: return "sun.horizon"
        case .qiyam: return "hands.sparkles"
        }
    }

    /// The five prayers, in schedule order — used for the small widget and the progress count.
    static let prayers: [TrackableItem] = [.fajr, .dhuhr, .asr, .maghrib, .isha]
}

/// Per-day completion state, shared between the app and the widget extension via the App Group.
enum PrayerTracking {
    private static let key = "prayerTracking"

    private static func dayKey(_ date: Date, _ tz: TimeZone) -> String {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = tz
        let c = cal.dateComponents([.year, .month, .day], from: date)
        return String(format: "%04d-%02d-%02d", c.year!, c.month!, c.day!)
    }

    private static func load() -> [String: [String]] {
        guard let data = SharedStore.defaults?.data(forKey: key),
              let dict = try? JSONDecoder().decode([String: [String]].self, from: data) else { return [:] }
        return dict
    }

    private static func save(_ dict: [String: [String]]) {
        guard let data = try? JSONEncoder().encode(dict) else { return }
        SharedStore.defaults?.set(data, forKey: key)
    }

    static func completed(on date: Date, _ tz: TimeZone) -> Set<String> {
        Set(load()[dayKey(date, tz)] ?? [])
    }

    @discardableResult
    static func toggle(_ item: TrackableItem, on date: Date, _ tz: TimeZone) -> Set<String> {
        var dict = load()
        let key = dayKey(date, tz)
        var items = Set(dict[key] ?? [])
        if items.contains(item.id) { items.remove(item.id) } else { items.insert(item.id) }
        dict[key] = Array(items)
        save(dict)
        return items
    }
}
