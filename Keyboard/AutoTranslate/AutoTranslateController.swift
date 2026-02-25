import Foundation
import Translation

@Observable
@MainActor
final class AutoTranslateController {
    var autoTranslatedText: String = ""
    var isAutoTranslating: Bool = false

    @ObservationIgnored private var debounceTask: Task<Void, Never>?
    @ObservationIgnored private var lastSubmittedText: String = ""
    @ObservationIgnored private var sentenceCache: [String: String] = [:]
    @ObservationIgnored private let sentenceCacheLimit = 100

    func textDidChange(
        getText: () -> String,
        isEnabled: Bool,
        translationService: TranslationService,
        fromLang: Locale.Language,
        toLang: Locale.Language,
        fromLangID: String,
        toLangID: String
    ) {
        guard isEnabled else { return }

        let text = getText()

        // User deleted all text
        guard !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            clearState()
            return
        }

        // Same text already translated
        guard text != lastSubmittedText else { return }

        // Sentence-end detection: if text ends with sentence terminator, translate immediately
        let trimmed = text.trimmingCharacters(in: .whitespaces)
        let lastChar = trimmed.last
        let isSentenceEnd = lastChar == "." || lastChar == "!" || lastChar == "?"
            || lastChar == "\u{3002}" || lastChar == "\u{FF01}" || lastChar == "\u{FF1F}"

        debounceTask?.cancel()

        if isSentenceEnd {
            // Immediate translate — no debounce
            let capturedText = text
            debounceTask = Task {
                await performIncrementalTranslate(
                    text: capturedText,
                    translationService: translationService,
                    fromLang: fromLang,
                    toLang: toLang,
                    fromLangID: fromLangID,
                    toLangID: toLangID
                )
            }
        } else {
            // Debounce 800ms
            let capturedText = text
            debounceTask = Task {
                try? await Task.sleep(for: .milliseconds(800))
                guard !Task.isCancelled else { return }
                // Re-read isn't possible here (closure not Sendable-safe after sleep),
                // but capturedText is what was current at debounce start.
                await performIncrementalTranslate(
                    text: capturedText,
                    translationService: translationService,
                    fromLang: fromLang,
                    toLang: toLang,
                    fromLangID: fromLangID,
                    toLangID: toLangID
                )
            }
        }
    }

    func clearState() {
        debounceTask?.cancel()
        debounceTask = nil
        autoTranslatedText = ""
        isAutoTranslating = false
        lastSubmittedText = ""
        sentenceCache.removeAll()
    }

    func clearSentenceCache() {
        sentenceCache.removeAll()
    }

    // MARK: - Private

    private func performIncrementalTranslate(
        text: String,
        translationService: TranslationService,
        fromLang: Locale.Language,
        toLang: Locale.Language,
        fromLangID: String,
        toLangID: String
    ) async {
        guard !Task.isCancelled else { return }

        isAutoTranslating = true
        lastSubmittedText = text

        let sentences = SentenceTracker.split(text)
        var translatedParts: [String] = []
        var uncachedSentences: [(index: Int, text: String)] = []

        for (i, sentence) in sentences.enumerated() {
            // Skip incomplete trailing fragment unless it's the only text
            if !sentence.isComplete && sentences.count > 1 { continue }

            let trimmedText = sentence.text.trimmingCharacters(in: .whitespaces)
            guard !trimmedText.isEmpty else { continue }

            // Check sentence cache first
            if let cached = sentenceCache[trimmedText] {
                translatedParts.append(cached)
                continue
            }

            // Check global cache
            let cacheKey = TranslationCacheKey(text: trimmedText, from: fromLangID, to: toLangID)
            if var cache = translationService.cache as TranslationCache?,
               let cached = cache.get(cacheKey) {
                translationService.cache = cache
                translatedParts.append(cached)
                sentenceCache[trimmedText] = cached
                continue
            }

            // Needs translation
            uncachedSentences.append((index: translatedParts.count, text: trimmedText))
            translatedParts.append("") // placeholder
        }

        guard !Task.isCancelled else {
            isAutoTranslating = false
            return
        }

        // Batch translate all uncached sentences
        if !uncachedSentences.isEmpty {
            do {
                let texts = uncachedSentences.map(\.text)
                let results = try await translationService.batchTranslateDirect(texts, from: fromLang, to: toLang)

                guard !Task.isCancelled else {
                    isAutoTranslating = false
                    return
                }

                for (i, result) in results.enumerated() {
                    let sourceText = uncachedSentences[i].text
                    let placeholderIndex = uncachedSentences[i].index
                    translatedParts[placeholderIndex] = result

                    // Cache at both levels
                    sentenceCache[sourceText] = result
                    if sentenceCache.count > sentenceCacheLimit {
                        sentenceCache.removeValue(forKey: sentenceCache.keys.first!)
                    }
                    let cacheKey = TranslationCacheKey(text: sourceText, from: fromLangID, to: toLangID)
                    translationService.cache.set(cacheKey, value: result)
                }
            } catch {
                // Session not ready or translation failed — silently fail,
                // next textDidChange will retry.
                isAutoTranslating = false
                return
            }
        }

        guard !Task.isCancelled else {
            isAutoTranslating = false
            return
        }

        autoTranslatedText = translatedParts.joined(separator: " ")
        isAutoTranslating = false
    }
}
