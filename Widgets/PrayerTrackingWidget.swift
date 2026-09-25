import AppIntents
import SwiftUI
import WidgetKit

// MARK: - Intent

struct ToggleTrackingIntent: AppIntent {
    static var title: LocalizedStringResource = "Toggle Tracking Item"
    static var openAppWhenRun = false

    @Parameter(title: "Item") var itemID: String
    @Parameter(title: "Date") var dateKey: Date

    init() {}
    init(item: TrackableItem, date: Date) {
        self.itemID = item.id
        self.dateKey = date
    }

    func perform() async throws -> some IntentResult {
        if let item = TrackableItem(rawValue: itemID) {
            let tz = SharedStore.load()?.timeZone ?? .current
            PrayerTracking.toggle(item, on: dateKey, tz)
        }
        WidgetCenter.shared.reloadTimelines(ofKind: "PrayerTracking")
        return .result()
    }
}

// MARK: - Timeline

struct TrackingEntry: TimelineEntry {
    let date: Date
    let today: PrayerSchedule?
    let completed: Set<String>

    var completedPrayers: Int { TrackableItem.prayers.filter { completed.contains($0.id) }.count }
}

struct TrackingProvider: TimelineProvider {
    func placeholder(in context: Context) -> TrackingEntry {
        entry(at: Date())
    }

    func getSnapshot(in context: Context, completion: @escaping (TrackingEntry) -> Void) {
        completion(entry(at: Date()))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<TrackingEntry>) -> Void) {
        let now = Date()
        let first = entry(at: now)
        var moments = Set((first.today?.entries.map(\.date) ?? []).filter { $0 > now })
        if let tz = first.today?.timeZone {
            moments.insert(WidgetFormat.nextMidnight(after: now, tz))
        }
        let entries = [first] + moments.sorted().map(entry(at:))
        completion(Timeline(entries: entries, policy: .atEnd))
    }

    private func entry(at date: Date) -> TrackingEntry {
        let snap = SharedStore.load()
        let today = snap?.schedule(for: date)
        let tz = snap?.timeZone ?? .current
        return TrackingEntry(date: date, today: today, completed: PrayerTracking.completed(on: date, tz))
    }
}

// MARK: - Small: the five prayers

struct TrackingSmallView: View {
    let entry: TrackingEntry

    private let columns = Array(repeating: GridItem(.flexible(), spacing: 6), count: 3)

    var body: some View {
        if let today = entry.today {
            let tz = today.timeZone
            LazyVGrid(columns: columns, spacing: 6) {
                ForEach(TrackableItem.prayers) { item in
                    Button(intent: ToggleTrackingIntent(item: item, date: entry.date)) {
                        TrackingTile(symbol: item.symbol,
                                    name: WidgetFormat.name(today.entries.first { $0.prayer == item.prayer! } ??
                                                             PrayerTime(prayer: item.prayer!, date: entry.date), tz),
                                    isDone: entry.completed.contains(item.id))
                    }
                    .buttonStyle(.plain)
                }
                TrackingTile(symbol: "square.grid.2x2", name: "المزيد", isDone: false)
                    .opacity(0.6)
            }
            .arabicLayout()
        } else {
            NoLocationView()
        }
    }
}

// MARK: - Large: full checklist

struct TrackingLargeView: View {
    let entry: TrackingEntry

    private let columns = Array(repeating: GridItem(.flexible(), spacing: 6), count: 4)
    private let rows: [[TrackableItem]] = [
        [.isha, .maghrib, .asr, .dhuhr, .fajr],
        [.quran, .adhkarSleep, .adhkarEvening, .adhkarMorning],
        [.sunnahMaghrib, .sunnahDhuhrAfter, .sunnahDhuhrBefore, .sunnahFajr],
        [.witr, .duha, .qiyam, .sunnahIsha],
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("عبادات اليوم")
                    .font(.headline)
                Spacer()
                Text("\(entry.completedPrayers) / \(TrackableItem.prayers.count)")
                    .font(.subheadline.weight(.semibold).monospacedDigit())
                    .foregroundStyle(.secondary)
            }

            GeometryReader { proxy in
                let ratio = Double(entry.completedPrayers) / Double(TrackableItem.prayers.count)
                ZStack(alignment: .trailing) {
                    Capsule().fill(Color.white.opacity(0.1))
                    Capsule().fill(Color.accentColor)
                        .frame(width: proxy.size.width * max(0, min(1, ratio)))
                }
            }
            .frame(height: 4)

            LazyVGrid(columns: columns, spacing: 6) {
                ForEach(rows.flatMap { $0 }) { item in
                    Button(intent: ToggleTrackingIntent(item: item, date: entry.date)) {
                        TrackingTile(symbol: item.symbol, name: item.arabicName,
                                    isDone: entry.completed.contains(item.id))
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .arabicLayout()
    }
}

// MARK: - Widget

struct TrackingView: View {
    @Environment(\.widgetFamily) private var family
    let entry: TrackingEntry

    var body: some View {
        if entry.today == nil {
            NoLocationView()
        } else if family == .systemLarge {
            TrackingLargeView(entry: entry)
        } else {
            TrackingSmallView(entry: entry)
        }
    }
}

struct PrayerTrackingWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "PrayerTracking", provider: TrackingProvider()) { entry in
            TrackingView(entry: entry).prayerWidgetBackground()
        }
        .configurationDisplayName("متابعة العبادات · Tracking")
        .description("Track your prayers, sunnah, and adhkar for the day.")
        .supportedFamilies([.systemSmall, .systemLarge])
    }
}
