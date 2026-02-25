import Foundation

@MainActor
protocol InputMethod: AnyObject {
    /// Process a key tap. Returns true if consumed by the IME.
    func processKey(_ key: String) -> Bool
    /// Process backspace. Returns true if consumed by the IME.
    func processBackspace() -> Bool
    /// Process space. Returns true if consumed (e.g. accept candidate).
    func processSpace() -> Bool
    /// Raw input buffer (pinyin/romaji letters).
    var compositionText: String { get }
    /// Rendered form shown to user (hiragana for ja, same as compositionText for zh).
    var displayText: String { get }
    /// Candidate list for the current composition.
    var candidates: [String] { get }
    /// Accept candidate at given index — inserts the character and advances.
    func acceptCandidate(at index: Int)
    /// Clear all composition state.
    func reset()
    /// Called by the IME when state changes; KeyboardContext sets this to sync observed properties.
    var onStateChanged: (() -> Void)? { get set }
    /// Called by the IME when text should be committed to the proxy.
    var onCommit: ((String) -> Void)? { get set }
}
