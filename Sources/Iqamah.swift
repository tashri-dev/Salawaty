import Foundation

struct IqamahCountdown: Equatable {
    let adhan: PrayerTime
    let englishName: String
    let arabicName: String
    let iqamah: Date
}

enum Iqamah {
    /// "Supplication between the adhan and the iqamah is not rejected." — Abu Dawud, Tirmidhi
    static let dua = "الدُّعَاءُ لَا يُرَدُّ بَيْنَ الْأَذَانِ وَالْإِقَامَةِ"

    /// Minutes after the adhan (typical Egyptian mosque defaults).
    static func defaultOffset(_ p: Prayer) -> Int {
        switch p {
        case .fajr: return 20
        case .maghrib: return 10
        default: return 15
        }
    }

    static let defaultJumuahOffset = 30

    /// Starting value (minutes after midnight) when switching a prayer to a fixed iqamah time.
    static func defaultFixed(_ p: Prayer) -> Int {
        switch p {
        case .fajr: return 5 * 60
        case .dhuhr: return 13 * 60
        case .asr: return 16 * 60
        case .maghrib: return 18 * 60
        case .isha: return 20 * 60
        case .sunrise: return 6 * 60
        }
    }

    static func isJumuah(_ e: PrayerTime, _ tz: TimeZone) -> Bool {
        guard e.prayer == .dhuhr else { return false }
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = tz
        return cal.component(.weekday, from: e.date) == 6 // Friday
    }

    static func englishName(_ e: PrayerTime, _ tz: TimeZone) -> String {
        isJumuah(e, tz) ? "Jumu'ah" : e.prayer.englishName
    }

    static func arabicName(_ e: PrayerTime, _ tz: TimeZone) -> String {
        isJumuah(e, tz) ? "الجمعة" : e.prayer.arabicName
    }

    /// When the iqamah happens for this adhan, or nil if iqamah is off for it.
    static func date(for e: PrayerTime, timeZone tz: TimeZone) -> Date? {
        guard e.prayer.isPrayer else { return nil }
        let jumuah = isJumuah(e, tz)

        if !jumuah, let fixed = Prefs.iqamahFixedMinutes(e.prayer) {
            var cal = Calendar(identifier: .gregorian)
            cal.timeZone = tz
            if let d = cal.date(byAdding: .minute, value: fixed, to: cal.startOfDay(for: e.date)), d > e.date {
                return d
            }
            // Fixed time is earlier than today's adhan (e.g. seasons shifted) → fall back to the offset.
        }

        let offset = jumuah ? Prefs.jumuahOffset : Prefs.iqamahOffsetMinutes(e.prayer)
        return offset > 0 ? e.date.addingTimeInterval(Double(offset) * 60) : nil
    }
}
