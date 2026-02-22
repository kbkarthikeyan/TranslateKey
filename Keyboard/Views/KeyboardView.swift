import SwiftUI
import Translation

struct KeyboardView: View {
    var context: KeyboardContext

    @State private var languageManager = LanguageManager()
    @State private var translationService = TranslationService()
    @State private var isEmojiMode = false
    @State private var emojiHistory = EmojiHistoryManager()
    @State private var selectedCategory: EmojiCategory = .smileys
    @State private var emojiSearchText = ""
    @State private var isEmojiSearching = false

    /// Tracks the direction of translation:
    /// - .outgoing: user types in source, translates to target (sending messages)
    /// - .incoming: user pastes foreign text, translates to source (reading messages)
    @State private var mode: TranslationMode = .outgoing
    private let keySpacing: CGFloat = 6
    private let rowSpacing: CGFloat = 9
    private let keyHeight: CGFloat = 41

    enum TranslationMode {
        case outgoing  // typing → translate to target language
        case incoming  // paste → translate to your language (English)
    }

    var body: some View {
        VStack(spacing: 0) {
            quickLanguageStrip
                .padding(.horizontal, 4)
                .padding(.top, 4)
                .opacity(isEmojiMode ? 0 : 1)
                .frame(height: isEmojiMode ? 0 : nil)
                .clipped()

            translationBar
                .padding(.horizontal, 4)
                .padding(.vertical, isEmojiMode ? 0 : 4)
                .opacity(isEmojiMode ? 0 : 1)
                .frame(height: isEmojiMode ? 0 : nil)
                .clipped()

            if (!context.predictions.isEmpty || context.undoCorrection != nil)
                && !isEmojiMode && !context.isNumberMode {
                predictionBar
                    .padding(.horizontal, 4)
                    .padding(.bottom, 2)
            }

            keyRows
                .padding(.horizontal, 3)
                .padding(.bottom, 2)
        }
        .background(keyboardBackground)
        .translationTask(translationService.configuration) { session in
            await translationService.performTranslation(using: session)
        }
    }

    // MARK: - Quick Language Strip
    // Tap a flag to set the target language for this conversation.

    private var quickLanguageStrip: some View {
        HStack(spacing: 6) {
            ForEach(languageManager.quickLanguages) { lang in
                Button {
                    languageManager.selectTarget(lang.id)
                } label: {
                    VStack(spacing: 1) {
                        Text(lang.flag)
                            .font(.title3)
                        Text(lang.id.uppercased())
                            .font(.system(size: 9, weight: .semibold))
                    }
                    .frame(width: 44, height: 38)
                    .background(
                        lang.id == languageManager.targetLanguageID
                            ? Color.blue.opacity(0.2) : Color.clear,
                        in: .rect(cornerRadius: 6)
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 6)
                            .stroke(
                                lang.id == languageManager.targetLanguageID
                                    ? Color.blue : Color.clear,
                                lineWidth: 1.5
                            )
                    )
                }
                .foregroundStyle(.primary)
            }

            Spacer()

            // Send: translate typed text → target language
            Button {
                let text = context.getCurrentText()
                guard !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
                translationService.requestTranslation(
                    of: text,
                    from: languageManager.sourceLanguage,
                    to: languageManager.targetLanguage
                )
            } label: {
                Text(LanguageManager.flag(for: languageManager.targetLanguageID))
                    .font(.system(size: 18))
                    .frame(width: 44, height: 31)
                    .background(Color.blue.opacity(0.2), in: RoundedRectangle(cornerRadius: 8))
            }

            Spacer()
                .frame(width: 12)

            // Read: translate copied message → source language
            Button {
                guard let pasted = UIPasteboard.general.string,
                      !pasted.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
                mode = .incoming
                translationService.requestTranslation(
                    of: pasted,
                    from: languageManager.targetLanguage,
                    to: languageManager.sourceLanguage
                )
            } label: {
                Text(LanguageManager.flag(for: languageManager.sourceLanguageID))
                    .font(.system(size: 18))
                    .frame(width: 44, height: 31)
                    .background(Color.green.opacity(0.2), in: RoundedRectangle(cornerRadius: 8))
            }

        }
    }

    // MARK: - Translation Bar

    private var translationBar: some View {
        HStack(spacing: 6) {
            // Translation output / status
            Group {
                if translationService.isTranslating {
                    HStack(spacing: 6) {
                        ProgressView()
                            .scaleEffect(0.7)
                        Text("Translating...")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                } else if let error = translationService.error {
                    Text(error)
                        .font(.subheadline)
                        .foregroundStyle(.red)
                } else if !translationService.translatedText.isEmpty {
                    ScrollView(.vertical, showsIndicators: true) {
                        Text(translationService.translatedText)
                            .font(.body)
                            .foregroundStyle(.primary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .frame(maxHeight: 54)
                } else {
                    Color.clear
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            // Insert button
            if !translationService.translatedText.isEmpty {
                Button {
                    context.replaceAllText(with: translationService.translatedText)
                    translationService.translatedText = ""
                } label: {
                    Image(systemName: "arrow.down.doc")
                        .font(.subheadline.bold())
                        .padding(6)
                        .background(.blue, in: .circle)
                        .foregroundStyle(.white)
                }
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 8)
        .modifier(GlassBarBackground())
    }

    // MARK: - Prediction Bar

    private var predictionBar: some View {
        HStack(spacing: 0) {
            // Undo correction button (shown after autocorrect fires)
            if let original = context.undoCorrection {
                Button {
                    context.revertCorrection()
                } label: {
                    Text("\u{201C}\(original)\u{201D}")
                        .font(.system(size: 15, weight: .medium))
                        .lineLimit(1)
                        .frame(maxWidth: .infinity)
                        .frame(height: 36)
                        .contentShape(Rectangle())
                }
                .foregroundStyle(.secondary)
            }

            // Word predictions
            ForEach(Array(context.predictions.enumerated()), id: \.offset) { index, word in
                if index > 0 || context.undoCorrection != nil {
                    Divider()
                        .frame(height: 20)
                        .opacity(0.4)
                }
                Button {
                    context.acceptPrediction(word)
                } label: {
                    Text(word)
                        .font(.system(size: 15))
                        .lineLimit(1)
                        .frame(maxWidth: .infinity)
                        .frame(height: 36)
                        .contentShape(Rectangle())
                }
                .foregroundStyle(.primary)
            }
        }
        .modifier(GlassBarBackground())
    }

    // MARK: - Key Rows

    @ViewBuilder
    private var keyRows: some View {
        if isEmojiMode {
            emojiKeys
        } else if context.isNumberMode {
            if context.isSymbolMode {
                symbolKeys
            } else {
                numberKeys
            }
        } else {
            letterKeys
        }
    }

    // MARK: - Letter Keys

    private var letterKeys: some View {
        let rows = Self.localizedLetterRows
        let topCount = rows[0].count

        return GeometryReader { geo in
            let totalWidth = geo.size.width
            let row2Pad = CGFloat(topCount - rows[1].count) * (totalWidth + keySpacing) / CGFloat(2 * topCount)

            VStack(spacing: rowSpacing) {
                ZStack(alignment: .top) {
                    VStack(spacing: rowSpacing) {
                        HStack(spacing: keySpacing) {
                            ForEach(rows[0], id: \.self) { key in
                                CharacterKey(label: displayChar(key), context: context, character: key)
                            }
                        }

                        HStack(spacing: keySpacing) {
                            ForEach(rows[1], id: \.self) { key in
                                CharacterKey(label: displayChar(key), context: context, character: key)
                            }
                        }
                        .padding(.horizontal, row2Pad)

                        HStack(spacing: keySpacing) {
                            ActionKey(
                                label: context.isCapsLock ? "capslock" : "shift",
                                systemImage: context.isCapsLock ? "capslock.fill"
                                    : (context.isShiftActive ? "shift.fill" : "shift"),
                                width: 44
                            ) {
                                context.toggleShift()
                            }

                            ForEach(rows[2], id: \.self) { key in
                                CharacterKey(label: displayChar(key), context: context, character: key)
                            }

                            DeleteKey(context: context, width: 44)
                        }
                    }

                    // Swipe preview bubble (driven by KeyboardContext)
                    if !context.swipePreview.isEmpty {
                        Text(context.swipePreview)
                            .font(.system(size: 18, weight: .medium))
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(.ultraThinMaterial, in: Capsule())
                            .allowsHitTesting(false)
                            .offset(y: -30)
                    }
                }

                bottomRow
            }
        }
        .frame(height: 4 * keyHeight + 3 * rowSpacing)
    }

    // MARK: - Number Keys

    private var numberKeys: some View {
        let rows: [[String]] = [
            ["1", "2", "3", "4", "5", "6", "7", "8", "9", "0"],
            ["-", "/", ":", ";", "(", ")", "$", "&", "@", "\""],
            [".", ",", "?", "!", "'"],
        ]

        return VStack(spacing: rowSpacing) {
            HStack(spacing: keySpacing) {
                ForEach(rows[0], id: \.self) { key in
                    CharacterKey(label: key, context: context, character: key, isLiteral: true)
                }
            }
            HStack(spacing: keySpacing) {
                ForEach(rows[1], id: \.self) { key in
                    CharacterKey(label: key, context: context, character: key, isLiteral: true)
                }
            }
            HStack(spacing: keySpacing) {
                ActionKey(label: "#+=", systemImage: nil, width: 42) {
                    context.toggleSymbolMode()
                }
                ForEach(rows[2], id: \.self) { key in
                    CharacterKey(label: key, context: context, character: key, isLiteral: true)
                }
                DeleteKey(context: context, width: 42)
            }
            bottomRow
        }
    }

    // MARK: - Symbol Keys

    private var symbolKeys: some View {
        let rows: [[String]] = [
            ["[", "]", "{", "}", "#", "%", "^", "*", "+", "="],
            ["_", "\\", "|", "~", "<", ">", "\u{20AC}", "\u{00A3}", "\u{00A5}", "\u{2022}"],
            [".", ",", "?", "!", "'"],
        ]

        return VStack(spacing: rowSpacing) {
            HStack(spacing: keySpacing) {
                ForEach(rows[0], id: \.self) { key in
                    CharacterKey(label: key, context: context, character: key, isLiteral: true)
                }
            }
            HStack(spacing: keySpacing) {
                ForEach(rows[1], id: \.self) { key in
                    CharacterKey(label: key, context: context, character: key, isLiteral: true)
                }
            }
            HStack(spacing: keySpacing) {
                ActionKey(label: "123", systemImage: nil, width: 42) {
                    context.toggleSymbolMode()
                }
                ForEach(rows[2], id: \.self) { key in
                    CharacterKey(label: key, context: context, character: key, isLiteral: true)
                }
                DeleteKey(context: context, width: 42)
            }
            bottomRow
        }
    }

    // MARK: - Bottom Row (non-emoji modes only)

    private var bottomRow: some View {
        HStack(spacing: keySpacing) {
            // 123/ABC toggle
            ActionKey(
                label: context.isNumberMode ? "ABC" : "123",
                systemImage: nil,
                width: 45
            ) {
                context.toggleNumberMode()
            }

            // Emoji key: tap → emoji grid, long-press → switch keyboard
            Image(systemName: "face.smiling")
                .font(.subheadline)
                .frame(width: 36, height: 41)
                .modifier(ActionKeyBackgroundModifier(tint: nil))
                .foregroundStyle(.primary)
                .onTapGesture {
                    isEmojiMode = true
                }
                .onLongPressGesture {
                    context.switchToNextKeyboard()
                }

            // Space bar
            SpaceKey(context: context)

            // Return key
            ActionKey(
                label: context.returnKeyLabel,
                systemImage: nil,
                width: 72,
                tint: .blue
            ) {
                context.insertReturn()
            }
        }
    }

    // MARK: - Emoji Keys

    @ViewBuilder
    private var emojiKeys: some View {
        if isEmojiSearching {
            emojiSearchView
        } else {
            emojiBrowseView
        }
    }

    // MARK: - Emoji Browse Mode

    private var emojiBrowseView: some View {
        let columns = Array(repeating: GridItem(.flexible(), spacing: 4), count: 8)
        let displayEmojis: [String] = selectedCategory == .frequentlyUsed
            ? emojiHistory.frequentEmojis
            : selectedCategory.emojis

        return VStack(spacing: 4) {
            // Search bar (tap to enter search mode)
            Button {
                isEmojiSearching = true
                emojiSearchText = ""
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: "magnifyingglass")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    Text("Search emojis...")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    Spacer()
                }
                .padding(.horizontal, 12)
                .frame(height: 38)
                .modifier(SearchBarBackground())
            }
            .buttonStyle(.plain)
            .padding(.horizontal, 2)

            // Scrollable emoji grid
            ScrollView {
                LazyVGrid(columns: columns, spacing: 4) {
                    ForEach(displayEmojis, id: \.self) { emoji in
                        Button {
                            context.insertText(emoji)
                            emojiHistory.recordUsage(emoji)
                        } label: {
                            Text(emoji)
                                .font(.system(size: 33))
                                .frame(maxWidth: .infinity)
                                .frame(height: 41)
                        }
                        .buttonStyle(KeyButtonStyle())
                    }
                }
                .padding(.horizontal, 2)
            }

            // Merged bottom row: ABC + category tabs + backspace
            emojiBrowseBottomRow
        }
    }

    private var emojiBrowseBottomRow: some View {
        HStack(spacing: 2) {
            // ABC button
            ActionKey(label: "ABC", systemImage: nil, width: 42) {
                isEmojiMode = false
            }

            // Category tabs
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 0) {
                    ForEach(EmojiCategory.browsable) { cat in
                        Button {
                            selectedCategory = cat
                        } label: {
                            Image(systemName: cat.icon)
                                .font(.system(size: 15))
                                .frame(width: 30, height: 41)
                                .foregroundStyle(selectedCategory == cat ? .primary : .secondary)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }

            // Backspace
            DeleteKey(context: context, width: 42)
        }
    }

    // MARK: - Emoji Search Mode

    private var emojiSearchView: some View {
        let columns = Array(repeating: GridItem(.flexible(), spacing: 4), count: 8)
        let results = EmojiSearch.search(emojiSearchText)
        let rows = Self.localizedLetterRows

        return GeometryReader { geo in
            let totalWidth = geo.size.width
            let topCount = rows[0].count
            let row2Pad = CGFloat(topCount - rows[1].count) * (totalWidth + keySpacing) / CGFloat(2 * topCount)

            VStack(spacing: 4) {
                // Search text display (not a TextField — we ARE the keyboard)
                HStack(spacing: 6) {
                    Image(systemName: "magnifyingglass")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    Text(emojiSearchText.isEmpty ? "Search emojis..." : emojiSearchText)
                        .font(.subheadline)
                        .foregroundStyle(emojiSearchText.isEmpty ? .secondary : .primary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .lineLimit(1)
                    if !emojiSearchText.isEmpty {
                        Button {
                            emojiSearchText = ""
                        } label: {
                            Image(systemName: "xmark.circle.fill")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 12)
                .frame(height: 38)
                .modifier(SearchBarBackground())
                .padding(.horizontal, 2)

                // Frequently used row
                if !emojiHistory.frequentEmojis.isEmpty {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 4) {
                            ForEach(emojiHistory.frequentEmojis, id: \.self) { emoji in
                                Button {
                                    context.insertText(emoji)
                                    emojiHistory.recordUsage(emoji)
                                } label: {
                                    Text(emoji)
                                        .font(.system(size: 22))
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        .padding(.horizontal, 6)
                    }
                    .frame(height: 28)
                }

                // Search results grid (scrollable, takes remaining space)
                ScrollView {
                    LazyVGrid(columns: columns, spacing: 4) {
                        ForEach(results, id: \.self) { emoji in
                            Button {
                                context.insertText(emoji)
                                emojiHistory.recordUsage(emoji)
                            } label: {
                                Text(emoji)
                                    .font(.system(size: 33))
                                    .frame(maxWidth: .infinity)
                                    .frame(height: keyHeight)
                            }
                            .buttonStyle(KeyButtonStyle())
                        }
                    }
                    .padding(.horizontal, 2)
                }

                // Letter keyboard for typing search query
                VStack(spacing: rowSpacing) {
                    HStack(spacing: keySpacing) {
                        ForEach(rows[0], id: \.self) { key in
                            searchLetterKey(key)
                        }
                    }
                    HStack(spacing: keySpacing) {
                        ForEach(rows[1], id: \.self) { key in
                            searchLetterKey(key)
                        }
                    }
                    .padding(.horizontal, row2Pad)
                    HStack(spacing: keySpacing) {
                        ForEach(rows[2], id: \.self) { key in
                            searchLetterKey(key)
                        }
                        // Backspace in the letter row
                        Button {
                            if !emojiSearchText.isEmpty {
                                emojiSearchText.removeLast()
                            }
                        } label: {
                            Image(systemName: "delete.left")
                                .font(.subheadline)
                                .frame(width: 44, height: keyHeight)
                                .modifier(ActionKeyBackgroundModifier(tint: nil))
                                .foregroundStyle(.primary)
                        }
                        .buttonStyle(.plain)
                    }
                }

                // Bottom row: ABC + emoji + space + Done
                HStack(spacing: keySpacing) {
                    // ABC — back to letter keyboard
                    ActionKey(label: "ABC", systemImage: nil, width: 45) {
                        isEmojiSearching = false
                        emojiSearchText = ""
                        isEmojiMode = false
                    }

                    // Emoji — back to emoji browse
                    Image(systemName: "face.smiling")
                        .font(.subheadline)
                        .frame(width: 36, height: keyHeight)
                        .modifier(ActionKeyBackgroundModifier(tint: nil))
                        .foregroundStyle(.primary)
                        .onTapGesture {
                            isEmojiSearching = false
                            emojiSearchText = ""
                        }

                    // Space (appends to search text)
                    Button {
                        emojiSearchText.append(" ")
                    } label: {
                        Text("space")
                            .font(.subheadline)
                            .frame(maxWidth: .infinity)
                            .frame(height: keyHeight)
                            .modifier(KeyBackgroundModifier())
                            .foregroundStyle(.primary)
                    }
                    .buttonStyle(.plain)

                    // Done — back to main keyboard
                    ActionKey(label: "Done", systemImage: nil, width: 72) {
                        isEmojiSearching = false
                        emojiSearchText = ""
                        isEmojiMode = false
                    }
                }
            }
        }
    }

    /// A letter key that appends to `emojiSearchText` instead of inserting into the text field.
    private func searchLetterKey(_ key: String) -> some View {
        Button {
            emojiSearchText.append(key)
        } label: {
            Text(key)
                .font(.system(size: 22, weight: .light))
                .frame(maxWidth: .infinity)
                .frame(height: keyHeight)
                .modifier(KeyBackgroundModifier())
                .foregroundStyle(.primary)
        }
        .buttonStyle(.plain)
    }

    // MARK: - Helpers

    private func displayChar(_ char: String) -> String {
        (context.isShiftActive || context.isCapsLock) ? char.uppercased() : char
    }

    @ViewBuilder
    private var keyboardBackground: some View {
        Color(.secondarySystemBackground)
    }

    /// Letter rows matching the device's keyboard layout convention.
    /// Static — locale doesn't change while the extension is running.
    private static let localizedLetterRows: [[String]] = {
        let lang = Locale.current.language.languageCode?.identifier ?? "en"
        switch lang {
        case "fr":
            return [
                ["a", "z", "e", "r", "t", "y", "u", "i", "o", "p"],
                ["q", "s", "d", "f", "g", "h", "j", "k", "l", "m"],
                ["w", "x", "c", "v", "b", "n"],
            ]
        case "de":
            return [
                ["q", "w", "e", "r", "t", "z", "u", "i", "o", "p"],
                ["a", "s", "d", "f", "g", "h", "j", "k", "l"],
                ["y", "x", "c", "v", "b", "n", "m"],
            ]
        default:
            return [
                ["q", "w", "e", "r", "t", "y", "u", "i", "o", "p"],
                ["a", "s", "d", "f", "g", "h", "j", "k", "l"],
                ["z", "x", "c", "v", "b", "n", "m"],
            ]
        }
    }()

}

// MARK: - Character Key

private struct CharacterKey: View {
    let label: String
    let context: KeyboardContext
    let character: String
    var isLiteral: Bool = false
    @State private var isPressed = false

    var body: some View {
        Text(label)
            .font(.system(size: 22, weight: .light))
            .frame(maxWidth: .infinity)
            .frame(height: 41)
            .modifier(KeyBackgroundModifier())
            .foregroundStyle(.primary)
            .contentShape(Rectangle())
            .scaleEffect(isPressed ? 0.95 : 1.0)
            .overlay(alignment: .top) {
                if isPressed {
                    Text(label)
                        .font(.system(size: 32, weight: .regular))
                        .frame(width: 48, height: 56)
                        .modifier(KeyBackgroundModifier())
                        .offset(y: -50)
                        .allowsHitTesting(false)
                }
            }
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { _ in
                        if !isPressed {
                            isPressed = true
                            context.insertCharacter(character)
                        }
                    }
                    .onEnded { _ in
                        isPressed = false
                    }
            )
            .onDisappear { isPressed = false }
    }
}

// MARK: - Action Key

private struct ActionKey: View {
    let label: String
    var systemImage: String?
    var width: CGFloat = 44
    var tint: Color?

    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Group {
                if let systemImage {
                    Image(systemName: systemImage)
                        .font(.subheadline)
                } else {
                    Text(label)
                        .font(.caption)
                }
            }
            .frame(width: width, height: 41)
            .modifier(ActionKeyBackgroundModifier(tint: tint))
            .foregroundStyle(tint != nil ? .white : .primary)
        }
        .buttonStyle(KeyButtonStyle())
    }
}

// MARK: - Delete Key (with repeat-on-hold)

private struct DeleteKey: View {
    let context: KeyboardContext
    var width: CGFloat = 44

    @State private var timer: Timer?
    @GestureState private var isHeld = false

    var body: some View {
        Image(systemName: "delete.left")
            .font(.subheadline)
            .frame(width: width, height: 41)
            .modifier(ActionKeyBackgroundModifier(tint: nil))
            .foregroundStyle(.primary)
            .scaleEffect(isHeld ? 0.95 : 1.0)
            .gesture(
                DragGesture(minimumDistance: 0)
                    .updating($isHeld) { _, state, _ in state = true }
                    .onChanged { _ in
                        guard timer == nil else { return }
                        context.deleteBackward()
                        let t = Timer.scheduledTimer(withTimeInterval: 0.08, repeats: true) { [context] _ in
                            MainActor.assumeIsolated {
                                context.deleteBackward()
                            }
                        }
                        // First repeat after a brief hold
                        t.fireDate = Date().addingTimeInterval(0.35)
                        timer = t
                    }
                    .onEnded { _ in
                        timer?.invalidate()
                        timer = nil
                    }
            )
            .onChange(of: isHeld) { _, held in
                if !held { timer?.invalidate(); timer = nil }
            }
    }
}

// MARK: - Space Key (touch-down firing)

private struct SpaceKey: View {
    let context: KeyboardContext
    @State private var isPressed = false

    var body: some View {
        Text("space")
            .font(.subheadline)
            .frame(maxWidth: .infinity)
            .frame(height: 41)
            .modifier(KeyBackgroundModifier())
            .foregroundStyle(.primary)
            .contentShape(Rectangle())
            .scaleEffect(isPressed ? 0.95 : 1.0)
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { _ in
                        if !isPressed {
                            isPressed = true
                            context.insertSpace()
                        }
                    }
                    .onEnded { _ in
                        isPressed = false
                    }
            )
            .onDisappear { isPressed = false }
    }
}

// MARK: - Key Press Animation

private struct KeyButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.95 : 1.0)
    }
}

// MARK: - Glass / Legacy Key Backgrounds

/// Character key + space bar background.
private struct KeyBackgroundModifier: ViewModifier {
    @Environment(\.colorScheme) private var colorScheme

    func body(content: Content) -> some View {
        content
            .background(
                colorScheme == .dark
                    ? Color.white.opacity(0.22)
                    : Color.white.opacity(0.95),
                in: .rect(cornerRadius: 8)
            )
            .shadow(color: .black.opacity(0.15), radius: 0, x: 0, y: 1)
    }
}

/// Action key background.
private struct ActionKeyBackgroundModifier: ViewModifier {
    var tint: Color?
    @Environment(\.colorScheme) private var colorScheme

    func body(content: Content) -> some View {
        content
            .background(
                tint ?? (colorScheme == .dark
                    ? Color.white.opacity(0.12)
                    : Color(.systemGray4)),
                in: .rect(cornerRadius: 8)
            )
            .shadow(color: .black.opacity(0.15), radius: 0, x: 0, y: 1)
    }
}

/// Rounded search bar background (capsule shape).
private struct SearchBarBackground: ViewModifier {
    @Environment(\.colorScheme) private var colorScheme

    func body(content: Content) -> some View {
        content
            .background(
                colorScheme == .dark
                    ? Color.white.opacity(0.12)
                    : Color(.systemGray4).opacity(0.5),
                in: Capsule()
            )
    }
}

/// Translation bar background: glass on iOS 26, solid on older.
private struct GlassBarBackground: ViewModifier {
    func body(content: Content) -> some View {
        if #available(iOS 26, *) {
            content.glassEffect(.regular, in: .rect(cornerRadius: 8))
        } else {
            content.background(.background, in: .rect(cornerRadius: 8))
        }
    }
}
