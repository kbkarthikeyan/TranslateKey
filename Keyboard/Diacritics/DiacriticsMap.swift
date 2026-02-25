import Foundation

/// Static mapping of base lowercase letters to their accented/diacritical variants.
/// Covers all Latin-script languages in the supported list: French, German, Spanish,
/// Portuguese, Italian, Polish, Turkish, Dutch, Vietnamese, Indonesian.
enum DiacriticsMap {

    static let variants: [String: [String]] = [
        "a": ["à", "á", "â", "ã", "ä", "å", "æ", "ą"],
        "c": ["ç", "ć", "č"],
        "d": ["đ"],
        "e": ["è", "é", "ê", "ë", "ę"],
        "g": ["ğ"],
        "i": ["ì", "í", "î", "ï", "ı"],
        "l": ["ł"],
        "n": ["ñ", "ń"],
        "o": ["ò", "ó", "ô", "õ", "ö", "ø", "œ"],
        "r": ["ř"],
        "s": ["ś", "ş", "š", "ß"],
        "u": ["ù", "ú", "û", "ü"],
        "y": ["ÿ"],
        "z": ["ź", "ż", "ž"],
    ]

    /// Returns variants for a character (case-insensitive lookup, returns matching case).
    static func variants(for character: String) -> [String]? {
        let lower = character.lowercased()
        guard let base = variants[lower], !base.isEmpty else { return nil }
        if character == lower {
            return base
        }
        return base.map { $0.uppercased() }
    }
}
