import Foundation

// MARK: - Source

enum HijriSource: String, CaseIterable, Identifiable, Codable {
    case ummAlQura, saudiSighting, diyanet

    var id: String { rawValue }

    var title: String {
        switch self {
        case .ummAlQura: return "Umm al-Qura (built in, offline)"
        case .saudiSighting: return "Saudi moon sighting (AlAdhan)"
        case .diyanet: return "Diyanet, Turkey (AlAdhan)"
        }
    }

    /// `calendarMethod` value for the AlAdhan API, nil for offline sources.
    var apiMethod: String? {
        switch self {
        case .ummAlQura: return nil
        case .saudiSighting: return "HJCoSA"
        case .diyanet: return "DIYANET"
        }
    }
}

// MARK: - Date value

struct HijriDay: Codable, Equatable {
    let day: Int
    let month: Int
    let year: Int

    var monthName: String {
        HijriCalendar.monthNames[min(max(month, 1), 12) - 1]
    }

    /// "1448-04-13"
    var numeric: String { String(format: "%04d-%02d-%02d", year, month, day) }

    /// "13 ربيع الآخر 1448 هـ"
    var long: String { "\(day) \(monthName) \(year) هـ" }
}

// MARK: - Calendar

enum HijriCalendar {
    static let monthNames = [
        "محرم", "صفر", "ربيع الأول", "ربيع الآخر", "جمادى الأولى", "جمادى الآخرة",
        "رجب", "شعبان", "رمضان", "شوال", "ذو القعدة", "ذو الحجة",
    ]

    /// The Hijri date for a Gregorian day.
    /// - adjustment: days added for local moon sighting (+1 = the month started a day earlier here).
    static func day(for date: Date, timeZone tz: TimeZone, source: HijriSource, adjustment: Int) -> HijriDay {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = tz
        let shifted = cal.date(byAdding: .day, value: adjustment, to: date) ?? date

        if source.apiMethod != nil, let downloaded = HijriStore.table(for: source)[gregorianKey(shifted, tz)] {
            return downloaded
        }
        return ummAlQura(shifted, tz) // offline source, or online data not downloaded yet
    }

    static func ummAlQura(_ date: Date, _ tz: TimeZone) -> HijriDay {
        var cal = Calendar(identifier: .islamicUmmAlQura)
        cal.timeZone = tz
        let c = cal.dateComponents([.year, .month, .day], from: date)
        return HijriDay(day: c.day ?? 1, month: c.month ?? 1, year: c.year ?? 1)
    }

    /// "2026-09-24" in the given time zone.
    static func gregorianKey(_ date: Date, _ tz: TimeZone) -> String {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = tz
        let c = cal.dateComponents([.year, .month, .day], from: date)
        return String(format: "%04d-%02d-%02d", c.year ?? 0, c.month ?? 0, c.day ?? 0)
    }
}

// MARK: - Downloaded dates (shared with the widgets through the App Group)

enum HijriStore {
    private static var cache: [HijriSource: (version: Int, table: [String: HijriDay])] = [:]

    private static func tableKey(_ s: HijriSource) -> String { "hijriTable.\(s.rawValue)" }
    private static func versionKey(_ s: HijriSource) -> String { "hijriTable.\(s.rawValue).version" }
    private static func updatedKey(_ s: HijriSource) -> String { "hijriTable.\(s.rawValue).updated" }

    /// Gregorian "yyyy-MM-dd" → Hijri date.
    static func table(for s: HijriSource) -> [String: HijriDay] {
        guard let d = SharedStore.defaults else { return [:] }
        let version = d.integer(forKey: versionKey(s))
        if let cached = cache[s], cached.version == version { return cached.table }
        guard let data = d.data(forKey: tableKey(s)),
              let table = try? JSONDecoder().decode([String: HijriDay].self, from: data) else { return [:] }
        cache[s] = (version, table)
        return table
    }

    static func lastUpdated(for s: HijriSource) -> Date? {
        SharedStore.defaults?.object(forKey: updatedKey(s)) as? Date
    }

    /// Adds newly downloaded days, keeps about 8 months, and returns true if anything changed.
    @discardableResult
    static func merge(_ days: [String: HijriDay], for s: HijriSource) -> Bool {
        guard let d = SharedStore.defaults else { return false }
        d.set(Date(), forKey: updatedKey(s))

        let before = table(for: s)
        var table = before.merging(days) { _, new in new }
        if table.count > 240 {
            let keep = Set(table.keys.sorted().suffix(240))
            table = table.filter { keep.contains($0.key) }
        }
        guard table != before, let data = try? JSONEncoder().encode(table) else { return false }

        let version = d.integer(forKey: versionKey(s)) + 1
        d.set(data, forKey: tableKey(s))
        d.set(version, forKey: versionKey(s))
        cache[s] = (version, table)
        return true
    }
}
