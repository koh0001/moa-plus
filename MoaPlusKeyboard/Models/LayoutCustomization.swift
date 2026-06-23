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
    /// iPad 가로 분리 레이아웃에서 숫자패드 위치. 아이폰/세로에선 무시.
    var numberPadSide: NumberPadSide = .left

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
        let raw = try c.decodeIfPresent([String].self, forKey: .slotC) ?? Self.defaultSlotC
        slotC = Self.normalizeSlotC(raw)
        koreanPunctuationEnabled = try c.decodeIfPresent(Bool.self, forKey: .koreanPunctuationEnabled) ?? true
        englishPunctuationEnabled = try c.decodeIfPresent(Bool.self, forKey: .englishPunctuationEnabled) ?? false
        slotARightColumnTopAsPunctuation = try c.decodeIfPresent(Bool.self, forKey: .slotARightColumnTopAsPunctuation) ?? false
        koreanPunctuationSlots = try c.decodeIfPresent(PunctuationSlots.self, forKey: .koreanPunctuationSlots) ?? .defaultKorean
        englishPunctuationSlots = try c.decodeIfPresent(PunctuationSlots.self, forKey: .englishPunctuationSlots) ?? .defaultEnglish
        slotARightColumnPunctuationSlots = try c.decodeIfPresent(PunctuationSlots.self, forKey: .slotARightColumnPunctuationSlots) ?? .defaultKorean
        numberPadSide = try c.decodeIfPresent(NumberPadSide.self, forKey: .numberPadSide) ?? .left
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
        case slotA, slotABackspaceSwap, slotARightColumn, slotB, slotC
        case koreanPunctuationEnabled, englishPunctuationEnabled, slotARightColumnTopAsPunctuation
        case koreanPunctuationSlots, englishPunctuationSlots, slotARightColumnPunctuationSlots
        case numberPadSide
    }
}
