import Foundation
import CoreGraphics

enum AppConstants {
    static let appGroupID = "group.com.translatekey.shared"
    static let sourceLanguageKey = "sourceLanguage"
    static let targetLanguageKey = "targetLanguage"
    static let quickLanguagesKey = "quickLanguages"
    static let autoTranslateEnabledKey = "autoTranslateEnabled"
    static let emojiFrequencyKey = "emojiFrequency"
    static let wordFrequencyKey = "wordFrequency"
}

/// Single source of truth for keyboard geometry — used by both KeyboardView and KeyboardContext.
enum KeyboardLayout {
    static let keySpacing: CGFloat = 6
    static let rowSpacing: CGFloat = 9
    static let keyHeight: CGFloat = 41
    static let keyboardHeight: CGFloat = 329
    static let horizontalPad: CGFloat = 3
    static let bottomPad: CGFloat = 2

    /// Letter rows matching the device locale (QWERTY / AZERTY / QWERTZ).
    /// Computed once at process launch — locale doesn't change while the extension runs.
    static let letterRows: [[String]] = {
        let lang = Locale.current.language.languageCode?.identifier ?? "en"
        switch lang {
        case "fr":
            return [
                ["a", "z", "e", "r", "t", "y", "u", "i", "o", "p"],
                ["q", "s", "d", "f", "g", "h", "j", "k", "l", "m"],
                ["w", "x", "c", "v", "b", "n"],
            ]
        case "de":
            return [
                ["q", "w", "e", "r", "t", "z", "u", "i", "o", "p"],
                ["a", "s", "d", "f", "g", "h", "j", "k", "l"],
                ["y", "x", "c", "v", "b", "n", "m"],
            ]
        default:
            return [
                ["q", "w", "e", "r", "t", "y", "u", "i", "o", "p"],
                ["a", "s", "d", "f", "g", "h", "j", "k", "l"],
                ["z", "x", "c", "v", "b", "n", "m"],
            ]
        }
    }()
}
