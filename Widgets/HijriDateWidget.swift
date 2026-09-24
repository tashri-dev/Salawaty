import SwiftUI
import WidgetKit

struct HijriEntry: TimelineEntry {
    let date: Date
    let timeZone: TimeZone
}

struct HijriProvider: TimelineProvider {
    func placeholder(in context: Context) -> HijriEntry {
        HijriEntry(date: Date(), timeZone: .current)
    }

    func getSnapshot(in context: Context, completion: @escaping (HijriEntry) -> Void) {
        completion(HijriEntry(date: Date(), timeZone: SharedStore.load()?.timeZone ?? .current))
    }

    /// One entry now and one at each of the next 7 midnights.
    func getTimeline(in context: Context, completion: @escaping (Timeline<HijriEntry>) -> Void) {
        let tz = SharedStore.load()?.timeZone ?? .current
        var entries = [HijriEntry(date: Date(), timeZone: tz)]
        var day = Date()
        for _ in 0..<7 {
            day = WidgetFormat.nextMidnight(after: day, tz)
            entries.append(HijriEntry(date: day, timeZone: tz))
        }
        completion(Timeline(entries: entries, policy: .atEnd))
    }
}

struct HijriDateView: View {
    let entry: HijriEntry

    var body: some View {
        let d = entry.date, tz = entry.timeZone
        VStack(spacing: 4) {
            Text("\(WidgetFormat.weekday(d, tz)) \(WidgetFormat.hijriMonth(d, tz))")
                .font(.callout.weight(.bold))
                .lineLimit(1)
                .minimumScaleFactor(0.7)
            Text(WidgetFormat.hijriDay(d, tz))
                .font(.system(size: 64, weight: .bold, design: .rounded))
                .minimumScaleFactor(0.6)
                .lineLimit(1)
            Text(WidgetFormat.gregorianDayMonth(d, tz))
                .font(.callout.weight(.semibold))
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .arabicLayout()
    }
}

struct HijriDateWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "HijriDate", provider: HijriProvider()) { entry in
            HijriDateView(entry: entry).prayerWidgetBackground()
        }
        .configurationDisplayName("التاريخ الهجري · Hijri Date")
        .description("Today's Hijri date with the Gregorian date.")
        .supportedFamilies([.systemSmall])
    }
}
