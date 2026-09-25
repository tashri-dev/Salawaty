import AppKit
import SwiftUI

@main
struct SalawatyApp: App {
    @StateObject private var state: AppState

    init() {
        Prefs.registerDefaults()
        _state = StateObject(wrappedValue: AppState())
    }

    var body: some Scene {
        MenuBarExtra {
            MenuContentView()
                .environmentObject(state)
                .environmentObject(state.location)
        } label: {
            if let icon = state.menuBarIcon {
                Text("\(Image(systemName: icon)) \(state.menuBarTitle)")
                    .monospacedDigit()
            } else {
                Text(state.menuBarTitle)
                    .monospacedDigit()
            }
        }
        .menuBarExtraStyle(.window)
    }
}

// MARK: - Popover

struct MenuContentView: View {
    @EnvironmentObject private var state: AppState
    @EnvironmentObject private var location: LocationService
    @State private var showingSettings = false

    var body: some View {
        Group {
            if showingSettings {
                SettingsView { showingSettings = false }
            } else {
                main
            }
        }
        .frame(width: 340)
    }

    private var main: some View {
        VStack(alignment: .leading, spacing: 12) {
            header

            if let update = state.updateAvailable {
                UpdateAvailableCard(update: update, onDismiss: state.dismissUpdateBanner)
            }

            if let days = state.daysUntilRamadan {
                RamadanCountdownCard(days: days)
            }

            if let occasion = state.seasonalPrompt {
                SeasonalPromptCard(occasion: occasion) { allow in
                    state.answerSeasonalPrompt(occasion, allow: allow)
                }
            }

            if state.player.isPlaying {
                AdhanPlayingCard(title: state.player.nowPlaying ?? "", onStop: state.stopAdhan)
            }

            if let today = state.today {
                if let iqamah = state.activeIqamah {
                    IqamahCard(countdown: iqamah)
                }
                if let next = state.nextPrayer {
                    NextPrayerCard(next: next, timeZone: today.timeZone)
                }
                VStack(spacing: 2) {
                    ForEach(today.entries) { entry in
                        PrayerRow(entry: entry,
                                  timeZone: today.timeZone,
                                  iqamah: Iqamah.date(for: entry, timeZone: today.timeZone),
                                  isNext: entry == state.nextPrayer,
                                  isPast: entry.date <= state.now)
                    }
                }
            } else {
                missingLocationCard
            }

            if !Prefs.enabledCategories.isEmpty {
                DhikrCard(item: state.dhikr, onNext: state.showNextDhikr)
            }

            Divider()
            footer
        }
        .padding(14)
    }

    private var header: some View {
        let tz = state.place?.timeZone ?? .current
        return HStack(alignment: .top, spacing: 8) {
            VStack(alignment: .leading, spacing: 3) {
                Label(state.place?.name ?? "No location set",
                      systemImage: state.place?.isDevice == true ? "location.fill" : "mappin.and.ellipse")
                    .font(.headline)
                    .lineLimit(1)
                Text(Format.gregorian(state.now, tz))
                    .font(.caption).foregroundStyle(.secondary)
                Text(Format.hijri(state.now, tz))
                    .font(.caption).foregroundStyle(.secondary)
            }
            Spacer(minLength: 4)
            if location.isLocating {
                ProgressView().controlSize(.small)
            }
            Button { showingSettings = true } label: {
                Image(systemName: "gearshape")
            }
            .buttonStyle(.borderless)
            .help("Settings")
        }
    }

    private var missingLocationCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            if Prefs.useDeviceLocation && location.status == .notDetermined {
                Text("Salawaty needs your location to calculate prayer times.")
                Button("Allow Location Access") { location.requestPermission() }
                Button("Enter a city instead") { showingSettings = true }.buttonStyle(.link)
            } else if Prefs.useDeviceLocation && location.isAuthorized {
                Text("Finding your location…")
                Button("Enter a city instead") { showingSettings = true }.buttonStyle(.link)
            } else {
                Text(location.isDenied && Prefs.useDeviceLocation
                     ? "Location access is off. Enter your city to see prayer times."
                     : "Enter your city to see prayer times.")
                Button("Set City…") { showingSettings = true }
            }
        }
        .font(.callout)
        .padding(10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: 8).fill(Color.primary.opacity(0.05)))
    }

    private var footer: some View {
        HStack {
            if Prefs.useDeviceLocation && location.isAuthorized {
                Button { location.refresh() } label: {
                    Label("Refresh Location", systemImage: "location")
                }
            }
            Spacer()
            Button("Quit") { NSApp.terminate(nil) }
        }
        .buttonStyle(.borderless)
        .font(.callout)
    }
}

// MARK: - Components

struct NextPrayerCard: View {
    let next: PrayerTime
    let timeZone: TimeZone

    var body: some View {
        TimelineView(.periodic(from: .now, by: 1)) { context in
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Next prayer").font(.caption).foregroundStyle(.secondary)
                    Text("\(Iqamah.englishName(next, timeZone)) · \(Iqamah.arabicName(next, timeZone))")
                        .font(.title3.weight(.semibold))
                }
                Spacer()
                Text(Format.clock(next.date.timeIntervalSince(context.date)))
                    .font(.title2.monospacedDigit().weight(.medium))
            }
        }
        .padding(12)
        .background(RoundedRectangle(cornerRadius: 10).fill(Color.accentColor.opacity(0.15)))
    }
}

struct PrayerRow: View {
    let entry: PrayerTime
    let timeZone: TimeZone
    let iqamah: Date?
    let isNext: Bool
    let isPast: Bool

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: entry.prayer.symbol).frame(width: 18)
            Text(Iqamah.englishName(entry, timeZone))
            Spacer()
            Text(Iqamah.arabicName(entry, timeZone)).foregroundStyle(.secondary)
            VStack(alignment: .trailing, spacing: 0) {
                Text(Format.time(entry.date, timeZone)).monospacedDigit()
                if let iqamah {
                    Text("Iqamah \(Format.time(iqamah, timeZone))")
                        .font(.caption2.weight(.regular))
                        .foregroundStyle(.secondary)
                        .monospacedDigit()
                }
            }
            .frame(width: 100, alignment: .trailing)
        }
        .font(isNext ? .body.weight(.semibold) : .body)
        .padding(.vertical, 5)
        .padding(.horizontal, 8)
        .background(RoundedRectangle(cornerRadius: 6).fill(isNext ? Color.accentColor.opacity(0.18) : .clear))
        .opacity(isPast && !isNext ? 0.5 : 1)
    }
}

struct AdhanPlayingCard: View {
    let title: String
    let onStop: () -> Void

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: "speaker.wave.2.fill")
                .font(.title2)
                .foregroundStyle(.orange)
            VStack(alignment: .leading, spacing: 2) {
                Text("Adhan · الأذان").font(.caption).foregroundStyle(.secondary)
                Text(title).font(.headline)
            }
            Spacer()
            Button("Stop", action: onStop)
                .keyboardShortcut(.cancelAction)
        }
        .padding(12)
        .background(RoundedRectangle(cornerRadius: 10).fill(Color.orange.opacity(0.15)))
    }
}

struct UpdateAvailableCard: View {
    let update: UpdateInfo
    let onDismiss: () -> Void

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: "arrow.down.circle.fill")
                .font(.title2)
                .foregroundStyle(.blue)
            VStack(alignment: .leading, spacing: 2) {
                Text("Update available").font(.caption).foregroundStyle(.secondary)
                Text(update.version).font(.headline)
            }
            Spacer()
            Button("Dismiss", action: onDismiss)
                .buttonStyle(.borderless)
            Button("View") { NSWorkspace.shared.open(update.url) }
        }
        .padding(12)
        .background(RoundedRectangle(cornerRadius: 10).fill(Color.blue.opacity(0.15)))
    }
}

struct RamadanCountdownCard: View {
    let days: Int

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: "moon.stars")
                .font(.title2)
                .foregroundStyle(.teal)
            VStack(alignment: .leading, spacing: 2) {
                Text("Ramadan · رمضان").font(.caption).foregroundStyle(.secondary)
                if days == 1 {
                    Text("Starts tomorrow").font(.headline)
                } else {
                    Text("Starts in \(days) days").font(.headline)
                }
            }
            Spacer()
        }
        .padding(12)
        .background(RoundedRectangle(cornerRadius: 10).fill(Color.teal.opacity(0.15)))
    }
}

struct SeasonalPromptCard: View {
    let occasion: SeasonalOccasion
    let onAnswer: (Bool) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(occasion.promptTitle).font(.headline)
            Text(occasion.promptBody)
                .font(.callout)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
            HStack {
                Spacer()
                Button("Not now") { onAnswer(false) }
                Button("Allow") { onAnswer(true) }
                    .keyboardShortcut(.defaultAction)
            }
        }
        .padding(12)
        .background(RoundedRectangle(cornerRadius: 10).fill(Color.purple.opacity(0.15)))
    }
}

struct IqamahCard: View {
    let countdown: IqamahCountdown

    var body: some View {
        TimelineView(.periodic(from: .now, by: 1)) { context in
            let total = max(countdown.iqamah.timeIntervalSince(countdown.adhan.date), 1)
            let left = countdown.iqamah.timeIntervalSince(context.date)
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Iqamah · الإقامة").font(.caption).foregroundStyle(.secondary)
                        Text("\(countdown.englishName) · \(countdown.arabicName)")
                            .font(.title3.weight(.semibold))
                    }
                    Spacer()
                    Text(Format.clock(left))
                        .font(.title2.monospacedDigit().weight(.medium))
                }
                ProgressView(value: min(max(1 - left / total, 0), 1))
                    .tint(.green)
                Text(Iqamah.dua)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .trailing)
            }
        }
        .padding(12)
        .background(RoundedRectangle(cornerRadius: 10).fill(Color.green.opacity(0.15)))
    }
}

struct DhikrCard: View {
    let item: DhikrItem
    let onNext: () -> Void
    @AppStorage(PrefKey.showTranslation) private var showTranslation = true

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(item.category.title)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                Spacer()
                Button {
                    NSPasteboard.general.clearContents()
                    NSPasteboard.general.setString(item.arabic, forType: .string)
                } label: { Image(systemName: "doc.on.doc") }
                .help("Copy")
                Button(action: onNext) { Image(systemName: "arrow.clockwise") }
                    .help("Show another")
            }
            .buttonStyle(.borderless)

            Text(item.arabic)
                .font(.system(size: 18))
                .multilineTextAlignment(.trailing)
                .frame(maxWidth: .infinity, alignment: .trailing)
                .fixedSize(horizontal: false, vertical: true)

            if showTranslation, let localized = item.localizedTranslation {
                Text(localized)
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Text(item.source).font(.caption2).foregroundStyle(.tertiary)
        }
        .textSelection(.enabled)
        .padding(10)
        .background(RoundedRectangle(cornerRadius: 8).fill(Color.primary.opacity(0.05)))
    }
}
