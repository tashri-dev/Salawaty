import Foundation

// MARK: - Model

enum Prayer: String, CaseIterable, Identifiable, Codable {
    case fajr, sunrise, dhuhr, asr, maghrib, isha

    var id: String { rawValue }

    /// Sunrise is shown in the list but is not a prayer.
    var isPrayer: Bool { self != .sunrise }

    var englishName: String {
        switch self {
        case .fajr: return "Fajr"
        case .sunrise: return "Sunrise"
        case .dhuhr: return "Dhuhr"
        case .asr: return "Asr"
        case .maghrib: return "Maghrib"
        case .isha: return "Isha"
        }
    }

    var arabicName: String {
        switch self {
        case .fajr: return "الفجر"
        case .sunrise: return "الشروق"
        case .dhuhr: return "الظهر"
        case .asr: return "العصر"
        case .maghrib: return "المغرب"
        case .isha: return "العشاء"
        }
    }

    var symbol: String {
        switch self {
        case .fajr: return "sun.haze"
        case .sunrise: return "sunrise"
        case .dhuhr: return "sun.max"
        case .asr: return "sun.min"
        case .maghrib: return "sunset"
        case .isha: return "moon.stars"
        }
    }
}

struct PrayerTime: Identifiable, Equatable {
    let prayer: Prayer
    let date: Date
    var id: Prayer { prayer }
}

struct PrayerSchedule: Equatable {
    let date: Date
    let timeZone: TimeZone
    let entries: [PrayerTime]
}

enum IshaRule {
    case angle(Double)
    case minutesAfterMaghrib(Double)
}

enum CalculationMethod: String, CaseIterable, Identifiable {
    case mwl, isna, egypt, makkah, karachi, dubai, kuwait, qatar, singapore, turkey, france

    var id: String { rawValue }

    var title: String {
        switch self {
        case .mwl: return "Muslim World League"
        case .isna: return "ISNA (North America)"
        case .egypt: return "Egyptian General Authority"
        case .makkah: return "Umm al-Qura (Makkah)"
        case .karachi: return "Karachi (Univ. of Islamic Sciences)"
        case .dubai: return "Dubai"
        case .kuwait: return "Kuwait"
        case .qatar: return "Qatar"
        case .singapore: return "Singapore (MUIS)"
        case .turkey: return "Diyanet (Turkey)"
        case .france: return "UOIF (France)"
        }
    }

    var fajrAngle: Double {
        switch self {
        case .mwl: return 18
        case .isna: return 15
        case .egypt: return 19.5
        case .makkah: return 18.5
        case .karachi: return 18
        case .dubai: return 18.2
        case .kuwait: return 18
        case .qatar: return 18
        case .singapore: return 20
        case .turkey: return 18
        case .france: return 12
        }
    }

    var isha: IshaRule {
        switch self {
        case .mwl: return .angle(17)
        case .isna: return .angle(15)
        case .egypt: return .angle(17.5)
        case .makkah: return .minutesAfterMaghrib(90)
        case .karachi: return .angle(18)
        case .dubai: return .angle(18.2)
        case .kuwait: return .angle(17.5)
        case .qatar: return .minutesAfterMaghrib(90)
        case .singapore: return .angle(18)
        case .turkey: return .angle(17)
        case .france: return .angle(12)
        }
    }
}

enum AsrMethod: String, CaseIterable, Identifiable {
    case standard, hanafi
    var id: String { rawValue }
    var title: String { self == .standard ? "Standard (Shafi'i, Maliki, Hanbali)" : "Hanafi" }
    var shadowFactor: Double { self == .standard ? 1 : 2 }
}

enum HighLatitudeRule: String, CaseIterable, Identifiable {
    case off, angleBased, middleOfNight, oneSeventh
    var id: String { rawValue }
    var title: String {
        switch self {
        case .off: return "None"
        case .angleBased: return "Angle-based"
        case .middleOfNight: return "Middle of the night"
        case .oneSeventh: return "One-seventh of the night"
        }
    }
}

// MARK: - Calculator (astronomical formulas based on the PrayTimes.org algorithm)

struct PrayerCalculator {
    var method: CalculationMethod = .mwl
    var asr: AsrMethod = .standard
    var highLatitude: HighLatitudeRule = .angleBased

    func schedule(for date: Date, latitude lat: Double, longitude lng: Double, timeZone tz: TimeZone) -> PrayerSchedule {
        var local = Calendar(identifier: .gregorian)
        local.timeZone = tz
        let c = local.dateComponents([.year, .month, .day], from: date)
        let (y, m, d) = (c.year!, c.month!, c.day!)

        let localNoon = local.date(bySettingHour: 12, minute: 0, second: 0, of: date) ?? date
        let tzHours = Double(tz.secondsFromGMT(for: localNoon)) / 3600

        let astro = Astro(jDate: Astro.julian(y, m, d) - lng / (15 * 24), lat: lat)

        var fajr = astro.sunAngleTime(method.fajrAngle, 5.0 / 24, ccw: true)
        var sunrise = astro.sunAngleTime(0.833, 6.0 / 24, ccw: true)
        var dhuhr = astro.midDay(12.0 / 24)
        var asrTime = astro.asrTime(asr.shadowFactor, 13.0 / 24)
        var sunset = astro.sunAngleTime(0.833, 18.0 / 24, ccw: false)
        var isha = Double.nan
        if case .angle(let a) = method.isha {
            isha = astro.sunAngleTime(a, 18.0 / 24, ccw: false)
        }

        // Shift from solar time to the location's clock time.
        let shift = tzHours - lng / 15
        fajr += shift; sunrise += shift; dhuhr += shift
        asrTime += shift; sunset += shift; isha += shift

        // High-latitude corrections for when twilight never ends / is too long.
        if highLatitude != .off, sunrise.isFinite, sunset.isFinite {
            let night = Astro.timeDiff(sunset, sunrise)
            func portion(_ angle: Double) -> Double {
                switch highLatitude {
                case .angleBased: return angle / 60 * night
                case .middleOfNight: return night / 2
                case .oneSeventh: return night / 7
                case .off: return .infinity
                }
            }
            let fp = portion(method.fajrAngle)
            if !fajr.isFinite || Astro.timeDiff(fajr, sunrise) > fp { fajr = sunrise - fp }
            if case .angle(let a) = method.isha {
                let ip = portion(a)
                if !isha.isFinite || Astro.timeDiff(sunset, isha) > ip { isha = sunset + ip }
            }
        }

        let maghrib = sunset
        if case .minutesAfterMaghrib(let mins) = method.isha {
            isha = maghrib + mins / 60
        }

        // Convert local-clock hours into absolute Dates (DST-safe), rounded to the minute.
        var utc = Calendar(identifier: .gregorian)
        utc.timeZone = TimeZone(identifier: "UTC")!
        let utcMidnight = utc.date(from: DateComponents(year: y, month: m, day: d))!
        func toDate(_ hours: Double) -> Date? {
            guard hours.isFinite else { return nil }
            let minutes = ((hours - tzHours) * 60).rounded()
            return utcMidnight.addingTimeInterval(minutes * 60)
        }

        let raw: [(Prayer, Double)] = [
            (.fajr, fajr), (.sunrise, sunrise), (.dhuhr, dhuhr),
            (.asr, asrTime), (.maghrib, maghrib), (.isha, isha)
        ]
        let entries = raw.compactMap { p, h in toDate(h).map { PrayerTime(prayer: p, date: $0) } }
        return PrayerSchedule(date: localNoon, timeZone: tz, entries: entries)
    }
}

// MARK: - Astronomy helpers

private struct Astro {
    let jDate: Double
    let lat: Double

    static func julian(_ year: Int, _ month: Int, _ day: Int) -> Double {
        var y = Double(year), m = Double(month)
        if m <= 2 { y -= 1; m += 12 }
        let a = floor(y / 100)
        let b = 2 - a + floor(a / 4)
        return floor(365.25 * (y + 4716)) + floor(30.6001 * (m + 1)) + Double(day) + b - 1524.5
    }

    static func timeDiff(_ t1: Double, _ t2: Double) -> Double { fixHour(t2 - t1) }

    func sunPosition(_ jd: Double) -> (declination: Double, equation: Double) {
        let d = jd - 2451545.0
        let g = Self.fixAngle(357.529 + 0.98560028 * d)
        let q = Self.fixAngle(280.459 + 0.98564736 * d)
        let l = Self.fixAngle(q + 1.915 * Self.dsin(g) + 0.020 * Self.dsin(2 * g))
        let e = 23.439 - 0.00000036 * d
        let ra = Self.darctan2(Self.dcos(e) * Self.dsin(l), Self.dcos(l)) / 15
        let eqt = q / 15 - Self.fixHour(ra)
        let decl = Self.darcsin(Self.dsin(e) * Self.dsin(l))
        return (decl, eqt)
    }

    func midDay(_ time: Double) -> Double {
        Self.fixHour(12 - sunPosition(jDate + time).equation)
    }

    func sunAngleTime(_ angle: Double, _ time: Double, ccw: Bool) -> Double {
        let decl = sunPosition(jDate + time).declination
        let noon = midDay(time)
        let x = (-Self.dsin(angle) - Self.dsin(decl) * Self.dsin(lat)) / (Self.dcos(decl) * Self.dcos(lat))
        guard abs(x) <= 1 else { return .nan }  // sun never reaches this angle today
        let t = Self.darccos(x) / 15
        return noon + (ccw ? -t : t)
    }

    func asrTime(_ factor: Double, _ time: Double) -> Double {
        let decl = sunPosition(jDate + time).declination
        let angle = -Self.darccot(factor + Self.dtan(abs(lat - decl)))
        return sunAngleTime(angle, time, ccw: false)
    }

    // Degree-based trig
    static func dsin(_ d: Double) -> Double { sin(d * .pi / 180) }
    static func dcos(_ d: Double) -> Double { cos(d * .pi / 180) }
    static func dtan(_ d: Double) -> Double { tan(d * .pi / 180) }
    static func darcsin(_ x: Double) -> Double { asin(x) * 180 / .pi }
    static func darccos(_ x: Double) -> Double { acos(x) * 180 / .pi }
    static func darctan2(_ y: Double, _ x: Double) -> Double { atan2(y, x) * 180 / .pi }
    static func darccot(_ x: Double) -> Double { atan(1 / x) * 180 / .pi }
    static func fix(_ a: Double, _ b: Double) -> Double { let r = a - b * floor(a / b); return r < 0 ? r + b : r }
    static func fixAngle(_ a: Double) -> Double { fix(a, 360) }
    static func fixHour(_ a: Double) -> Double { fix(a, 24) }
}
