import CoreGraphics

/// 한손 모드 — 키보드를 좁혀 한쪽으로 붙인다 (앱스토어 리뷰 2026-09-24 "한손모드가 있을까요?").
///
/// 이름을 "왼손/오른손" 이 아니라 **위치**로 붙인 이유: 긋기 프리셋에 이미 "오른손용/왼손용/양손용"
/// 이 있어 사용자들이 헷갈린다(이슈 #31 제보자가 "양손용" 긋기 모드를 "양손모아키" 로 부름).
///
/// 아이폰 세로 화면에서만 적용된다. 아이패드·가로 화면은 폭이 넉넉해 항상 전체 폭.
/// `.center` 는 좌우 여백 (앱스토어 리뷰 2026-10 "가로 양 옆 여백을 기본 설정값으로") — 띠 버튼 없이
/// 양옆을 비우므로 내림 키는 기능행에 남는다.
enum KeyboardPlacement: String, Codable, CaseIterable {
    case full
    case left
    case center
    case right

    var displayName: String {
        switch self {
        case .full:  return "전체"
        case .left:  return "왼쪽"
        case .center: return "가운데"
        case .right: return "오른쪽"
        }
    }

    /// 좁힌 키보드 폭 비율 범위. 하한 0.70 = 375pt 기기 + 지구본 표시에서도 기능행
    /// 스페이스바가 남는 선 (`OneHandedLayoutTests` 가드).
    static let widthRatioRange: ClosedRange<Double> = 0.70...0.90
    static let defaultWidthRatio: Double = 0.82
    /// 가운데(좌우 여백)의 폭 범위. 띠가 없어 내림 키가 기능행에 남으므로 하한이 더 높다 — 375pt × 0.70 에
    /// 지구본·내림 키를 얹으면 스페이스바가 키 한 칸보다 좁아진다 (`OneHandedLayoutTests` 가드).
    static let centerWidthRatioRange: ClosedRange<Double> = 0.80...0.96

    /// 이 배치의 폭 비율 범위 (설정 슬라이더와 실제 폭이 같이 쓴다). 저장값 하나를 공유한다.
    var widthRatioBounds: ClosedRange<Double> {
        self == .center ? Self.centerWidthRatioRange : Self.widthRatioRange
    }

    /// 실제로 좁힐지. 꺼져 있거나, 아이패드거나, 가로 화면이면 nil(전체 폭).
    func effectiveSide(isPad: Bool, isLandscape: Bool) -> KeyboardPlacement? {
        guard self != .full, !isPad, !isLandscape else { return nil }
        return self
    }

    /// 좁힌 키보드 폭. 비율은 범위 밖 저장값도 잘라서 쓴다.
    static func keyboardWidth(totalWidth: CGFloat, ratio: Double,
                              range: ClosedRange<Double> = widthRatioRange) -> CGFloat {
        let clamped = min(max(ratio, range.lowerBound), range.upperBound)
        return (totalWidth * CGFloat(clamped)).rounded(.down)
    }
}
