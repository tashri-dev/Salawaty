import Foundation

enum DhikrCategory: String, CaseIterable, Identifiable {
    case dhikr, dua, quran

    var id: String { rawValue }
    var prefKey: String { "category.\(rawValue)" }

    var title: String {
        switch self {
        case .dhikr: return "Dhikr · ذكر"
        case .dua: return "Dua · دعاء"
        case .quran: return "Quran · قرآن"
        }
    }

    var settingsTitle: String {
        switch self {
        case .dhikr: return "Adhkar (أذكار)"
        case .dua: return "Duas (أدعية)"
        case .quran: return "Quran verses (آيات)"
        }
    }
}

struct DhikrItem: Identifiable, Hashable {
    let category: DhikrCategory
    let arabic: String
    let translation: String
    let source: String
    var id: String { arabic }
}

/// Add your own entries here — they appear automatically in the rotation.
enum AdhkarLibrary {
    static let all: [DhikrItem] = [
        // MARK: Adhkar
        DhikrItem(category: .dhikr,
                  arabic: "سُبْحَانَ اللهِ وَبِحَمْدِهِ، سُبْحَانَ اللهِ الْعَظِيمِ",
                  translation: "Glory be to Allah and praise Him; glory be to Allah the Magnificent.",
                  source: "Bukhari & Muslim"),
        DhikrItem(category: .dhikr,
                  arabic: "لَا إِلَهَ إِلَّا اللهُ وَحْدَهُ لَا شَرِيكَ لَهُ، لَهُ الْمُلْكُ وَلَهُ الْحَمْدُ، وَهُوَ عَلَى كُلِّ شَيْءٍ قَدِيرٌ",
                  translation: "None has the right to be worshipped but Allah alone, without partner. His is the dominion and the praise, and He has power over all things.",
                  source: "Bukhari & Muslim"),
        DhikrItem(category: .dhikr,
                  arabic: "سُبْحَانَ اللهِ، وَالْحَمْدُ لِلهِ، وَلَا إِلَهَ إِلَّا اللهُ، وَاللهُ أَكْبَرُ",
                  translation: "Glory be to Allah, praise be to Allah, none is worthy of worship but Allah, and Allah is the Greatest.",
                  source: "Muslim"),
        DhikrItem(category: .dhikr,
                  arabic: "لَا حَوْلَ وَلَا قُوَّةَ إِلَّا بِاللهِ",
                  translation: "There is no might nor power except with Allah.",
                  source: "Bukhari & Muslim"),
        DhikrItem(category: .dhikr,
                  arabic: "أَسْتَغْفِرُ اللهَ وَأَتُوبُ إِلَيْهِ",
                  translation: "I seek Allah's forgiveness and turn to Him in repentance.",
                  source: "Bukhari"),
        DhikrItem(category: .dhikr,
                  arabic: "اللَّهُمَّ صَلِّ وَسَلِّمْ عَلَى نَبِيِّنَا مُحَمَّدٍ",
                  translation: "O Allah, send blessings and peace upon our Prophet Muhammad.",
                  source: "Salawat (Quran 33:56)"),
        DhikrItem(category: .dhikr,
                  arabic: "بِسْمِ اللهِ الَّذِي لَا يَضُرُّ مَعَ اسْمِهِ شَيْءٌ فِي الْأَرْضِ وَلَا فِي السَّمَاءِ وَهُوَ السَّمِيعُ الْعَلِيمُ",
                  translation: "In the name of Allah, with whose name nothing on earth or in heaven can cause harm, and He is the All-Hearing, All-Knowing. (3× morning & evening)",
                  source: "Abu Dawud & Tirmidhi"),
        DhikrItem(category: .dhikr,
                  arabic: "حَسْبِيَ اللهُ لَا إِلَهَ إِلَّا هُوَ عَلَيْهِ تَوَكَّلْتُ وَهُوَ رَبُّ الْعَرْشِ الْعَظِيمِ",
                  translation: "Allah is sufficient for me; there is no god but Him. In Him I trust, and He is Lord of the Mighty Throne. (7× morning & evening)",
                  source: "Abu Dawud"),
        DhikrItem(category: .dhikr,
                  arabic: "رَضِيتُ بِاللهِ رَبًّا، وَبِالْإِسْلَامِ دِينًا، وَبِمُحَمَّدٍ ﷺ نَبِيًّا",
                  translation: "I am pleased with Allah as my Lord, Islam as my religion, and Muhammad ﷺ as my Prophet.",
                  source: "Abu Dawud & Tirmidhi"),
        DhikrItem(category: .dhikr,
                  arabic: "اللَّهُمَّ أَنْتَ رَبِّي لَا إِلَهَ إِلَّا أَنْتَ، خَلَقْتَنِي وَأَنَا عَبْدُكَ، وَأَنَا عَلَى عَهْدِكَ وَوَعْدِكَ مَا اسْتَطَعْتُ، أَعُوذُ بِكَ مِنْ شَرِّ مَا صَنَعْتُ، أَبُوءُ لَكَ بِنِعْمَتِكَ عَلَيَّ، وَأَبُوءُ بِذَنْبِي فَاغْفِرْ لِي، فَإِنَّهُ لَا يَغْفِرُ الذُّنُوبَ إِلَّا أَنْتَ",
                  translation: "Sayyid al-Istighfar — the master supplication for forgiveness.",
                  source: "Bukhari"),

        // MARK: Duas
        DhikrItem(category: .dua,
                  arabic: "رَبَّنَا آتِنَا فِي الدُّنْيَا حَسَنَةً وَفِي الْآخِرَةِ حَسَنَةً وَقِنَا عَذَابَ النَّارِ",
                  translation: "Our Lord, give us good in this world and good in the Hereafter, and protect us from the punishment of the Fire.",
                  source: "Quran 2:201"),
        DhikrItem(category: .dua,
                  arabic: "اللَّهُمَّ إِنِّي أَسْأَلُكَ الْعَفْوَ وَالْعَافِيَةَ فِي الدُّنْيَا وَالْآخِرَةِ",
                  translation: "O Allah, I ask You for pardon and well-being in this world and the Hereafter.",
                  source: "Ibn Majah"),
        DhikrItem(category: .dua,
                  arabic: "يَا مُقَلِّبَ الْقُلُوبِ ثَبِّتْ قَلْبِي عَلَى دِينِكَ",
                  translation: "O Turner of hearts, keep my heart firm upon Your religion.",
                  source: "Tirmidhi"),
        DhikrItem(category: .dua,
                  arabic: "اللَّهُمَّ أَعِنِّي عَلَى ذِكْرِكَ وَشُكْرِكَ وَحُسْنِ عِبَادَتِكَ",
                  translation: "O Allah, help me to remember You, thank You, and worship You well.",
                  source: "Abu Dawud & Nasa'i"),
        DhikrItem(category: .dua,
                  arabic: "رَبِّ اشْرَحْ لِي صَدْرِي وَيَسِّرْ لِي أَمْرِي",
                  translation: "My Lord, expand my chest for me and ease my task for me.",
                  source: "Quran 20:25–26"),
        DhikrItem(category: .dua,
                  arabic: "اللَّهُمَّ إِنِّي أَعُوذُ بِكَ مِنَ الْهَمِّ وَالْحَزَنِ، وَالْعَجْزِ وَالْكَسَلِ",
                  translation: "O Allah, I seek refuge in You from worry and grief, and from helplessness and laziness.",
                  source: "Bukhari"),
        DhikrItem(category: .dua,
                  arabic: "رَبِّ اجْعَلْنِي مُقِيمَ الصَّلَاةِ وَمِن ذُرِّيَّتِي ۚ رَبَّنَا وَتَقَبَّلْ دُعَاءِ",
                  translation: "My Lord, make me one who establishes prayer, and from my descendants. Our Lord, accept my supplication.",
                  source: "Quran 14:40"),
        DhikrItem(category: .dua,
                  arabic: "رَبَّنَا لَا تُزِغْ قُلُوبَنَا بَعْدَ إِذْ هَدَيْتَنَا وَهَبْ لَنَا مِن لَّدُنكَ رَحْمَةً ۚ إِنَّكَ أَنتَ الْوَهَّابُ",
                  translation: "Our Lord, do not let our hearts deviate after You have guided us, and grant us mercy from Yourself. You are the Bestower.",
                  source: "Quran 3:8"),
        DhikrItem(category: .dua,
                  arabic: "رَّبِّ زِدْنِي عِلْمًا",
                  translation: "My Lord, increase me in knowledge.",
                  source: "Quran 20:114"),

        // MARK: Quran
        DhikrItem(category: .quran,
                  arabic: "أَلَا بِذِكْرِ اللَّهِ تَطْمَئِنُّ الْقُلُوبُ",
                  translation: "Surely, in the remembrance of Allah do hearts find rest.",
                  source: "Ar-Ra'd 13:28"),
        DhikrItem(category: .quran,
                  arabic: "فَاذْكُرُونِي أَذْكُرْكُمْ وَاشْكُرُوا لِي وَلَا تَكْفُرُونِ",
                  translation: "So remember Me; I will remember you. Be grateful to Me and do not deny Me.",
                  source: "Al-Baqarah 2:152"),
        DhikrItem(category: .quran,
                  arabic: "فَإِنَّ مَعَ الْعُسْرِ يُسْرًا ۝ إِنَّ مَعَ الْعُسْرِ يُسْرًا",
                  translation: "For indeed, with hardship comes ease. Indeed, with hardship comes ease.",
                  source: "Ash-Sharh 94:5–6"),
        DhikrItem(category: .quran,
                  arabic: "وَمَن يَتَوَكَّلْ عَلَى اللَّهِ فَهُوَ حَسْبُهُ",
                  translation: "Whoever relies upon Allah, He is sufficient for him.",
                  source: "At-Talaq 65:3"),
        DhikrItem(category: .quran,
                  arabic: "لَا يُكَلِّفُ اللَّهُ نَفْسًا إِلَّا وُسْعَهَا",
                  translation: "Allah does not burden a soul beyond what it can bear.",
                  source: "Al-Baqarah 2:286"),
        DhikrItem(category: .quran,
                  arabic: "وَإِذَا سَأَلَكَ عِبَادِي عَنِّي فَإِنِّي قَرِيبٌ ۖ أُجِيبُ دَعْوَةَ الدَّاعِ إِذَا دَعَانِ",
                  translation: "When My servants ask you about Me — I am near. I answer the call of the caller when he calls upon Me.",
                  source: "Al-Baqarah 2:186"),
        DhikrItem(category: .quran,
                  arabic: "إِنَّ الصَّلَاةَ كَانَتْ عَلَى الْمُؤْمِنِينَ كِتَابًا مَّوْقُوتًا",
                  translation: "Indeed, prayer has been decreed upon the believers at fixed times.",
                  source: "An-Nisa 4:103"),
        DhikrItem(category: .quran,
                  arabic: "وَاسْتَعِينُوا بِالصَّبْرِ وَالصَّلَاةِ",
                  translation: "And seek help through patience and prayer.",
                  source: "Al-Baqarah 2:45"),
        DhikrItem(category: .quran,
                  arabic: "إِنَّ الصَّلَاةَ تَنْهَىٰ عَنِ الْفَحْشَاءِ وَالْمُنكَرِ",
                  translation: "Indeed, prayer prohibits immorality and wrongdoing.",
                  source: "Al-'Ankabut 29:45"),
        DhikrItem(category: .quran,
                  arabic: "قُلْ يَا عِبَادِيَ الَّذِينَ أَسْرَفُوا عَلَىٰ أَنفُسِهِمْ لَا تَقْنَطُوا مِن رَّحْمَةِ اللَّهِ",
                  translation: "Say: O My servants who have transgressed against themselves, do not despair of the mercy of Allah.",
                  source: "Az-Zumar 39:53"),
        DhikrItem(category: .quran,
                  arabic: "فَقَالُوا عَلَى اللَّهِ تَوَكَّلْنَا رَبَّنَا لَا تَجْعَلْنَا فِتْنَةً لِّلْقَوْمِ الظَّالِمِينَ",
                  translation: "They said, \"Upon Allah we rely. Our Lord, do not make us a trial for the wrongdoing people.\"",
                  source: "Yunus 10:85"),
    ]

    /// Shown automatically when the adhan plays.
    static let afterAdhan = DhikrItem(
        category: .dua,
        arabic: "اللَّهُمَّ رَبَّ هَذِهِ الدَّعْوَةِ التَّامَّةِ، وَالصَّلَاةِ الْقَائِمَةِ، آتِ مُحَمَّدًا الْوَسِيلَةَ وَالْفَضِيلَةَ، وَابْعَثْهُ مَقَامًا مَحْمُودًا الَّذِي وَعَدْتَهُ",
        translation: "Dua after the adhan: O Allah, Lord of this perfect call and the prayer about to be established, grant Muhammad al-Wasilah and virtue, and raise him to the praised station You promised him.",
        source: "Bukhari")

    static func random(in categories: Set<DhikrCategory>, excluding current: DhikrItem? = nil) -> DhikrItem? {
        let pool = all.filter { categories.contains($0.category) && $0 != current }
        return pool.randomElement() ?? all.first { categories.contains($0.category) }
    }
}

// MARK: - Arabic source labels (used by the widgets)

extension DhikrItem {
    var arabicSource: String { AdhkarLibrary.arabicSources[source] ?? source }

    /// The meaning in the user's language, or nil to hide the row when the app is in
    /// Arabic — the Arabic text above already stands on its own there.
    var localizedTranslation: String? {
        guard Locale.current.language.languageCode?.identifier != "ar" else { return nil }
        return String(localized: String.LocalizationValue(translation))
    }
}

extension AdhkarLibrary {
    static let arabicSources: [String: String] = [
        "Bukhari & Muslim": "متفق عليه",
        "Bukhari": "رواه البخاري",
        "Muslim": "رواه مسلم",
        "Abu Dawud": "رواه أبو داود",
        "Abu Dawud & Tirmidhi": "رواه أبو داود والترمذي",
        "Abu Dawud & Nasa'i": "رواه أبو داود والنسائي",
        "Tirmidhi": "رواه الترمذي",
        "Ibn Majah": "رواه ابن ماجه",
        "Salawat (Quran 33:56)": "الأحزاب ٥٦",
        "Quran 2:201": "البقرة ٢٠١",
        "Quran 20:25–26": "طه ٢٥–٢٦",
        "Quran 14:40": "إبراهيم ٤٠",
        "Quran 3:8": "آل عمران ٨",
        "Quran 20:114": "طه ١١٤",
        "Ar-Ra'd 13:28": "الرعد ٢٨",
        "Al-Baqarah 2:152": "البقرة ١٥٢",
        "Ash-Sharh 94:5–6": "الشرح ٥–٦",
        "At-Talaq 65:3": "الطلاق ٣",
        "Al-Baqarah 2:286": "البقرة ٢٨٦",
        "Al-Baqarah 2:186": "البقرة ١٨٦",
        "An-Nisa 4:103": "النساء ١٠٣",
        "Al-Baqarah 2:45": "البقرة ٤٥",
        "Al-'Ankabut 29:45": "العنكبوت ٤٥",
        "Az-Zumar 39:53": "الزمر ٥٣",
        "Yunus 10:85": "يونس ٨٥",
    ]
}
