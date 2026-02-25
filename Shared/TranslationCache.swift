import Foundation

struct TranslationCacheKey: Hashable {
    let text: String
    let from: String
    let to: String
}

struct TranslationCache {
    private let maxEntries: Int
    private var entries: [(key: TranslationCacheKey, value: String)] = []

    init(maxEntries: Int = 50) {
        self.maxEntries = maxEntries
    }

    mutating func get(_ key: TranslationCacheKey) -> String? {
        guard let index = entries.firstIndex(where: { $0.key == key }) else { return nil }
        let entry = entries.remove(at: index)
        entries.append(entry)
        return entry.value
    }

    mutating func set(_ key: TranslationCacheKey, value: String) {
        if let index = entries.firstIndex(where: { $0.key == key }) {
            entries.remove(at: index)
        } else if entries.count >= maxEntries {
            entries.removeFirst()
        }
        entries.append((key: key, value: value))
    }

    mutating func clear() {
        entries.removeAll()
    }
}
