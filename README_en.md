[한국어](README.md)

# Moa+

> Korean at your fingertips — Gesture-based iOS Hangul Keyboard

Swipe on consonant keys to input vowels. All 21 Korean vowels through intuitive 8-directional gesture combinations.

**New in v1.2**: English QWERTY keyboard, Cheonjiin vowel input (ㅣ · dot · ㅡ), space-bar drag for cursor movement, unified gesture settings screen.

> Based on [ios-moaki](https://github.com/vkehfdl1/ios-moaki) by Jeffrey (Dongkyu) Kim

## Screenshots

### v1.2 — Keyboard and Appearance preview

| Korean keyboard | English keyboard | Appearance preview |
|:--:|:--:|:--:|
| <img src="resources/screenshots/new-01_ko.PNG" width="180"> | <img src="resources/screenshots/new-02_en.PNG" width="180"> | <img src="resources/screenshots/new-03_skin.PNG" width="180"> |

### Host app

| Home | Settings | Tutorial | Abbreviation | About |
|:--:|:--:|:--:|:--:|:--:|
| <img src="resources/screenshots/01_home.png" width="160"> | <img src="resources/screenshots/03_settings.png" width="160"> | <img src="resources/screenshots/05_tutorial.png" width="160"> | <img src="resources/screenshots/06_abbreviation.png" width="160"> | <img src="resources/screenshots/07_about.png" width="160"> |

## Features

### Input
- **Gesture vowel input** — 8-directional swipe on consonant keys for all 21 vowels
- **Cheonjiin vowel input** (v1.2) — Compose every Korean vowel using just three keys: ㅣ, dot (ㆍ), and ㅡ. Includes dot-stroke accumulation (dot+dot+ㅣ → ㅕ).
- **English QWERTY mode** (v1.2) — Switch instantly with the language key. Double-tap Shift for Caps Lock.
- **Long-press auxiliary input** — Hold for numbers/symbols, drag to select candidates
- **English number specials** (v1.2) — Long-press number keys in English mode for ! @ # $ % ^ & * ( )
- **Abbreviation expansion** — Type a few consonants to expand into full phrases (e.g. ㅇㅎ → 확인했습니다)

### Editing
- **Space-drag cursor** (v1.2) — Drag the space bar left/right to move the cursor
- **Auto bracket close** — Typing `(`, `[`, `{`, `「` etc. automatically inserts the closing pair
- **Word-level delete** — Long-press backspace for fast word-by-word deletion

### Customization
- **Custom themes** — 5 presets + custom colors + background image + key opacity
- **Unified gesture settings** (v1.2) — Angle, length, direction mapping, and per-column correction managed in one screen
- **Live gesture visualization** (v1.2) — Test your gestures with the same engine the keyboard uses
- **Typing practice** (v1.2) — 33 scenarios covering cheonjiin, English, and cursor movement

### Privacy
- **Fully offline** — No network access, no data collection
- **No Full Access required** (v1.2 onward) — Settings sync via App Group entitlements. iOS no longer shows the "Allow Full Access" warning.

## Gesture Guide

Drag on a consonant key to input a vowel.

### Basic Vowels + Diagonals

| Direction | Vowel | Direction | Vowel |
|-----------|-------|-----------|-------|
| → | ㅏ (a) | ↗ ↖ | ㅣ (i) |
| ← | ㅓ (eo) | ↘ ↙ | ㅡ (eu) |
| ↑ | ㅗ (o) | | |
| ↓ | ㅜ (u) | | |

> Diagonal mappings are customizable in settings.

### Y-Vowels (Back-and-forth)

| Direction | Vowel | Direction | Vowel |
|-----------|-------|-----------|-------|
| →←→ | ㅑ (ya) | ↑↓↑ | ㅛ (yo) |
| ←→← | ㅕ (yeo) | ↓↑↓ | ㅠ (yu) |

### Compound Vowels

| Direction | Vowel | Direction | Vowel |
|-----------|-------|-----------|-------|
| ↑→ | ㅘ (wa) | →← | ㅐ (ae) |
| ↓← | ㅝ (wo) | ←→ | ㅔ (e) |
| ↑↓ | ㅚ (oe) | →←→← | ㅒ (yae) |
| ↓↑ | ㅟ (wi) | ←→←→ | ㅖ (ye) |
| ↑→← | ㅙ (wae) | ↘↖ | ㅢ (ui) |
| ↓→← | ㅞ (we) | | |

## Keyboard Layout

### Korean mode (v1.2)

```
 ~  ㅃ ㅉ ㄸ ㄲ ㅆ  #
 ^  ㅂ ㅈ ㄷ ㄱ ㅅ  ⌫
 ;  ㅁ ㄴ ㅇ ㄹ ㅎ  ㅣ
 *  ㅋ ㅌ ㅊ ㅍ  ㅡ  ㆍ
 123  한/영  [Space (drag → cursor)]  .  ⏎
```

The right column keys **ㅣ, dot (ㆍ), and ㅡ** are the cheonjiin vowel primitives. Tap, swipe in 8 directions, or accumulate dots (dot+dot+ㅣ → ㅕ) to compose any vowel.

### English mode (v1.2)

```
 1  2  3  4  5  6  7  8  9  0
 q  w  e  r  t  y  u  i  o  p
 a  s  d  f  g  h  j  k  l
 ⇧  z  x  c  v  b  n  m  ⌫
```

- **Shift single tap**: One-shot uppercase, auto-resets after one letter
- **Shift double tap**: Caps Lock until tapped again
- **Long-press number keys**: ! @ # $ % ^ & * ( )

### Long-press numbers (Korean mode)

```
ㅃ→1  ㅉ→2  ㄸ→3  ㄲ→4  ㅆ→5
ㅂ→6  ㅈ→7  ㄷ→8  ㄱ→9  ㅅ→0
```

## Install

### Build

```bash
git clone https://github.com/koh0001/moa-plus.git
cd moa-plus
open MoaPlus.xcodeproj
```

Select the `MoaPlus` scheme in Xcode → Choose device/simulator → `Cmd + R`

### Activate the Keyboard

1. **Settings** → **General** → **Keyboard** → **Add New Keyboard** → Select **Moa+**
2. Switch to Moa+ using the 🌐 button when typing

> Starting with v1.2, **Full Access is no longer required**. Settings sync between the host app and keyboard via App Group, and the keyboard never connects to the network.

> For device installation, see [Build & Install Guide](docs/moakey_ios_custom_docs/03_빌드_및_설치_가이드.md)

## Project Structure

```
moa-plus/
├── MoaPlus/                    # Main app (home, settings, tutorial, typing practice)
│   ├── Practice/               # Typing practice (33 scenarios)
│   └── Settings/               # Appearance / gesture / shortcut / long-press + live test
├── MoaPlusKeyboard/            # Keyboard extension
│   ├── Engine/                 # Hangul composer (with cheonjiin dotPending), gesture analyzer, abbreviation
│   ├── Models/                 # Jamo, gesture, theme, shortcut, keyboard mode (Korean/English/Symbol)
│   ├── ViewModels/             # Keyboard view model (mode/Shift/cursor management)
│   ├── Views/                  # Keyboard UI (Korean 7-col, English 10-col, cheonjiin vowel keys)
│   └── Utilities/              # Settings, metrics, haptics
├── MoaPlusKeyboardTests/       # Unit tests (HangulComposer, Shift, Cursor, VowelDrag, etc.)
├── scripts/                    # Build automation (target membership helpers)
└── docs/                       # Development docs
```

For detailed architecture, see [CLAUDE.md](CLAUDE.md).

## Acknowledgments

This project is based on [ios-moaki](https://github.com/vkehfdl1/ios-moaki) by Jeffrey (Dongkyu) Kim.
Thank you for making the project open source.

## Credits

- Original project: [ios-moaki](https://github.com/vkehfdl1/ios-moaki) by Jeffrey (Dongkyu) Kim
- Image cropping: [TOCropViewController](https://github.com/TimOliver/TOCropViewController) by Tim Oliver

## License

[MIT License](LICENSE)
