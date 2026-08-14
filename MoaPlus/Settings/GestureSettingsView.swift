import SwiftUI

/// Unified screen for all swipe-gesture related settings.
/// Aggregates the previously scattered sections of InputSettingsView:
///   - swipe angle preset
///   - swipe length
///   - direction mapping
///   - per-column correction
/// Plus a live "real-time test" entry point.
struct GestureSettingsView: View {
    @ObservedObject private var settings = KeyboardSettings.shared

    private func profileBinding<T>(_ keyPath: WritableKeyPath<SwipeProfile, T>) -> Binding<T> {
        Binding(
            get: { settings.gestureSettings.swipeProfile[keyPath: keyPath] },
            set: { newValue in
                var gs = settings.gestureSettings
                gs.swipeProfile[keyPath: keyPath] = newValue
                settings.gestureSettings = gs
            }
        )
    }

    /// 멀티스트로크 모음 turn 민감도(GestureSettings 직속, 0~2) 바인딩.
    private var sensitivityBinding: Binding<Int> {
        Binding(
            get: { settings.gestureSettings.multiStrokeTurnSensitivity },
            set: { newValue in
                var gs = settings.gestureSettings
                gs.multiStrokeTurnSensitivity = newValue
                settings.gestureSettings = gs
            }
        )
    }

    var body: some View {
        List {
            // Real-time gesture test (placed first for discoverability)
            Section {
                NavigationLink(destination: GestureTestView()) {
                    Label("긋기 실시간 테스트", systemImage: "scribble.variable")
                }
            } header: {
                Text("실시간 테스트")
            } footer: {
                Text("실제 긋기가 어떤 방향/모음으로 인식되는지 손가락으로 직접 그어 확인할 수 있습니다.")
            }

            // 자음 대각선 진입 파생 (순정 모아키 vs 확장)
            Section {
                // 실기기 실측 D4: .inline 피커의 라벨 행("복합모음 입력")이 옵션
                // 행과 같은 모양으로 렌더돼 세 번째 선택지처럼 오인됐다 — 라벨을
                // 숨기고 섹션 헤더가 그 역할을 대신한다.
                Picker("복합모음 입력 방식", selection: $settings.consonantDiagonalDerivationEnabled) {
                    Text("순정 모아키").tag(false)
                    Text("확장 (대각선 진입)").tag(true)
                }
                .pickerStyle(.inline)
                .labelsHidden()
            } header: {
                Text("복합모음 입력 방식")
            } footer: {
                Text(settings.consonantDiagonalDerivationEnabled
                     ? "자음을 대각선(↗↖ = ㅣ / ↙↘ = ㅡ)으로 그은 뒤 이어서 그으면 천지인 방식으로 복합모음이 만들어집니다. 순정에 없는 확장 기능이라, 긋기 끝의 작은 흔들림이 '으'를 '워'로 바꾸는 오타가 생길 수 있습니다."
                     : "순정 모아키와 동일하게 동작합니다. 대각선은 ㅣ/ㅡ 그 자체이고, 복합모음은 방향 조합으로 만듭니다 (ㅘ = 위→오른쪽, ㅝ = 아래→왼쪽). 대각선 왕복도 순정처럼 지원합니다 (↗↙ = ㅐ, ↖↘ = ㅔ, ↙↗ = ㅢ).")
            }

            // Swipe Angle preset
            Section {
                Picker("프리셋", selection: profileBinding(\.mode)) {
                    Text("오른손용").tag(SwipeMode.right)
                    Text("왼손용").tag(SwipeMode.left)
                    Text("양손용").tag(SwipeMode.both)
                    Text("직접 설정").tag(SwipeMode.custom)
                }
                .pickerStyle(.inline)
                .disabled(isFourWay)
            } header: {
                Text("긋기 각도")
            } footer: {
                Text(swipeModeDescription)
            }

            // Swipe Length
            Section {
                Picker("길이", selection: profileBinding(\.swipeLength)) {
                    ForEach(SwipeLength.allCases, id: \.self) { length in
                        Text(length.displayName).tag(length)
                    }
                }
                .pickerStyle(.segmented)
            } header: {
                Text("긋기 길이")
            } footer: {
                Text(swipeLengthDescription)
            }

            // Multi-stroke turn sensitivity (T4)
            Section {
                Picker("민감도", selection: sensitivityBinding) {
                    Text("끔").tag(0)
                    Text("보통").tag(1)
                    Text("민감").tag(2)
                }
                .pickerStyle(.segmented)
            } header: {
                Text("멀티스트로크 모음 (ㅛ ㅑ ㅕ 등)")
            } footer: {
                VStack(alignment: .leading, spacing: 8) {
                    Text("ㅛ·ㅑ·ㅕ 같은 모음은 자음 키에서 방향을 두 번 꺾어 입력합니다. 예: ㅛ = 위 → 아래 → 위")
                        .fixedSize(horizontal: false, vertical: true)
                    Label {
                        Text("**끔** — 처음 위치로 정확히 되돌아와야 인식 (오인식 적음, 기존 방식)")
                    } icon: { Image(systemName: "lock.fill").foregroundColor(.secondary) }
                    Label {
                        Text("**보통 / 민감** — 끝까지 돌아오지 않고 방향만 살짝 바꿔도 인식. 빠르지만 ㅗ·ㅜ·ㅏ·ㅓ를 그을 때 손이 떨리면 ㅚ·ㅛ·ㅐ·ㅑ로 잘못 입력될 수 있음")
                    } icon: { Image(systemName: "bolt.fill").foregroundColor(.secondary) }
                }
                .font(.footnote)
            }

            // Direction mapping
            Section {
                NavigationLink(destination: DirectionMappingView()) {
                    HStack {
                        Text("방향별 모음 매핑")
                        Spacer()
                        Text(mappingSummary)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                NavigationLink(destination: SectorAngleHybridView()) {
                    HStack {
                        Text("방향별 좌/우 각도")
                        Spacer()
                        Text(settings.gestureSettings.swipeProfile.mode == .custom ? "커스텀" : "프리셋")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            } header: {
                Text("방향 설정")
            } footer: {
                Text("각 방향이 어떤 모음을 입력하는지, 인식 범위를 얼마나 넓힐지 조정합니다.")
            }
            .disabled(isFourWay)

            // Column correction (advanced)
            Section {
                ForEach(0..<5, id: \.self) { index in
                    let columnId = index + 1
                    NavigationLink(destination: ColumnCorrectionDetailView(columnId: columnId)) {
                        HStack {
                            Text("\(columnId)열")
                                .font(.headline)
                            Spacer()
                            Text(columnKeysLabel(for: columnId))
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                }
            } header: {
                Text("세로 라인별 제스처 보정")
            } footer: {
                Text("고급 설정: 끝열에서 바깥쪽 긋기가 잘 안 되는 경우 보정값을 조정할 수 있습니다.")
            }
            // Gesture preview toggle
            Section {
                Toggle("제스처 미리보기", isOn: $settings.showGesturePreview)
            } footer: {
                Text("입력 시 긋기 방향과 예측 모음을 화면에 표시합니다.")
            }
        }
        .navigationTitle("긋기 입력 설정")
    }

    private var isFourWay: Bool {
        settings.gestureSettings.swipeProfile.fourWayMode
    }

    private var mappingSummary: String {
        let p = settings.gestureSettings.swipeProfile
        return "↖\(p.upLeftMapping.displayName) ↗\(p.upRightMapping.displayName)"
    }

    private var swipeModeDescription: String {
        if isFourWay {
            return "4방향 전용 모드가 켜져 있어 각도·방향 설정은 적용되지 않습니다. (레이아웃 설정 ‘모던’에서 변경)"
        }
        switch settings.gestureSettings.swipeProfile.mode {
        case .right: return "오른손 위주 사용 습관에 맞는 프리셋"
        case .left: return "왼손 위주 사용 습관에 맞는 프리셋"
        case .both: return "좌우 균형형 45도 프리셋"
        case .custom: return "세부 각도를 직접 조정합니다"
        }
    }

    private var swipeLengthDescription: String {
        switch settings.gestureSettings.swipeProfile.swipeLength {
        case .short: return "조금만 움직여도 긋기로 인식됩니다. 빠르지만 오입력이 있을 수 있습니다."
        case .normal: return "기본 설정입니다."
        case .long: return "더 크게 움직여야 긋기로 인식됩니다. 안정적이지만 다소 둔할 수 있습니다."
        }
    }

    private func columnKeysLabel(for columnId: Int) -> String {
        switch columnId {
        case 1: return "ㅃ / ㅂ / ㅁ / ㅋ"
        case 2: return "ㅉ / ㅈ / ㄴ / ㅌ"
        case 3: return "ㄸ / ㄷ / ㅇ / ㅊ"
        case 4: return "ㄲ / ㄱ / ㄹ / ㅍ"
        case 5: return "ㅆ / ㅅ / ㅎ"
        default: return ""
        }
    }
}
