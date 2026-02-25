import Foundation

/// Static layout data for the Arabic keyboard.
/// Characters insert directly — no IME composition needed.
enum ArabicLayout {
    /// Standard Arabic typewriter layout rows.
    static let row1: [String] = ["ض", "ص", "ث", "ق", "ف", "غ", "ع", "ه", "خ", "ح", "ج"]
    static let row2: [String] = ["ش", "س", "ي", "ب", "ل", "ا", "ت", "ن", "م", "ك", "ط"]
    static let row3: [String] = ["ذ", "ئ", "ء", "ؤ", "ر", "لا", "ى", "ة", "و"]

    /// Shift variants (diacritics and alternate forms).
    static let row1Shift: [String] = ["َ", "ً", "ُ", "ٌ", "ِ", "ٍ", "ّ", "ْ", "×", "÷", "؛"]
    static let row2Shift: [String] = ["\\", "/", "~", "ّ", "،", "آ", "'", "\"", ":", "؟", "!"]
    static let row3Shift: [String] = ["ذ", "ئ", "ء", "ؤ", "ر", "لآ", "أ", "إ", "و"]

    /// All rows for a given shift state.
    static func rows(shifted: Bool) -> [[String]] {
        if shifted {
            return [row1Shift, row2Shift, row3Shift]
        }
        return [row1, row2, row3]
    }
}
