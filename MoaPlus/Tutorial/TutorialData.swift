import Foundation

struct VowelGesture: Identifiable {
    let id = UUID()
    let vowel: String
    let directions: [String]
    let label: String
    var altDirections: [String]? = nil
    var altLabel: String? = nil
}

struct TutorialStage: Identifiable {
    let id: Int
    let title: String
    let description: String
    let vowelGestures: [VowelGesture]
    let practiceLines: [String]
    let isSentenceMode: Bool
    let tip: String?

    init(
        id: Int,
        title: String,
        description: String,
        vowelGestures: [VowelGesture] = [],
        practiceLines: [String] = [],
        isSentenceMode: Bool = false,
        tip: String? = nil
    ) {
        self.id = id
        self.title = title
        self.description = description
        self.vowelGestures = vowelGestures
        self.practiceLines = practiceLines
        self.isSentenceMode = isSentenceMode
        self.tip = tip
    }
}

enum TutorialContent {
    static let stages: [TutorialStage] = [
        // Stage 0: Welcome
        TutorialStage(
            id: 0,
            title: "모아+에 오신 걸 환영합니다",
            description: "자음 키를 누르고 방향을 긋기만 하면 모음이 입력됩니다.\n\n세 가지만 기억하세요:",
            tip: "긋기 = 모음 · 왕복 = Y-모음 · 길게 누르기 = 숫자"
        ),

        // Stage 1: First letters
        TutorialStage(
            id: 1,
            title: "첫 글자 만들기",
            description: "자음 키 위에서 상하좌우로 긋기만 하면 됩니다.\n→ ㅏ, ← ㅓ, ↑ ㅗ, ↓ ㅜ",
            vowelGestures: [
                VowelGesture(vowel: "ㅏ", directions: ["→"], label: "오른쪽"),
                VowelGesture(vowel: "ㅓ", directions: ["←"], label: "왼쪽"),
                VowelGesture(vowel: "ㅗ", directions: ["↑"], label: "위"),
                VowelGesture(vowel: "ㅜ", directions: ["↓"], label: "아래"),
            ],
            practiceLines: [
                "가나다",
                "거너더",
                "고노도",
                "구누두",
            ],
            tip: "정확히 수직/수평이 아니어도 괜찮아요. 대각선은 다음 단계에서 배웁니다."
        ),

        // Stage 2: ㅣ and ㅡ + Name practice
        TutorialStage(
            id: 2,
            title: "ㅣ와 ㅡ, 내 이름 써보기",
            description: "대각선 긋기로 ㅣ와 ㅡ를 입력합니다.\n↗ ↖ = ㅣ, ↘ ↙ = ㅡ",
            vowelGestures: [
                VowelGesture(vowel: "ㅣ", directions: ["↗"], label: "오른쪽 위 대각선", altDirections: ["↖"], altLabel: "왼쪽 위 대각선"),
                VowelGesture(vowel: "ㅡ", directions: ["↘"], label: "오른쪽 아래 대각선", altDirections: ["↙"], altLabel: "왼쪽 아래 대각선"),
            ],
            practiceLines: [
                "기미리",
                "그므르",
                "시비히",
                "스브흐",
            ],
            tip: "자유롭게 본인 이름도 입력해 보세요!"
        ),

        // Stage 3: Y-Vowels
        TutorialStage(
            id: 3,
            title: "빠른 모음 (왕복 긋기)",
            description: "같은 방향을 왕복하면 Y-모음이 됩니다.\n→←→ = ㅑ, ↑↓↑ = ㅛ",
            vowelGestures: [
                VowelGesture(vowel: "ㅑ", directions: ["→", "←", "→"], label: "오른쪽-왼쪽-오른쪽"),
                VowelGesture(vowel: "ㅕ", directions: ["←", "→", "←"], label: "왼쪽-오른쪽-왼쪽"),
                VowelGesture(vowel: "ㅛ", directions: ["↑", "↓", "↑"], label: "위-아래-위"),
                VowelGesture(vowel: "ㅠ", directions: ["↓", "↑", "↓"], label: "아래-위-아래"),
            ],
            practiceLines: [
                "야유",
                "여요",
                "교류",
                "사랑해요",
            ],
            tip: "리듬감 있게 긋기 — 왕복을 부드럽게 하면 잘 인식됩니다."
        ),

        // Stage 4: Common compound vowels
        TutorialStage(
            id: 4,
            title: "일상 속 복합 모음",
            description: "방향을 꺾으면 복합 모음이 만들어집니다.",
            vowelGestures: [
                VowelGesture(vowel: "ㅘ", directions: ["↑", "→"], label: "위→오른쪽"),
                VowelGesture(vowel: "ㅝ", directions: ["↓", "←"], label: "아래→왼쪽"),
                VowelGesture(vowel: "ㅐ", directions: ["→", "←"], label: "오른쪽→왼쪽"),
                VowelGesture(vowel: "ㅔ", directions: ["←", "→"], label: "왼쪽→오른쪽"),
                VowelGesture(vowel: "ㅚ", directions: ["↑", "↓"], label: "위→아래"),
                VowelGesture(vowel: "ㅟ", directions: ["↓", "↑"], label: "아래→위"),
            ],
            practiceLines: [
                "왜 그래",
                "돼지",
                "네게",
                "사과",
                "궤도",
            ],
            tip: "ㅐ(→←)와 ㅔ(←→)는 시작 방향이 반대입니다."
        ),

        // Stage 5: Rare compound vowels
        TutorialStage(
            id: 5,
            title: "나머지 모음 완성",
            description: "자주 쓰이진 않지만, 알아두면 좋은 모음들입니다.",
            vowelGestures: [
                VowelGesture(vowel: "ㅒ", directions: ["→", "←", "→", "←"], label: "오른쪽-왼쪽 두 번"),
                VowelGesture(vowel: "ㅖ", directions: ["←", "→", "←", "→"], label: "왼쪽-오른쪽 두 번"),
                VowelGesture(vowel: "ㅙ", directions: ["↑", "→", "←"], label: "위-오른쪽-왼쪽"),
                VowelGesture(vowel: "ㅞ", directions: ["↓", "→", "←"], label: "아래-오른쪽-왼쪽"),
                VowelGesture(vowel: "ㅢ", directions: ["↘", "↖"], label: "오른쪽아래-왼쪽위"),
            ],
            practiceLines: [
                "예의",
                "왜냐",
                "웨이터",
            ],
            tip: "ㅒ와 ㅖ는 ㅐ/ㅔ를 두 번 왕복하면 됩니다."
        ),

        // Stage 6: Long-press, space drag, shortcuts
        TutorialStage(
            id: 6,
            title: "보조 입력 — 숫자, 커서, 단축어",
            description: "자음 키를 길게 누르면 숫자와 기호가 입력됩니다. 그대로 드래그하면 다른 후보를 선택할 수 있어요.\n\n스페이스바를 좌우로 드래그하면 커서가 한 글자씩 이동합니다.\n\n설정에서 단축어를 등록하면 자음 몇 개로 긴 문장을 입력할 수 있어요. 같은 글자로 시작하는 단축어가 여러 개면 후보 바에서 골라 쓸 수 있고, 입력 직후 백스페이스를 한 번 누르면 원래 글자로 되돌립니다.",
            practiceLines: [
                "12345",
                "67890",
            ],
            tip: "예: ㅇㅎ + 스페이스 → '확인했습니다' (단축어 설정 후)"
        ),

        // Stage 7: English mode & caps lock
        TutorialStage(
            id: 7,
            title: "영문 모드 & Caps Lock",
            description: "키보드 하단의 한/영 키를 누르면 영문 QWERTY 모드로 전환됩니다.\n123 키를 누르면 숫자·기호 모드입니다.\n\n영문 모드의 Shift 키:\n• 한 번 탭 → 다음 한 글자만 대문자\n• 더블탭 또는 길게 누르기 → Caps Lock (대문자 고정). 다시 길게 누르면 풀립니다.",
            practiceLines: [
                "Hello",
                "MOA Plus",
                "iOS 26",
            ],
            tip: "한↔영 / 123 / 한글은 같은 자리의 모드 키로 순환됩니다."
        ),

        // Stage 8: Real sentences
        TutorialStage(
            id: 8,
            title: "실전 문장 연습",
            description: "지금까지 배운 모든 제스처를 활용해 문장을 입력해보세요.\n틀려도 괜찮아요. 연습하면 빨라집니다!",
            practiceLines: [
                "안녕하세요",
                "오늘 날씨가 좋네요",
                "내일 시간 되세요?",
                "감사합니다",
            ],
            isSentenceMode: true,
            tip: "처음엔 느려도 괜찮아요. 며칠만 쓰면 손에 익습니다."
        ),
    ]
}
