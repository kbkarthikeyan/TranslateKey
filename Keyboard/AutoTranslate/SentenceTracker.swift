import Foundation

struct Sentence {
    let text: String
    let isComplete: Bool
}

enum SentenceTracker {

    /// Latin sentence terminators followed by whitespace or end-of-string.
    /// CJK terminators: 。(U+3002) ！(U+FF01) ？(U+FF1F)
    private static let terminators: Set<Character> = [".", "!", "?", "\u{3002}", "\u{FF01}", "\u{FF1F}"]

    static func split(_ text: String) -> [Sentence] {
        guard !text.isEmpty else { return [] }

        var sentences: [Sentence] = []
        var current: String.Index = text.startIndex

        var i = text.startIndex
        while i < text.endIndex {
            let ch = text[i]
            if terminators.contains(ch) {
                let afterTerminator = text.index(after: i)
                // CJK terminators complete a sentence immediately.
                // Latin terminators require whitespace or end-of-string after them.
                let isCJK = ch == "\u{3002}" || ch == "\u{FF01}" || ch == "\u{FF1F}"
                let atEnd = afterTerminator == text.endIndex
                let followedBySpace = !atEnd && text[afterTerminator].isWhitespace

                if isCJK || atEnd || followedBySpace {
                    // Include the terminator (and trailing space for Latin) in the sentence
                    let end: String.Index
                    if followedBySpace && !isCJK {
                        end = text.index(after: afterTerminator)
                    } else {
                        end = afterTerminator
                    }
                    let sentenceText = String(text[current..<end])
                    sentences.append(Sentence(text: sentenceText, isComplete: true))
                    current = end
                    i = end
                    continue
                }
            }
            i = text.index(after: i)
        }

        // Trailing incomplete fragment
        if current < text.endIndex {
            let remaining = String(text[current...])
            if !remaining.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                sentences.append(Sentence(text: remaining, isComplete: false))
            }
        }

        return sentences
    }
}
