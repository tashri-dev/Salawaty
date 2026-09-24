import Foundation

/// A yearly occasion whose audio (takbir or talbiyah) the user can opt into.
/// Eid al-Fitr and Eid al-Adha share one consent (`.eid`); Hajj season is separate (`.hajj`).
enum SeasonalOccasion: String, CaseIterable {
    case eidFitr, eidAdha, hajj

    var category: SeasonalCategory { self == .hajj ? .hajj : .eid }

    var promptTitle: String {
        switch self {
        case .eidFitr: return "Eid Mubarak! 🌙"
        case .eidAdha: return "Eid Mubarak! 🐑"
        case .hajj: return "Wishes for an accepted Hajj 🕋"
        }
    }

    var promptBody: String {
        switch self {
        case .eidFitr, .eidAdha:
            return "Play the Eid takbir in the background every so often today? — تكبيرات العيد"
        case .hajj:
            return "Play the talbiyah in the background every so often during these days? — لبيك اللهم لبيك"
        }
    }

    var label: String {
        switch self {
        case .eidFitr: return "Eid al-Fitr · عيد الفطر"
        case .eidAdha: return "Eid al-Adha · عيد الأضحى"
        case .hajj: return "Hajj · الحج"
        }
    }

    /// File ids (without extension) to look for in `Resources/Adhan`, in preference order.
    var candidateSoundIds: [String] {
        switch self {
        case .eidFitr, .eidAdha: return ["eid-mecca", "eid-madina"]
        case .hajj: return ["haj-labyk"]
        }
    }

    /// The occasion active for a given Hijri day, if any.
    /// Eid al-Adha (Dhul Hijjah 10) takes priority over the surrounding Hajj window.
    static func detect(for hijri: HijriDay) -> SeasonalOccasion? {
        if hijri.month == 10, hijri.day == 1 { return .eidFitr }
        if hijri.month == 12, hijri.day == 10 { return .eidAdha }
        if hijri.month == 12, (1...13).contains(hijri.day) { return .hajj }
        return nil
    }
}

enum SeasonalCategory: String {
    case eid, hajj

    var title: String {
        switch self {
        case .eid: return "Eid takbir · تكبيرات العيد"
        case .hajj: return "Hajj talbiyah · تلبية الحج"
        }
    }
}
