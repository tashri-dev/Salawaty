import AppIntents
import SwiftUI
import WidgetKit

// MARK: - Configuration (right-click the widget → Edit)

enum VerseContent: String, AppEnum {
    case quran, dhikr, dua, all

    static var typeDisplayRepresentation: TypeDisplayRepresentation = "Content"
    static var caseDisplayRepresentations: [VerseContent: DisplayRepresentation] = [
        .quran: "Quran verses · آيات",
        .dhikr: "Adhkar · أذكار",
        .dua: "Duas · أدعية",
        .all: "All · الكل",
    ]

    var categories: Set<DhikrCategory> {
        switch self {
        case .quran: return [.quran]
        case .dhikr: return [.dhikr]
        case .dua: return [.dua]
        case .all: return Set(DhikrCategory.allCases)
        }
    }
}

enum VerseInterval: Int, AppEnum {
    case fifteen = 15, thirty = 30, hour = 60, threeHours = 180, sixHours = 360, day = 1440

    static var typeDisplayRepresentation: TypeDisplayRepresentation = "Change every"
    static var caseDisplayRepresentations: [VerseInterval: DisplayRepresentation] = [
        .fifteen: "15 minutes", .thirty: "30 minutes", .hour: "1 hour",
        .threeHours: "3 hours", .sixHours: "6 hours", .day: "Day",
    ]
}

struct VerseIntent: WidgetConfigurationIntent {
    static var title: LocalizedStringResource = "Verse & Dhikr"
    static var description = IntentDescription("Shows a Quran verse, dhikr or dua that changes during the day.")

    @Parameter(title: "Content", default: .quran)
    var content: VerseContent

    @Parameter(title: "Change every", default: .hour)
    var interval: VerseInterval

    @Parameter(title: "Show English meaning", default: false)
    var showTranslation: Bool
}

// MARK: - Timeline

struct VerseEntry: TimelineEntry {
    let date: Date
    let item: DhikrItem
    let showTranslation: Bool
}

struct VerseProvider: AppIntentTimelineProvider {
    func placeholder(in context: Context) -> VerseEntry {
        VerseEntry(date: Date(), item: Self.pick(for: Date(), content: .quran, minutes: 60), showTranslation: false)
    }

    func snapshot(for configuration: VerseIntent, in context: Context) async -> VerseEntry {
        let now = Date()
        return VerseEntry(date: now,
                          item: Self.pick(for: now, content: configuration.content, minutes: configuration.interval.rawValue),
                          showTranslation: configuration.showTranslation)
    }

    /// Precomputes the next 24 changes, each starting exactly on its slot boundary.
    func timeline(for configuration: VerseIntent, in context: Context) async -> Timeline<VerseEntry> {
        let seconds = Double(configuration.interval.rawValue * 60)
        let now = Date()
        let slotStart = Date(timeIntervalSince1970: floor(now.timeIntervalSince1970 / seconds) * seconds)

        let entries = (0..<24).map { i -> VerseEntry in
            let date = i == 0 ? now : slotStart.addingTimeInterval(Double(i) * seconds)
            return VerseEntry(date: date,
                              item: Self.pick(for: date, content: configuration.content,
                                              minutes: configuration.interval.rawValue),
                              showTranslation: configuration.showTranslation)
        }
        return Timeline(entries: entries, policy: .atEnd)
    }

    /// Stable, shuffled pick: the same slot always shows the same item,
    /// and consecutive slots don't walk through the list in order.
    static func pick(for date: Date, content: VerseContent, minutes: Int) -> DhikrItem {
        let pool = AdhkarLibrary.all.filter { content.categories.contains($0.category) }
        guard !pool.isEmpty else { return AdhkarLibrary.all[0] }
        let slot = UInt64(max(0, date.timeIntervalSince1970 / Double(minutes * 60)))
        let mixed = (slot &* 2_654_435_761) ^ (slot >> 7)
        return pool[Int(mixed % UInt64(pool.count))]
    }
}

// MARK: - View

struct VerseView: View {
    @Environment(\.widgetFamily) private var family
    let entry: VerseEntry

    private var text: String {
        entry.item.category == .quran ? "﴿ \(entry.item.arabic) ﴾" : entry.item.arabic
    }

    private var fontSize: CGFloat {
        switch family {
        case .systemSmall: return 17
        case .systemLarge: return 30
        default: return 24
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Spacer(minLength: 0)
            Text(text)
                .font(WidgetFont.quran(fontSize))
                .multilineTextAlignment(.center)
                .lineSpacing(6)
                .minimumScaleFactor(0.45)
                .frame(maxWidth: .infinity)
            if entry.showTranslation && family != .systemSmall {
                Text(entry.item.translation)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .minimumScaleFactor(0.7)
                    .frame(maxWidth: .infinity)
                    .environment(\.layoutDirection, .leftToRight)
            }
            Spacer(minLength: 0)
            HStack {
                Spacer()
                Text(entry.item.arabicSource)
                    .font(.caption2.weight(.medium))
                    .foregroundStyle(.secondary)
            }
        }
        .arabicLayout()
    }
}

struct VerseWidget: Widget {
    var body: some WidgetConfiguration {
        AppIntentConfiguration(kind: "Verse", intent: VerseIntent.self, provider: VerseProvider()) { entry in
            VerseView(entry: entry).prayerWidgetBackground()
        }
        .configurationDisplayName("آية وذكر · Verse & Dhikr")
        .description("A Quran verse, dhikr or dua that changes through the day.")
        .supportedFamilies([.systemSmall, .systemMedium, .systemLarge])
    }
}
