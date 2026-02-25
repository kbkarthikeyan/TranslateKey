import Foundation

/// Lightweight swipe-to-type engine for keyboard extensions.
/// Uses first/last letter filtering + subsequence matching against a frequency-ranked word list.
/// Thread-safe: index is populated once in init() and never mutated after.
final class SwipeEngine: @unchecked Sendable {

    static let shared = SwipeEngine()

    /// Index: (firstLetter, lastLetter) pair → [(word, frequencyRank)]
    /// Lower rank = more common word.
    private var index: [UInt16: [(String, Int)]] = [:]

    private init() {
        let source: String
        if let url = Bundle.main.url(forResource: "words_en", withExtension: "txt"),
           let contents = try? String(contentsOf: url, encoding: .utf8) {
            source = contents
        } else {
            source = Self.wordList
        }
        let words = source.split(separator: "\n")
        for (rank, slice) in words.enumerated() {
            let word = String(slice).trimmingCharacters(in: .whitespaces)
            guard word.count >= 2,
                  let first = word.first?.asciiValue,
                  let last = word.last?.asciiValue,
                  first >= 97, first <= 122,
                  last >= 97, last <= 122 else { continue }
            let key = UInt16(first - 97) &* 26 &+ UInt16(last - 97)
            index[key, default: []].append((word, rank))
        }
        // Cap bucket size to limit memory and search time
        for key in index.keys {
            if index[key]!.count > 300 {
                index[key] = Array(index[key]!.prefix(300))
            }
        }
    }

    /// Match a swipe path (sequence of lowercase key characters) to a word.
    /// Returns the most common word whose letters form a subsequence of the path.
    func match(path: [Character]) -> String? {
        guard path.count >= 2,
              let first = path.first, let last = path.last,
              let fv = first.asciiValue, let lv = last.asciiValue,
              fv >= 97, fv <= 122, lv >= 97, lv <= 122 else { return nil }

        let key = UInt16(fv - 97) &* 26 &+ UInt16(lv - 97)
        guard let candidates = index[key] else { return nil }

        // Deduplicate consecutive keys in path (e.g. [h,h,e,l,l,o] → [h,e,l,o])
        var cleaned: [Character] = []
        for ch in path {
            if cleaned.last != ch { cleaned.append(ch) }
        }

        var bestWord: String?
        var bestRank = Int.max

        for (word, rank) in candidates {
            guard rank < bestRank else { continue }
            // Skip words much shorter than swipe path
            if word.count < max(2, cleaned.count - 4) { continue }
            // Length sanity: word shouldn't be drastically longer than cleaned path
            if word.count > cleaned.count + 3 { continue }
            if isSubsequence(word: word, of: cleaned) {
                bestWord = word
                bestRank = rank
                break  // Candidates sorted by frequency; first match is best
            }
        }

        return bestWord
    }

    /// Check if every character in `word` appears in `path` in order.
    private func isSubsequence(word: String, of path: [Character]) -> Bool {
        var pi = 0
        for ch in word {
            while pi < path.count {
                if path[pi] == ch { pi += 1; break }
                pi += 1
                if pi > path.count { return false }
            }
            if pi > path.count { return false }
        }
        return true
    }

    // MARK: - Fallback Word List (used only if words_en.txt not in bundle)

    private static let wordList = """
the
and
you
that
was
for
are
with
his
they
have
this
from
had
not
but
what
all
were
when
your
can
said
there
each
which
she
how
their
will
other
about
out
many
then
them
these
some
her
would
make
like
him
into
time
has
look
two
more
see
way
could
than
first
been
call
""" // top 50 words, frequency-ranked
}
