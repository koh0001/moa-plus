import SwiftUI

struct InputSettingsView: View {
    @ObservedObject private var settings = KeyboardSettings.shared

    var body: some View {
        List {
            // Swipe Angle Section
            Section {
                Picker("프리셋", selection: $settings.gestureSettings.swipeProfile.mode) {
                    Text("오른손용").tag(SwipeMode.right)
                    Text("왼손용").tag(SwipeMode.left)
                    Text("양손용").tag(SwipeMode.both)
                    Text("직접 설정").tag(SwipeMode.custom)
                }
                .pickerStyle(.inline)
            } header: {
                Text("긋기 각도")
            } footer: {
                Text(swipeModeDescription)
            }

            // Swipe Length Section
            Section {
                Picker("길이", selection: $settings.gestureSettings.swipeProfile.swipeLength) {
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

            // Direction Mapping Section
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
                NavigationLink(destination: SectorAngleView()) {
                    HStack {
                        Text("방향별 각도 범위")
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

            // Column Correction Section (Advanced)
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

            // Side key width
            Section {
                HStack {
                    Text("좌우 특수키 크기")
                    Spacer()
                    Text("\(Int(settings.sideKeyWidthRatio * 100))%")
                        .foregroundColor(.secondary)
                }
                Slider(value: $settings.sideKeyWidthRatio, in: 0.15...0.5, step: 0.05)
            } header: {
                Text("레이아웃")
            } footer: {
                Text("좌우 끝 기호키의 너비를 조절합니다. 기본값: 35%")
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

    private var mappingSummary: String {
        let p = settings.gestureSettings.swipeProfile
        return "↖\(p.upLeftMapping.displayName) ↗\(p.upRightMapping.displayName)"
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

// MARK: - Column Correction Detail

struct ColumnCorrectionDetailView: View {
    let columnId: Int
    @ObservedObject private var settings = KeyboardSettings.shared

    private var override: ColumnGestureOverride {
        settings.gestureSettings.columnOverrides.first(where: { $0.columnId == columnId })
            ?? ColumnGestureOverride(columnId: columnId)
    }

    private var binding: Binding<ColumnGestureOverride> {
        Binding(
            get: { override },
            set: { newValue in
                if let index = settings.gestureSettings.columnOverrides.firstIndex(where: { $0.columnId == columnId }) {
                    settings.gestureSettings.columnOverrides[index] = newValue
                }
            }
        )
    }

    var body: some View {
        List {
            // Visualization
            Section {
                GestureAngleVisualization(
                    rotationOffset: override.rotationOffsetDeg,
                    verticalIWidthDelta: override.verticalIWidthDelta,
                    horizontalEuWidthDelta: override.horizontalEuWidthDelta
                )
                .frame(height: 200)
                .listRowInsets(EdgeInsets())
                .listRowBackground(Color(.systemGroupedBackground))
            } header: {
                Text("방향 인식 영역")
            } footer: {
                Text("원 안의 색상 영역이 각 모음의 인식 범위입니다. 슬라이더를 조정하면 실시간으로 변합니다.")
            }

            // Sliders
            Section {
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
            } header: {
                Text("보정값")
            }

            if columnId == 1 || columnId == 5 {
                Section {
                    HStack {
                        Text("민감도")
                        Spacer()
                        Text("\(binding.wrappedValue.outwardDistanceMultiplier, specifier: "%.2f")x")
                    }
                    Slider(value: binding.outwardDistanceMultiplier, in: 0.5...1.5, step: 0.05)
                } header: {
                    Text("바깥쪽 긋기")
                } footer: {
                    Text("값이 낮을수록 바깥쪽 긋기를 더 쉽게 인식합니다.")
                }
            }

            // Key list
            Section {
                HStack(spacing: 12) {
                    ForEach(columnKeys, id: \.self) { key in
                        Text(key)
                            .font(.title2)
                            .frame(width: 40, height: 40)
                            .background(Color(.systemGray5))
                            .cornerRadius(8)
                    }
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 4)
            } header: {
                Text("이 열의 자음 키")
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

    private var columnKeys: [String] {
        switch columnId {
        case 1: return ["ㅃ", "ㅂ", "ㅁ", "ㅋ"]
        case 2: return ["ㅉ", "ㅈ", "ㄴ", "ㅌ"]
        case 3: return ["ㄸ", "ㄷ", "ㅇ", "ㅊ"]
        case 4: return ["ㄲ", "ㄱ", "ㄹ", "ㅍ"]
        case 5: return ["ㅆ", "ㅅ", "ㅎ"]
        default: return []
        }
    }
}

// MARK: - Gesture Angle Visualization

struct GestureAngleVisualization: View {
    let rotationOffset: Double
    let verticalIWidthDelta: Double
    let horizontalEuWidthDelta: Double

    // Base sector size: 45° each for 8 directions
    private let baseSector: Double = 45.0

    var body: some View {
        GeometryReader { geo in
            let center = CGPoint(x: geo.size.width / 2, y: geo.size.height / 2)
            let radius = min(geo.size.width, geo.size.height) / 2 - 20

            ZStack {
                // Background circle
                Circle()
                    .fill(Color(.systemGray6))
                    .frame(width: radius * 2, height: radius * 2)

                // Direction sectors
                ForEach(sectors, id: \.label) { sector in
                    SectorShape(
                        startAngle: .degrees(sector.startAngle),
                        endAngle: .degrees(sector.endAngle)
                    )
                    .fill(sector.color.opacity(0.3))
                    .frame(width: radius * 2, height: radius * 2)

                    SectorShape(
                        startAngle: .degrees(sector.startAngle),
                        endAngle: .degrees(sector.endAngle)
                    )
                    .stroke(sector.color.opacity(0.6), lineWidth: 1)
                    .frame(width: radius * 2, height: radius * 2)
                }

                // Direction labels
                ForEach(sectors, id: \.label) { sector in
                    let midAngle = (sector.startAngle + sector.endAngle) / 2
                    let labelRadius = radius * 0.7
                    let x = center.x + labelRadius * cos(midAngle * .pi / 180)
                    let y = center.y + labelRadius * sin(midAngle * .pi / 180)

                    Text(sector.label)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(sector.color)
                        .position(x: x, y: y)
                }

                // Center dot
                Circle()
                    .fill(Color(.label))
                    .frame(width: 6, height: 6)

                // Rotation offset indicator
                if abs(rotationOffset) > 0.1 {
                    let arrowAngle = -90.0 + rotationOffset
                    let arrowX = center.x + (radius + 12) * cos(arrowAngle * .pi / 180)
                    let arrowY = center.y + (radius + 12) * sin(arrowAngle * .pi / 180)
                    Text("↻ \(rotationOffset, specifier: "%.1f")°")
                        .font(.system(size: 10))
                        .foregroundColor(.orange)
                        .position(x: arrowX, y: arrowY)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }

    // 8 direction sectors with rotation and width adjustments applied
    private var sectors: [SectorInfo] {
        let rot = rotationOffset
        let iDelta = verticalIWidthDelta
        let euDelta = horizontalEuWidthDelta

        // Angles in screen coordinates (0° = right, clockwise)
        // Base: each 45° centered on cardinal/diagonal directions
        return [
            // → ㅏ (0°)
            SectorInfo(label: "ㅏ", startAngle: -22.5 + rot, endAngle: 22.5 + rot, color: .blue),
            // ↘ ㅡ (45°) — widened by euDelta
            SectorInfo(label: "ㅡ", startAngle: 22.5 + rot - euDelta/2, endAngle: 67.5 + rot + euDelta/2, color: .purple),
            // ↓ ㅜ (90°)
            SectorInfo(label: "ㅜ", startAngle: 67.5 + rot, endAngle: 112.5 + rot, color: .green),
            // ↙ → ↓ 정규화 (135°)
            SectorInfo(label: "↙↓", startAngle: 112.5 + rot, endAngle: 157.5 + rot, color: .green.opacity(0.5)),
            // ← ㅓ (180°)
            SectorInfo(label: "ㅓ", startAngle: 157.5 + rot, endAngle: 202.5 + rot, color: .red),
            // ↖ → ↑ 정규화 (225°)
            SectorInfo(label: "↖↑", startAngle: 202.5 + rot, endAngle: 247.5 + rot, color: .orange.opacity(0.5)),
            // ↑ ㅗ (270°)
            SectorInfo(label: "ㅗ", startAngle: 247.5 + rot, endAngle: 292.5 + rot, color: .orange),
            // ↗ ㅣ (315°) — widened by iDelta
            SectorInfo(label: "ㅣ", startAngle: 292.5 + rot - iDelta/2, endAngle: 337.5 + rot + iDelta/2, color: .cyan),
        ]
    }
}

private struct SectorInfo {
    let label: String
    let startAngle: Double
    let endAngle: Double
    let color: Color
}

private struct SectorShape: Shape {
    let startAngle: Angle
    let endAngle: Angle

    func path(in rect: CGRect) -> Path {
        let center = CGPoint(x: rect.midX, y: rect.midY)
        let radius = min(rect.width, rect.height) / 2
        var path = Path()
        path.move(to: center)
        path.addArc(center: center, radius: radius, startAngle: startAngle, endAngle: endAngle, clockwise: false)
        path.closeSubpath()
        return path
    }
}

// MARK: - Direction Mapping View

struct DirectionMappingView: View {
    @ObservedObject private var settings = KeyboardSettings.shared

    var body: some View {
        List {
            // Visual overview
            Section {
                DirectionMappingDiagram(profile: settings.gestureSettings.swipeProfile)
                    .frame(height: 180)
                    .listRowInsets(EdgeInsets())
                    .listRowBackground(Color(.systemGroupedBackground))
            } header: {
                Text("현재 매핑")
            }

            // Cardinal directions (fixed)
            Section {
                directionRow("→", "ㅏ", fixed: true)
                directionRow("←", "ㅓ", fixed: true)
                directionRow("↑", "ㅗ", fixed: true)
                directionRow("↓", "ㅜ", fixed: true)
            } header: {
                Text("기본 방향 (고정)")
            } footer: {
                Text("상하좌우 기본 방향의 모음은 변경할 수 없습니다.")
            }

            // Diagonal directions (customizable)
            Section {
                Picker("↖ 왼쪽 위", selection: $settings.gestureSettings.swipeProfile.upLeftMapping) {
                    ForEach(DiagonalMapping.allCases, id: \.self) { mapping in
                        Text(mapping.displayName).tag(mapping)
                    }
                }

                Picker("↗ 오른쪽 위", selection: $settings.gestureSettings.swipeProfile.upRightMapping) {
                    ForEach(DiagonalMapping.allCases, id: \.self) { mapping in
                        Text(mapping.displayName).tag(mapping)
                    }
                }

                Picker("↙ 왼쪽 아래", selection: $settings.gestureSettings.swipeProfile.downLeftMapping) {
                    ForEach(DiagonalMapping.allCases, id: \.self) { mapping in
                        Text(mapping.displayName).tag(mapping)
                    }
                }

                Picker("↘ 오른쪽 아래", selection: $settings.gestureSettings.swipeProfile.downRightMapping) {
                    ForEach(DiagonalMapping.allCases, id: \.self) { mapping in
                        Text(mapping.displayName).tag(mapping)
                    }
                }
            } header: {
                Text("대각선 방향 (커스텀)")
            } footer: {
                Text("대각선 방향에 매핑할 모음을 선택하세요. 기본값: ↖↗=ㅣ, ↙↘=ㅡ")
            }

            Section {
                Button("기본값으로 복원") {
                    settings.gestureSettings.swipeProfile.upLeftMapping = .vowelI
                    settings.gestureSettings.swipeProfile.upRightMapping = .vowelI
                    settings.gestureSettings.swipeProfile.downLeftMapping = .vowelEu
                    settings.gestureSettings.swipeProfile.downRightMapping = .vowelEu
                }
                .foregroundColor(.red)
            }
        }
        .navigationTitle("방향별 모음 매핑")
    }

    private func directionRow(_ symbol: String, _ vowel: String, fixed: Bool) -> some View {
        HStack {
            Text(symbol)
                .font(.title2)
                .frame(width: 30)
            Text("→")
                .foregroundColor(.secondary)
            Text(vowel)
                .font(.title3)
            Spacer()
            if fixed {
                Text("고정")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
    }
}

// MARK: - Direction Mapping Diagram

private struct DirectionMappingDiagram: View {
    let profile: SwipeProfile

    private let colors: [Color] = [.blue, .cyan, .orange, .cyan, .red, .purple, .green, .purple]

    var body: some View {
        GeometryReader { geo in
            let center = CGPoint(x: geo.size.width / 2, y: geo.size.height / 2)
            let radius: CGFloat = min(geo.size.width, geo.size.height) / 2 - 24

            ZStack {
                // Background circle
                Circle()
                    .fill(Color(.systemGray6))
                    .frame(width: radius * 2, height: radius * 2)

                // Concentric guide circles
                ForEach([0.33, 0.66, 1.0], id: \.self) { ratio in
                    Circle()
                        .stroke(Color(.separator).opacity(0.3), lineWidth: 0.5)
                        .frame(width: radius * 2 * ratio, height: radius * 2 * ratio)
                }

                // 8 angle divider lines
                ForEach(0..<8, id: \.self) { i in
                    let angle = Double(i) * 45.0 + 22.5 // between sectors
                    let rad = angle * .pi / 180
                    Path { path in
                        path.move(to: center)
                        path.addLine(to: CGPoint(
                            x: center.x + radius * cos(rad),
                            y: center.y - radius * sin(rad)
                        ))
                    }
                    .stroke(Color(.separator).opacity(0.25), lineWidth: 0.5)
                }

                // Colored sector fills
                ForEach(0..<8, id: \.self) { i in
                    let startAngle = Double(i) * 45.0 - 22.5
                    let endAngle = startAngle + 45.0
                    SectorShape(
                        startAngle: .degrees(-endAngle),
                        endAngle: .degrees(-startAngle)
                    )
                    .fill(colors[i].opacity(0.15))
                    .frame(width: radius * 2, height: radius * 2)
                }

                // Direction labels
                ForEach(0..<8, id: \.self) { i in
                    let angle = Double(i) * 45.0
                    let label = directionLabel(index: i)
                    let r = radius * 0.72
                    let rad = angle * .pi / 180

                    Text(label)
                        .font(.system(size: 15, weight: .bold))
                        .foregroundColor(colors[i])
                        .position(
                            x: center.x + r * cos(rad),
                            y: center.y - r * sin(rad)
                        )
                }

                // Direction symbols (small, near edge)
                ForEach(0..<8, id: \.self) { i in
                    let angle = Double(i) * 45.0
                    let symbol = ["→", "↗", "↑", "↖", "←", "↙", "↓", "↘"][i]
                    let r = radius * 0.42
                    let rad = angle * .pi / 180

                    Text(symbol)
                        .font(.system(size: 10))
                        .foregroundColor(Color(.secondaryLabel))
                        .position(
                            x: center.x + r * cos(rad),
                            y: center.y - r * sin(rad)
                        )
                }

                // Center dot
                Circle()
                    .fill(Color(.label))
                    .frame(width: 6, height: 6)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }

    private func directionLabel(index: Int) -> String {
        switch index {
        case 0: return "ㅏ"
        case 1: return mappingLabel(profile.upRightMapping, fallback: "↗")
        case 2: return "ㅗ"
        case 3: return mappingLabel(profile.upLeftMapping, fallback: "↖")
        case 4: return "ㅓ"
        case 5: return mappingLabel(profile.downLeftMapping, fallback: "↙")
        case 6: return "ㅜ"
        case 7: return mappingLabel(profile.downRightMapping, fallback: "↘")
        default: return ""
        }
    }

    private func mappingLabel(_ mapping: DiagonalMapping, fallback: String) -> String {
        switch mapping {
        case .vowelI: return "ㅣ"
        case .vowelEu: return "ㅡ"
        case .vowelO: return "ㅗ"
        case .vowelU: return "ㅜ"
        case .vowelA: return "ㅏ"
        case .vowelEo: return "ㅓ"
        case .normalizeUp: return "→ㅗ"
        case .normalizeDown: return "→ㅜ"
        case .normalizeLeft: return "→ㅓ"
        case .normalizeRight: return "→ㅏ"
        case .disabled: return "✕"
        }
    }

    private func directionColor(index: Int) -> Color {
        switch index {
        case 0: return .blue       // →
        case 1: return .cyan       // ↗
        case 2: return .orange     // ↑
        case 3: return .cyan       // ↖
        case 4: return .red        // ←
        case 5: return .purple     // ↙
        case 6: return .green      // ↓
        case 7: return .purple     // ↘
        default: return .gray
        }
    }
}

// MARK: - Sector Angle View

struct SectorAngleView: View {
    @ObservedObject private var settings = KeyboardSettings.shared

    var body: some View {
        List {
            // Visualization
            Section {
                SectorAngleDiagram(sectors: settings.gestureSettings.swipeProfile.sectors)
                    .frame(height: 200)
                    .listRowInsets(EdgeInsets())
                    .listRowBackground(Color(.systemGroupedBackground))
            } header: {
                Text("인식 범위 미리보기")
            }

            // Per-direction angle width
            Section {
                ForEach(0..<8, id: \.self) { i in
                    let label = DirectionSector.directionLabels[i]
                    VStack(alignment: .leading, spacing: 4) {
                        HStack {
                            Text(label)
                                .font(.headline)
                            Spacer()
                            Text("±\(settings.gestureSettings.swipeProfile.sectors[i].halfWidth, specifier: "%.1f")°")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        Slider(
                            value: $settings.gestureSettings.swipeProfile.sectors[i].halfWidth,
                            in: 10...40,
                            step: 0.5
                        )
                    }
                    .padding(.vertical, 2)
                }
            } header: {
                Text("방향별 인식 폭")
            } footer: {
                Text("각 방향의 인식 범위 폭을 조정합니다. 기본값: ±22.5° (총 45°). 넓힐수록 해당 방향을 더 쉽게 인식합니다.")
            }

            Section {
                Button("기본값으로 복원 (45° 균등)") {
                    settings.gestureSettings.swipeProfile.sectors = DirectionSector.defaultSectors
                }
                .foregroundColor(.red)
            }
        }
        .navigationTitle("방향별 각도 범위")
    }
}

// MARK: - Sector Angle Diagram

private struct SectorAngleDiagram: View {
    let sectors: [DirectionSector]

    private let colors: [Color] = [.blue, .cyan, .orange, .cyan, .red, .purple, .green, .purple]

    var body: some View {
        GeometryReader { geo in
            let radius = min(geo.size.width, geo.size.height) / 2 - 20

            ZStack {
                Circle()
                    .fill(Color(.systemGray6))
                    .frame(width: radius * 2, height: radius * 2)

                ForEach(0..<sectors.count, id: \.self) { i in
                    let sector = sectors[i]
                    // Convert from math angles (0=right, CCW) to screen angles (0=right, CW)
                    let startScreen = -sector.endAngle
                    let endScreen = -sector.startAngle

                    SectorShape(
                        startAngle: .degrees(startScreen),
                        endAngle: .degrees(endScreen)
                    )
                    .fill(colors[i].opacity(0.25))
                    .frame(width: radius * 2, height: radius * 2)

                    SectorShape(
                        startAngle: .degrees(startScreen),
                        endAngle: .degrees(endScreen)
                    )
                    .stroke(colors[i].opacity(0.5), lineWidth: 1)
                    .frame(width: radius * 2, height: radius * 2)
                }

                // Labels
                ForEach(0..<sectors.count, id: \.self) { i in
                    let angle = sectors[i].centerAngle
                    let r = radius * 0.7
                    let rad = angle * .pi / 180

                    Text(DirectionSector.directionSymbols[i])
                        .font(.system(size: 13, weight: .bold))
                        .foregroundColor(colors[i])
                        .position(
                            x: geo.size.width / 2 + r * cos(rad),
                            y: geo.size.height / 2 - r * sin(rad)
                        )
                }

                Circle()
                    .fill(Color(.label))
                    .frame(width: 6, height: 6)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }
}
