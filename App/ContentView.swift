import SwiftUI
import Translation

struct ContentView: View {
    @State private var languageManager = LanguageManager()
    @State private var testInput = ""
    @State private var testOutput = ""
    @State private var translationConfig: TranslationSession.Configuration?
    @State private var selectedTab = 0
    @State private var isTranslating = false
    @State private var languageStatuses: [(String, String, LanguageAvailability.Status)] = []
    @State private var downloadConfig: TranslationSession.Configuration?
    @State private var downloadingLanguageID: String?

    var body: some View {
        TabView(selection: $selectedTab) {
            setupView
                .tabItem { Label("Setup", systemImage: "keyboard") }
                .tag(0)

            settingsView
                .tabItem { Label("Languages", systemImage: "globe") }
                .tag(1)

            quickLanguagesView
                .tabItem { Label("Quick Bar", systemImage: "flag") }
                .tag(2)

            tryItView
                .tabItem { Label("Try It", systemImage: "text.bubble") }
                .tag(3)

            downloadsView
                .tabItem { Label("Downloads", systemImage: "arrow.down.circle") }
                .tag(4)
        }
    }

    // MARK: - Setup Tab

    private var setupView: some View {
        NavigationStack {
            List {
                Section {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("TranslateKey")
                            .font(.largeTitle.bold())
                        Text("Type in any language. Translate instantly.")
                            .foregroundStyle(.secondary)
                    }
                    .listRowBackground(Color.clear)
                    .padding(.vertical, 8)
                }

                Section("Enable the Keyboard") {
                    step(1, "Open Settings app")
                    step(2, "Go to General > Keyboard > Keyboards")
                    step(3, "Tap \"Add New Keyboard...\"")
                    step(4, "Select \"TranslateKey\"")
                    step(5, "Tap TranslateKey and enable \"Allow Full Access\"")
                }

                Section("Sending Messages") {
                    step(1, "Switch to TranslateKey (globe icon)")
                    step(2, "Tap the flag of the language you want")
                    step(3, "Type your message normally")
                    step(4, "Tap the translate button")
                    step(5, "Tap translated text to insert it, then send")
                }

                Section("Reading Messages") {
                    step(1, "Tap \"Send/Read\" toggle to switch to Read mode")
                    step(2, "Copy the foreign message (long press > Copy)")
                    step(3, "Tap the read button — translation appears in the bar")
                }

                Section("Auto-Translate") {
                    Toggle("Auto-Translate", isOn: $languageManager.isAutoTranslateEnabled)
                    Text("When enabled, translations happen automatically as you type (Send mode) or when you copy text (Read mode). No need to tap the translate button.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Section {
                    Button("Open Settings") {
                        if let url = URL(string: UIApplication.openSettingsURLString) {
                            UIApplication.shared.open(url)
                        }
                    }
                }
            }
        }
    }

    private func step(_ number: Int, _ text: String) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Text("\(number)")
                .font(.caption.bold())
                .frame(width: 24, height: 24)
                .background(Circle().fill(.blue))
                .foregroundStyle(.white)
            Text(text)
        }
    }

    // MARK: - Settings Tab

    private var settingsView: some View {
        NavigationStack {
            List {
                Section("Your Language (source)") {
                    Picker("Source Language", selection: $languageManager.sourceLanguageID) {
                        ForEach(LanguageManager.supportedLanguages) { lang in
                            HStack {
                                Text(lang.flag)
                                Text(lang.name)
                            }
                            .tag(lang.id)
                        }
                    }
                    .pickerStyle(.inline)
                    .labelsHidden()
                }

                Section("Default Target Language") {
                    Picker("Target Language", selection: $languageManager.targetLanguageID) {
                        ForEach(LanguageManager.supportedLanguages) { lang in
                            HStack {
                                Text(lang.flag)
                                Text(lang.name)
                            }
                            .tag(lang.id)
                        }
                    }
                    .pickerStyle(.inline)
                    .labelsHidden()
                }
            }
            .navigationTitle("Languages")
        }
    }

    // MARK: - Quick Languages Tab

    private var quickLanguagesView: some View {
        NavigationStack {
            List {
                Section {
                    Text("Pick up to 5 languages to show as quick-switch flags in your keyboard. Tap a flag while chatting to switch target language per conversation.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }

                Section("Selected (\(languageManager.quickLanguageIDs.count))") {
                    ForEach(languageManager.quickLanguageIDs, id: \.self) { id in
                        if let lang = LanguageManager.supportedLanguages.first(where: { $0.id == id }) {
                            HStack {
                                Text(lang.flag)
                                Text(lang.name)
                                Spacer()
                                Button {
                                    languageManager.quickLanguageIDs.removeAll { $0 == id }
                                } label: {
                                    Image(systemName: "minus.circle.fill")
                                        .foregroundStyle(.red)
                                }
                            }
                        }
                    }
                    .onMove { from, to in
                        languageManager.quickLanguageIDs.move(fromOffsets: from, toOffset: to)
                    }
                }

                Section("Available Languages") {
                    ForEach(LanguageManager.supportedLanguages.filter {
                        !languageManager.quickLanguageIDs.contains($0.id)
                    }) { lang in
                        Button {
                            if languageManager.quickLanguageIDs.count < 5 {
                                languageManager.quickLanguageIDs.append(lang.id)
                            }
                        } label: {
                            HStack {
                                Text(lang.flag)
                                Text(lang.name)
                                    .foregroundStyle(.primary)
                                Spacer()
                                if languageManager.quickLanguageIDs.count < 5 {
                                    Image(systemName: "plus.circle.fill")
                                        .foregroundStyle(.green)
                                }
                            }
                        }
                        .disabled(languageManager.quickLanguageIDs.count >= 5)
                    }
                }
            }
            .navigationTitle("Quick Bar")
            .toolbar { EditButton() }
        }
    }

    // MARK: - Try It Tab

    private var tryItView: some View {
        NavigationStack {
            VStack(spacing: 20) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("\(languageManager.sourceName)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    TextField("Type something to translate...", text: $testInput, axis: .vertical)
                        .textFieldStyle(.roundedBorder)
                        .lineLimit(3...6)
                }

                Button {
                    guard !testInput.isEmpty else { return }
                    isTranslating = true
                    testOutput = ""
                    if translationConfig != nil {
                        translationConfig?.source = languageManager.sourceLanguage
                        translationConfig?.target = languageManager.targetLanguage
                        translationConfig?.invalidate()
                    } else {
                        translationConfig = .init(
                            source: languageManager.sourceLanguage,
                            target: languageManager.targetLanguage
                        )
                    }
                } label: {
                    if isTranslating {
                        ProgressView()
                            .frame(maxWidth: .infinity)
                    } else {
                        Label("Translate to \(languageManager.targetName)", systemImage: "arrow.forward")
                            .frame(maxWidth: .infinity)
                    }
                }
                .buttonStyle(.borderedProminent)
                .disabled(isTranslating)

                if !testOutput.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("\(languageManager.targetName)")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Text(testOutput)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding()
                            .background(.fill.tertiary, in: .rect(cornerRadius: 10))
                    }
                }

                Spacer()

                Text("This also downloads translation models for offline use.")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }
            .padding()
            .navigationTitle("Try It")
            .toolbar {
                ToolbarItemGroup(placement: .keyboard) {
                    Spacer()
                    Button("Done") {
                        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
                    }
                }
            }
            .translationTask(translationConfig) { session in
                do {
                    try await session.prepareTranslation()
                    let response = try await session.translate(testInput)
                    testOutput = response.targetText
                } catch {
                    testOutput = "Translation failed: \(error.localizedDescription)"
                }
                isTranslating = false
            }
        }
    }

    // MARK: - Downloads Tab

    private var downloadsView: some View {
        NavigationStack {
            List {
                Section {
                    Text("Tap \"Download\" to install language pairs for offline translation. Requires Wi-Fi.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }

                if languageStatuses.isEmpty {
                    Section {
                        ProgressView("Checking languages...")
                    }
                } else {
                    Section("Language Pairs (with English)") {
                        ForEach(languageStatuses, id: \.0) { id, name, status in
                            HStack {
                                Text(LanguageManager.flag(for: id))
                                Text(name)
                                Spacer()
                                if status == .installed {
                                    Label("Ready", systemImage: "checkmark.circle.fill")
                                        .font(.caption.bold())
                                        .foregroundStyle(.green)
                                } else if status == .supported {
                                    if downloadingLanguageID == id {
                                        ProgressView()
                                    } else {
                                        Button("Download") {
                                            downloadingLanguageID = id
                                            let target = Locale.Language(identifier: id)
                                            let source = Locale.Language(identifier: "en")
                                            if downloadConfig != nil {
                                                downloadConfig?.source = source
                                                downloadConfig?.target = target
                                                downloadConfig?.invalidate()
                                            } else {
                                                downloadConfig = .init(source: source, target: target)
                                            }
                                        }
                                        .font(.caption.bold())
                                        .buttonStyle(.bordered)
                                    }
                                } else {
                                    Label("Unsupported", systemImage: "xmark.circle")
                                        .font(.caption.bold())
                                        .foregroundStyle(.red)
                                }
                            }
                        }
                    }

                    Section {
                        Button("Refresh Status") {
                            Task { await checkLanguageAvailability() }
                        }
                    }
                }
            }
            .navigationTitle("Downloads")
            .task { await checkLanguageAvailability() }
            .translationTask(downloadConfig) { session in
                do {
                    try await session.prepareTranslation()
                } catch {
                    // download cancelled or failed
                }
                downloadingLanguageID = nil
                await checkLanguageAvailability()
            }
        }
    }

    private func checkLanguageAvailability() async {
        let availability = LanguageAvailability()
        let english = Locale.Language(identifier: "en")
        var results: [(String, String, LanguageAvailability.Status)] = []

        for lang in LanguageManager.supportedLanguages where lang.id != "en" {
            let target = Locale.Language(identifier: lang.id)
            let status = await availability.status(from: english, to: target)
            results.append((lang.id, lang.name, status))
        }

        languageStatuses = results
    }
}
