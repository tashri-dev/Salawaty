import SwiftUI
import WidgetKit

@main
struct SalawatyWidgets: WidgetBundle {
    var body: some Widget {
        PrayerTimesWidget()
        NextPrayerWidget()
        HijriDateWidget()
        VerseWidget()
        PrayerTrackingWidget()
    }
}
