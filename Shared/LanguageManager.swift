import Foundation

@Observable
final class LanguageManager {

    struct LanguageOption: Identifiable, Hashable {
        let id: String
        let name: String
        let flag: String
        var locale: Locale.Language { Locale.Language(identifier: id) }
    }

    static let supportedLanguages: [LanguageOption] = [
        .init(id: "en", name: "English", flag: "🇬🇧"),
        .init(id: "es", name: "Spanish", flag: "🇪🇸"),
        .init(id: "fr", name: "French", flag: "🇫🇷"),
        .init(id: "de", name: "German", flag: "🇩🇪"),
        .init(id: "it", name: "Italian", flag: "🇮🇹"),
        .init(id: "pt", name: "Portuguese", flag: "🇵🇹"),
        .init(id: "zh-Hans", name: "Chinese (Simplified)", flag: "🇨🇳"),
        .init(id: "zh-Hant", name: "Chinese (Traditional)", flag: "🇹🇼"),
        .init(id: "ja", name: "Japanese", flag: "🇯🇵"),
        .init(id: "ko", name: "Korean", flag: "🇰🇷"),
        .init(id: "ar", name: "Arabic", flag: "🇸🇦"),
        .init(id: "hi", name: "Hindi", flag: "🇮🇳"),
        .init(id: "ru", name: "Russian", flag: "🇷🇺"),
        .init(id: "tr", name: "Turkish", flag: "🇹🇷"),
        .init(id: "pl", name: "Polish", flag: "🇵🇱"),
        .init(id: "nl", name: "Dutch", flag: "🇳🇱"),
        .init(id: "th", name: "Thai", flag: "🇹🇭"),
        .init(id: "vi", name: "Vietnamese", flag: "🇻🇳"),
        .init(id: "id", name: "Indonesian", flag: "🇮🇩"),
        .init(id: "uk", name: "Ukrainian", flag: "🇺🇦"),
    ]

    private let defaults: UserDefaults?

    var sourceLanguageID: String {
        didSet { defaults?.set(sourceLanguageID, forKey: AppConstants.sourceLanguageKey) }
    }

    var targetLanguageID: String {
        didSet { defaults?.set(targetLanguageID, forKey: AppConstants.targetLanguageKey) }
    }

    /// Languages shown as quick-switch buttons in the keyboard (user configurable)
    var quickLanguageIDs: [String] {
        didSet { defaults?.set(quickLanguageIDs, forKey: AppConstants.quickLanguagesKey) }
    }

    var isAutoTranslateEnabled: Bool {
        didSet { defaults?.set(isAutoTranslateEnabled, forKey: AppConstants.autoTranslateEnabledKey) }
    }

    var sourceLanguage: Locale.Language {
        Locale.Language(identifier: sourceLanguageID)
    }

    var targetLanguage: Locale.Language {
        Locale.Language(identifier: targetLanguageID)
    }

    var sourceName: String {
        Self.name(for: sourceLanguageID)
    }

    var targetName: String {
        Self.name(for: targetLanguageID)
    }

    var quickLanguages: [LanguageOption] {
        quickLanguageIDs.compactMap { id in
            Self.supportedLanguages.first { $0.id == id }
        }
    }

    init() {
        let defaults = UserDefaults(suiteName: AppConstants.appGroupID)
        self.defaults = defaults
        self.sourceLanguageID = defaults?.string(forKey: AppConstants.sourceLanguageKey) ?? "en"
        self.targetLanguageID = defaults?.string(forKey: AppConstants.targetLanguageKey) ?? "es"
        self.quickLanguageIDs = defaults?.stringArray(forKey: AppConstants.quickLanguagesKey)
            ?? ["es", "it", "pl", "fr"]
        self.isAutoTranslateEnabled = defaults?.object(forKey: AppConstants.autoTranslateEnabledKey) as? Bool ?? true
    }

    // DEAD CODE: no UI calls this — kept for potential future use
    // func swapLanguages() {
    //     let temp = sourceLanguageID
    //     sourceLanguageID = targetLanguageID
    //     targetLanguageID = temp
    // }

    func selectTarget(_ id: String) {
        targetLanguageID = id
    }

    static func name(for id: String) -> String {
        supportedLanguages.first { $0.id == id }?.name ?? id
    }

    static func flag(for id: String) -> String {
        supportedLanguages.first { $0.id == id }?.flag ?? "🏳️"
    }

}
