import SwiftUI
import WidgetKit

enum WidgetFormat {
    /// Arabic words with Western digits, like the design ("24 سبتمبر", "13").
    static let arabic = Locale(identifier: "ar@numbers=latn")
    static let posix = Locale(identifier: "en_US_POSIX")

    private static func string(_ date: Date, _ format: String, _ tz: TimeZone,
                               locale: Locale = arabic) -> String {
        let f = DateFormatter()
        f.locale = locale
        f.timeZone = tz
        f.calendar = Calendar(identifier: .gregorian)
        f.dateFormat = format
        return f.string(from: date)
    }

    static func time(_ d: Date, _ tz: TimeZone) -> String { string(d, "h:mm", tz, locale: posix) }
    static func weekday(_ d: Date, _ tz: TimeZone) -> String { string(d, "EEEE", tz) }
    /// Hijri date using the app's chosen source and moon-sighting adjustment.
    static func hijri(_ d: Date, _ tz: TimeZone) -> HijriDay {
        let settings = SharedStore.load()?.hijri ?? (.ummAlQura, 0)
        return HijriCalendar.day(for: d, timeZone: tz, source: settings.source, adjustment: settings.adjustment)
    }
    static func hijriMonth(_ d: Date, _ tz: TimeZone) -> String { hijri(d, tz).monthName }
    static func hijriDay(_ d: Date, _ tz: TimeZone) -> String { "\(hijri(d, tz).day)" }
    static func hijriNumeric(_ d: Date, _ tz: TimeZone) -> String { hijri(d, tz).numeric }
    static func gregorianDayMonth(_ d: Date, _ tz: TimeZone) -> String { string(d, "d MMMM", tz) }
    static func isoDate(_ d: Date, _ tz: TimeZone) -> String { string(d, "yyyy-MM-dd", tz, locale: posix) }

    static func isFriday(_ d: Date, _ tz: TimeZone) -> Bool {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = tz
        return cal.component(.weekday, from: d) == 6
    }

    /// "الجمعة" instead of "الظهر" on Fridays.
    static func name(_ p: PrayerTime, _ tz: TimeZone) -> String {
        p.prayer == .dhuhr && isFriday(p.date, tz) ? "الجمعة" : p.prayer.arabicName
    }

    static func nextMidnight(after d: Date, _ tz: TimeZone) -> Date {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = tz
        return cal.startOfDay(for: cal.date(byAdding: .day, value: 1, to: d) ?? d.addingTimeInterval(86_400))
    }
}

enum WidgetFont {
    /// Amiri Quran (SIL Open Font License) is bundled in Widgets/Fonts.
    /// SwiftUI falls back to the system font if it isn't found.
    static func quran(_ size: CGFloat) -> Font { .custom("Amiri Quran", size: size) }
}

extension View {
    /// Dark, subtle background. On the desktop macOS swaps this for its translucent
    /// material automatically, which gives the frosted look in the screenshot.
    func prayerWidgetBackground() -> some View {
        containerBackground(for: .widget) {
            LinearGradient(colors: [Color(white: 0.20), Color(white: 0.12)],
                           startPoint: .top, endPoint: .bottom)
        }
    }

    func arabicLayout() -> some View {
        environment(\.layoutDirection, .rightToLeft)
            .environment(\.locale, WidgetFormat.arabic)
    }
}

/// One toggleable cell in the tracking widgets: symbol, name, and a checkmark when done.
struct TrackingTile: View {
    let symbol: String
    let name: String
    let isDone: Bool

    var body: some View {
        VStack(spacing: 4) {
            ZStack(alignment: .topTrailing) {
                Image(systemName: symbol)
                    .font(.title3)
                    .foregroundStyle(isDone ? Color.accentColor : .secondary)
                if isDone {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.caption2)
                        .foregroundStyle(Color.accentColor)
                        .offset(x: 8, y: -4)
                }
            }
            Text(name)
                .font(.caption2.weight(.medium))
                .lineLimit(1)
                .minimumScaleFactor(0.7)
                .foregroundStyle(isDone ? Color.primary : .secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(.vertical, 6)
        .background(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(isDone ? Color.accentColor.opacity(0.15) : Color.white.opacity(0.06))
        )
    }
}

struct NoLocationView: View {
    var body: some View {
        VStack(spacing: 6) {
            Image(systemName: "location.slash").font(.title2).foregroundStyle(.secondary)
            Text("افتح Salawaty لتحديد موقعك")
                .font(.callout.weight(.semibold))
                .multilineTextAlignment(.center)
            Text("Open Salawaty to set your location")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
