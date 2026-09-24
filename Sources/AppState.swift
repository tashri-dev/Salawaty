import AppKit
import Combine
import Foundation
import WidgetKit

final class AppState: ObservableObject {
    @Published private(set) var today: PrayerSchedule?
    @Published private(set) var tomorrow: PrayerSchedule?
    @Published private(set) var now = Date()
    @Published private(set) var dhikr: DhikrItem
    @Published private(set) var place: ResolvedLocation?
    /// Shown in Settings when an online Hijri source is selected.
    @Published private(set) var hijriStatus: String?
    /// Non-nil while a seasonal-audio consent banner should be shown in the popover.
    @Published private(set) var seasonalPrompt: SeasonalOccasion?
    /// Days until the next Ramadan starts, nil during Ramadan itself.
    @Published private(set) var daysUntilRamadan: Int?

    let location = LocationService()
    let player = AdhanPlayer()
    private let notifications = NotificationService()
    private var cancellables = Set<AnyCancellable>()
    private var clockTimer: Timer?
    private var eventTimer: Timer?
    private var dhikrTimer: Timer?
    private var seasonalTimer: Timer?
    private var seasonalTimerCategory: SeasonalCategory?
    private var lastSeasonalOccasion: SeasonalOccasion?
    private var lastSeasonalInterval: Int
    private var lastHijriYear: Int?
    private var lastUseDevice: Bool
    private var lastInterval: Int
    private var lastHijriSource: HijriSource
    private var lastEventCheck = Date()

    init() {
        dhikr = AdhkarLibrary.random(in: Prefs.enabledCategories) ?? AdhkarLibrary.all[0]
        lastUseDevice = Prefs.useDeviceLocation
        lastInterval = Prefs.dhikrInterval
        lastHijriSource = Prefs.hijriSource
        lastSeasonalInterval = Prefs.seasonalIntervalMinutes

        location.$resolved
            .removeDuplicates()
            .sink { [weak self] place in
                self?.place = place
                self?.recompute()
            }
            .store(in: &cancellables)

        // Let views that observe AppState also refresh when playback starts/stops.
        player.objectWillChange
            .sink { [weak self] _ in self?.objectWillChange.send() }
            .store(in: &cancellables)

        NotificationCenter.default.publisher(for: UserDefaults.didChangeNotification)
            .debounce(for: .milliseconds(300), scheduler: RunLoop.main)
            .sink { [weak self] _ in self?.preferencesChanged() }
            .store(in: &cancellables)

        NSWorkspace.shared.notificationCenter.publisher(for: NSWorkspace.didWakeNotification)
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in
                self?.location.refresh()
                self?.recompute()
                self?.refreshHijri(force: false)
            }
            .store(in: &cancellables)

        let clock = Timer(timeInterval: 10, repeats: true) { [weak self] _ in self?.tick() }
        RunLoop.main.add(clock, forMode: .common)
        clockTimer = clock

        // Checks every second whether an adhan or iqamah moment has just passed.
        let events = Timer(timeInterval: 1, repeats: true) { [weak self] _ in self?.checkEvents() }
        RunLoop.main.add(events, forMode: .common)
        eventTimer = events

        notifications.requestAuthorization()
        location.start()
        rebuildDhikrTimer()
        refreshHijri(force: false)
    }

    // MARK: Derived values

    private var allEntries: [PrayerTime] {
        [today, tomorrow].compactMap { $0 }.flatMap(\.entries)
    }

    var nextPrayer: PrayerTime? {
        allEntries.first { $0.prayer.isPrayer && $0.date > now }
    }

    /// Non-nil between an adhan and its iqamah.
    var activeIqamah: IqamahCountdown? {
        guard let tz = place?.timeZone,
              let last = allEntries.last(where: { $0.prayer.isPrayer && $0.date <= now }),
              let iq = Iqamah.date(for: last, timeZone: tz), iq > now else { return nil }
        return IqamahCountdown(adhan: last,
                               englishName: Iqamah.englishName(last, tz),
                               arabicName: Iqamah.arabicName(last, tz),
                               iqamah: iq)
    }

    /// nil = no icon. During the iqamah window the countdown replaces the icon
    /// (the speaker stays while the adhan is playing, so you can see it's on).
    var menuBarIcon: String? {
        if player.isPlaying { return "speaker.wave.2.fill" }
        if activeIqamah != nil { return nil }
        return "moon.stars.fill"
    }

    var menuBarTitle: String {
        let arabic = Prefs.menuArabicNames
        if let iq = activeIqamah {
            let countdown = Format.minSec(iq.iqamah.timeIntervalSince(now))
            guard Prefs.menuIqamahName else { return countdown }
            return "\(arabic ? iq.arabicName : iq.englishName) \(countdown)"
        }
        if player.isPlaying, let playing = player.nowPlaying {
            return playing
        }
        guard let next = nextPrayer, let place else { return "" }
        let name = arabic ? Iqamah.arabicName(next, place.timeZone) : Iqamah.englishName(next, place.timeZone)
        if Prefs.menuCountdown {
            return "\(name) \(Format.shortCountdown(next.date.timeIntervalSince(now)))"
        }
        return "\(name) \(Format.time(next.date, place.timeZone))"
    }

    // MARK: Actions

    func showNextDhikr() {
        pickDhikr(notify: false)
    }

    func stopAdhan() {
        player.stop()
    }

    /// Answers the seasonal-audio consent banner. Declining asks again next Hijri year.
    func answerSeasonalPrompt(_ occasion: SeasonalOccasion, allow: Bool) {
        let category = occasion.category
        if allow {
            Prefs.setSeasonalEnabled(category, true)
        } else if let year = lastHijriYear {
            Prefs.setSeasonalAskedYear(category, year)
        }
        seasonalPrompt = nil
        syncSeasonalAudio()
    }

    /// Downloads Hijri dates for online sources (at most every 12 hours unless forced).
    func refreshHijri(force: Bool) {
        let source = Prefs.hijriSource
        guard source.apiMethod != nil else {
            hijriStatus = nil
            return
        }
        if !force, let last = HijriStore.lastUpdated(for: source),
           Date().timeIntervalSince(last) < 12 * 3600,
           !HijriStore.table(for: source).isEmpty {
            hijriStatus = "Updated \(Self.relative(last))"
            return
        }

        hijriStatus = "Updating from AlAdhan…"
        let tz = place?.timeZone ?? .current
        Task { [weak self] in
            let result = await HijriFetcher.fetch(source: source, around: Date(), timeZone: tz)
            await MainActor.run {
                guard let self else { return }
                switch result {
                case .success(let days):
                    if HijriStore.merge(days, for: source) {
                        WidgetCenter.shared.reloadAllTimelines()
                    }
                    self.hijriStatus = "Updated just now"
                case .failure:
                    self.hijriStatus = HijriStore.table(for: source).isEmpty
                        ? "Couldn't reach AlAdhan — showing Umm al-Qura until it can"
                        : "Offline — using saved dates"
                }
                self.objectWillChange.send()
            }
        }
    }

    private static func relative(_ date: Date) -> String {
        let f = RelativeDateTimeFormatter()
        f.unitsStyle = .full
        return f.localizedString(for: date, relativeTo: Date())
    }

    func recompute() {
        now = Date()
        syncSeasonalAudio()
        updateRamadanCountdown()
        guard let place else {
            today = nil
            tomorrow = nil
            notifications.schedulePrayerAlerts([], now: now)
            return
        }
        let calc = PrayerCalculator(method: Prefs.method,
                                    asr: Prefs.asrMethod,
                                    highLatitude: Prefs.highLatitudeRule)
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = place.timeZone
        let nextDay = cal.date(byAdding: .day, value: 1, to: now) ?? now.addingTimeInterval(86_400)

        let t = calc.schedule(for: now, latitude: place.latitude, longitude: place.longitude, timeZone: place.timeZone)
        let tm = calc.schedule(for: nextDay, latitude: place.latitude, longitude: place.longitude, timeZone: place.timeZone)
        today = t
        tomorrow = tm
        notifications.schedulePrayerAlerts([t, tm], now: now)
        updateWidgets(for: place)
    }

    /// Shares location + calculation settings with the widgets, reloading them only on change.
    private func updateWidgets(for place: ResolvedLocation) {
        let snapshot = WidgetSnapshot(latitude: place.latitude,
                                      longitude: place.longitude,
                                      placeName: place.name,
                                      timeZoneID: place.timeZone.identifier,
                                      method: Prefs.method.rawValue,
                                      asrMethod: Prefs.asrMethod.rawValue,
                                      highLatitudeRule: Prefs.highLatitudeRule.rawValue,
                                      hijriSource: Prefs.hijriSource.rawValue,
                                      hijriAdjustment: Prefs.hijriAdjustment)
        if SharedStore.save(snapshot) {
            WidgetCenter.shared.reloadAllTimelines()
        }
    }

    // MARK: Adhan & iqamah events

    private func checkEvents() {
        let current = Date()
        let from = lastEventCheck
        lastEventCheck = current
        guard let tz = place?.timeZone else { return }

        // An event fires if its moment passed since the last check, and not more than
        // 2 minutes ago (so waking the Mac hours later doesn't play a stale adhan).
        func crossed(_ d: Date) -> Bool {
            d > from && d <= current && current.timeIntervalSince(d) < 120
        }

        for e in allEntries where e.prayer.isPrayer {
            if crossed(e.date) { adhanDue(e, tz) }
            if let iq = Iqamah.date(for: e, timeZone: tz), crossed(iq) { now = current }
        }

        // Tick the menu bar every second while the iqamah countdown is showing.
        if activeIqamah != nil { now = current }
    }

    private func adhanDue(_ e: PrayerTime, _ tz: TimeZone) {
        now = Date()
        dhikr = AdhkarLibrary.afterAdhan
        guard Prefs.isAdhanEnabled(e.prayer), let sound = AdhanLibrary.sound(for: e.prayer) else { return }
        let label = "\(Iqamah.englishName(e, tz)) · \(Iqamah.arabicName(e, tz))"
        player.play(sound, volume: Float(Prefs.adhanVolume), label: label)
    }

    // MARK: Ramadan countdown

    /// Counts forward day by day (Ramadan's length varies 29–30 days, so this is more
    /// robust than arithmetic) until Hijri month 9 day 1. Cheap: at most ~354 calendar lookups.
    private func updateRamadanCountdown() {
        let tz = place?.timeZone ?? .current
        let source = Prefs.hijriSource
        let adjustment = Prefs.hijriAdjustment
        let today = HijriCalendar.day(for: now, timeZone: tz, source: source, adjustment: adjustment)
        guard today.month != 9 else {
            daysUntilRamadan = nil
            return
        }
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = tz
        var date = cal.startOfDay(for: now)
        for day in 1...400 {
            date = cal.date(byAdding: .day, value: 1, to: date) ?? date
            let h = HijriCalendar.day(for: date, timeZone: tz, source: source, adjustment: adjustment)
            if h.month == 9, h.day == 1 {
                daysUntilRamadan = day
                return
            }
        }
        daysUntilRamadan = nil
    }

    // MARK: Seasonal audio (Eid takbir, Hajj talbiyah)

    /// Detects today's occasion, shows the consent banner the first time one starts
    /// (once per Hijri year until allowed), and keeps the periodic-playback timer in sync.
    private func syncSeasonalAudio() {
        let tz = place?.timeZone ?? .current
        let hijri = HijriCalendar.day(for: now, timeZone: tz, source: Prefs.hijriSource, adjustment: Prefs.hijriAdjustment)
        lastHijriYear = hijri.year
        let occasion = SeasonalOccasion.detect(for: hijri)

        if occasion != lastSeasonalOccasion {
            lastSeasonalOccasion = occasion
            seasonalPrompt = nil
        }
        guard let occasion else {
            stopSeasonalTimer()
            return
        }

        let category = occasion.category
        if Prefs.isSeasonalEnabled(category) {
            seasonalPrompt = nil
            rebuildSeasonalTimer(for: occasion)
        } else {
            stopSeasonalTimer()
            if Prefs.seasonalAskedYear(category) != hijri.year {
                seasonalPrompt = occasion
            }
        }
    }

    private func rebuildSeasonalTimer(for occasion: SeasonalOccasion) {
        let interval = Prefs.seasonalIntervalMinutes
        if seasonalTimerCategory == occasion.category, lastSeasonalInterval == interval, seasonalTimer != nil { return }
        seasonalTimer?.invalidate()
        lastSeasonalInterval = interval
        seasonalTimerCategory = occasion.category
        let t = Timer(timeInterval: TimeInterval(max(interval, 1) * 60), repeats: true) { [weak self] _ in
            self?.playSeasonalAudio(occasion)
        }
        RunLoop.main.add(t, forMode: .common)
        seasonalTimer = t
    }

    private func stopSeasonalTimer() {
        seasonalTimer?.invalidate()
        seasonalTimer = nil
        seasonalTimerCategory = nil
    }

    private func playSeasonalAudio(_ occasion: SeasonalOccasion) {
        guard !player.isPlaying else { return } // don't interrupt an adhan or another seasonal clip
        let sounds = AdhanLibrary.availableSounds()
        var ids = occasion.candidateSoundIds
        let preferred = Prefs.seasonalEidSound
        if occasion.category == .eid, !preferred.isEmpty {
            ids = [preferred] + ids
        }
        guard let id = ids.first(where: { cand in sounds.contains { $0.id == cand } }),
              let sound = sounds.first(where: { $0.id == id }) else { return }
        player.play(sound, volume: Float(Prefs.adhanVolume), label: occasion.label)
    }

    // MARK: Private

    private func tick() {
        now = Date()
        guard let today else { return }
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = today.timeZone
        if !cal.isDate(today.date, inSameDayAs: now) {
            recompute()
            refreshHijri(force: false)
        }
    }

    private func preferencesChanged() {
        let useDevice = Prefs.useDeviceLocation
        if useDevice != lastUseDevice {
            lastUseDevice = useDevice
            location.start()
        }
        let hijriSource = Prefs.hijriSource
        if hijriSource != lastHijriSource {
            lastHijriSource = hijriSource
            refreshHijri(force: true)
        }
        let interval = Prefs.dhikrInterval
        if interval != lastInterval {
            lastInterval = interval
            rebuildDhikrTimer()
        }
        if !Prefs.enabledCategories.contains(dhikr.category) && dhikr != AdhkarLibrary.afterAdhan {
            pickDhikr(notify: false)
        }
        recompute()
    }

    private func rebuildDhikrTimer() {
        dhikrTimer?.invalidate()
        dhikrTimer = nil
        let minutes = Prefs.dhikrInterval
        guard minutes > 0 else { return }
        let t = Timer(timeInterval: TimeInterval(minutes * 60), repeats: true) { [weak self] _ in
            self?.pickDhikr(notify: true)
        }
        RunLoop.main.add(t, forMode: .common)
        dhikrTimer = t
    }

    private func pickDhikr(notify: Bool) {
        guard let item = AdhkarLibrary.random(in: Prefs.enabledCategories, excluding: dhikr) else { return }
        dhikr = item
        // Don't interrupt the adhan with a dhikr notification.
        if notify && Prefs.dhikrNotify && !player.isPlaying {
            notifications.post(item)
        }
    }
}
