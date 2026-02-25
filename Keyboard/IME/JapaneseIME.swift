import UIKit

/// Japanese Romaji → Hiragana → Kanji IME.
///
/// Input: QWERTY romaji letters
/// Display: converted hiragana
/// Candidates: kanji from UITextChecker + hiragana/katakana forms
@MainActor
final class JapaneseIME: InputMethod {
    var onStateChanged: (() -> Void)?
    var onCommit: ((String) -> Void)?

    private(set) var compositionText: String = ""  // raw romaji buffer
    private(set) var displayText: String = ""       // hiragana rendering
    private(set) var candidates: [String] = []

    private var romajiBuffer: String = ""
    private var kanjiTask: Task<Void, Never>?

    // MARK: - Romaji → Hiragana Table

    private static let romajiMap: [String: String] = [
        // Vowels
        "a": "あ", "i": "い", "u": "う", "e": "え", "o": "お",
        // K-row
        "ka": "か", "ki": "き", "ku": "く", "ke": "け", "ko": "こ",
        // S-row
        "sa": "さ", "si": "し", "shi": "し", "su": "す", "se": "せ", "so": "そ",
        // T-row
        "ta": "た", "ti": "ち", "chi": "ち", "tu": "つ", "tsu": "つ", "te": "て", "to": "と",
        // N-row
        "na": "な", "ni": "に", "nu": "ぬ", "ne": "ね", "no": "の",
        // H-row
        "ha": "は", "hi": "ひ", "hu": "ふ", "fu": "ふ", "he": "へ", "ho": "ほ",
        // M-row
        "ma": "ま", "mi": "み", "mu": "む", "me": "め", "mo": "も",
        // Y-row
        "ya": "や", "yu": "ゆ", "yo": "よ",
        // R-row
        "ra": "ら", "ri": "り", "ru": "る", "re": "れ", "ro": "ろ",
        // W-row
        "wa": "わ", "wi": "ゐ", "we": "ゑ", "wo": "を",
        // N (standalone)
        "nn": "ん", "n'": "ん", "xn": "ん",
        // Voiced (G)
        "ga": "が", "gi": "ぎ", "gu": "ぐ", "ge": "げ", "go": "ご",
        // Voiced (Z)
        "za": "ざ", "zi": "じ", "ji": "じ", "zu": "ず", "ze": "ぜ", "zo": "ぞ",
        // Voiced (D)
        "da": "だ", "di": "ぢ", "du": "づ", "de": "で", "do": "ど",
        // Voiced (B)
        "ba": "ば", "bi": "び", "bu": "ぶ", "be": "べ", "bo": "ぼ",
        // Half-voiced (P)
        "pa": "ぱ", "pi": "ぴ", "pu": "ぷ", "pe": "ぺ", "po": "ぽ",
        // Combo kana (KY, SH, CH, NY, HY, MY, RY, GY, JY, BY, PY)
        "kya": "きゃ", "kyi": "きぃ", "kyu": "きゅ", "kye": "きぇ", "kyo": "きょ",
        "sha": "しゃ", "shu": "しゅ", "she": "しぇ", "sho": "しょ",
        "sya": "しゃ", "syu": "しゅ", "syo": "しょ",
        "cha": "ちゃ", "chu": "ちゅ", "che": "ちぇ", "cho": "ちょ",
        "tya": "ちゃ", "tyu": "ちゅ", "tyo": "ちょ",
        "nya": "にゃ", "nyu": "にゅ", "nye": "にぇ", "nyo": "にょ",
        "hya": "ひゃ", "hyu": "ひゅ", "hye": "ひぇ", "hyo": "ひょ",
        "mya": "みゃ", "myu": "みゅ", "mye": "みぇ", "myo": "みょ",
        "rya": "りゃ", "ryu": "りゅ", "rye": "りぇ", "ryo": "りょ",
        "gya": "ぎゃ", "gyu": "ぎゅ", "gye": "ぎぇ", "gyo": "ぎょ",
        "ja": "じゃ", "ju": "じゅ", "je": "じぇ", "jo": "じょ",
        "jya": "じゃ", "jyu": "じゅ", "jyo": "じょ",
        "bya": "びゃ", "byu": "びゅ", "bye": "びぇ", "byo": "びょ",
        "pya": "ぴゃ", "pyu": "ぴゅ", "pye": "ぴぇ", "pyo": "ぴょ",
        // Small kana
        "xtu": "っ", "xtsu": "っ", "ltu": "っ",
        "xa": "ぁ", "xi": "ぃ", "xu": "ぅ", "xe": "ぇ", "xo": "ぉ",
        "xya": "ゃ", "xyu": "ゅ", "xyo": "ょ",
        // Fa/fi/fe/fo
        "fa": "ふぁ", "fi": "ふぃ", "fe": "ふぇ", "fo": "ふぉ",
        // Di/du/ti/tu alternates
        "dya": "ぢゃ", "dyu": "ぢゅ", "dyo": "ぢょ",
        // Tsa/tsi/tse/tso
        "tsa": "つぁ", "tsi": "つぃ", "tse": "つぇ", "tso": "つぉ",
    ]

    /// Prefixes that could become a valid romaji if more letters are added.
    private static let validPrefixes: Set<String> = {
        var prefixes = Set<String>()
        for key in romajiMap.keys {
            for i in 1..<key.count {
                prefixes.insert(String(key.prefix(i)))
            }
        }
        return prefixes
    }()

    // MARK: - InputMethod

    func processKey(_ key: String) -> Bool {
        let ch = key.lowercased()
        guard ch.count == 1, let c = ch.first, c.isASCII, c.isLetter else { return false }

        // Double consonant → small tsu (っ) + new consonant
        if romajiBuffer.count == 1 && ch == romajiBuffer && ch != "a" && ch != "i"
            && ch != "u" && ch != "e" && ch != "o" && ch != "n" {
            romajiBuffer = ch
            displayText += "っ"
            compositionText = romajiBuffer
            updateCandidates()
            onStateChanged?()
            return true
        }

        let newBuffer = romajiBuffer + ch

        // Check if it directly maps
        if let hiragana = Self.romajiMap[newBuffer] {
            displayText += hiragana
            romajiBuffer = ""
            compositionText = romajiBuffer
            updateCandidates()
            onStateChanged?()
            return true
        }

        // "n" followed by a consonant (not n, y, or vowel) → commit ん
        if romajiBuffer == "n" && ch != "n" && ch != "y" && ch != "a" && ch != "i"
            && ch != "u" && ch != "e" && ch != "o" {
            displayText += "ん"
            romajiBuffer = ch
            compositionText = romajiBuffer
            updateCandidates()
            onStateChanged?()
            return true
        }

        // Check if newBuffer is a valid prefix
        if Self.validPrefixes.contains(newBuffer) || Self.romajiMap[newBuffer] != nil {
            romajiBuffer = newBuffer
            compositionText = romajiBuffer
            onStateChanged?()
            return true
        }

        // Not a valid continuation — try to flush current buffer
        // Attempt converting just the buffer first
        if let hiragana = Self.romajiMap[romajiBuffer] {
            displayText += hiragana
            romajiBuffer = ch
            compositionText = romajiBuffer
            updateCandidates()
            onStateChanged?()
            return true
        }

        // If buffer was "n" standalone
        if romajiBuffer == "n" {
            displayText += "ん"
            romajiBuffer = ch
            compositionText = romajiBuffer
            updateCandidates()
            onStateChanged?()
            return true
        }

        // Can't convert — just append
        romajiBuffer = newBuffer
        compositionText = romajiBuffer
        onStateChanged?()
        return true
    }

    func processBackspace() -> Bool {
        if !romajiBuffer.isEmpty {
            romajiBuffer.removeLast()
            compositionText = romajiBuffer
            if romajiBuffer.isEmpty && displayText.isEmpty {
                candidates = []
            }
            onStateChanged?()
            return true
        }
        if !displayText.isEmpty {
            displayText.removeLast()
            compositionText = romajiBuffer
            updateCandidates()
            onStateChanged?()
            return true
        }
        return false
    }

    func processSpace() -> Bool {
        guard !displayText.isEmpty || !romajiBuffer.isEmpty else { return false }
        flushBuffer()
        // Accept first candidate or hiragana as-is
        if let first = candidates.first {
            onCommit?(first)
        } else {
            onCommit?(displayText)
        }
        displayText = ""
        romajiBuffer = ""
        compositionText = ""
        candidates = []
        onStateChanged?()
        return true
    }

    func acceptCandidate(at index: Int) {
        guard index < candidates.count else { return }
        onCommit?(candidates[index])
        displayText = ""
        romajiBuffer = ""
        compositionText = ""
        candidates = []
        onStateChanged?()
    }

    func reset() {
        romajiBuffer = ""
        displayText = ""
        compositionText = ""
        candidates = []
        onStateChanged?()
    }

    // MARK: - Private

    private func flushBuffer() {
        if romajiBuffer == "n" {
            displayText += "ん"
            romajiBuffer = ""
        } else if let h = Self.romajiMap[romajiBuffer] {
            displayText += h
            romajiBuffer = ""
        } else if !romajiBuffer.isEmpty {
            // Can't convert remainder — append as-is
            displayText += romajiBuffer
            romajiBuffer = ""
        }
        compositionText = ""
    }

    private func updateCandidates() {
        let hiragana = displayText
        guard !hiragana.isEmpty else {
            kanjiTask?.cancel()
            candidates = []
            return
        }

        // Immediate: hiragana + katakana (zero-cost)
        var immediate: [String] = [hiragana]
        let mutable = NSMutableString(string: hiragana)
        CFStringTransform(mutable, nil, kCFStringTransformHiraganaKatakana, false)
        let katakana = mutable as String
        if katakana != hiragana { immediate.append(katakana) }
        candidates = immediate

        // Deferred: kanji from UITextChecker on background thread
        let capturedHiragana = hiragana
        kanjiTask?.cancel()
        kanjiTask = Task { @MainActor [weak self] in
            let kanji = await Self.kanjiLookup(hiragana: capturedHiragana)
            guard !Task.isCancelled else { return }
            guard let self, self.displayText == capturedHiragana else { return }
            var merged = kanji
            if !merged.contains(capturedHiragana) { merged.append(capturedHiragana) }
            if katakana != capturedHiragana && !merged.contains(katakana) { merged.append(katakana) }
            self.candidates = merged
            self.onStateChanged?()
        }
    }

    /// Shared background UITextChecker — avoids creating a new instance per lookup.
    private static let backgroundChecker = UITextChecker()
    private static let checkerQueue = DispatchQueue(label: "jp.spellcheck", qos: .userInitiated)

    /// Runs UITextChecker kanji lookup off the main thread.
    nonisolated private static func kanjiLookup(hiragana: String) async -> [String] {
        await withCheckedContinuation { continuation in
            checkerQueue.async {
                let range = NSRange(0..<hiragana.utf16.count)
                let results = backgroundChecker.completions(
                    forPartialWordRange: range, in: hiragana, language: "ja"
                ) ?? []
                continuation.resume(returning: Array(results.prefix(8)))
            }
        }
    }
}
