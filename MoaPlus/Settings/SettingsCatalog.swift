import SwiftUI

/// 설정 화면 카탈로그 — 검색(`SettingsMainView`)과 증상 라우터(`HelpView`)가 공유한다.
///
/// **왜 필요한가**: 앱스토어 리뷰 7건 중 5건이 "기능이 없다"가 아니라 **있는 기능을
/// 찾지 못한** 경우였다. 사용자는 "진입앵글", "지구봉", "글자 힌트"라고 말하는데
/// 앱은 "섹터 각도", "키보드 전환 키", "보조 매핑 힌트"라고 부른다. IA 를 아무리 잘
/// 짜도 이 어휘 다리가 없으면 같은 리뷰가 반복된다.
///
/// 그래서 `keywords` 에는 **앱 용어가 아니라 사용자가 실제로 쓴 말**을 넣는다.
/// 리뷰에서 관찰된 표현은 주석으로 출처를 남겨 뒀다 — 지우지 말 것.
enum SettingsDestination: String, Hashable, CaseIterable {
    case layout, size, gesture, gestureTest, longPress, backspace, inputBehavior
    case appearance, feedback, abbreviation, debugBoard

    /// 탐색 경로 표시용. 검색 결과에서 "어디에 있는 설정인지"를 알려준다.
    var breadcrumb: String {
        switch self {
        case .layout, .size, .gesture, .gestureTest, .longPress, .backspace, .inputBehavior:
            return "설정 › 키보드"
        case .appearance, .feedback, .abbreviation, .debugBoard:
            return "설정"
        }
    }

    @ViewBuilder
    var view: some View {
        switch self {
        case .layout: LayoutCustomizationView()
        case .size: KeyboardSizeSettingsView()
        case .gesture: GestureSettingsView()
        case .gestureTest: GestureTestView()
        case .longPress: LongPressSettingsView()
        case .backspace: BackspaceSettingsView()
        case .inputBehavior: InputBehaviorSettingsView()
        case .appearance: AppearanceSettingsView()
        case .feedback: FeedbackSettingsView()
        case .abbreviation: AbbreviationSettingsView()
        case .debugBoard: DebugBoardView()
        }
    }
}

/// 검색 가능한 설정 항목 하나.
struct SettingsEntry: Identifiable {
    let id = UUID()
    let title: String
    let icon: String
    let destination: SettingsDestination
    /// 사용자 어휘를 포함한 검색어. 제목에 없는 말로도 찾을 수 있어야 한다.
    let keywords: [String]

    /// **알려진 한계 — 버그 아님**: 한글을 타이핑하는 중에는 질의가 아직 조합 중인
    /// 자모(`ㄱ` → `ㄱㅏ` → `가`)라, 완성된 음절이 되기 전까지 `contains` 가 걸리지
    /// 않아 결과가 비어 보인다. 음절이 완성되는 순간 정상적으로 나온다.
    /// 초성 검색(`ㄱㄷ` → `각도`)은 별도 기능이며 여기에 없다.
    func matches(_ query: String) -> Bool {
        let q = query.trimmingCharacters(in: .whitespaces).lowercased()
        guard !q.isEmpty else { return false }
        if title.lowercased().contains(q) { return true }
        if destination.breadcrumb.lowercased().contains(q) { return true }
        return keywords.contains { $0.lowercased().contains(q) }
    }
}

/// "이럴 때 어떻게 하나요" — 증상으로 설정을 찾는 항목.
struct SettingsSymptom: Identifiable {
    let id = UUID()
    /// 사용자가 겪는 현상을 사용자 말로. 기능 이름을 쓰면 안 된다.
    let symptom: String
    /// 무엇을 조절하면 되는지 한 줄.
    let remedy: String
    let icon: String
    let destination: SettingsDestination
}

enum SettingsCatalog {

    /// 검색 인덱스.
    static let entries: [SettingsEntry] = [
        SettingsEntry(
            title: "긋기 각도",
            icon: "angle",
            destination: .gesture,
            // "진입앵글" — 리뷰에서 실제로 쓰인 표현.
            keywords: ["진입앵글", "앵글", "각도", "방향", "섹터", "오타", "잘못", "인식", "기울"]
        ),
        SettingsEntry(
            title: "긋기 길이",
            icon: "ruler",
            destination: .gesture,
            keywords: ["길이", "짧게", "길게", "거리", "임계", "민감", "인식"]
        ),
        SettingsEntry(
            title: "복합모음 입력 방식",
            icon: "character.textbox",
            destination: .gesture,
            keywords: ["순정", "모아키", "복합모음", "대각선", "확장", "ㅘ", "ㅝ", "와", "워", "ㅐ", "ㅔ", "ㅢ", "애", "에", "의", "왕복"]
        ),
        SettingsEntry(
            title: "멀티스트로크 민감도",
            icon: "scribble.variable",
            destination: .gesture,
            // "빨리 치면 안 나온다" 갈래.
            keywords: ["민감도", "멀티스트로크", "빨리", "속도", "ㅛ", "ㅠ", "ㅢ", "안나옴", "인식안됨"]
        ),
        SettingsEntry(
            title: "긋기 테스트",
            icon: "hand.draw",
            destination: .gestureTest,
            keywords: ["테스트", "연습", "확인", "실시간", "미리보기"]
        ),
        SettingsEntry(
            title: "키보드 높이",
            icon: "arrow.up.and.down",
            destination: .size,
            keywords: ["높이", "크기", "크다", "작다", "세로", "줄이", "키우"]
        ),
        SettingsEntry(
            title: "키보드 전환 (지구본) 키",
            icon: "globe",
            destination: .size,
            // "지구봉" — 리뷰 오타 표기까지 포함해 둔다.
            keywords: ["지구본", "지구봉", "전환", "키보드바꾸", "다른키보드", "영어키보드", "globe"]
        ),
        SettingsEntry(
            title: "좌우 끝 키 폭",
            icon: "arrow.left.and.right",
            destination: .layout,
            keywords: ["폭", "너비", "여백", "좌우", "가로", "넓", "좁"]
        ),
        SettingsEntry(
            title: "키 배치 (레이아웃)",
            icon: "rectangle.3.group",
            destination: .layout,
            keywords: ["레이아웃", "배치", "모던", "클래식", "확장형", "백스페이스위치", "숫자패드"]
        ),
        SettingsEntry(
            title: "모음 키 동작",
            icon: "character.textbox",
            destination: .layout,
            keywords: ["모음키", "모음", "순정", "삼성", "모아키", "천지인", "ㆍ", "아래아", "ㅣ", "ㅡ", "8방향", "스와이프"]
        ),
        SettingsEntry(
            title: "4방향 전용 모드",
            icon: "arrow.up.arrow.down",
            destination: .layout,
            keywords: ["4방향", "사방향", "대각선끄기", "상하좌우", "간단"]
        ),
        SettingsEntry(
            title: "특수문자 키",
            icon: "textformat.123",
            destination: .layout,
            keywords: ["특수문자", "기호", "123", "숫자", "괄호", "슬롯"]
        ),
        SettingsEntry(
            title: "키 힌트 표시",
            icon: "textformat.size.smaller",
            destination: .longPress,
            // "키에 작은 글자가 보인다" 갈래.
            keywords: ["힌트", "작은글자", "글자지우", "숫자표시", "안보이게", "깔끔"]
        ),
        SettingsEntry(
            title: "롱프레스 키 매핑",
            icon: "hand.tap",
            destination: .longPress,
            keywords: ["롱프레스", "길게", "꾹", "보조", "매핑", "팝업"]
        ),
        SettingsEntry(
            // 실기기 실측 D4: "자소"로 검색해도 제목에 그 말이 없어 결과를
            // 지나치기 쉬웠다 — 제목에 자소 단위 삭제를 드러낸다.
            title: "백스페이스 · 자소/단어 삭제",
            icon: "delete.left",
            destination: .backspace,
            keywords: ["백스페이스", "지우기", "삭제", "속도", "단어", "자소", "한자소", "낱자", "받침"]
        ),
        SettingsEntry(
            title: "입력 기록 보드",
            icon: "note.text",
            destination: .debugBoard,
            keywords: ["기록", "보드", "메모", "디버그", "실측", "오타기록", "테스트입력"]
        ),
        SettingsEntry(
            title: "스페이스 드래그 커서 이동",
            icon: "arrow.left.arrow.right",
            destination: .inputBehavior,
            keywords: ["커서", "스페이스", "드래그", "이동", "연속"]
        ),
        SettingsEntry(
            title: "괄호 자동 닫기 · 더블 스페이스 마침표",
            icon: "gearshape",
            destination: .inputBehavior,
            keywords: ["괄호", "자동", "마침표", "더블스페이스", "온점"]
        ),
        SettingsEntry(
            title: "테마 · 색상 · 배경 이미지",
            icon: "paintbrush",
            destination: .appearance,
            keywords: ["테마", "색", "색상", "배경", "이미지", "사진", "다크", "밝기", "투명"]
        ),
        SettingsEntry(
            title: "소리 · 진동",
            icon: "waveform",
            destination: .feedback,
            keywords: ["소리", "사운드", "클릭", "진동", "햅틱", "무음", "끄기"]
        ),
        SettingsEntry(
            title: "단축어",
            icon: "text.badge.plus",
            destination: .abbreviation,
            keywords: ["단축어", "약어", "자동완성", "확장", "등록"]
        ),
    ]

    /// 증상 라우터. 리뷰에서 실제로 관찰된 불만을 그대로 항목화했다.
    static let symptoms: [SettingsSymptom] = [
        SettingsSymptom(
            symptom: "오타가 잦아요",
            remedy: "긋기 각도와 길이를 손에 맞게 조절하세요",
            icon: "exclamationmark.triangle",
            destination: .gesture
        ),
        SettingsSymptom(
            symptom: "‘으’가 ‘워’로, ‘이’가 ‘와’로 바뀌어요",
            remedy: "복합모음 입력 방식을 ‘순정 모아키’로 두세요 (기본값)",
            icon: "character.textbox",
            destination: .gesture
        ),
        SettingsSymptom(
            symptom: "빨리 치면 ㅛ·ㅠ·ㅢ 가 안 나와요",
            remedy: "멀티스트로크 민감도를 올려 보세요",
            icon: "hare",
            destination: .gesture
        ),
        SettingsSymptom(
            symptom: "키에 작은 글자가 보여요",
            remedy: "키 힌트 표시를 끄면 사라집니다",
            icon: "textformat.size.smaller",
            destination: .longPress
        ),
        SettingsSymptom(
            symptom: "다른 키보드로 못 바꾸겠어요",
            remedy: "키보드 전환(지구본) 키를 켜세요",
            icon: "globe",
            destination: .size
        ),
        SettingsSymptom(
            symptom: "키보드가 너무 크거나 작아요",
            remedy: "키보드 높이를 85%~135%로 조절할 수 있습니다",
            icon: "arrow.up.and.down",
            destination: .size
        ),
        SettingsSymptom(
            symptom: "특수문자를 바꾸고 싶어요",
            remedy: "레이아웃에서 특수키 슬롯을 편집하세요",
            icon: "textformat.123",
            destination: .layout
        ),
        SettingsSymptom(
            symptom: "긋기가 잘 되는지 확인하고 싶어요",
            remedy: "긋기 테스트에서 실시간으로 볼 수 있습니다",
            icon: "hand.draw",
            destination: .gestureTest
        ),
    ]

    static func search(_ query: String) -> [SettingsEntry] {
        entries.filter { $0.matches(query) }
    }
}
