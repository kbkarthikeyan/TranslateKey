import UIKit
import SwiftUI

/// Enables system keyboard click sound via UIDevice.current.playInputClick().
private class AudioInputView: UIInputView, UIInputViewAudioFeedback {
    var enableInputClicksWhenVisible: Bool { true }
}

class KeyboardViewController: UIInputViewController, UIGestureRecognizerDelegate {

    private var hostingController: UIHostingController<KeyboardView>?
    private let keyboardContext = KeyboardContext()

    override func loadView() {
        self.inputView = AudioInputView(frame: .zero, inputViewStyle: .keyboard)
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        keyboardContext.viewController = self

        let keyboardView = KeyboardView(context: keyboardContext)
        let hosting = UIHostingController(rootView: keyboardView)
        hosting.view.backgroundColor = .clear
        hosting.view.translatesAutoresizingMaskIntoConstraints = false

        addChild(hosting)
        view.addSubview(hosting.view)

        NSLayoutConstraint.activate([
            hosting.view.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            hosting.view.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            hosting.view.topAnchor.constraint(equalTo: view.topAnchor),
            hosting.view.bottomAnchor.constraint(equalTo: view.bottomAnchor),
        ])

        hosting.didMove(toParent: self)
        hostingController = hosting

        // Set keyboard height
        let heightConstraint = view.heightAnchor.constraint(equalToConstant: 329)
        heightConstraint.priority = .defaultHigh
        heightConstraint.isActive = true

        // Swipe typing gesture — uses UIKit pan so it coexists with SwiftUI buttons
        let pan = UIPanGestureRecognizer(target: self, action: #selector(handleSwipePan(_:)))
        pan.delegate = self
        pan.cancelsTouchesInView = false
        pan.delaysTouchesBegan = false
        hosting.view.addGestureRecognizer(pan)
    }

    // MARK: - Swipe Typing Gesture

    @objc private func handleSwipePan(_ recognizer: UIPanGestureRecognizer) {
        switch recognizer.state {
        case .changed:
            // Only process after 40pt of movement — taps cost zero
            let t = recognizer.translation(in: view)
            guard t.x * t.x + t.y * t.y > 1600 else { return }
            let location = recognizer.location(in: view)
            if let ch = keyboardContext.keyCharacterAtPoint(location, keyboardWidth: view.bounds.width) {
                keyboardContext.swipeAppendKey(ch)
            }
        case .ended:
            guard keyboardContext.swipeActive else { return }
            keyboardContext.swipeEnd()
        case .cancelled, .failed:
            guard keyboardContext.swipeActive else { return }
            keyboardContext.swipeCancel()
        default:
            break
        }
    }

    func gestureRecognizer(
        _ gestureRecognizer: UIGestureRecognizer,
        shouldRecognizeSimultaneouslyWith other: UIGestureRecognizer
    ) -> Bool {
        true
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        keyboardContext.onKeyboardAppeared()
    }

    override func textDidChange(_ textInput: UITextInput?) {
        super.textDidChange(textInput)
        keyboardContext.updateReturnKeyType(textDocumentProxy.returnKeyType ?? .default)
        keyboardContext.onTextChanged()
    }
}

// MARK: - KeyboardContext

@Observable
@MainActor
final class KeyboardContext {
    weak var viewController: KeyboardViewController?

    @ObservationIgnored private lazy var feedbackGenerator = UIImpactFeedbackGenerator(style: .light)

    var isShiftActive = false
    var isCapsLock = false
    var isNumberMode = false
    var isSymbolMode = false
    var returnKeyLabel = "return"

    /// Last text that was auto-translated (to avoid re-translating identical content)
    var lastAutoTranslatedText: String = ""

    /// Fires when text changes in the text field (for debounced auto-translate in Send mode)
    @ObservationIgnored var textChangeGeneration: Int = 0

    /// Fires when keyboard becomes visible (for clipboard check in Read mode)
    @ObservationIgnored var keyboardAppearGeneration: Int = 0

    /// Word predictions shown in the suggestion bar
    var predictions: [String] = []
    @ObservationIgnored private var lastPredictedPrefix = ""
    @ObservationIgnored private var predictionTask: Task<Void, Never>?

    /// Undo correction: shows original word in prediction bar after autocorrect fires
    var undoCorrection: String?
    @ObservationIgnored private var correctedWord: String?

    /// Swipe typing state (only swipePreview is observed by views)
    var swipePreview: String = ""
    @ObservationIgnored private(set) var swipeActive = false
    @ObservationIgnored private var swipePath: [Character] = []

    // Layout constants for key position mapping (must match KeyboardView)
    private let kKeySpacing: CGFloat = 6
    private let kRowSpacing: CGFloat = 9
    private let kKeyHeight: CGFloat = 41
    private let kKeyboardHeight: CGFloat = 329
    private let kHorizontalPad: CGFloat = 3
    private let kBottomPad: CGFloat = 2

    private var proxy: UITextDocumentProxy? {
        viewController?.textDocumentProxy
    }

    /// Characters that end a word and should trigger auto-correction before insertion.
    private static let wordTerminators: Set<Character> = [".", ",", "!", "?", ";", ":", "'", "\""]

    func insertCharacter(_ char: String) {
        let text = (isShiftActive || isCapsLock) ? char.uppercased() : char.lowercased()
        // Static-only autocorrect on punctuation (instant, no UITextChecker)
        if let ch = text.first, Self.wordTerminators.contains(ch) {
            autoCorrectQuick()
        } else {
            clearUndoCorrection()
        }
        proxy?.insertText(text)
        if isShiftActive && !isCapsLock { isShiftActive = false }
        if text == "." || text == "!" || text == "?" { isShiftActive = true }
        asyncFeedback()
    }

    func deleteBackward() {
        clearUndoCorrection()
        proxy?.deleteBackward()
        asyncFeedback()
    }

    func insertSpace() {
        let before = proxy?.documentContextBeforeInput
        if !predictions.isEmpty { predictions = []; lastPredictedPrefix = "" }
        clearUndoCorrection()
        // Double-space → period
        if let before, before.hasSuffix(" "),
           let last = before.dropLast().last, last.isLetter {
            proxy?.deleteBackward()
            proxy?.insertText(". ")
            if !isCapsLock { isShiftActive = true }
            asyncFeedback()
            return
        }
        // Space appears instantly — zero blocking
        proxy?.insertText(" ")
        asyncFeedback()
        // Autocorrect + capitalize deferred to next frame
        let capturedBefore = before
        DispatchQueue.main.async { [self] in
            autoCorrectAfterSpace(originalBefore: capturedBefore)
            autoCapitalize(before: (capturedBefore ?? "") + " ")
        }
    }

    func insertReturn() {
        if !predictions.isEmpty { predictions = []; lastPredictedPrefix = "" }
        clearUndoCorrection()
        proxy?.insertText("\n")
        if !isCapsLock { isShiftActive = true }
        asyncFeedback()
    }

    func insertText(_ text: String) {
        proxy?.insertText(text)
        asyncFeedback()
    }

    // MARK: - Feedback

    // DEAD CODE: never called — views use asyncFeedback() directly
    // func keyFeedback() {
    //     asyncFeedback()
    // }

    /// ALL feedback deferred — character appears with zero main-thread blocking.
    /// Throttled: only one pending closure at a time to prevent queue buildup during fast typing.
    @ObservationIgnored private var feedbackPending = false

    private func asyncFeedback() {
        guard !feedbackPending else { return }
        feedbackPending = true
        DispatchQueue.main.async { [self] in
            feedbackGenerator.impactOccurred()
            UIDevice.current.playInputClick()
            feedbackGenerator.prepare()
            feedbackPending = false
        }
    }

    // MARK: - Auto-Capitalization

    /// Activates shift after sentence-ending punctuation or at start of text field.
    /// Pass `before` to skip the IPC read when the caller already has it.
    private func autoCapitalize(before: String? = nil) {
        guard !isCapsLock else { return }
        let context = before ?? proxy?.documentContextBeforeInput
        let trimmed = (context ?? "").trimmingCharacters(in: .whitespaces)
        let shouldCapitalize = trimmed.isEmpty
            || trimmed.hasSuffix(".")
            || trimmed.hasSuffix("!")
            || trimmed.hasSuffix("?")
        if shouldCapitalize != isShiftActive {
            isShiftActive = shouldCapitalize
        }
    }

    // MARK: - Auto-Correction (UITextChecker + static fallback)

    @ObservationIgnored private lazy var textChecker = UITextChecker()

    /// Static autocorrect dictionary: contractions, adjacent-key errors, transpositions,
    /// missing/double letter typos, and common misspellings. Only unambiguous pairs
    /// (the typo is never a valid English word).
    private static let corrections: [String: String] = [
        // ── Contractions ──
        "dont": "don't",
        "didnt": "didn't", "doesnt": "doesn't", "isnt": "isn't",
        "wasnt": "wasn't", "werent": "weren't", "hasnt": "hasn't",
        "havent": "haven't", "wouldnt": "wouldn't", "shouldnt": "shouldn't",
        "couldnt": "couldn't", "im": "I'm", "ive": "I've",
        "youre": "you're", "theyre": "they're",
        "weve": "we've", "youve": "you've", "theyve": "they've",
        "arent": "aren't", "hadnt": "hadn't", "mustnt": "mustn't",
        "thats": "that's",
        "whats": "what's", "wheres": "where's", "whos": "who's",
        "theres": "there's", "itll": "it'll",
        "youll": "you'll", "theyll": "they'll",
        "youd": "you'd",
        "theyd": "they'd", "hed": "he'd",

        // ── Transpositions (swapped adjacent letters) ──
        "teh": "the", "hte": "the",
        "adn": "and", "nad": "and", "nda": "and",
        "taht": "that", "thta": "that",
        "wiht": "with", "iwth": "with",
        "waht": "what", "hwat": "what",
        "thsi": "this", "htis": "this", "tihs": "this",
        "jsut": "just", "ujst": "just",
        "ahve": "have", "hvae": "have",
        "hwen": "when", "wehn": "when", "whne": "when",
        "fomr": "from", "rfom": "from",
        "sicne": "since", "snice": "since",
        "amke": "make", "mkae": "make",
        "konw": "know", "nkow": "know", "knwo": "know",
        "liek": "like", "ilke": "like",
        "tiem": "time",
        "coudl": "could", "cuold": "could",
        "woudl": "would", "wuold": "would",
        "shoudl": "should", "shuold": "should",
        "agian": "again", "agin": "again",
        "baout": "about", "aobut": "about", "abotu": "about",
        "poeple": "people", "peopel": "people",
        "wrold": "world", "wolrd": "world",
        "chnage": "change", "chnace": "chance",
        "oepn": "open", "opne": "open",
        "nigth": "night", "nihgt": "night",
        "rigth": "right", "rihgt": "right",
        "wokr": "work", "owrk": "work",
        "palce": "place", "plcae": "place",
        "bakc": "back", "bcak": "back",
        "evrey": "every", "eevry": "every",
        "beofre": "before", "bfeore": "before",
        "soem": "some",
        "aslo": "also", "laso": "also",
        "veyr": "very", "vrey": "very",
        "evne": "even", "eevn": "even",
        "eahc": "each", "aech": "each",
        "suhc": "such", "scuh": "such",
        "muhc": "much", "mcuh": "much",
        "mroe": "more", "moer": "more",
        "olny": "only", "onyl": "only",
        "yera": "year", "yaer": "year",
        "heer": "here", "ehre": "here",
        "thign": "thing", "thnig": "thing",
        "caer": "care",
        "hsa": "has", "hda": "had",
        "wsa": "was", "aws": "was",
        "ddi": "did",
        "nwo": "now",
        "hwo": "how", "owh": "how",
        "yuo": "you", "oyu": "you",
        "rae": "are",
        "cna": "can", "acn": "can",
        "otu": "out", "tou": "out",
        "gte": "get", "egt": "get",
        "lte": "let", "etl": "let",
        "sya": "say", "ays": "say",
        "wya": "way", "awy": "way",
        "dya": "day", "ady": "day",
        "nto": "not", "ont": "not",

        // ── Adjacent-key errors (fat finger on QWERTY) ──
        "mw": "me",
        "thr": "the", "yhe": "the", "tge": "the", "rhe": "the",
        "wiyh": "with", "wirh": "with", "wuth": "with",
        "abd": "and", "anf": "and", "snd": "and",
        "fpr": "for",
        "grom": "from", "feom": "from", "drom": "from",
        "npt": "not", "noy": "not",
        "habe": "have", "hace": "have", "hsve": "have",
        "thay": "that", "thar": "that",
        "thwn": "then", "tben": "then",
        "thwre": "there", "therw": "there",
        "wherw": "where", "whete": "where",
        "ehat": "what", "whar": "what", "qhat": "what",
        "woukd": "would", "woyld": "would",
        "coukd": "could", "coyld": "could",
        "shoukd": "should", "shoyld": "should",
        "lile": "like", "likw": "like",
        "somw": "some",
        "homw": "home",
        "cpme": "come", "cime": "come", "comw": "come",
        "goid": "good", "giod": "good", "gopd": "good",
        "knoe": "know", "kmow": "know",
        "helo": "help", "hrlp": "help", "hwlp": "help",
        "grt": "get",
        "biy": "bit",
        "ir": "or", "pr": "or",
        "os": "is", "ks": "is",
        "ut": "it",
        "od": "of", "og": "of",
        "wss": "was",
        "hsd": "had", "haf": "had",
        "fo": "of",
        "peiple": "people", "peoplw": "people",
        "wprk": "work", "wirk": "work",
        "yime": "time", "timw": "time",
        "nees": "need",
        "lofe": "life", "lide": "life",
        "thonk": "think", "rhink": "think", "thinl": "think",
        "befire": "before", "befote": "before",
        "afyer": "after", "aftet": "after",
        "othet": "other", "otger": "other",
        "abiut": "about", "aboit": "about",
        "becsuse": "because", "becayse": "because",
        "persin": "person", "oerson": "person",
        "pount": "point", "poiny": "point",
        "worls": "world", "qorld": "world",
        "hoyse": "house", "housw": "house",
        "mpney": "money",
        "stiry": "story", "syory": "story",
        "grear": "great", "greay": "great",
        "scgool": "school", "achool": "school",
        "hesd": "head", "heaf": "head",
        "eighr": "eight", "eifht": "eight",
        "atill": "still",
        "giing": "going", "goung": "going",
        "bwing": "being", "beung": "being",

        // ── Double-letter errors (accidental key repeat) ──
        "thhe": "the", "annd": "and", "forr": "for",
        "withh": "with", "thatt": "that", "whatt": "what",
        "whenn": "when", "fromm": "from", "havve": "have",
        "jusst": "just", "thiss": "this", "verry": "very",
        "backk": "back", "beenn": "been", "onlyy": "only",
        "ovver": "over", "evenn": "even", "yearr": "year",
        "alsoo": "also", "morre": "more", "aboutt": "about",
        "afterr": "after", "otherr": "other", "wouldd": "would",
        "couldd": "could", "ssame": "same", "tthat": "that",
        "wwhat": "what", "wwork": "work",

        // ── Missing-letter errors ──
        "becuse": "because", "beause": "because",
        "shoud": "should", "woud": "would", "coud": "could",
        "peple": "people", "pople": "people",
        "diffrent": "different", "diffrence": "difference",
        "probaly": "probably", "proably": "probably",
        "intresting": "interesting",
        "remeber": "remember", "rember": "remember",
        "togther": "together", "togehter": "together",
        "betwen": "between",
        "languge": "language",
        "somthing": "something", "somethng": "something",
        "everthing": "everything", "everythng": "everything",
        "thnik": "think",
        "informaton": "information",
        "diferent": "different",

        // ── Common misspellings ──
        "alot": "a lot",
        "becuase": "because", "becasue": "because", "beacuse": "because",
        "freind": "friend",
        "accomodate": "accommodate",
        "acheive": "achieve", "acheived": "achieved",
        "acknowlege": "acknowledge",
        "adress": "address",
        "arguement": "argument",
        "awfull": "awful",
        "basicly": "basically",
        "beggining": "beginning", "begining": "beginning",
        "beleif": "belief", "beleive": "believe",
        "buisness": "business", "busines": "business",
        "calender": "calendar",
        "catagory": "category",
        "cemetary": "cemetery",
        "cheif": "chief",
        "collegue": "colleague",
        "comitted": "committed", "committment": "commitment",
        "concensus": "consensus",
        "concious": "conscious",
        "definate": "definite",
        "definately": "definitely", "definitly": "definitely", "definetly": "definitely",
        "desparate": "desperate",
        "developement": "development",
        "dilema": "dilemma",
        "disapoint": "disappoint", "dissappoint": "disappoint",
        "embarass": "embarrass", "embarras": "embarrass",
        "enviroment": "environment",
        "equiptment": "equipment",
        "excercise": "exercise",
        "existance": "existence",
        "experiance": "experience",
        "facinating": "fascinating",
        "foriegn": "foreign",
        "fourty": "forty",
        "garantee": "guarantee", "gaurantee": "guarantee",
        "goverment": "government", "govermnent": "government",
        "grammer": "grammar",
        "gratefull": "grateful", "greatful": "grateful",
        "guidence": "guidance",
        "harrass": "harass",
        "heirarchy": "hierarchy",
        "ignorence": "ignorance",
        "imediately": "immediately", "immediatly": "immediately",
        "independance": "independence",
        "independant": "independent",
        "inteligence": "intelligence",
        "irrelevent": "irrelevant",
        "knowlege": "knowledge",
        "lenght": "length", "strenght": "strength",
        "liason": "liaison",
        "libary": "library",
        "lisence": "license",
        "maintainance": "maintenance",
        "milennium": "millennium", "millenium": "millennium",
        "mispell": "misspell",
        "morgage": "mortgage",
        "mountian": "mountain",
        "neccessary": "necessary", "necessery": "necessary", "neccesary": "necessary",
        "nieghbor": "neighbor", "neighbour": "neighbor",
        "noticable": "noticeable",
        "occassion": "occasion", "occassionally": "occasionally",
        "occurence": "occurrence", "occurrance": "occurrence",
        "oppurtunity": "opportunity",
        "orignal": "original",
        "paralell": "parallel",
        "percieve": "perceive",
        "persue": "pursue",
        "posession": "possession", "possesion": "possession",
        "preceed": "precede",
        "priviledge": "privilege", "privelege": "privilege",
        "professer": "professor",
        "pronounciation": "pronunciation",
        "publically": "publicly",
        "quarentine": "quarantine",
        "questionaire": "questionnaire",
        "reccomend": "recommend", "reccommend": "recommend", "recomend": "recommend",
        "reciept": "receipt",
        "recieve": "receive", "recive": "receive",
        "rediculous": "ridiculous",
        "referance": "reference",
        "relevent": "relevant",
        "religous": "religious",
        "repitition": "repetition",
        "restaraunt": "restaurant", "restraunt": "restaurant",
        "secratary": "secretary",
        "sentance": "sentence",
        "seperate": "separate", "seperately": "separately",
        "similer": "similar",
        "sincerly": "sincerely",
        "speach": "speech",
        "succesful": "successful", "successfull": "successful",
        "suprise": "surprise", "surprize": "surprise",
        "thier": "their",
        "throughly": "thoroughly",
        "tommorrow": "tomorrow", "tomorow": "tomorrow", "tommorow": "tomorrow",
        "truely": "truly",
        "untill": "until",
        "useing": "using",
        "usualy": "usually",
        "vegitarian": "vegetarian",
        "wierd": "weird",
        "writting": "writing",
    ]

    /// Instant autocorrect using static dictionary only — used inline during typing.
    private func autoCorrectQuick(before: String? = nil) {
        guard let before = before ?? proxy?.documentContextBeforeInput, !before.isEmpty else { return }
        let lastWord = extractLastWord(from: before)
        guard lastWord.count > 1 else { return }
        guard let correction = Self.corrections[lastWord.lowercased()] else { return }
        replaceLastWord(lastWord, with: correction)
        // No undo for punctuation-triggered corrections — the trailing punctuation
        // is inserted after the correction, so revert context check would fail.
    }

    /// Full autocorrect (static + UITextChecker) — runs deferred after space insertion.
    /// Space is already inserted, so deletes word+space and re-inserts correction+space.
    private func autoCorrectAfterSpace(originalBefore: String?) {
        guard let before = originalBefore, !before.isEmpty else { return }
        let lastWord = extractLastWord(from: before)
        guard lastWord.count > 1 else { return }
        let lower = lastWord.lowercased()

        // 1. Static dictionary
        var correction = Self.corrections[lower]

        // 2. UITextChecker (system dictionary)
        if correction == nil {
            let range = NSRange(0..<lower.utf16.count)
            let misspelled = textChecker.rangeOfMisspelledWord(
                in: lower, range: range, startingAt: 0, wrap: false, language: "en"
            )
            if misspelled.location != NSNotFound {
                correction = textChecker.guesses(forWordRange: misspelled, in: lower, language: "en")?.first
            }
        }

        guard let correction else { return }

        // Verify context unchanged (user hasn't typed more since space)
        guard let current = proxy?.documentContextBeforeInput,
              current.hasSuffix(lastWord + " ") else { return }

        // Delete word + space, insert correction + space
        for _ in 0..<(lastWord.count + 1) {
            proxy?.deleteBackward()
        }
        if lastWord.first?.isUppercase == true {
            proxy?.insertText(correction.prefix(1).uppercased() + correction.dropFirst() + " ")
        } else {
            proxy?.insertText(correction + " ")
        }
        setUndoCorrection(original: lastWord, correction: correction)
    }

    private func extractLastWord(from text: String) -> String {
        var wordChars: [Character] = []
        for char in text.reversed() {
            if char.isLetter || char == "'" { wordChars.append(char) } else { break }
        }
        return String(wordChars.reversed())
    }

    private func replaceLastWord(_ original: String, with correction: String) {
        for _ in 0..<original.count {
            proxy?.deleteBackward()
        }
        if original.first?.isUppercase == true {
            proxy?.insertText(correction.prefix(1).uppercased() + correction.dropFirst())
        } else {
            proxy?.insertText(correction)
        }
    }

    func switchToNextKeyboard() {
        viewController?.advanceToNextInputMode()
    }

    func toggleShift() {
        if isShiftActive {
            // Double-tap for caps lock
            isCapsLock = !isCapsLock
            if !isCapsLock { isShiftActive = false }
        } else {
            isShiftActive = true
            isCapsLock = false
        }
    }

    func toggleNumberMode() {
        isNumberMode.toggle()
        isSymbolMode = false
    }

    func toggleSymbolMode() {
        isSymbolMode.toggle()
    }

    func getCurrentText() -> String {
        let before = proxy?.documentContextBeforeInput ?? ""
        let after = proxy?.documentContextAfterInput ?? ""
        return before + after
    }

    func replaceAllText(with newText: String) {
        // Move cursor to end
        if let after = proxy?.documentContextAfterInput, !after.isEmpty {
            proxy?.adjustTextPosition(byCharacterOffset: after.count)
        }
        // Delete everything backwards
        while let before = proxy?.documentContextBeforeInput, !before.isEmpty {
            for _ in 0..<before.count {
                proxy?.deleteBackward()
            }
        }
        proxy?.insertText(newText)
    }

    func updateReturnKeyType(_ type: UIReturnKeyType) {
        let newLabel: String
        switch type {
        case .send: newLabel = "send"
        case .search: newLabel = "search"
        case .go: newLabel = "go"
        case .done: newLabel = "done"
        case .next: newLabel = "next"
        case .join: newLabel = "join"
        default: newLabel = "return"
        }
        // Only mutate if changed — avoids @Observable triggering a full SwiftUI re-render
        if newLabel != returnKeyLabel { returnKeyLabel = newLabel }
    }

    func onTextChanged() {
        textChangeGeneration &+= 1
        updatePredictions()
    }

    func onKeyboardAppeared() {
        keyboardAppearGeneration += 1
        autoCapitalize()
        // Defer haptic engine init + prepare off the synchronous viewDidAppear path
        DispatchQueue.main.async { [self] in
            feedbackGenerator.prepare()
        }
    }

    // MARK: - Word Predictions

    private func updatePredictions() {
        predictionTask?.cancel()
        predictionTask = Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(150))
            guard !Task.isCancelled else { return }

            guard let before = proxy?.documentContextBeforeInput else {
                if !predictions.isEmpty { predictions = [] }
                lastPredictedPrefix = ""
                return
            }
            let prefix = extractLastWord(from: before).lowercased()

            // Clear stale predictions when prefix too short or empty
            guard prefix.count >= 2 else {
                if !predictions.isEmpty { predictions = [] }
                lastPredictedPrefix = ""
                return
            }
            guard prefix != lastPredictedPrefix else { return }

            // Heavy lexicon lookup off main thread to prevent UI freeze
            let capturedPrefix = prefix
            let range = NSRange(0..<capturedPrefix.utf16.count)
            let top = await Self.completionsOnBackground(prefix: capturedPrefix, range: range)

            guard !Task.isCancelled else { return }
            lastPredictedPrefix = capturedPrefix
            if top != predictions { predictions = top }
        }
    }

    /// Runs UITextChecker.completions on a background thread (avoids main-thread freeze
    /// on first lexicon load and satisfies Swift 6 actor isolation).
    nonisolated private static func completionsOnBackground(
        prefix: String, range: NSRange
    ) async -> [String] {
        await withCheckedContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async {
                let checker = UITextChecker()
                let results = checker.completions(
                    forPartialWordRange: range, in: prefix, language: "en"
                ) ?? []
                continuation.resume(returning: Array(results.prefix(3)))
            }
        }
    }

    func acceptPrediction(_ word: String) {
        guard let before = proxy?.documentContextBeforeInput else { return }
        let partial = extractLastWord(from: before)
        for _ in 0..<partial.count {
            proxy?.deleteBackward()
        }
        proxy?.insertText(word + " ")
        predictions = []
        lastPredictedPrefix = ""
        clearUndoCorrection()
        asyncFeedback()
    }

    /// Store undo state after autocorrect fires — shows original in prediction bar.
    private func setUndoCorrection(original: String, correction: String) {
        undoCorrection = original
        correctedWord = correction
        // Clear predictions so the undo suggestion is prominent
        predictions = []
        lastPredictedPrefix = ""
    }

    /// Revert autocorrection: delete the correction + trailing space, re-insert original + space.
    func revertCorrection() {
        guard let original = undoCorrection, let corrected = correctedWord else { return }
        guard let before = proxy?.documentContextBeforeInput else { return }

        // Determine the actual inserted form (may be capitalized)
        let insertedForm: String
        if original.first?.isUppercase == true {
            insertedForm = corrected.prefix(1).uppercased() + corrected.dropFirst()
        } else {
            insertedForm = corrected
        }

        // Verify context: the corrected word + space should be at end
        guard before.hasSuffix(insertedForm + " ") || before.hasSuffix(insertedForm) else {
            clearUndoCorrection()
            return
        }

        // Delete correction (+ trailing space if present)
        let hasSuffix = before.hasSuffix(insertedForm + " ")
        let deleteCount = insertedForm.count + (hasSuffix ? 1 : 0)
        for _ in 0..<deleteCount {
            proxy?.deleteBackward()
        }
        proxy?.insertText(original + (hasSuffix ? " " : ""))
        clearUndoCorrection()
        asyncFeedback()
    }

    private func clearUndoCorrection() {
        if undoCorrection != nil { undoCorrection = nil }
        correctedWord = nil
    }

    // MARK: - Swipe Typing

    func swipeAppendKey(_ ch: Character) {
        if !swipeActive {
            swipeActive = true
            swipePath = []
            proxy?.deleteBackward()  // remove character inserted by touch-down
        }
        if swipePath.last != ch {
            swipePath.append(ch)
            if swipePath.count >= 2 {
                let newPreview = SwipeEngine.shared.match(path: swipePath) ?? ""
                if newPreview != swipePreview { swipePreview = newPreview }
            }
        }
    }

    func swipeEnd() {
        guard swipeActive, swipePath.count >= 2 else { swipeCancel(); return }
        if let word = SwipeEngine.shared.match(path: swipePath) {
            proxy?.insertText(word + " ")
            asyncFeedback()
        }
        swipePath = []
        swipeActive = false
        if !swipePreview.isEmpty { swipePreview = "" }
    }

    func swipeCancel() {
        swipePath = []
        swipeActive = false
        if !swipePreview.isEmpty { swipePreview = "" }
    }

    /// Maps a point in the keyboard view to the letter key at that position.
    /// Returns nil if the point is outside the letter key area.
    func keyCharacterAtPoint(_ point: CGPoint, keyboardWidth: CGFloat) -> Character? {
        // Key rows area starts from the bottom of the keyboard, working up:
        // bottomPad(2) + bottomRow(41) + spacing(9) + row3(41) + spacing(9) + row2(41) + spacing(9) + row1(41)
        // = 2 + 41 + 9 + 41 + 9 + 41 + 9 + 41 = 193
        // So row1 top = keyboardHeight - 193
        let letterRowsTop = kKeyboardHeight - (4 * kKeyHeight + 3 * kRowSpacing + kBottomPad)
        let relY = point.y - letterRowsTop
        guard relY >= 0 else { return nil }

        let rowStride = kKeyHeight + kRowSpacing
        let row: Int
        if relY < rowStride { row = 0 }
        else if relY < 2 * rowStride { row = 1 }
        else if relY < 3 * rowStride { row = 2 }
        else { return nil } // bottom row (space/return)

        let rows = cachedLetterRows
        let topCount = CGFloat(rows[0].count)
        let effectiveWidth = keyboardWidth - 2 * kHorizontalPad
        let row2Pad = CGFloat(rows[0].count - rows[1].count) * (effectiveWidth + kKeySpacing) / (2 * topCount)

        var x = point.x - kHorizontalPad
        let rowKeys: [String]
        let areaWidth: CGFloat

        switch row {
        case 0:
            rowKeys = rows[0]
            areaWidth = effectiveWidth
        case 1:
            x -= row2Pad
            rowKeys = rows[1]
            areaWidth = effectiveWidth - 2 * row2Pad
        case 2:
            let shiftWidth: CGFloat = 44 + kKeySpacing
            x -= shiftWidth
            rowKeys = rows[2]
            areaWidth = effectiveWidth - 2 * shiftWidth
            guard x >= 0, x <= areaWidth else { return nil }
        default:
            return nil
        }

        let keyCount = CGFloat(rowKeys.count)
        let keyWidth = (areaWidth - kKeySpacing * (keyCount - 1)) / keyCount
        let idx = Int(x / (keyWidth + kKeySpacing))
        guard idx >= 0, idx < rowKeys.count else { return nil }
        return rowKeys[idx].first
    }

    /// Letter rows matching device locale (must match KeyboardView.localizedLetterRows).
    /// Stored once, not recomputed per-call.
    @ObservationIgnored
    private var cachedLetterRows: [[String]] = {
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
