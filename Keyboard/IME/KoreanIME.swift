import Foundation

/// Korean 2-set Jamo keyboard layout.
enum KoreanLayout {
    static let row1: [String] = ["ㅂ", "ㅈ", "ㄷ", "ㄱ", "ㅅ", "ㅛ", "ㅕ", "ㅑ", "ㅐ", "ㅔ"]
    static let row2: [String] = ["ㅁ", "ㄴ", "ㅇ", "ㄹ", "ㅎ", "ㅗ", "ㅓ", "ㅏ", "ㅣ"]
    static let row3: [String] = ["ㅋ", "ㅌ", "ㅊ", "ㅍ", "ㅠ", "ㅜ", "ㅡ"]

    /// Shift produces double (tense) consonants.
    static let row1Shift: [String] = ["ㅃ", "ㅉ", "ㄸ", "ㄲ", "ㅆ", "ㅛ", "ㅕ", "ㅑ", "ㅐ", "ㅔ"]
    static let row2Shift: [String] = ["ㅁ", "ㄴ", "ㅇ", "ㄹ", "ㅎ", "ㅗ", "ㅓ", "ㅏ", "ㅣ"]
    static let row3Shift: [String] = ["ㅋ", "ㅌ", "ㅊ", "ㅍ", "ㅠ", "ㅜ", "ㅡ"]

    static func rows(shifted: Bool) -> [[String]] {
        if shifted {
            return [row1Shift, row2Shift, row3Shift]
        }
        return [row1, row2, row3]
    }
}

/// Korean Jamo composition engine using Unicode syllable math.
///
/// Hangul syllable = 0xAC00 + (leadIndex × 21 + vowelIndex) × 28 + tailIndex
///
/// State machine: empty → hasLead → hasLeadVowel → hasLeadVowelTail
/// When tail + vowel arrives, commit current syllable without tail,
/// tail becomes new lead, compose new syllable with new vowel.
@MainActor
final class KoreanIME: InputMethod {
    var onStateChanged: (() -> Void)?
    var onCommit: ((String) -> Void)?

    private(set) var compositionText: String = ""
    var displayText: String { compositionText }
    var candidates: [String] { [] }

    private enum State {
        case empty
        case hasLead(Int)
        case hasLeadVowel(Int, Int)
        case hasLeadVowelTail(Int, Int, Int)
    }

    private var state: State = .empty

    // MARK: - Jamo Tables

    /// 19 leading consonants (choseong)
    private static let leads: [Character] = [
        "ㄱ", "ㄲ", "ㄴ", "ㄷ", "ㄸ", "ㄹ", "ㅁ", "ㅂ", "ㅃ",
        "ㅅ", "ㅆ", "ㅇ", "ㅈ", "ㅉ", "ㅊ", "ㅋ", "ㅌ", "ㅍ", "ㅎ"
    ]

    /// 21 vowels (jungseong)
    private static let vowels: [Character] = [
        "ㅏ", "ㅐ", "ㅑ", "ㅒ", "ㅓ", "ㅔ", "ㅕ", "ㅖ", "ㅗ", "ㅘ", "ㅙ",
        "ㅚ", "ㅛ", "ㅜ", "ㅝ", "ㅞ", "ㅟ", "ㅠ", "ㅡ", "ㅢ", "ㅣ"
    ]

    /// 28 trailing consonants (jongseong), index 0 = none
    private static let tails: [Character?] = [
        nil,
        "ㄱ", "ㄲ", "ㄳ", "ㄴ", "ㄵ", "ㄶ", "ㄷ", "ㄹ", "ㄺ", "ㄻ",
        "ㄼ", "ㄽ", "ㄾ", "ㄿ", "ㅀ", "ㅁ", "ㅂ", "ㅄ", "ㅅ", "ㅆ",
        "ㅇ", "ㅈ", "ㅊ", "ㅋ", "ㅌ", "ㅍ", "ㅎ"
    ]

    /// Compound vowel composition: (base vowel, added jamo) → compound vowel
    private static let compoundVowels: [(Int, Character, Int)] = [
        (8,  "ㅏ", 9),   // ㅗ + ㅏ → ㅘ
        (8,  "ㅐ", 10),  // ㅗ + ㅐ → ㅙ
        (8,  "ㅣ", 11),  // ㅗ + ㅣ → ㅚ
        (13, "ㅓ", 14),  // ㅜ + ㅓ → ㅝ
        (13, "ㅔ", 15),  // ㅜ + ㅔ → ㅞ
        (13, "ㅣ", 16),  // ㅜ + ㅣ → ㅟ
        (18, "ㅣ", 19),  // ㅡ + ㅣ → ㅢ
    ]

    /// Compound tail composition: (base tail index, added jamo) → compound tail index
    private static let compoundTails: [(Int, Character, Int)] = [
        (1,  "ㅅ", 3),   // ㄱ + ㅅ → ㄳ
        (4,  "ㅈ", 5),   // ㄴ + ㅈ → ㄵ
        (4,  "ㅎ", 6),   // ㄴ + ㅎ → ㄶ
        (8,  "ㄱ", 9),   // ㄹ + ㄱ → ㄺ
        (8,  "ㅁ", 10),  // ㄹ + ㅁ → ㄻ
        (8,  "ㅂ", 11),  // ㄹ + ㅂ → ㄼ
        (8,  "ㅅ", 12),  // ㄹ + ㅅ → ㄽ
        (8,  "ㅌ", 13),  // ㄹ + ㅌ → ㄾ
        (8,  "ㅍ", 14),  // ㄹ + ㅍ → ㄿ
        (8,  "ㅎ", 15),  // ㄹ + ㅎ → ㅀ
        (17, "ㅅ", 18),  // ㅂ + ㅅ → ㅄ
    ]

    /// Decompose a compound tail into (base tail index, detached lead index).
    /// When a vowel follows a compound tail, the second part detaches as a new lead.
    private static let tailDecompose: [Int: (Int, Int)] = [
        3:  (1, 9),   // ㄳ → ㄱ + ㅅ(lead 9)
        5:  (4, 12),  // ㄵ → ㄴ + ㅈ(lead 12)
        6:  (4, 18),  // ㄶ → ㄴ + ㅎ(lead 18)
        9:  (8, 0),   // ㄺ → ㄹ + ㄱ(lead 0)
        10: (8, 6),   // ㄻ → ㄹ + ㅁ(lead 6)
        11: (8, 7),   // ㄼ → ㄹ + ㅂ(lead 7)
        12: (8, 9),   // ㄽ → ㄹ + ㅅ(lead 9)
        13: (8, 16),  // ㄾ → ㄹ + ㅌ(lead 16)
        14: (8, 17),  // ㄿ → ㄹ + ㅍ(lead 17)
        15: (8, 18),  // ㅀ → ㄹ + ㅎ(lead 18)
        18: (17, 9),  // ㅄ → ㅂ + ㅅ(lead 9)
    ]

    /// Map a single-char tail to its lead index (for tail→lead promotion).
    private static let tailToLead: [Int: Int] = {
        // Build from tails and leads arrays: tail char → lead index
        var map: [Int: Int] = [:]
        for (ti, tchar) in tails.enumerated() {
            guard let tc = tchar else { continue }
            if let li = leads.firstIndex(of: tc) {
                map[ti] = li
            }
        }
        return map
    }()

    // MARK: - InputMethod

    func processKey(_ key: String) -> Bool {
        guard let ch = key.first else { return false }
        let isLead = Self.leads.contains(ch)
        let isVowel = Self.vowels.contains(ch)
        guard isLead || isVowel else { return false }

        switch state {
        case .empty:
            if isLead, let li = Self.leads.firstIndex(of: ch) {
                state = .hasLead(li)
            } else if isVowel, let vi = Self.vowels.firstIndex(of: ch) {
                // Bare vowel — commit directly
                commitChar(String(ch))
                state = .empty
            }

        case .hasLead(let lead):
            if isVowel, let vi = Self.vowels.firstIndex(of: ch) {
                state = .hasLeadVowel(lead, vi)
            } else if isLead, let li = Self.leads.firstIndex(of: ch) {
                // New consonant — commit the old one as a bare jamo and start fresh
                commitChar(String(Self.leads[lead]))
                state = .hasLead(li)
            }

        case .hasLeadVowel(let lead, let vowel):
            if isVowel {
                // Check compound vowel
                if let compound = Self.compoundVowels.first(where: { $0.0 == vowel && $0.1 == ch }) {
                    state = .hasLeadVowel(lead, compound.2)
                } else if let vi = Self.vowels.firstIndex(of: ch) {
                    // Commit current syllable, start new bare vowel
                    commitSyllable(lead: lead, vowel: vowel, tail: 0)
                    commitChar(String(ch))
                    state = .empty
                }
            } else if isLead {
                // Could be a tail
                if let ti = tailIndex(for: ch), ti > 0 {
                    state = .hasLeadVowelTail(lead, vowel, ti)
                } else {
                    // Not a valid tail — commit syllable, start new lead
                    commitSyllable(lead: lead, vowel: vowel, tail: 0)
                    if let li = Self.leads.firstIndex(of: ch) {
                        state = .hasLead(li)
                    }
                }
            }

        case .hasLeadVowelTail(let lead, let vowel, let tail):
            if isVowel {
                // Check if compound tail can decompose
                if let decomp = Self.tailDecompose[tail] {
                    // Commit syllable with base tail, detached part becomes new lead
                    commitSyllable(lead: lead, vowel: vowel, tail: decomp.0)
                    if let vi = Self.vowels.firstIndex(of: ch) {
                        state = .hasLeadVowel(decomp.1, vi)
                    }
                } else if let newLead = Self.tailToLead[tail] {
                    // Simple tail → promote to lead
                    commitSyllable(lead: lead, vowel: vowel, tail: 0)
                    if let vi = Self.vowels.firstIndex(of: ch) {
                        state = .hasLeadVowel(newLead, vi)
                    }
                } else {
                    // Can't promote — commit everything
                    commitSyllable(lead: lead, vowel: vowel, tail: tail)
                    commitChar(String(ch))
                    state = .empty
                }
            } else if isLead {
                // Check compound tail
                if let compound = Self.compoundTails.first(where: { $0.0 == tail && $0.1 == ch }) {
                    state = .hasLeadVowelTail(lead, vowel, compound.2)
                } else {
                    // Commit current, start new lead
                    commitSyllable(lead: lead, vowel: vowel, tail: tail)
                    if let li = Self.leads.firstIndex(of: ch) {
                        state = .hasLead(li)
                    }
                }
            }
        }

        updateCompositionText()
        onStateChanged?()
        return true
    }

    func processBackspace() -> Bool {
        switch state {
        case .empty:
            return false
        case .hasLead:
            state = .empty
        case .hasLeadVowel(let lead, let vowel):
            // Check if vowel is compound — decompose
            if let base = Self.compoundVowels.first(where: { $0.2 == vowel }) {
                state = .hasLeadVowel(lead, base.0)
            } else {
                state = .hasLead(lead)
            }
        case .hasLeadVowelTail(let lead, let vowel, let tail):
            // Check if tail is compound — decompose
            if let base = Self.compoundTails.first(where: { $0.2 == tail }) {
                state = .hasLeadVowelTail(lead, vowel, base.0)
            } else {
                state = .hasLeadVowel(lead, vowel)
            }
        }
        updateCompositionText()
        onStateChanged?()
        return true
    }

    func processSpace() -> Bool {
        guard case .empty = state else {
            commitCurrentComposition()
            return true
        }
        return false
    }

    func acceptCandidate(at index: Int) {}

    func reset() {
        state = .empty
        compositionText = ""
        onStateChanged?()
    }

    // MARK: - Private

    private func tailIndex(for ch: Character) -> Int? {
        for (i, t) in Self.tails.enumerated() {
            if let t, t == ch { return i }
        }
        return nil
    }

    private func syllableChar(lead: Int, vowel: Int, tail: Int) -> String {
        let code = 0xAC00 + (lead * 21 + vowel) * 28 + tail
        guard let scalar = Unicode.Scalar(code) else { return "" }
        return String(scalar)
    }

    private func commitSyllable(lead: Int, vowel: Int, tail: Int) {
        let ch = syllableChar(lead: lead, vowel: vowel, tail: tail)
        onCommit?(ch)
    }

    private func commitChar(_ ch: String) {
        onCommit?(ch)
    }

    private func commitCurrentComposition() {
        switch state {
        case .empty:
            break
        case .hasLead(let lead):
            commitChar(String(Self.leads[lead]))
        case .hasLeadVowel(let lead, let vowel):
            commitSyllable(lead: lead, vowel: vowel, tail: 0)
        case .hasLeadVowelTail(let lead, let vowel, let tail):
            commitSyllable(lead: lead, vowel: vowel, tail: tail)
        }
        state = .empty
        compositionText = ""
        onStateChanged?()
    }

    private func updateCompositionText() {
        switch state {
        case .empty:
            compositionText = ""
        case .hasLead(let lead):
            compositionText = String(Self.leads[lead])
        case .hasLeadVowel(let lead, let vowel):
            compositionText = syllableChar(lead: lead, vowel: vowel, tail: 0)
        case .hasLeadVowelTail(let lead, let vowel, let tail):
            compositionText = syllableChar(lead: lead, vowel: vowel, tail: tail)
        }
    }
}
