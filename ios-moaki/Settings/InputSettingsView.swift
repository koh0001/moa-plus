//
//  InputSettingsView.swift
//  ios-moaki
//

import SwiftUI

struct InputSettingsView: View {
    @ObservedObject private var settings = KeyboardSettings.shared

    var body: some View {
        List {
            // Swipe Angle Section
            Section(header: Text("긋기 각도")) {
                Picker("프리셋", selection: $settings.gestureSettings.swipeProfile.mode) {
                    Text("오른손용").tag(SwipeMode.right)
                    Text("왼손용").tag(SwipeMode.left)
                    Text("양손용").tag(SwipeMode.both)
                    Text("직접 설정").tag(SwipeMode.custom)
                }
                .pickerStyle(.inline)
            } footer: {
                Text(swipeModeDescription)
            }

            // Swipe Length Section
            Section(header: Text("긋기 길이")) {
                Picker("길이", selection: $settings.gestureSettings.swipeProfile.swipeLength) {
                    ForEach(SwipeLength.allCases, id: \.self) { length in
                        Text(length.displayName).tag(length)
                    }
                }
                .pickerStyle(.segmented)
            } footer: {
                Text(swipeLengthDescription)
            }

            // Column Correction Section (Advanced)
            Section(header: Text("세로 라인별 제스처 보정")) {
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
            } footer: {
                Text("고급 설정: 끝열에서 바깥쪽 긋기가 잘 안 되는 경우 보정값을 조정할 수 있습니다.")
            }

            // Debug
            Section {
                Toggle("제스처 미리보기", isOn: $settings.showGesturePreview)
            } footer: {
                Text("입력 시 긋기 방향과 예측 모음을 화면에 표시합니다.")
            }
        }
        .navigationTitle("모아키 입력")
    }

    private var swipeModeDescription: String {
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

/// Detail view for per-column gesture correction
struct ColumnCorrectionDetailView: View {
    let columnId: Int
    @ObservedObject private var settings = KeyboardSettings.shared

    private var binding: Binding<ColumnGestureOverride> {
        Binding(
            get: {
                settings.gestureSettings.columnOverrides.first(where: { $0.columnId == columnId })
                    ?? ColumnGestureOverride(columnId: columnId)
            },
            set: { newValue in
                if let index = settings.gestureSettings.columnOverrides.firstIndex(where: { $0.columnId == columnId }) {
                    settings.gestureSettings.columnOverrides[index] = newValue
                }
            }
        )
    }

    var body: some View {
        List {
            Section(header: Text("보정값")) {
                HStack {
                    Text("회전 보정")
                    Spacer()
                    Text("\(binding.wrappedValue.rotationOffsetDeg, specifier: "%.1f")°")
                }
                Slider(value: binding.rotationOffsetDeg, in: -15...15, step: 0.5)

                HStack {
                    Text("ㅣ 인식 폭 보정")
                    Spacer()
                    Text("\(binding.wrappedValue.verticalIWidthDelta, specifier: "%.1f")°")
                }
                Slider(value: binding.verticalIWidthDelta, in: 0...10, step: 0.5)

                HStack {
                    Text("ㅡ 인식 폭 보정")
                    Spacer()
                    Text("\(binding.wrappedValue.horizontalEuWidthDelta, specifier: "%.1f")°")
                }
                Slider(value: binding.horizontalEuWidthDelta, in: 0...10, step: 0.5)
            }

            if columnId == 1 || columnId == 5 {
                Section(header: Text("바깥쪽 긋기")) {
                    HStack {
                        Text("민감도")
                        Spacer()
                        Text("\(binding.wrappedValue.outwardDistanceMultiplier, specifier: "%.2f")x")
                    }
                    Slider(value: binding.outwardDistanceMultiplier, in: 0.5...1.5, step: 0.05)
                } footer: {
                    Text("값이 낮을수록 바깥쪽 긋기를 더 쉽게 인식합니다.")
                }
            }

            Section {
                Button("이 열만 기본값으로 복원") {
                    if let defaultOverride = ColumnGestureOverride.defaults.first(where: { $0.columnId == columnId }),
                       let index = settings.gestureSettings.columnOverrides.firstIndex(where: { $0.columnId == columnId }) {
                        settings.gestureSettings.columnOverrides[index] = defaultOverride
                    }
                }
                .foregroundColor(.red)
            }
        }
        .navigationTitle("\(columnId)열 보정")
    }
}
