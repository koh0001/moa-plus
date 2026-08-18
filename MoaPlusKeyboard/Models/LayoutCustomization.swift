import Foundation

/// 긋기 펑크 키의 5개 슬롯 (탭 + 4방향). 빈 문자열("")은 비활성을 의미.
struct PunctuationSlots: Codable, Equatable {
    var tap: String
    var left: String
    var right: String
    var up: String
    var down: String

    static let defaultKorean = PunctuationSlots(
        tap: ".", left: "?", right: "!", up: ",", down: "."
    )
    static let defaultEnglish = PunctuationSlots(
        tap: ".", left: "?", right: "!", up: ",", down: "."
    )
}

enum SlotAPreset: String, Codable, CaseIterable {
    case vowel        // A1 — 모음 (기본, 1.3)
    case classic11    // A2 — 1.1 특수문자
    case fullPackage  // A3 — Classic 기반 + col 6 에 모음/특수 키 + 긴 스페이스
}

enum SlotBPreset: String, Codable, CaseIterable {
    case punctuation  // B2 — 특수문자 (기본, 1.3)
    case vowelKey     // B1 — 자음드래그 패턴 모음 키
}

/// 모음 키(`ㅣㆍㅡ / 모음`)를 눌렀을 때의 동작. `SlotBPreset` 과 분리된 별도
/// 필드인 이유: 확장형(`.fullPackage`)은 `slotB` 값과 무관하게 모음 키를 그리드
/// col 6 row 1 에 임베드한다(`KeyboardMetrics.koreanLayout`). 프리셋 케이스로
/// 넣으면 확장형에서는 선택 자체가 도달하지 못한다.
enum VowelKeyBehavior: String, Codable, CaseIterable {
    /// 기본 — tap = ㆍ, 8방향 + 멀티스트로크(자음 키와 동일한 파이프라인).
    /// 한 번의 긋기로 ㅏ~ㅞ 까지 전부 나온다.
    case gestureMulti
    /// 순정/삼성 모아키 방식 (이슈 #25) — tap = ㆍ, ← = ㅣ, → = ㅡ.
    /// 나머지 모음은 천지인 합성(`HangulComposer.combineVowels`)으로 쌓아 만든다.
    /// 순정은 키 위에 `ㅣ · ㅡ` 3칸 팝업을 띄우고 손가락이 놓인 칸을 고르게 하는데,
    /// 그 선택 기하가 곧 "가로 변위로 3분할"이라 판정은 좌우 순변위만 본다
    /// (위/아래로 그어도 가운데 칸 = ㆍ).
    case cheonjiin

    var displayName: String {
        switch self {
        case .gestureMulti: return "긋기 모음 (8방향)"
        case .cheonjiin:    return "순정 모아키 방식"
        }
    }

    /// 설정 화면의 한 줄 설명. 키 하나의 동작을 그대로 적는다.
    var shortDescription: String {
        switch self {
        case .gestureMulti: return "탭=ㆍ + 8방향 긋기로 모음 한 번에"
        case .cheonjiin:    return "탭=ㆍ ←=ㅣ →=ㅡ (천지인 조합)"
        }
    }
}

enum NumberPadSide: String, Codable, CaseIterable {
    case left   // 좌=숫자패드 (기본)
    case right  // 우=숫자패드
}

struct LayoutCustomization: Codable, Equatable {
    var slotA: SlotAPreset = .vowel
    /// A1 일 때 백스페이스 ↔ ㆍ 위치 swap. A2 일 때 무시.
    var slotABackspaceSwap: Bool = false
    /// A2 (classic11) col 6 row 0/1/2 셀 매핑. A1 일 때 무시.
    /// 기본값 ["!", "?", "."] — 모음/특수문자/일반 문자 모두 가능 (1~4 자).
    var slotARightColumn: [String] = LayoutCustomization.defaultSlotARightColumn
    var slotB: SlotBPreset = .punctuation
    /// 모음 키 동작. 스페이스 옆 모음 키(B1)와 확장형 우측 컬럼 임베드 모음 키
    /// 양쪽에 공통 적용된다. 기본은 기존 동작(8방향) 유지 — 이미 모음 키를 쓰던
    /// 사용자의 손버릇을 업데이트가 깨면 안 된다.
    var vowelKeyBehavior: VowelKeyBehavior = .gestureMulti
    var slotC: [String] = LayoutCustomization.defaultSlotC

    // MARK: - Punctuation key (v1.5)

    /// 한글 자판 function row의 긋기 펑크 키 활성화. 기본 ON (기존 동작 유지).
    var koreanPunctuationEnabled: Bool = true
    /// 영문 자판 function row의 긋기 펑크 키 활성화. 기본 OFF — ON 시 스페이스 폭이 줄어듦.
    var englishPunctuationEnabled: Bool = false
    /// A1 (vowel) 프리셋 우측 col 6 row 0 (`#` 자리)을 긋기 펑크 키로 교체. 한글 슬롯 데이터 공유.
    var slotARightColumnTopAsPunctuation: Bool = false
    /// 한글 모드 슬롯 B(스페이스바 옆 / 확장형 col 6 임베드) 펑크 키 슬롯.
    var koreanPunctuationSlots: PunctuationSlots = .defaultKorean
    /// 영문 모드 펑크 키 슬롯.
    var englishPunctuationSlots: PunctuationSlots = .defaultEnglish
    /// 한글 모드 우측 컬럼 row 0 펑크 옵션(모던 #자리 / 확장형 1번 셀) 전용 슬롯.
    /// 슬롯 B 슬롯과 독립적으로 편집됨.
    var slotARightColumnPunctuationSlots: PunctuationSlots = .defaultKorean
    /// iPad 분리 레이아웃에서 숫자패드 위치(왼쪽/오른쪽). 가로·세로 분리에 공통
    /// 적용. 아이폰에선 무시.
    var numberPadSide: NumberPadSide = .left
    /// iPad 세로에서도 숫자패드 분리(확장) 레이아웃을 쓸지. 기본 OFF(세로=단일
    /// 확대 그리드). 가로는 이 값과 무관하게 항상 분리. 아이폰에선 무시.
    var iPadPortraitSplitEnabled: Bool = false

    static let defaultSlotC: [String] = ["~", "^", ";", "*"]
    static let defaultSlotARightColumn: [String] = ["!", "?", "."]

    init() {}
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        slotA = try c.decodeIfPresent(SlotAPreset.self, forKey: .slotA) ?? .vowel
        slotABackspaceSwap = try c.decodeIfPresent(Bool.self, forKey: .slotABackspaceSwap) ?? false
        let rawRight = try c.decodeIfPresent([String].self, forKey: .slotARightColumn) ?? Self.defaultSlotARightColumn
        slotARightColumn = Self.normalizeSlotARightColumn(rawRight)
        slotB = try c.decodeIfPresent(SlotBPreset.self, forKey: .slotB) ?? .punctuation
        vowelKeyBehavior = try c.decodeIfPresent(VowelKeyBehavior.self, forKey: .vowelKeyBehavior) ?? .gestureMulti
        let raw = try c.decodeIfPresent([String].self, forKey: .slotC) ?? Self.defaultSlotC
        slotC = Self.normalizeSlotC(raw)
        koreanPunctuationEnabled = try c.decodeIfPresent(Bool.self, forKey: .koreanPunctuationEnabled) ?? true
        englishPunctuationEnabled = try c.decodeIfPresent(Bool.self, forKey: .englishPunctuationEnabled) ?? false
        slotARightColumnTopAsPunctuation = try c.decodeIfPresent(Bool.self, forKey: .slotARightColumnTopAsPunctuation) ?? false
        koreanPunctuationSlots = try c.decodeIfPresent(PunctuationSlots.self, forKey: .koreanPunctuationSlots) ?? .defaultKorean
        englishPunctuationSlots = try c.decodeIfPresent(PunctuationSlots.self, forKey: .englishPunctuationSlots) ?? .defaultEnglish
        slotARightColumnPunctuationSlots = try c.decodeIfPresent(PunctuationSlots.self, forKey: .slotARightColumnPunctuationSlots) ?? .defaultKorean
        numberPadSide = try c.decodeIfPresent(NumberPadSide.self, forKey: .numberPadSide) ?? .left
        iPadPortraitSplitEnabled = try c.decodeIfPresent(Bool.self, forKey: .iPadPortraitSplitEnabled) ?? false
    }

    private static func normalizeSlotC(_ raw: [String]) -> [String] {
        var result = raw.prefix(4).map { $0.isEmpty ? " " : $0 }
        while result.count < 4 { result.append(defaultSlotC[result.count]) }
        return Array(result)
    }

    private static func normalizeSlotARightColumn(_ raw: [String]) -> [String] {
        var result = raw.prefix(3).map { $0.isEmpty ? " " : $0 }
        while result.count < 3 { result.append(defaultSlotARightColumn[result.count]) }
        return Array(result)
    }

    private enum CodingKeys: String, CodingKey {
        case slotA, slotABackspaceSwap, slotARightColumn, slotB, vowelKeyBehavior, slotC
        case koreanPunctuationEnabled, englishPunctuationEnabled, slotARightColumnTopAsPunctuation
        case koreanPunctuationSlots, englishPunctuationSlots, slotARightColumnPunctuationSlots
        case numberPadSide
        case iPadPortraitSplitEnabled
    }
}
