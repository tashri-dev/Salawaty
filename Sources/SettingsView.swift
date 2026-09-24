import AppKit
import ServiceManagement
import SwiftUI

struct SettingsView: View {
    @EnvironmentObject private var location: LocationService
    @EnvironmentObject private var state: AppState
    let onDone: () -> Void

    // Adhan
    @AppStorage(PrefKey.adhanSound) private var adhanSound = ""
    @AppStorage(PrefKey.adhanFajrSound) private var adhanFajrSound = ""
    @AppStorage(PrefKey.adhanVolume) private var adhanVolume = 0.8
    @State private var sounds: [AdhanSound] = []

    // Seasonal audio
    @AppStorage(PrefKey.seasonalEnabled(.eid)) private var seasonalEidEnabled = false
    @AppStorage(PrefKey.seasonalEnabled(.hajj)) private var seasonalHajjEnabled = false
    @AppStorage(PrefKey.seasonalEidSound) private var seasonalEidSound = ""
    @AppStorage(PrefKey.seasonalIntervalMinutes) private var seasonalInterval = 60

    // Iqamah
    @AppStorage(PrefKey.iqamahAlerts) private var iqamahAlerts = true
    @AppStorage(PrefKey.jumuahOffset) private var jumuahOffset = Iqamah.defaultJumuahOffset

    // Location
    @AppStorage(PrefKey.useDeviceLocation) private var useDevice = true
    @AppStorage(PrefKey.manualName) private var manualName = ""
    @State private var cityQuery = ""
    @State private var searching = false
    @State private var searchMessage: String?

    // Hijri
    @AppStorage(PrefKey.hijriSource) private var hijriSource = HijriSource.ummAlQura.rawValue
    @AppStorage(PrefKey.hijriAdjustment) private var hijriAdjustment = 0

    // Calculation
    @AppStorage(PrefKey.method) private var method = CalculationMethod.mwl.rawValue
    @AppStorage(PrefKey.asrMethod) private var asr = AsrMethod.standard.rawValue
    @AppStorage(PrefKey.highLatitudeRule) private var highLat = HighLatitudeRule.angleBased.rawValue

    // Notifications
    @AppStorage(PrefKey.prayerAlerts) private var prayerAlerts = true
    @AppStorage(PrefKey.alertMinutesBefore) private var minutesBefore = 0
    @AppStorage(PrefKey.morningEveningReminder) private var morningEvening = true

    // Adhkar
    @AppStorage(PrefKey.dhikrInterval) private var interval = 60
    @AppStorage(PrefKey.dhikrNotify) private var dhikrNotify = true
    @AppStorage(PrefKey.showTranslation) private var showTranslation = true
    @AppStorage(DhikrCategory.dhikr.prefKey) private var catDhikr = true
    @AppStorage(DhikrCategory.dua.prefKey) private var catDua = true
    @AppStorage(DhikrCategory.quran.prefKey) private var catQuran = true

    // General
    @AppStorage(PrefKey.menuCountdown) private var menuCountdown = true
    @AppStorage(PrefKey.menuArabicNames) private var menuArabic = false
    @AppStorage(PrefKey.menuIqamahName) private var menuIqamahName = false
    @State private var launchAtLogin = SMAppService.mainApp.status == .enabled

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Button(action: onDone) { Label("Back", systemImage: "chevron.left") }
                    .buttonStyle(.borderless)
                Spacer()
                Text("Settings").font(.headline)
                Spacer()
                Color.clear.frame(width: 50, height: 1)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)

            Form {
                locationSection
                adhanSection
                seasonalSection
                iqamahSection
                hijriSection

                Section("Calculation") {
                    Picker("Method", selection: $method) {
                        ForEach(CalculationMethod.allCases) { Text($0.title).tag($0.rawValue) }
                    }
                    Picker("Asr", selection: $asr) {
                        ForEach(AsrMethod.allCases) { Text($0.title).tag($0.rawValue) }
                    }
                    Picker("High latitudes", selection: $highLat) {
                        ForEach(HighLatitudeRule.allCases) { Text($0.title).tag($0.rawValue) }
                    }
                }

                Section("Notifications") {
                    Toggle("Alert at prayer times", isOn: $prayerAlerts)
                    Picker("Early reminder", selection: $minutesBefore) {
                        Text("Off").tag(0)
                        ForEach([5, 10, 15, 20, 30], id: \.self) { Text("\($0) min before").tag($0) }
                    }
                    .disabled(!prayerAlerts)
                    Toggle("Morning & evening adhkar reminder", isOn: $morningEvening)
                }

                Section("Adhkar, duas & Quran") {
                    Picker("Show a new one every", selection: $interval) {
                        Text("Off").tag(0)
                        Text("15 minutes").tag(15)
                        Text("30 minutes").tag(30)
                        Text("1 hour").tag(60)
                        Text("2 hours").tag(120)
                        Text("3 hours").tag(180)
                        Text("6 hours").tag(360)
                    }
                    Toggle("Send as a notification", isOn: $dhikrNotify)
                        .disabled(interval == 0)
                    Toggle(DhikrCategory.dhikr.settingsTitle, isOn: $catDhikr)
                    Toggle(DhikrCategory.dua.settingsTitle, isOn: $catDua)
                    Toggle(DhikrCategory.quran.settingsTitle, isOn: $catQuran)
                    Toggle("Show English meaning", isOn: $showTranslation)
                }

                Section("Menu bar") {
                    Toggle("Show countdown (instead of time)", isOn: $menuCountdown)
                    Toggle("Arabic prayer names", isOn: $menuArabic)
                    Toggle("Show prayer name with iqamah countdown", isOn: $menuIqamahName)
                    Toggle("Launch at login", isOn: $launchAtLogin)
                        .onChange(of: launchAtLogin) { on in
                            do {
                                if on { try SMAppService.mainApp.register() }
                                else { try SMAppService.mainApp.unregister() }
                            } catch {
                                launchAtLogin = SMAppService.mainApp.status == .enabled
                            }
                        }
                }
            }
            .formStyle(.grouped)
        }
        .frame(height: 560)
        .onAppear { sounds = AdhanLibrary.availableSounds() }
    }

    // MARK: Adhan

    private var adhanSection: some View {
        Section("Adhan · الأذان") {
            if sounds.isEmpty {
                Text("No adhan recordings yet. Tap “Add Sound…” to import MP3/M4A files of your favourite sheikhs.")
                    .font(.caption)
                    .foregroundStyle(.orange)
            }
            Picker("Reciter", selection: $adhanSound) {
                Text("Automatic").tag("")
                ForEach(sounds.filter { !$0.isFajr }) { Text($0.title).tag($0.id) }
            }
            Picker("Fajr adhan", selection: $adhanFajrSound) {
                Text("Same reciter (Fajr version if available)").tag("")
                ForEach(sounds) { Text($0.title).tag($0.id) }
            }
            HStack {
                Image(systemName: "speaker.fill").foregroundStyle(.secondary)
                Slider(value: $adhanVolume, in: 0...1)
                    .onChange(of: adhanVolume) { state.player.setVolume(Float($0)) }
                Image(systemName: "speaker.wave.3.fill").foregroundStyle(.secondary)
            }

            VStack(alignment: .leading, spacing: 6) {
                Text("Play adhan for").font(.caption).foregroundStyle(.secondary)
                LazyVGrid(columns: Array(repeating: GridItem(.flexible(), alignment: .leading), count: 3),
                          alignment: .leading, spacing: 6) {
                    ForEach(Prayer.allCases.filter(\.isPrayer)) { AdhanPrayerToggle(prayer: $0) }
                }
            }

            HStack {
                Button(state.player.isPlaying ? "Stop" : "Preview") {
                    if state.player.isPlaying {
                        state.player.stop()
                    } else if let sound = AdhanLibrary.sound(for: .dhuhr, in: sounds) {
                        state.player.play(sound, volume: Float(adhanVolume), label: "Preview")
                    }
                }
                .disabled(sounds.isEmpty && !state.player.isPlaying)
                Spacer()
                Button("Add Sound…") {
                    if let added = AdhanLibrary.importSounds() {
                        sounds = AdhanLibrary.availableSounds()
                        if !added.isFajr { UserDefaults.standard.set(added.id, forKey: PrefKey.adhanSound) }
                    }
                }
                Button {
                    NSWorkspace.shared.open(AdhanLibrary.userFolder)
                } label: { Image(systemName: "folder") }
                .help("Open the sounds folder")
            }
        }
    }

    // MARK: Seasonal audio

    private var seasonalSection: some View {
        Section("Seasonal audio") {
            Toggle(SeasonalCategory.eid.title, isOn: $seasonalEidEnabled)
            if seasonalEidEnabled {
                Picker("Recording", selection: $seasonalEidSound) {
                    Text("Automatic").tag("")
                    ForEach(sounds.filter { SeasonalOccasion.eidFitr.candidateSoundIds.contains($0.id) }) {
                        Text($0.title).tag($0.id)
                    }
                }
            }
            Toggle(SeasonalCategory.hajj.title, isOn: $seasonalHajjEnabled)
            if seasonalEidEnabled || seasonalHajjEnabled {
                Picker("Repeat every", selection: $seasonalInterval) {
                    Text("30 minutes").tag(30)
                    Text("1 hour").tag(60)
                    Text("2 hours").tag(120)
                    Text("3 hours").tag(180)
                }
            }
            Text("Plays occasionally in the background on Eid and during Hajj days — never continuously.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    // MARK: Hijri date

    private var hijriSection: some View {
        let source = HijriSource(rawValue: hijriSource) ?? .ummAlQura
        let today = HijriCalendar.day(for: Date(), timeZone: state.place?.timeZone ?? .current,
                                      source: source, adjustment: hijriAdjustment)
        return Section("Hijri date · التاريخ الهجري") {
            Picker("Source", selection: $hijriSource) {
                ForEach(HijriSource.allCases) { Text($0.title).tag($0.rawValue) }
            }
            Stepper(value: $hijriAdjustment, in: -2...2) {
                Text(hijriAdjustment == 0 ? "Adjustment: none"
                     : "Adjustment: \(hijriAdjustment > 0 ? "+" : "")\(hijriAdjustment) day\(abs(hijriAdjustment) == 1 ? "" : "s")")
            }
            HStack {
                Text("Today")
                Spacer()
                Text(today.long).foregroundStyle(.secondary)
            }
            if source.apiMethod != nil {
                HStack {
                    Text(state.hijriStatus ?? "").font(.caption).foregroundStyle(.secondary)
                    Spacer()
                    Button("Update Now") { state.refreshHijri(force: true) }
                        .font(.caption)
                }
            }
            Text("If your country announced the start of the month a day earlier or later after the moon sighting, adjust by that many days here.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    // MARK: Iqamah

    private var iqamahSection: some View {
        Section("Iqamah · الإقامة") {
            Toggle("Notify at iqamah time", isOn: $iqamahAlerts)
            ForEach(Prayer.allCases.filter(\.isPrayer)) { IqamahRow(prayer: $0) }
            HStack {
                Text("Jumu'ah").frame(width: 60, alignment: .leading)
                Text("After adhan").foregroundStyle(.secondary)
                Spacer()
                Stepper(jumuahOffset == 0 ? "Off" : "\(jumuahOffset) min",
                        value: $jumuahOffset, in: 0...90)
            }
            Text("Set 0 min to turn the iqamah timer off for a prayer.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    // MARK: Location

    private var locationSection: some View {
        Section("Location") {
            Toggle("Use this Mac's location", isOn: $useDevice)

            if useDevice {
                switch location.status {
                case .notDetermined:
                    Button("Allow Location Access") { location.requestPermission() }
                case .denied, .restricted:
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Location access is denied — the city below is used instead.")
                            .font(.caption).foregroundStyle(.orange)
                        Button("Open Privacy Settings") {
                            if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_LocationServices") {
                                NSWorkspace.shared.open(url)
                            }
                        }
                    }
                default:
                    Label("Following your location automatically", systemImage: "checkmark.circle.fill")
                        .foregroundStyle(.green)
                }
            }

            HStack {
                TextField("City, e.g. Cairo, Egypt", text: $cityQuery)
                    .textFieldStyle(.roundedBorder)
                    .onSubmit(search)
                if searching {
                    ProgressView().controlSize(.small)
                } else {
                    Button("Set", action: search)
                        .disabled(cityQuery.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
            if let searchMessage {
                Text(searchMessage).font(.caption).foregroundStyle(.secondary)
            } else if !manualName.isEmpty {
                Text("Saved city: \(manualName)").font(.caption).foregroundStyle(.secondary)
            }
        }
    }

    private func search() {
        let q = cityQuery.trimmingCharacters(in: .whitespaces)
        guard !q.isEmpty else { return }
        searching = true
        searchMessage = nil
        location.setManualLocation(query: q) { result in
            searching = false
            switch result {
            case .success(let name):
                searchMessage = String(localized: "Location set to \(name)")
                cityQuery = ""
            case .failure:
                searchMessage = String(localized: "Couldn't find that place. Try “City, Country”.")
            }
        }
    }
}

// MARK: - Rows

private struct AdhanPrayerToggle: View {
    let prayer: Prayer
    @AppStorage private var isOn: Bool

    init(prayer: Prayer) {
        self.prayer = prayer
        _isOn = AppStorage(wrappedValue: true, PrefKey.adhanEnabled(prayer))
    }

    var body: some View {
        Toggle(prayer.englishName, isOn: $isOn).toggleStyle(.checkbox)
    }
}

private struct IqamahRow: View {
    let prayer: Prayer
    @AppStorage private var offset: Int
    @AppStorage private var fixed: Int

    init(prayer: Prayer) {
        self.prayer = prayer
        _offset = AppStorage(wrappedValue: Iqamah.defaultOffset(prayer), PrefKey.iqamahOffset(prayer))
        _fixed = AppStorage(wrappedValue: -1, PrefKey.iqamahFixed(prayer))
    }

    private var isFixed: Binding<Bool> {
        Binding(get: { fixed >= 0 },
                set: { fixed = $0 ? Iqamah.defaultFixed(prayer) : -1 })
    }

    /// Stored as minutes after midnight; shown with a time picker.
    private var fixedTime: Binding<Date> {
        Binding(
            get: { Calendar.current.startOfDay(for: Date()).addingTimeInterval(Double(max(fixed, 0)) * 60) },
            set: {
                let c = Calendar.current.dateComponents([.hour, .minute], from: $0)
                fixed = (c.hour ?? 0) * 60 + (c.minute ?? 0)
            })
    }

    var body: some View {
        HStack {
            Text(prayer.englishName).frame(width: 60, alignment: .leading)
            Picker("", selection: isFixed) {
                Text("After adhan").tag(false)
                Text("Fixed time").tag(true)
            }
            .labelsHidden()
            .fixedSize()
            Spacer()
            if fixed >= 0 {
                DatePicker("", selection: fixedTime, displayedComponents: .hourAndMinute)
                    .labelsHidden()
            } else {
                Stepper(offset == 0 ? "Off" : "\(offset) min", value: $offset, in: 0...90)
            }
        }
    }
}
