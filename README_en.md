[한국어](README.md)

# Moa+

> Korean at your fingertips — Gesture-based iOS Hangul Keyboard

Swipe on consonant keys to input vowels. All 21 Korean vowels through intuitive 8-directional gesture combinations.

**New in v1.4**: Three layout presets (Modern / Classic / Extended), Slot B vowel key beside the space bar, first-launch layout selection modal, flat 6-item settings structure, last-keyboard-mode persistence, Help section (tutorial replay + typing practice), redesigned gesture test screen.

**v1.3**: Caps Lock via long-press Shift, abbreviation master ON/OFF toggle, per-column gesture correction sliders, device-proportional swipe thresholds.

**v1.2**: English QWERTY keyboard, Cheonjiin vowel input (ㅣ · dot · ㅡ), space-bar drag for cursor movement, unified gesture settings screen.

> Based on [ios-moaki](https://github.com/vkehfdl1/ios-moaki) by Jeffrey (Dongkyu) Kim

## Screenshots

### v1.4 — Keyboard and Appearance preview

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
- **Abbreviation master toggle** (v1.3) — Pause auto-expansion without losing saved phrases; backspace immediately after expansion restores the original input
- **English QWERTY Caps Lock** (v1.3) — Long-press Shift to toggle Caps Lock

### Editing
- **Space-drag cursor** (v1.2) — Drag the space bar left/right to move the cursor
- **Auto bracket close** — Typing `(`, `[`, `{`, `「` etc. automatically inserts the closing pair
- **Word-level delete** — Long-press backspace for fast word-by-word deletion

### Customization
- **Layout presets** (v1.4) — Choose from Modern, Classic, or Extended at Settings → Keyboard → Layout. A selection modal appears on first launch.
- **Slot B vowel key** (v1.4) — Assign the key next to the space bar as a vowel input key. Supports the same multi-stroke gestures as consonant keys (ㅑ ㅕ ㅛ ㅠ ㅘ ㅙ ㅚ ㅝ ㅞ ㅟ ㅒ ㅖ ㅢ).
- **Last-mode persistence** (v1.4) — Optionally restore the last used Korean/English mode on next launch (Settings → Keyboard → Input Behavior).
- **Custom themes** — 5 presets + custom colors + background image + key opacity
- **Unified gesture settings** (v1.2) — Angle, length, direction mapping, and per-column correction managed in one screen
- **Per-column gesture correction** (v1.3) — Per-column sliders to tune false positives like ㅗ → ㅘ end-curve misreads
- **Gesture test screen** (v1.4, redesigned) — Test directly on a real keyboard layout; sector canvas shows live input results
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

## Settings Structure (v1.4)

The host app settings were reorganized into a flat 6-item structure:

| Section | Contents |
|---------|----------|
| Keyboard | Layout presets / Input behavior / Long-press / Backspace |
| Appearance | Theme / Colors / Background image / Key opacity |
| Feedback | Haptics / Click sound |
| Abbreviations | Phrase CRUD + master ON/OFF |
| Help | Tutorial replay + Typing practice |
| About | Credits / License |

## Project Structure

```
moa-plus/
├── MoaPlus/                    # Main app (home, settings, tutorial, typing practice)
│   ├── Practice/               # Typing practice (33 scenarios)
│   └── Settings/               # Keyboard / Appearance / Feedback / Abbreviations / Help / About (v1.4 flat structure)
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
