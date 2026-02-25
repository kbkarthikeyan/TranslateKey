import UIKit

/// Chinese Pinyin IME — QWERTY pinyin input → character candidates via dictionary lookup.
///
/// Supports both Simplified (zh-Hans) and Traditional (zh-Hant) output.
/// Traditional mode applies CFStringTransform on the selected character before insertion.
@MainActor
final class ChinesePinyinIME: InputMethod {
    var onStateChanged: (() -> Void)?
    var onCommit: ((String) -> Void)?

    private(set) var compositionText: String = ""  // raw pinyin letters
    private(set) var displayText: String { get { compositionText } set {} }
    private(set) var candidates: [String] = []

    private let isTraditional: Bool

    /// Pinyin dictionary: syllable → [characters]
    /// nonisolated(unsafe) is safe here — Swift static var uses dispatch_once,
    /// so initialization is inherently thread-safe. Allows background preloading.
    nonisolated(unsafe) private static var dict: [String: [String]] = {
        guard let url = Bundle.main.url(forResource: "pinyin_dict", withExtension: "txt"),
              let content = try? String(contentsOf: url, encoding: .utf8) else {
            assertionFailure("pinyin_dict.txt missing from bundle")
            return minimalFallback
        }
        var map: [String: [String]] = [:]
        for line in content.split(separator: "\n") {
            let parts = line.split(separator: " ", maxSplits: 1)
            guard parts.count == 2 else { continue }
            let syllable = String(parts[0])
            let chars = parts[1].split(separator: ",").map { String($0) }
            map[syllable] = chars
        }
        return map
    }()

    /// ~40 most common syllables so basic input still works if the dict file is missing.
    private static let minimalFallback: [String: [String]] = [
        "a": ["啊", "阿"], "ai": ["爱", "哀"], "an": ["安", "按"],
        "ba": ["把", "八"], "bei": ["北", "被"], "bu": ["不", "步"],
        "da": ["大", "打"], "de": ["的", "得"], "di": ["地", "第"],
        "ge": ["个", "各"], "guo": ["国", "过"],
        "he": ["和", "河"], "hui": ["会", "回"],
        "ji": ["几", "机"], "jiu": ["就", "九"],
        "ke": ["可", "客"], "lai": ["来", "赖"],
        "ma": ["吗", "妈"], "mei": ["没", "美"], "men": ["们", "门"],
        "na": ["那", "拿"], "ni": ["你", "呢"], "nian": ["年", "念"],
        "ren": ["人", "认"], "ri": ["日"],
        "shi": ["是", "时", "十"], "shuo": ["说", "所"],
        "ta": ["他", "她", "它"], "tai": ["太", "台"],
        "wo": ["我", "握"], "wu": ["五", "无"],
        "xi": ["西", "习"], "xian": ["先", "现"],
        "yi": ["一", "以", "已"], "you": ["有", "又", "右"],
        "zai": ["在", "再"], "zhe": ["这", "着"], "zhong": ["中", "重"],
        "zi": ["子", "自"], "zuo": ["做", "作"],
    ]

    /// All valid pinyin syllables (keys from dictionary).
    private static var validSyllables: Set<String> = {
        Set(dict.keys)
    }()

    /// Triggers lazy dict initialization from a background thread.
    /// Swift static var init is thread-safe (dispatch_once), so subsequent
    /// access from main thread returns instantly with no blocking.
    nonisolated static func preloadDict() {
        _ = dict
    }

    init(traditional: Bool = false) {
        self.isTraditional = traditional
    }

    // MARK: - InputMethod

    func processKey(_ key: String) -> Bool {
        let ch = key.lowercased()
        guard ch.count == 1, let c = ch.first, c.isASCII, c.isLetter else { return false }

        compositionText += ch
        updateCandidates()
        onStateChanged?()
        return true
    }

    func processBackspace() -> Bool {
        guard !compositionText.isEmpty else { return false }
        compositionText.removeLast()
        if compositionText.isEmpty {
            candidates = []
        } else {
            updateCandidates()
        }
        onStateChanged?()
        return true
    }

    func processSpace() -> Bool {
        guard !compositionText.isEmpty else { return false }
        if let first = candidates.first {
            commitCharacter(first)
        }
        return true
    }

    func acceptCandidate(at index: Int) {
        guard index < candidates.count else { return }
        commitCharacter(candidates[index])
    }

    func reset() {
        compositionText = ""
        candidates = []
        onStateChanged?()
    }

    // MARK: - Private

    private func commitCharacter(_ char: String) {
        let output: String
        if isTraditional {
            let mutable = NSMutableString(string: char)
            CFStringTransform(mutable, nil, "Simplified-Traditional" as CFString, false)
            output = mutable as String
        } else {
            output = char
        }
        onCommit?(output)

        // Remove the matched syllable from compositionText
        let matched = findFirstSyllable(in: compositionText)
        if !matched.isEmpty {
            compositionText = String(compositionText.dropFirst(matched.count))
        } else {
            compositionText = ""
        }

        if compositionText.isEmpty {
            candidates = []
        } else {
            updateCandidates()
        }
        onStateChanged?()
    }

    /// Greedy longest-match segmentation for the first syllable.
    private func findFirstSyllable(in input: String) -> String {
        let maxLen = min(input.count, 6) // longest pinyin syllable is 6 chars (e.g. "zhuang")
        for len in stride(from: maxLen, through: 1, by: -1) {
            let prefix = String(input.prefix(len))
            if Self.validSyllables.contains(prefix) {
                return prefix
            }
        }
        // No valid syllable found — return first char to avoid getting stuck
        return input.isEmpty ? "" : String(input.prefix(1))
    }

    private func updateCandidates() {
        let syllable = findFirstSyllable(in: compositionText)
        guard !syllable.isEmpty else {
            candidates = []
            return
        }

        var result: [String] = []

        // Exact match from dictionary
        if let chars = Self.dict[syllable] {
            result.append(contentsOf: chars)
        }

        // Also check partial matches (prefix of valid syllables)
        if result.isEmpty {
            for (key, chars) in Self.dict where key.hasPrefix(compositionText) {
                result.append(contentsOf: chars.prefix(3))
                if result.count >= 15 { break }
            }
        }

        // If traditional, convert candidates for display
        if isTraditional {
            result = result.map { char in
                let mutable = NSMutableString(string: char)
                CFStringTransform(mutable, nil, "Simplified-Traditional" as CFString, false)
                return mutable as String
            }
        }

        candidates = Array(result.prefix(20))
    }
}
