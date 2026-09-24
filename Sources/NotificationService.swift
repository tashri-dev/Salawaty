import Foundation
import UserNotifications

final class NotificationService: NSObject, UNUserNotificationCenterDelegate {
    private let center = UNUserNotificationCenter.current()
    private let prefix = "prayer."

    override init() {
        super.init()
        center.delegate = self
    }

    func requestAuthorization() {
        center.requestAuthorization(options: [.alert, .sound]) { _, _ in }
    }

    /// Replaces all scheduled prayer, iqamah and morning/evening notifications.
    func schedulePrayerAlerts(_ schedules: [PrayerSchedule], now: Date) {
        var requests: [UNNotificationRequest] = []
        let sounds = AdhanLibrary.availableSounds()

        func add(_ key: String, at date: Date, title: String, body: String, silent: Bool = false) {
            guard date > now else { return }
            let content = UNMutableNotificationContent()
            content.title = title
            content.body = body
            content.sound = silent ? nil : .default
            let comps = Calendar.current.dateComponents([.year, .month, .day, .hour, .minute, .second], from: date)
            let trigger = UNCalendarNotificationTrigger(dateMatching: comps, repeats: false)
            let id = "\(prefix)\(key).\(Int(date.timeIntervalSince1970))"
            requests.append(UNNotificationRequest(identifier: id, content: content, trigger: trigger))
        }

        let alerts = Prefs.prayerAlerts
        let before = Prefs.alertMinutesBefore
        let morningEvening = Prefs.morningEveningReminder
        let iqamahAlerts = Prefs.iqamahAlerts

        for schedule in schedules {
            let tz = schedule.timeZone
            for e in schedule.entries {
                let p = e.prayer
                let en = Iqamah.englishName(e, tz)
                let ar = Iqamah.arabicName(e, tz)

                if alerts && p.isPrayer {
                    // The adhan audio is the sound — keep the banner silent.
                    let adhanPlays = Prefs.isAdhanEnabled(p) && AdhanLibrary.sound(for: p, in: sounds) != nil
                    add(p.rawValue, at: e.date,
                        title: "\(en) · \(ar)",
                        body: "It's time for \(en) prayer — حان الآن موعد صلاة \(ar)",
                        silent: adhanPlays)
                    if before > 0 {
                        add("\(p.rawValue).before", at: e.date.addingTimeInterval(-Double(before) * 60),
                            title: "\(en) in \(before) min",
                            body: "صلاة \(ar) بعد \(before) دقيقة")
                    }
                }
                if iqamahAlerts, let iq = Iqamah.date(for: e, timeZone: tz) {
                    add("\(p.rawValue).iqamah", at: iq,
                        title: "Iqamah · \(en)",
                        body: "حان وقت إقامة صلاة \(ar)")
                }
                if morningEvening && p == .fajr {
                    add("morning", at: e.date.addingTimeInterval(15 * 60),
                        title: "Morning adhkar · أذكار الصباح",
                        body: "Take a few minutes for the morning remembrance.")
                }
                if morningEvening && p == .asr {
                    add("evening", at: e.date.addingTimeInterval(15 * 60),
                        title: "Evening adhkar · أذكار المساء",
                        body: "Take a few minutes for the evening remembrance.")
                }
            }
        }

        center.getPendingNotificationRequests { [weak self] pending in
            guard let self else { return }
            let old = pending.map(\.identifier).filter { $0.hasPrefix(self.prefix) }
            self.center.removePendingNotificationRequests(withIdentifiers: old)
            requests.forEach { self.center.add($0) }
        }
    }

    func post(_ item: DhikrItem) {
        let content = UNMutableNotificationContent()
        content.title = item.category.title
        content.subtitle = item.source
        content.body = Prefs.showTranslation ? "\(item.arabic)\n\(item.translation)" : item.arabic
        let request = UNNotificationRequest(identifier: "dhikr.\(UUID().uuidString)", content: content, trigger: nil)
        center.add(request)
    }

    func userNotificationCenter(_ center: UNUserNotificationCenter,
                                willPresent notification: UNNotification,
                                withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
        completionHandler([.banner, .sound])
    }
}
