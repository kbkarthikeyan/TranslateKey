# TranslateKey

An iOS keyboard extension with real-time translation, swipe typing, autocorrect, and a full emoji palette.

## Features

**Translation**
- 20 supported languages with neural machine translation (iOS Translation framework)
- Quick language strip for fast target switching
- Send mode (type → translate to target) and Read mode (paste → translate to source)
- Session caching for low-latency repeat translations

**Typing**
- QWERTY / AZERTY / QWERTZ layouts based on device locale
- Swipe typing with frequency-ranked word matching
- Autocorrect via 270+ static corrections + UITextChecker
- Word predictions with undo support
- Auto-capitalization after sentence-ending punctuation

**Emoji**
- 600+ emojis across 9 categories (smileys, people, animals, food, travel, objects, symbols, flags)
- Search by Unicode name with live filtering
- Frequently used tracking (persisted across sessions)
- Browse mode with category tabs and search mode with dedicated keyboard

## Requirements

- iOS 18.0+
- Xcode 16+
- Apple Developer account (for keyboard extension provisioning)

## Setup

1. Clone the repo
2. Open `TranslateKey.xcodeproj`
3. Set your development team in both targets (TranslateKey and TranslateKeyboard)
4. Build and run on a device
5. Go to Settings → General → Keyboard → Keyboards → Add New Keyboard → TranslateKey
6. Enable "Allow Full Access" for translation features

## Project Structure

```
TranslateKey/
├── App/                          # Host app (settings UI)
│   ├── ContentView.swift
│   └── TranslateKeyApp.swift
├── Keyboard/                     # Keyboard extension
│   ├── KeyboardViewController.swift
│   ├── Emoji/
│   │   └── EmojiStore.swift      # Categories, search index, frequency tracking
│   ├── SwipeTyping/
│   │   └── SwipeEngine.swift     # Swipe-to-type engine
│   └── Views/
│       └── KeyboardView.swift    # All keyboard UI
└── Shared/                       # Shared between app and extension
    ├── Constants.swift
    ├── LanguageManager.swift
    └── TranslationService.swift
```

## Supported Languages

English, Spanish, French, German, Italian, Portuguese, Simplified Chinese, Traditional Chinese, Japanese, Korean, Arabic, Hindi, Russian, Turkish, Polish, Dutch, Thai, Vietnamese, Indonesian, Ukrainian
