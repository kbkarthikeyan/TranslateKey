import Foundation

// MARK: - Emoji Category

enum EmojiCategory: String, CaseIterable, Identifiable {
    case frequentlyUsed
    case smileys
    case people
    case animals
    case food
    case travel
    case objects
    case symbols
    case flags

    var id: String { rawValue }

    var icon: String {
        switch self {
        case .frequentlyUsed: "clock.arrow.circlepath"
        case .smileys:        "face.smiling"
        case .people:         "person"
        case .animals:        "pawprint.fill"
        case .food:           "fork.knife"
        case .travel:         "car.fill"
        case .objects:        "lightbulb.fill"
        case .symbols:        "number"
        case .flags:          "flag.fill"
        }
    }

    /// Categories shown in the tab bar (excludes frequentlyUsed — it gets its own clock icon).
    static let browsable: [EmojiCategory] = allCases

    var emojis: [String] {
        switch self {
        case .frequentlyUsed: []  // populated dynamically
        case .smileys:  Self.smileysEmojis
        case .people:   Self.peopleEmojis
        case .animals:  Self.animalsEmojis
        case .food:     Self.foodEmojis
        case .travel:   Self.travelEmojis
        case .objects:  Self.objectsEmojis
        case .symbols:  Self.symbolsEmojis
        case .flags:    Self.flagsEmojis
        }
    }

    // MARK: - Emoji Lists

    private static let smileysEmojis: [String] = [
        "😀", "😃", "😄", "😁", "😆", "🥹", "😅", "😂",
        "🤣", "🥲", "☺️", "😊", "😇", "🙂", "🙃", "😉",
        "😌", "😍", "🥰", "😘", "😗", "😙", "😚", "😋",
        "😛", "😝", "😜", "🤪", "🤨", "🧐", "🤓", "😎",
        "🥸", "🤩", "🥳", "😏", "😒", "😞", "😔", "😟",
        "😕", "🙁", "☹️", "😣", "😖", "😫", "😩", "🥺",
        "😢", "😭", "😮‍💨", "😤", "😠", "😡", "🤬", "🤯",
        "😳", "🥵", "🥶", "😱", "😨", "😰", "😥", "😓",
        "🫣", "🤗", "🫡", "🤔", "🫢", "🤭", "🤫", "🤥",
        "😶", "😐", "😑", "😬", "🫠", "🙄", "😯", "😦",
        "😧", "😮", "😲", "🥱", "😴", "🤤", "😪", "😵",
        "😵‍💫", "🫥", "🤐", "🥴", "🤢", "🤮", "🤧", "😷",
        "🤒", "🤕", "🤑", "🤠", "😈", "👿", "👹", "👺",
        "🤡", "💩", "👻", "💀", "☠️", "👽", "👾", "🤖",
        "🎃", "😺", "😸", "😹", "😻", "😼", "😽", "🙀",
        "😿", "😾",
    ]

    private static let peopleEmojis: [String] = [
        "👋", "🤚", "🖐️", "✋", "🖖", "🫱", "🫲", "🫳",
        "🫴", "👌", "🤌", "🤏", "✌️", "🤞", "🫰", "🤟",
        "🤘", "🤙", "👈", "👉", "👆", "🖕", "👇", "☝️",
        "🫵", "👍", "👎", "✊", "👊", "🤛", "🤜", "👏",
        "🙌", "🫶", "👐", "🤲", "🤝", "🙏", "✍️", "💅",
        "🤳", "💪", "🦾", "🦿", "🦵", "🦶", "👂", "🦻",
        "👃", "🧠", "🫀", "🫁", "🦷", "🦴", "👀", "👁️",
        "👅", "👄", "🫦", "👶", "🧒", "👦", "👧", "🧑",
        "👱", "👨", "🧔", "👩", "🧓", "👴", "👵", "🙍",
        "🙎", "🙅", "🙆", "💁", "🙋", "🧏", "🙇", "🤦",
        "🤷", "👮", "🕵️", "💂", "🥷", "👷", "🫅", "🤴",
        "👸", "👳", "👲", "🧕", "🤵", "👰", "🤰", "🫃",
    ]

    private static let animalsEmojis: [String] = [
        "🐶", "🐱", "🐭", "🐹", "🐰", "🦊", "🐻", "🐼",
        "🐻‍❄️", "🐨", "🐯", "🦁", "🐮", "🐷", "🐸", "🐵",
        "🙈", "🙉", "🙊", "🐒", "🐔", "🐧", "🐦", "🐤",
        "🐣", "🐥", "🦆", "🦅", "🦉", "🦇", "🐺", "🐗",
        "🐴", "🦄", "🐝", "🪱", "🐛", "🦋", "🐌", "🐞",
        "🐜", "🪰", "🪲", "🪳", "🦟", "🦗", "🕷️", "🦂",
        "🐢", "🐍", "🦎", "🦖", "🦕", "🐙", "🦑", "🦐",
        "🦞", "🦀", "🪸", "🐡", "🐠", "🐟", "🐬", "🐳",
        "🐋", "🦈", "🐊", "🐅", "🐆", "🦓", "🦍", "🦧",
        "🐘", "🦛", "🦏", "🐪", "🐫", "🦒", "🦘", "🦬",
        "🐃", "🐂", "🐄", "🐎", "🐖", "🐏", "🐑", "🦙",
        "🐐", "🦌", "🐕", "🐩", "🦮", "🐈", "🐓", "🦃",
        "🦤", "🕊️", "🐇", "🦝", "🦨", "🦡", "🦫", "🦦",
        "🦥", "🐁", "🐀", "🐿️", "🦔",
        "🌸", "🌺", "🌻", "🌹", "🌷", "🌼", "🍀", "🌿",
        "🍃", "🍂", "🍁", "🌾", "🌵", "🌴", "🌳", "🌲",
        "🪴", "🌱", "🪹", "🪺", "🍄", "🌈", "☀️", "🌙",
        "⭐", "🌟", "✨", "⚡", "🔥", "💧", "🌊", "⛅",
    ]

    private static let foodEmojis: [String] = [
        "🍏", "🍎", "🍐", "🍊", "🍋", "🍌", "🍉", "🍇",
        "🍓", "🫐", "🍈", "🍒", "🍑", "🥭", "🍍", "🥥",
        "🥝", "🍅", "🍆", "🥑", "🥦", "🥬", "🥒", "🌶️",
        "🫑", "🌽", "🥕", "🫒", "🧄", "🧅", "🥔", "🍠",
        "🫘", "🥐", "🍞", "🥖", "🥨", "🧀", "🥚", "🍳",
        "🧈", "🥞", "🧇", "🥓", "🥩", "🍗", "🍖", "🦴",
        "🌭", "🍔", "🍟", "🍕", "🫓", "🥪", "🥙", "🧆",
        "🌮", "🌯", "🫔", "🥗", "🥘", "🫕", "🥫", "🍝",
        "🍜", "🍲", "🍛", "🍣", "🍱", "🥟", "🦪", "🍤",
        "🍙", "🍚", "🍘", "🍥", "🥠", "🥮", "🍢", "🍡",
        "🍧", "🍨", "🍦", "🥧", "🧁", "🍰", "🎂", "🍮",
        "🍭", "🍬", "🍫", "🍿", "🍩", "🍪", "🌰", "🥜",
        "🍯", "🥛", "🍼", "🫖", "☕", "🍵", "🧃", "🥤",
        "🧋", "🍶", "🍺", "🍻", "🥂", "🍷", "🥃", "🍸",
        "🍹", "🧉", "🍾", "🧊",
    ]

    private static let travelEmojis: [String] = [
        "🚗", "🚕", "🚙", "🚌", "🚎", "🏎️", "🚓", "🚑",
        "🚒", "🚐", "🛻", "🚚", "🚛", "🚜", "🛵", "🏍️",
        "🛺", "🚲", "🛴", "🛹", "🛼", "🚁", "✈️", "🛩️",
        "🚀", "🛸", "🚢", "⛵", "🛶", "🚤", "🛥️", "⛴️",
        "🚂", "🚃", "🚄", "🚅", "🚆", "🚇", "🚈", "🚉",
        "🏠", "🏡", "🏢", "🏣", "🏤", "🏥", "🏦", "🏨",
        "🏩", "🏪", "🏫", "🏬", "🏭", "🏯", "🏰", "💒",
        "🗼", "🗽", "⛪", "🕌", "🛕", "🕍", "⛩️", "🕋",
        "⛲", "⛺", "🌁", "🌃", "🏙️", "🌅", "🌄", "🌠",
        "🎠", "🎡", "🎢", "💈", "🎪", "🗺️", "🧭", "🏔️",
        "⛰️", "🌋", "🏕️", "🏖️", "🏜️", "🏝️", "🏞️",
    ]

    private static let objectsEmojis: [String] = [
        "⌚", "📱", "📲", "💻", "⌨️", "🖥️", "🖨️", "🖱️",
        "🖲️", "💾", "💿", "📀", "📷", "📸", "📹", "🎥",
        "📽️", "🎞️", "📞", "☎️", "📟", "📠", "📺", "📻",
        "🎙️", "🎚️", "🎛️", "🧭", "⏱️", "⏲️", "⏰", "🕰️",
        "💡", "🔦", "🕯️", "🪔", "🧯", "🗑️", "🛒", "🛍️",
        "🎁", "🎈", "🎏", "🎀", "🪄", "🪅", "🎊", "🎉",
        "🎎", "🏮", "🎐", "🧧", "✉️", "📩", "📨", "📧",
        "💌", "📥", "📤", "📦", "🏷️", "📪", "📫", "📬",
        "📮", "📝", "💼", "📁", "📂", "🗂️", "📅", "📆",
        "📇", "📈", "📉", "📊", "📋", "📌", "📍", "📎",
        "🖇️", "📏", "📐", "✂️", "🗃️", "🗄️", "🗒️", "🗓️",
        "📔", "📕", "📖", "📗", "📘", "📙", "📚", "📓",
        "🔖", "🔗", "📐", "🔐", "🔑", "🗝️", "🔒", "🔓",
        "🛠️", "⛏️", "🔨", "🪓", "🔧", "🪛", "🔩", "⚙️",
        "🎵", "🎶", "🎤", "🎧", "🎷", "🎸", "🎹", "🪗",
        "🥁", "🪘", "🎺", "🎻", "🪕", "🎬", "🏆", "🥇",
        "🥈", "🥉", "⚽", "🏀", "🏈", "⚾", "🥎", "🎾",
        "🏐", "🏉", "🥏", "🎱", "🪀", "🏓", "🏸", "🏒",
        "🥊", "🥋", "🎯", "⛳", "🪁", "🎣", "🤿", "🎿",
        "🛷", "🥌", "🎮", "🕹️", "🎲", "🧩", "🪆", "♟️",
        "💰", "💴", "💵", "💶", "💷", "🪙", "💸", "💳",
    ]

    private static let symbolsEmojis: [String] = [
        "❤️", "🧡", "💛", "💚", "💙", "💜", "🖤", "🤍",
        "🤎", "💔", "❤️‍🔥", "❤️‍🩹", "❣️", "💕", "💞", "💓",
        "💗", "💖", "💘", "💝", "💟", "☮️", "✝️", "☪️",
        "🕉️", "☸️", "✡️", "🔯", "🕎", "☯️", "☦️", "🛐",
        "⛎", "♈", "♉", "♊", "♋", "♌", "♍", "♎",
        "♏", "♐", "♑", "♒", "♓", "🆔", "⚛️", "🉑",
        "☢️", "☣️", "📴", "📳", "🈶", "🈚", "🈸", "🈺",
        "🈷️", "✴️", "🆚", "💮", "🉐", "㊙️", "㊗️", "🈴",
        "🈵", "🈹", "🈲", "🅰️", "🅱️", "🆎", "🆑", "🅾️",
        "🆘", "❌", "⭕", "🛑", "⛔", "📛", "🚫", "💯",
        "💢", "♨️", "🚷", "🚯", "🚳", "🚱", "🔞", "📵",
        "🚭", "❗", "❕", "❓", "❔", "‼️", "⁉️", "🔅",
        "🔆", "〽️", "⚠️", "🚸", "🔱", "⚜️", "🔰", "♻️",
        "✅", "🈯", "💹", "❇️", "✳️", "❎", "🌐", "💠",
        "Ⓜ️", "🌀", "💤", "🏧", "🚾", "♿", "🅿️", "🛗",
        "🈳", "🈂️", "🛂", "🛃", "🛄", "🛅", "🔣", "ℹ️",
        "🔤", "🔡", "🔠", "🆖", "🆗", "🆙", "🆒", "🆕",
        "🆓", "0️⃣", "1️⃣", "2️⃣", "3️⃣", "4️⃣", "5️⃣", "6️⃣",
        "7️⃣", "8️⃣", "9️⃣", "🔟", "🔢", "#️⃣", "*️⃣", "⏏️",
        "▶️", "⏸️", "⏯️", "⏹️", "⏺️", "⏭️", "⏮️", "⏩",
        "⏪", "⏫", "⏬", "◀️", "🔼", "🔽", "➡️", "⬅️",
        "⬆️", "⬇️", "↗️", "↘️", "↙️", "↖️", "↕️", "↔️",
        "🔀", "🔁", "🔂", "🔄", "🔃",
    ]

    private static let flagsEmojis: [String] = [
        "🏳️", "🏴", "🏁", "🚩", "🏳️‍🌈", "🏳️‍⚧️", "🏴‍☠️",
        "🇺🇸", "🇬🇧", "🇨🇦", "🇦🇺", "🇫🇷", "🇩🇪", "🇮🇹",
        "🇪🇸", "🇵🇹", "🇧🇷", "🇲🇽", "🇯🇵", "🇰🇷", "🇨🇳",
        "🇮🇳", "🇷🇺", "🇹🇷", "🇸🇦", "🇦🇪", "🇮🇱", "🇪🇬",
        "🇿🇦", "🇳🇬", "🇰🇪", "🇬🇭", "🇪🇹", "🇹🇿", "🇦🇷",
        "🇨🇴", "🇨🇱", "🇵🇪", "🇻🇪", "🇨🇺", "🇵🇷", "🇯🇲",
        "🇹🇭", "🇻🇳", "🇮🇩", "🇵🇭", "🇲🇾", "🇸🇬", "🇳🇿",
        "🇫🇮", "🇳🇴", "🇸🇪", "🇩🇰", "🇮🇸", "🇮🇪", "🇳🇱",
        "🇧🇪", "🇨🇭", "🇦🇹", "🇵🇱", "🇨🇿", "🇭🇺", "🇷🇴",
        "🇬🇷", "🇺🇦", "🇭🇷", "🇷🇸", "🇧🇬", "🇸🇰", "🇸🇮",
        "🇱🇹", "🇱🇻", "🇪🇪", "🇪🇺",
    ]

    /// Every emoji across all categories (for search).
    static let allEmojis: [String] = {
        var all: [String] = []
        for cat in allCases where cat != .frequentlyUsed {
            all.append(contentsOf: cat.emojis)
        }
        return all
    }()
}

// MARK: - Emoji History Manager

@Observable
@MainActor
final class EmojiHistoryManager {
    private(set) var frequentEmojis: [String] = []
    private var frequencyMap: [String: Int] = [:]

    private let defaults: UserDefaults

    init() {
        defaults = UserDefaults(suiteName: AppConstants.appGroupID) ?? .standard
        load()
    }

    func recordUsage(_ emoji: String) {
        frequencyMap[emoji, default: 0] += 1
        persist()
        rebuildFrequent()
    }

    private func load() {
        if let data = defaults.dictionary(forKey: AppConstants.emojiFrequencyKey) as? [String: Int] {
            frequencyMap = data
        }
        rebuildFrequent()
    }

    private func persist() {
        defaults.set(frequencyMap, forKey: AppConstants.emojiFrequencyKey)
    }

    private func rebuildFrequent() {
        frequentEmojis = frequencyMap
            .sorted { $0.value > $1.value }
            .prefix(16)
            .map(\.key)
    }
}

// MARK: - Emoji Search Index

enum EmojiSearch {
    /// Lazily built mapping: emoji → lowercased Unicode name.
    private static let nameIndex: [String: String] = {
        var index: [String: String] = [:]
        for emoji in EmojiCategory.allEmojis {
            let name = unicodeName(for: emoji)
            if !name.isEmpty {
                index[emoji] = name
            }
        }
        return index
    }()

    /// Extracts the Unicode name from the first scalar of the emoji.
    private static func unicodeName(for emoji: String) -> String {
        guard let scalar = emoji.unicodeScalars.first else { return "" }
        return scalar.properties.name?.lowercased() ?? ""
    }

    /// Returns emojis whose Unicode name contains the query (case-insensitive).
    static func search(_ query: String) -> [String] {
        guard !query.isEmpty else { return EmojiCategory.allEmojis }
        let q = query.lowercased()
        return EmojiCategory.allEmojis.filter { emoji in
            nameIndex[emoji]?.contains(q) == true
        }
    }
}
