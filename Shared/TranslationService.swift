import Foundation
import Translation

enum TranslationError: Error {
    case noSession
}

@Observable
@MainActor
final class TranslationService {
    var translatedText: String = ""
    var isTranslating: Bool = false
    var error: String?
    var cache = TranslationCache(maxEntries: 50)

    /// The configuration that drives `.translationTask()`.
    var configuration: TranslationSession.Configuration?

    private var pendingText: String = ""
    private var cachedSession: TranslationSession?
    private var sessionTimeout: Task<Void, Never>?
    @ObservationIgnored private var pendingCacheKey: TranslationCacheKey?

    func requestTranslation(
        of text: String,
        from source: Locale.Language,
        to target: Locale.Language
    ) {
        guard !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }

        // Check cache before hitting the API
        let cacheKey = TranslationCacheKey(
            text: text,
            from: source.minimalIdentifier,
            to: target.minimalIdentifier
        )
        if let cached = cache.get(cacheKey) {
            translatedText = cached
            isTranslating = false
            error = nil
            return
        }

        pendingText = text
        pendingCacheKey = cacheKey
        isTranslating = true
        error = nil

        // If we have a cached session, translate directly — skip the modifier round-trip.
        if let session = cachedSession {
            Task {
                await translateDirectly(text, using: session, source: source, target: target)
            }
        } else {
            configuration = .init(source: source, target: target)
        }
    }

    /// Called from `.translationTask()` modifier on first use to bootstrap the session.
    func performTranslation(using session: TranslationSession) async {
        cachedSession = session
        guard !pendingText.isEmpty else {
            isTranslating = false
            return
        }
        do {
            let response = try await session.translate(pendingText)
            translatedText = response.targetText
            error = nil
            if let key = pendingCacheKey {
                cache.set(key, value: response.targetText)
                pendingCacheKey = nil
            }
        } catch {
            self.error = error.localizedDescription
            translatedText = ""
        }
        pendingText = ""
        isTranslating = false
        resetSessionTimeout()
    }

    /// Fast path — reuses the cached session directly, no SwiftUI round-trip.
    private func translateDirectly(
        _ text: String,
        using session: TranslationSession,
        source: Locale.Language,
        target: Locale.Language
    ) async {
        do {
            let request = TranslationSession.Request(sourceText: text, clientIdentifier: "keyboard")
            let responses = try await session.translations(from: [request])
            if let result = responses.first {
                translatedText = result.targetText
                if let key = pendingCacheKey {
                    cache.set(key, value: result.targetText)
                    pendingCacheKey = nil
                }
            }
            error = nil
        } catch {
            // Session might be stale — fall back to config-based path.
            cachedSession = nil
            configuration = .init(source: source, target: target)
            return
        }
        pendingText = ""
        isTranslating = false
        resetSessionTimeout()
    }

    // MARK: - Auto-Translate API

    /// Direct translation for AutoTranslateController — does NOT touch translatedText/isTranslating.
    func translateDirect(_ text: String, from source: Locale.Language, to target: Locale.Language) async throws -> String {
        guard let session = cachedSession else { throw TranslationError.noSession }
        let request = TranslationSession.Request(sourceText: text, clientIdentifier: "auto")
        let responses = try await session.translations(from: [request])
        resetSessionTimeout()
        guard let result = responses.first else { throw TranslationError.noSession }
        return result.targetText
    }

    /// Batch translation — single XPC round-trip for multiple sentences.
    func batchTranslateDirect(_ texts: [String], from source: Locale.Language, to target: Locale.Language) async throws -> [String] {
        guard let session = cachedSession else { throw TranslationError.noSession }
        let requests = texts.map { TranslationSession.Request(sourceText: $0, clientIdentifier: "auto") }
        let responses = try await session.translations(from: requests)
        resetSessionTimeout()
        return responses.map(\.targetText)
    }

    /// Pre-warm the translation session so first real translation has no bootstrap delay.
    func prewarmSession(source: Locale.Language, target: Locale.Language) {
        guard cachedSession == nil else { return }
        pendingText = ""
        configuration = .init(source: source, target: target)
    }

    /// Releases the cached session after 60 seconds of inactivity to free XPC resources.
    private func resetSessionTimeout() {
        sessionTimeout?.cancel()
        sessionTimeout = Task { [weak self] in
            try? await Task.sleep(for: .seconds(60))
            self?.cachedSession = nil
        }
    }
}
