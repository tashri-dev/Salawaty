import SwiftUI
import WidgetKit

@main
struct PrayerBarWidgets: WidgetBundle {
    var body: some Widget {
        PrayerTimesWidget()
        NextPrayerWidget()
        HijriDateWidget()
        VerseWidget()
    }
}
