import Foundation
import Translation

@Observable
@MainActor
final class TranslationService {
    var translatedText: String = ""
    var isTranslating: Bool = false
    var error: String?

    /// The configuration that drives `.translationTask()`.
    var configuration: TranslationSession.Configuration?

    private var pendingText: String = ""
    private var cachedSession: TranslationSession?
    private var sessionTimeout: Task<Void, Never>?

    func requestTranslation(
        of text: String,
        from source: Locale.Language,
        to target: Locale.Language
    ) {
        guard !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
        pendingText = text
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

    /// Releases the cached session after 60 seconds of inactivity to free XPC resources.
    private func resetSessionTimeout() {
        sessionTimeout?.cancel()
        sessionTimeout = Task { [weak self] in
            try? await Task.sleep(for: .seconds(60))
            self?.cachedSession = nil
        }
    }
}
