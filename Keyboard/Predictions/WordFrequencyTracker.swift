import Foundation

@Observable
@MainActor
final class WordFrequencyTracker {
    private static let maxWords = 5000
    private static let minWordLength = 2

    private var frequencyMap: [String: Int] = [:]
    private var sortedWords: [(word: String, count: Int)] = []
    private let defaults: UserDefaults
    @ObservationIgnored private var persistTimer: Timer?
    @ObservationIgnored private var sortedDirty = false

    init() {
        defaults = UserDefaults(suiteName: AppConstants.appGroupID) ?? .standard
        load()
    }

    func recordWord(_ word: String) {
        let normalized = word.lowercased()
        guard normalized.count >= Self.minWordLength,
              normalized.allSatisfy({ $0.isLetter }) else { return }
        frequencyMap[normalized, default: 0] += 1
        if frequencyMap.count > Self.maxWords {
            evictLeastFrequent(excluding: normalized)
        }
        sortedDirty = true
        debouncePersist()
    }

    func predictions(for prefix: String) -> [String] {
        if sortedDirty { rebuildSorted(); sortedDirty = false }
        let p = prefix.lowercased()
        guard p.count >= Self.minWordLength else { return [] }
        var results: [String] = []
        for (word, _) in sortedWords {
            if word == p { continue }
            if word.hasPrefix(p) {
                results.append(word)
                if results.count >= 3 { break }
            }
        }
        return results
    }

    private func load() {
        if let data = defaults.dictionary(forKey: AppConstants.wordFrequencyKey) as? [String: Int] {
            frequencyMap = data
        }
        rebuildSorted()
    }

    private func persist() {
        defaults.set(frequencyMap, forKey: AppConstants.wordFrequencyKey)
    }

    private func rebuildSorted() {
        sortedWords = frequencyMap
            .sorted { $0.value > $1.value }
            .map { (word: $0.key, count: $0.value) }
    }

    private func debouncePersist() {
        persistTimer?.invalidate()
        persistTimer = Timer.scheduledTimer(withTimeInterval: 3.0, repeats: false) { [weak self] _ in
            MainActor.assumeIsolated {
                self?.persist()
            }
        }
    }

    private func evictLeastFrequent(excluding protected: String) {
        var minWord: String?
        var minCount = Int.max
        for (word, count) in frequencyMap where word != protected {
            if count < minCount { minCount = count; minWord = word }
        }
        if let victim = minWord { frequencyMap.removeValue(forKey: victim) }
    }
}
