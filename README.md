# PrayerBar — مواقيت الصلاة في شريط القوائم

A macOS menu bar app (macOS 13+, desktop widgets on macOS 14+) that shows prayer times, a live countdown to the next prayer,
and rotating adhkar, duas and Quran verses.

## Build (option A — XcodeGen, fastest)
```bash
brew install xcodegen
cd PrayerBar
xcodegen generate
open PrayerBar.xcodeproj
```
Select your Team under Signing & Capabilities, then press ⌘R.

## Build (option B — plain Xcode)
1. Xcode → New Project → macOS → App (SwiftUI). Name it `PrayerBar`, deployment target macOS 13.
2. Delete the generated `ContentView.swift` and `PrayerBarApp.swift`, then drag in everything from `Sources/`.
3. Target → Info: add
   - `Application is agent (UIElement)` = YES (hides the Dock icon)
   - `Privacy - Location When In Use Usage Description` and `Privacy - Location Usage Description`
4. Signing & Capabilities → App Sandbox: tick **Location** and **Outgoing Connections (Client)**.

## How location works
- On first launch it asks for location permission.
- **Granted** → it uses the Mac's location and keeps following it (significant-change monitoring
  plus a refresh on wake), recalculating only when you move more than ~3 km.
- **Denied / not wanted** → type a city in Settings; it's geocoded and saved, including its time zone.

## Configurable
- Calculation method (MWL, ISNA, Egypt, Umm al-Qura, Karachi, Dubai, Kuwait, Qatar, Singapore, Turkey, France),
  Asr (Standard/Hanafi), high-latitude rule.
- Prayer-time notifications, optional early reminder, morning/evening adhkar reminder.
- Adhkar interval (off / 15 min … 6 h), categories (adhkar, duas, Quran), notification on/off, English meaning.
- Menu bar countdown vs. time, Arabic names, launch at login.

## Adhan (الأذان)
The app plays the full adhan at each prayer time, with a choice of Egyptian sheikhs, a separate Fajr adhan,
per-prayer on/off, a volume control and a **Stop** button (also shown in the menu bar while playing).

The recordings are **not included**, so add the files yourself:
- **In the app:** Settings → Adhan → **Add Sound…** (you can pick several files at once).
- **Bundled:** drop the files into `Resources/Adhan/` before building (see the naming table in `README.txt` there).

Name files after the reciter id (`refaat`, `abdulbasit`, `naqshabandi`, `alimahmoud`, `husary`, `minshawi`)
to get proper names. Add `_fajr` (e.g. `refaat_fajr.mp3`) for the Fajr version; it's picked automatically at Fajr.
Only use recordings you have the right to use, especially if you distribute the app.

The audio plays from the app itself (not from the notification), so the full adhan plays.
The prayer-time notification is silent when the adhan will play.
An adhan missed while the Mac was asleep is skipped if it was more than 2 minutes ago.

## Iqamah (الإقامة)
After each adhan, the menu bar icon and name are replaced by a live countdown (e.g. `12:34`) until the iqamah,
and a countdown card appears in the popover. Turn on "Show prayer name with iqamah countdown" to show `Dhuhr 12:34` instead.
For each prayer you can choose, in Settings → Iqamah:
- **After adhan:** 0–90 minutes (0 = off). Defaults: Fajr 20, Dhuhr 15, Asr 15, Maghrib 10, Isha 15.
- **Fixed time:** a set clock time, like your mosque's timetable. If the fixed time falls before that
  day's adhan, the "after adhan" minutes are used instead.
- **Jumu'ah:** its own offset (default 30 min) replaces Dhuhr on Fridays.

The iqamah time also appears under each prayer in the list, and an optional notification fires at the iqamah.

## Hijri date (التاريخ الهجري)
Settings → Hijri date:
- **Source**
  - *Umm al-Qura* — built into macOS, works offline (default).
  - *Saudi moon sighting* — AlAdhan's `HJCoSA` method: Umm al-Qura corrected after the Saudi High Judiciary
    Council's sighting announcements for Muharram, Ramadan, Shawwal and Dhul-Hijjah.
  - *Diyanet* — Turkey's calendar, via AlAdhan.
- **Adjustment** −2…+2 days, applied on top of any source, for your country's own moon sighting
  (for example, if Egypt's Dar al-Ifta started the month a day before or after the calendar).

There is no worldwide API for each country's own sighting, which is why the manual adjustment exists.
Online sources download last, this and next month from `api.aladhan.com/v1/gToHCalendar/{month}/{year}`
(at most every 12 hours, plus a manual "Update Now"). Dates are saved to the App Group, so the widgets
keep working offline and fall back to Umm al-Qura only if nothing was ever downloaded.

## Desktop widgets (macOS 14+)
Four widgets, in Arabic, right-to-left. Add them by right-clicking the desktop → **Edit Widgets** → PrayerBar.

| Widget | Size | Shows |
|---|---|---|
| Prayer Times · مواقيت الصلاة | Medium | City, weekday + Hijri date, Gregorian date, next time with a live countdown, the five prayers (next one highlighted) |
| Next Prayer · الصلاة القادمة | Small | Next prayer, its time and a countdown |
| Hijri Date · التاريخ الهجري | Small | Weekday + Hijri month, big Hijri day, Gregorian day and month |
| Verse & Dhikr · آية وذكر | Small / Medium / Large | A Quran verse (﴿ ﴾), dhikr or dua with its source. Right-click → **Edit** to choose content, how often it changes and whether to show the English meaning |

How it works:
- Widgets can't use location themselves. The app saves the resolved location and calculation settings into a
  shared **App Group**, and the widgets calculate times from that. **Run the app once** before adding widgets.
- The widgets reload only when location or calculation settings change. Otherwise they update on their own
  at each prayer time and at midnight.
- Verses use the **Amiri Quran** font (SIL Open Font License, bundled in `Widgets/Fonts`).

Setup notes:
- Pick the **same Team** for both targets (PrayerBar and PrayerBarWidgets) under Signing & Capabilities.
  The App Group id is built from your Team ID automatically (`<TeamID>.com.yourname.PrayerBar`).
- If you change `com.yourname`, change it everywhere in `project.yml`.
- After rebuilding, if the widget gallery shows an old version, quit the app and run it again from Xcode.

## Customizing content
Add entries to `AdhkarLibrary.all` in `Shared/AdhkarLibrary.swift` (used by both the app and the widgets).
For widgets, add the Arabic source label to `arabicSources` in the same file.

## Ideas for next steps
- Per-prayer minute offsets to match your local mosque.
