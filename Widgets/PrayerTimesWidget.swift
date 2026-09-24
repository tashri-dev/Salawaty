import SwiftUI
import WidgetKit

// MARK: - Timeline

struct PrayerEntry: TimelineEntry {
    let date: Date
    let placeName: String?
    let today: PrayerSchedule?
    let tomorrow: PrayerSchedule?

    var events: [PrayerTime] { [today, tomorrow].compactMap { $0 }.flatMap(\.entries) }

    /// Next time of any kind, including sunrise (as in the design).
    var nextEvent: PrayerTime? { events.first { $0.date > date } }

    /// Next actual prayer (skips sunrise).
    var nextPrayer: PrayerTime? { events.first { $0.prayer.isPrayer && $0.date > date } }

    /// The day whose five prayers should be listed: tomorrow once Isha has passed.
    func listedDay(for next: PrayerTime?) -> PrayerSchedule? {
        if let next, let tomorrow, tomorrow.entries.contains(next), today?.entries.contains(next) != true {
            return tomorrow
        }
        return today
    }
}

struct PrayerProvider: TimelineProvider {
    func placeholder(in context: Context) -> PrayerEntry {
        Self.entry(at: Date(), snapshot: .sample)
    }

    func getSnapshot(in context: Context, completion: @escaping (PrayerEntry) -> Void) {
        completion(Self.entry(at: Date(), snapshot: SharedStore.load() ?? .sample))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<PrayerEntry>) -> Void) {
        let now = Date()
        guard let snap = SharedStore.load() else {
            let empty = PrayerEntry(date: now, placeName: nil, today: nil, tomorrow: nil)
            completion(Timeline(entries: [empty], policy: .after(now.addingTimeInterval(3600))))
            return
        }

        // A new entry at every prayer time (so "next" moves on) and at midnight (new day).
        let first = Self.entry(at: now, snapshot: snap)
        var moments = Set(first.events.map(\.date).filter { $0 > now })
        moments.insert(WidgetFormat.nextMidnight(after: now, snap.timeZone))
        let entries = [first] + moments.sorted().map { Self.entry(at: $0, snapshot: snap) }
        completion(Timeline(entries: entries, policy: .atEnd))
    }

    static func entry(at date: Date, snapshot s: WidgetSnapshot) -> PrayerEntry {
        PrayerEntry(date: date,
                    placeName: s.placeName,
                    today: s.schedule(for: date),
                    tomorrow: s.schedule(for: date.addingTimeInterval(86_400)))
    }
}

// MARK: - Medium: all prayer times

struct PrayerTimesView: View {
    let entry: PrayerEntry

    var body: some View {
        if let today = entry.today {
            let tz = today.timeZone
            let next = entry.nextEvent
            let listed = entry.listedDay(for: next) ?? today

            VStack(alignment: .leading, spacing: 0) {
                // Header: city · weekday + Hijri date · Gregorian date
                HStack(alignment: .firstTextBaseline) {
                    Text(entry.placeName ?? "")
                        .font(.subheadline.weight(.semibold))
                        .lineLimit(1)
                    Spacer(minLength: 6)
                    Text("\(WidgetFormat.weekday(entry.date, tz))  \(WidgetFormat.hijriNumeric(entry.date, tz))")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Spacer(minLength: 6)
                    Text(WidgetFormat.isoDate(entry.date, tz))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer(minLength: 4)

                // Next time + live countdown
                if let next {
                    HStack(alignment: .firstTextBaseline, spacing: 12) {
                        Text("\(WidgetFormat.name(next, tz)) \(WidgetFormat.time(next.date, tz))")
                            .font(.title2.weight(.bold))
                            .fixedSize()
                        Text(timerInterval: entry.date...next.date, countsDown: true)
                            .font(.title3.monospacedDigit().weight(.medium))
                            .foregroundStyle(.secondary)
                            .environment(\.layoutDirection, .leftToRight)
                            .frame(maxWidth: 90, alignment: .leading)
                        Spacer(minLength: 0)
                    }
                }

                Spacer(minLength: 4)

                // Five prayers
                HStack(spacing: 0) {
                    ForEach(listed.entries.filter { $0.prayer.isPrayer }) { p in
                        let isNext = p == entry.nextPrayer
                        VStack(spacing: 2) {
                            Text(WidgetFormat.name(p, tz))
                                .font(.callout.weight(.semibold))
                            Text(WidgetFormat.time(p.date, tz))
                                .font(.callout.monospacedDigit())
                        }
                        .foregroundStyle(isNext ? Color.accentColor : Color.primary)
                        .frame(maxWidth: .infinity)
                    }
                }
            }
            .arabicLayout()
        } else {
            NoLocationView()
        }
    }
}

// MARK: - Small: next prayer

struct NextPrayerView: View {
    let entry: PrayerEntry

    var body: some View {
        if let today = entry.today, let next = entry.nextPrayer {
            let tz = today.timeZone
            VStack(alignment: .leading, spacing: 2) {
                Label(entry.placeName ?? "", systemImage: "location.fill")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                Spacer(minLength: 0)
                Text("الصلاة القادمة")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text(WidgetFormat.name(next, tz))
                    .font(.title.weight(.bold))
                Text(WidgetFormat.time(next.date, tz))
                    .font(.title3.monospacedDigit().weight(.medium))
                Text(timerInterval: entry.date...next.date, countsDown: true)
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(.secondary)
                    .environment(\.layoutDirection, .leftToRight)
                    .frame(maxWidth: .infinity, alignment: .trailing)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .arabicLayout()
        } else {
            NoLocationView()
        }
    }
}

// MARK: - Widgets

struct PrayerTimesWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "PrayerTimes", provider: PrayerProvider()) { entry in
            PrayerTimesView(entry: entry).prayerWidgetBackground()
        }
        .configurationDisplayName("مواقيت الصلاة · Prayer Times")
        .description("Today's prayer times with a countdown to the next one.")
        .supportedFamilies([.systemMedium])
    }
}

struct NextPrayerWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "NextPrayer", provider: PrayerProvider()) { entry in
            NextPrayerView(entry: entry).prayerWidgetBackground()
        }
        .configurationDisplayName("الصلاة القادمة · Next Prayer")
        .description("The next prayer and a live countdown.")
        .supportedFamilies([.systemSmall])
    }
}
