import AppKit
import AVFoundation
import Combine
import UniformTypeIdentifiers

// MARK: - Sound library

struct Reciter {
    let id: String
    let english: String
    let arabic: String
}

struct AdhanSound: Identifiable, Hashable {
    let id: String      // file name without extension
    let url: URL
    let title: String
    var isFajr: Bool { id.hasSuffix("_fajr") }
}

/// Adhan recordings are plain audio files. They are looked up in two places:
///  1. `Adhan/` inside the app bundle (files you ship with the app)
///  2. `~/Library/Containers/<bundle id>/Data/Library/Application Support/PrayerBar/Adhan`
///     (files the user adds from Settings → "Add Sound…")
///
/// Name a file after a reciter id below (e.g. `abdulbasit.mp3`) to get a nice title.
/// Add `_fajr` for the Fajr version with "الصلاة خير من النوم" (e.g. `abdulbasit_fajr.mp3`);
/// it is picked automatically for Fajr.
enum AdhanLibrary {
    static let reciters: [Reciter] = [
        Reciter(id: "alslat_kyr_mn_alnwm", english: "The Prayer is Better than Sleep", arabic: "الصلاة خير من النوم"),
        Reciter(id: "refaat", english: "Sheikh Mohamed Refaat", arabic: "الشيخ محمد رفعت"),
        Reciter(id: "abdulbasit", english: "Sheikh Abdul Basit Abdus Samad", arabic: "الشيخ عبد الباسط عبد الصمد"),
        Reciter(id: "mahmoudElBana", english: "Sheikh Mahmoud Ali Al-Bana", arabic: "الشيخ محمود علي البنا"),
        Reciter(id: "mostafaIsmaail", english: "Sheikh Mostafa Ismaail", arabic: "الشيخ مصطفي اسماعيل"),
        Reciter(id: "husary", english: "Sheikh Mahmoud Khalil El-Husary", arabic: "الشيخ محمود خليل الحصري"),
        Reciter(id: "minshawi", english: "Sheikh Mohamed Siddiq El-Minshawi", arabic: "الشيخ محمد صديق المنشاوي"),
        Reciter(id: "makkah", english: "Adhan in Makkah", arabic: "اذان مكة"),
        Reciter(id: "eid-madina", english: "Eid in Madina", arabic: "تكبيرات العيد في المدينة"),
        Reciter(id: "eid-makkah", english: "Eid in Makkah", arabic: "تكبيرات العيد في مكة"),
        Reciter(id: "haj-labyk", english: "Haj: Labyk Allahumma Labyk", arabic: "الحج: لبيك اللهم لبيك"),
    ]

    static let audioExtensions: Set<String> = ["mp3", "m4a", "aac", "wav", "aiff", "aif", "caf"]

    static var userFolder: URL {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("PrayerBar/Adhan", isDirectory: true)
        try? FileManager.default.createDirectory(at: base, withIntermediateDirectories: true)
        return base
    }

    static var bundleFolder: URL? { Bundle.main.url(forResource: "Adhan", withExtension: nil) }

    static func availableSounds() -> [AdhanSound] {
        var found: [String: AdhanSound] = [:]
        // User folder last, so it overrides a bundled file with the same name.
        for folder in [bundleFolder, userFolder].compactMap({ $0 }) {
            let files = (try? FileManager.default.contentsOfDirectory(at: folder, includingPropertiesForKeys: nil)) ?? []
            for url in files where audioExtensions.contains(url.pathExtension.lowercased()) {
                let id = url.deletingPathExtension().lastPathComponent
                found[id] = AdhanSound(id: id, url: url, title: title(for: id))
            }
        }
        return found.values.sorted { $0.title.localizedCompare($1.title) == .orderedAscending }
    }

    static func title(for id: String) -> String {
        let isFajr = id.hasSuffix("_fajr")
        let base = isFajr ? String(id.dropLast(5)) : id
        let name = reciters.first { $0.id == base }.map { "\($0.english) · \($0.arabic)" }
            ?? base.replacingOccurrences(of: "_", with: " ")
        return isFajr ? "\(name) (Fajr)" : name
    }

    /// The sound to play for a prayer, based on the user's choices.
    static func sound(for prayer: Prayer, in list: [AdhanSound]? = nil) -> AdhanSound? {
        let sounds = list ?? availableSounds()
        let d = UserDefaults.standard
        func byId(_ id: String?) -> AdhanSound? {
            guard let id, !id.isEmpty else { return nil }
            return sounds.first { $0.id == id }
        }

        if prayer == .fajr, let explicit = byId(d.string(forKey: PrefKey.adhanFajrSound)) {
            return explicit
        }
        let base = byId(d.string(forKey: PrefKey.adhanSound)) ?? sounds.first { !$0.isFajr } ?? sounds.first
        if prayer == .fajr, let base, let variant = byId(base.id + "_fajr") {
            return variant
        }
        return base
    }

    /// Lets the user pick audio files and copies them into the app's Adhan folder.
    /// Returns the last imported sound.
    static func importSounds() -> AdhanSound? {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.audio]
        panel.allowsMultipleSelection = true
        panel.message = "Choose adhan recordings (MP3, M4A, WAV…)"
        NSApp.activate(ignoringOtherApps: true)
        guard panel.runModal() == .OK else { return nil }

        var lastId: String?
        for src in panel.urls {
            let dest = userFolder.appendingPathComponent(src.lastPathComponent)
            try? FileManager.default.removeItem(at: dest)
            if (try? FileManager.default.copyItem(at: src, to: dest)) != nil {
                lastId = dest.deletingPathExtension().lastPathComponent
            }
        }
        return availableSounds().first { $0.id == lastId }
    }
}

// MARK: - Player

final class AdhanPlayer: NSObject, ObservableObject, AVAudioPlayerDelegate {
    @Published private(set) var isPlaying = false
    @Published private(set) var nowPlaying: String?

    private var player: AVAudioPlayer?

    @discardableResult
    func play(_ sound: AdhanSound, volume: Float, label: String) -> Bool {
        stop()
        guard let p = try? AVAudioPlayer(contentsOf: sound.url) else { return false }
        p.delegate = self
        p.volume = volume
        p.prepareToPlay()
        guard p.play() else { return false }
        player = p
        isPlaying = true
        nowPlaying = label
        return true
    }

    func stop() {
        player?.stop()
        player = nil
        isPlaying = false
        nowPlaying = nil
    }

    func setVolume(_ volume: Float) {
        player?.volume = volume
    }

    func audioPlayerDidFinishPlaying(_ p: AVAudioPlayer, successfully flag: Bool) {
        DispatchQueue.main.async {
            if p === self.player { self.stop() }
        }
    }
}
