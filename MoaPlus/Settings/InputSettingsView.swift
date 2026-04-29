import SwiftUI

struct InputSettingsView: View {
    @ObservedObject private var settings = KeyboardSettings.shared

    var body: some View {
        List {
            // Unified gesture settings entry
            Section {
                NavigationLink(destination: GestureSettingsView()) {
                    HStack {
                        Label("긋기 입력 설정", systemImage: "hand.draw")
                        Spacer()
                        Text(gestureSummary)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            } header: {
                Text("제스처")
            } footer: {
                Text("긋기 각도/길이/방향 매핑/열별 보정과 실시간 테스트가 한 곳에 모여 있습니다.")
            }

            // Side key width
            Section {
                HStack {
                    Text("좌우 특수키 크기")
                    Spacer()
                    Text("\(Int(settings.sideKeyWidthRatio * 100))%")
                        .foregroundColor(.secondary)
                }
                Slider(value: $settings.sideKeyWidthRatio, in: 0.15...1.0, step: 0.05)
            } header: {
                Text("레이아웃")
            } footer: {
                Text("좌우 끝 기호키의 너비를 조절합니다. 기본값: 70% (정사각 키)")
            }

            // Cursor control
            Section {
                Toggle("스페이스 드래그로 커서 이동", isOn: $settings.cursorMoveBySpaceDragEnabled)
            } header: {
                Text("커서 제어")
            } footer: {
                Text("스페이스바를 길게 누른 채 드래그하면 커서가 좌우로 이동합니다.")
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

    private var gestureSummary: String {
        let p = settings.gestureSettings.swipeProfile
        let mode: String = {
            switch p.mode {
            case .right: return "오른손"
            case .left: return "왼손"
            case .both: return "양손"
            case .custom: return "커스텀"
            }
        }()
        return "\(mode) · \(p.swipeLength.displayName)"
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
                    // Force full struct reassignment to trigger @Published didSet
                    var gs = settings.gestureSettings
                    gs.columnOverrides[index] = newValue
                    settings.gestureSettings = gs
                }
            }
        )
    }

    var body: some View {
        List {
            // Visualization
            Section {
                DirectionPieChart(
                    slices: DirectionPieChart.columnCorrectionSlices(
                        settings: settings,
                        rotationOffset: override.rotationOffsetDeg,
                        iDelta: override.verticalIWidthDelta,
                        euDelta: override.horizontalEuWidthDelta
                    ),
                    rotationLabel: abs(override.rotationOffsetDeg) > 0.1 ? "↻\(String(format: "%.1f", override.rotationOffsetDeg))°" : nil
                )
                .frame(height: 200)
                .listRowInsets(EdgeInsets())
                .listRowBackground(Color(.systemBackground))

                // Column keys shown below the chart
                HStack(spacing: 10) {
                    ForEach(columnKeys, id: \.self) { key in
                        Text(key)
                            .font(.title3)
                            .frame(width: 36, height: 36)
                            .background(Color(.systemGray5))
                            .cornerRadius(8)
                    }
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 4)
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


            Section {
                Button("이 열만 기본값으로 복원") {
                    if let defaultOverride = ColumnGestureOverride.defaults.first(where: { $0.columnId == columnId }),
                       let index = settings.gestureSettings.columnOverrides.firstIndex(where: { $0.columnId == columnId }) {
                        // Force full struct reassignment to trigger @Published didSet
                        var gs = settings.gestureSettings
                        gs.columnOverrides[index] = defaultOverride
                        settings.gestureSettings = gs
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

// MARK: - Unified Pie Chart Component

/// Unified pie chart for all gesture direction visualizations.
/// Pass 8 slices as (startDeg, endDeg) in math coords (0°=right, CCW).
/// The chart handles coordinate conversion internally.
struct DirectionPieChart: View {
    let slices: [PieSlice]
    var rotationLabel: String? = nil

    struct PieSlice {
        let mathStart: Double  // degrees, math coords (0°=right, CCW)
        let mathEnd: Double
        let label: String
        let color: Color
    }

    // Unified color palette
    static let vowelColors: [String: Color] = [
        "ㅏ": Color(red: 0.70, green: 0.82, blue: 1.0),   // light blue
        "ㅓ": Color(red: 1.0,  green: 0.75, blue: 0.75),   // light red/pink
        "ㅗ": Color(red: 1.0,  green: 0.85, blue: 0.65),   // light orange
        "ㅜ": Color(red: 0.70, green: 0.92, blue: 0.78),   // light green
        "ㅣ": Color(red: 0.72, green: 0.92, blue: 0.98),   // light cyan
        "ㅡ": Color(red: 0.85, green: 0.78, blue: 0.95),   // light purple
        "✕":  Color(.systemGray4),
    ]

    static func colorForMapping(_ mapping: DiagonalMapping) -> Color {
        switch mapping {
        case .vowelI:  return vowelColors["ㅣ"]!
        case .vowelEu: return vowelColors["ㅡ"]!
        case .vowelO:  return vowelColors["ㅗ"]!
        case .vowelU:  return vowelColors["ㅜ"]!
        case .vowelA:  return vowelColors["ㅏ"]!
        case .vowelEo: return vowelColors["ㅓ"]!
        case .normalizeUp:    return vowelColors["ㅗ"]!.opacity(0.5)
        case .normalizeDown:  return vowelColors["ㅜ"]!.opacity(0.5)
        case .normalizeLeft:  return vowelColors["ㅓ"]!.opacity(0.5)
        case .normalizeRight: return vowelColors["ㅏ"]!.opacity(0.5)
        case .disabled: return .gray
        }
    }

    static func labelForMapping(_ mapping: DiagonalMapping, symbol: String) -> String {
        switch mapping {
        case .vowelI:  return "ㅣ"
        case .vowelEu: return "ㅡ"
        case .vowelO:  return "ㅗ"
        case .vowelU:  return "ㅜ"
        case .vowelA:  return "ㅏ"
        case .vowelEo: return "ㅓ"
        case .normalizeUp:    return "\(symbol)→ㅗ"
        case .normalizeDown:  return "\(symbol)→ㅜ"
        case .normalizeLeft:  return "\(symbol)→ㅓ"
        case .normalizeRight: return "\(symbol)→ㅏ"
        case .disabled: return "✕"
        }
    }

    var body: some View {
        GeometryReader { geo in
            let cx = geo.size.width / 2
            let cy = geo.size.height / 2
            let radius = min(geo.size.width, geo.size.height) / 2 - 20

            // Canvas draws pie slices — single pass, no overlap
            Canvas { context, _ in
                let center = CGPoint(x: cx, y: cy)

                // Pie slices (no background — sectors fill the entire circle)
                // Math coords: 0°=right, CCW (90°=up)
                // Screen coords: 0°=right, CW (90°=down)
                // To draw a math sector [A, B] on screen:
                //   screen coords = negate: [-A, -B]
                //   But SwiftUI addArc goes from start→end in CW direction
                //   Sector from -B to -A going CW = the small arc
                for s in slices {
                    // Convert math angles to screen by drawing with Path manually
                    // This avoids all clockwise/CCW confusion
                    let startRad = -s.mathStart * .pi / 180  // negate for screen Y-flip
                    let endRad = -s.mathEnd * .pi / 180

                    var path = Path()
                    path.move(to: center)
                    // Draw arc point by point to guarantee correct direction
                    let steps = 30
                    for step in 0...steps {
                        let t = Double(step) / Double(steps)
                        let angle = startRad + (endRad - startRad) * t
                        let px = cx + radius * cos(angle)
                        let py = cy + radius * sin(angle)
                        path.addLine(to: CGPoint(x: px, y: py))
                    }
                    path.closeSubpath()
                    context.fill(path, with: .color(s.color))
                    context.stroke(path, with: .color(s.color.opacity(0.5)), lineWidth: 0.5)
                }

                // Center dot
                let dot = CGRect(x: cx - 3, y: cy - 3, width: 6, height: 6)
                context.fill(Ellipse().path(in: dot), with: .color(Color(.label)))
            }

            // Labels (SwiftUI Text for crisp rendering)
            ForEach(0..<slices.count, id: \.self) { i in
                let s = slices[i]
                let mid = (s.mathStart + s.mathEnd) / 2
                let r = radius * 0.65
                Text(s.label)
                    .font(.system(size: 13, weight: .heavy))
                    .foregroundColor(Color(.label))
                    .position(
                        x: cx + r * cos(mid * .pi / 180),
                        y: cy - r * sin(mid * .pi / 180)
                    )
            }

            // Rotation label
            if let rot = rotationLabel {
                Text(rot)
                    .font(.system(size: 9))
                    .foregroundColor(DirectionPieChart.vowelColors["ㅗ"]!)
                    .position(x: cx, y: cy - radius - 12)
            }
        }
    }
}

// MARK: - Pie Chart Builders (convenience)

extension DirectionPieChart {
    // Shared helper: build base slices from DirectionSector start/end angles
    // All 3 builders use this to ensure no overlap/gap
    private static func baseSlices(
        sectors: [DirectionSector],
        profile: SwipeProfile,
        rotationOffset: Double = 0,
        iDelta: Double = 0,
        euDelta: Double = 0
    ) -> [(start: Double, end: Double, mapping: DiagonalMapping, symbol: String)] {
        let mappings: [DiagonalMapping] = [
            .vowelA, profile.upRightMapping, .vowelO, profile.upLeftMapping,
            .vowelEo, profile.downLeftMapping, .vowelU, profile.downRightMapping
        ]
        let symbols = ["→", "↗", "↑", "↖", "←", "↙", "↓", "↘"]

        return (0..<min(sectors.count, 8)).map { i in
            var s = sectors[i]
            // Apply ㅣ/ㅡ delta to diagonal sectors
            switch i {
            case 1, 3: s.halfWidth += iDelta   // ↗, ↖
            case 5, 7: s.halfWidth += euDelta   // ↙, ↘
            default: break
            }
            return (
                start: s.startAngle + rotationOffset,
                end: s.endAngle + rotationOffset,
                mapping: mappings[i],
                symbol: symbols[i]
            )
        }
    }

    // Unified color palette for all 8 directions (same order as DirectionSector)
    // → ㅏ blue, ↗ ㅣ cyan, ↑ ㅗ orange, ↖ ㅣ cyan, ← ㅓ red, ↙ ㅡ purple, ↓ ㅜ green, ↘ ㅡ purple
    private static let directionColors: [Color] = [
        vowelColors["ㅏ"]!, vowelColors["ㅣ"]!, vowelColors["ㅗ"]!, vowelColors["ㅣ"]!,
        vowelColors["ㅓ"]!, vowelColors["ㅡ"]!, vowelColors["ㅜ"]!, vowelColors["ㅡ"]!,
    ]

    /// Column correction view — shows rotation + ㅣ/ㅡ delta
    static func columnCorrectionSlices(
        settings: KeyboardSettings,
        rotationOffset: Double,
        iDelta: Double,
        euDelta: Double
    ) -> [PieSlice] {
        let profile = settings.gestureSettings.swipeProfile
        let bases = baseSlices(sectors: profile.sectors, profile: profile,
                               rotationOffset: rotationOffset, iDelta: iDelta, euDelta: euDelta)
        let fixedLabels = ["ㅏ", nil, "ㅗ", nil, "ㅓ", nil, "ㅜ", nil]

        return bases.enumerated().map { i, b in
            PieSlice(
                mathStart: b.start, mathEnd: b.end,
                label: fixedLabels[i] ?? labelForMapping(b.mapping, symbol: b.symbol),
                color: directionColors[i]
            )
        }
    }

    /// Direction mapping overview — no rotation/delta, shows current mappings
    static func mappingSlices(profile: SwipeProfile) -> [PieSlice] {
        let bases = baseSlices(sectors: profile.sectors, profile: profile)
        let fixedLabels = ["ㅏ", nil, "ㅗ", nil, "ㅓ", nil, "ㅜ", nil]

        return bases.enumerated().map { i, b in
            PieSlice(
                mathStart: b.start, mathEnd: b.end,
                label: fixedLabels[i] ?? labelForMapping(b.mapping, symbol: b.symbol),
                color: directionColors[i]
            )
        }
    }

    /// Sector angle editor — shows direction symbols
    static func sectorAngleSlices(sectors: [DirectionSector], profile: SwipeProfile) -> [PieSlice] {
        let mappings: [DiagonalMapping] = [
            .vowelA, profile.upRightMapping, .vowelO, profile.upLeftMapping,
            .vowelEo, profile.downLeftMapping, .vowelU, profile.downRightMapping
        ]
        let symbols = ["→", "↗", "↑", "↖", "←", "↙", "↓", "↘"]
        let fixedLabels = ["ㅏ", nil, "ㅗ", nil, "ㅓ", nil, "ㅜ", nil]

        return (0..<min(sectors.count, 8)).map { i in
            let label = fixedLabels[i] ?? labelForMapping(mappings[i], symbol: symbols[i])
            return PieSlice(
                mathStart: sectors[i].startAngle,
                mathEnd: sectors[i].endAngle,
                label: label,
                color: directionColors[i]
            )
        }
    }
}

// MARK: - Direction Mapping View

struct DirectionMappingView: View {
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

    var body: some View {
        List {
            // Visual overview
            Section {
                DirectionPieChart(slices: DirectionPieChart.mappingSlices(profile: settings.gestureSettings.swipeProfile))
                    .frame(height: 180)
                    .listRowInsets(EdgeInsets())
                    .listRowBackground(Color(.systemBackground))
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
                Picker("↖ 왼쪽 위", selection: profileBinding(\.upLeftMapping)) {
                    ForEach(DiagonalMapping.allCases, id: \.self) { mapping in
                        Text(mapping.displayName).tag(mapping)
                    }
                }

                Picker("↗ 오른쪽 위", selection: profileBinding(\.upRightMapping)) {
                    ForEach(DiagonalMapping.allCases, id: \.self) { mapping in
                        Text(mapping.displayName).tag(mapping)
                    }
                }

                Picker("↙ 왼쪽 아래", selection: profileBinding(\.downLeftMapping)) {
                    ForEach(DiagonalMapping.allCases, id: \.self) { mapping in
                        Text(mapping.displayName).tag(mapping)
                    }
                }

                Picker("↘ 오른쪽 아래", selection: profileBinding(\.downRightMapping)) {
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
                    var gs = settings.gestureSettings
                    gs.swipeProfile.upLeftMapping = .vowelI
                    gs.swipeProfile.upRightMapping = .vowelI
                    gs.swipeProfile.downLeftMapping = .vowelEu
                    gs.swipeProfile.downRightMapping = .vowelEu
                    settings.gestureSettings = gs
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

// DirectionMappingDiagram removed — replaced by DirectionPieChart

// MARK: - Sector Angle View

struct SectorAngleView: View {
    @ObservedObject private var settings = KeyboardSettings.shared

    var body: some View {
        List {
            // Visualization
            Section {
                DirectionPieChart(slices: DirectionPieChart.sectorAngleSlices(sectors: settings.gestureSettings.swipeProfile.sectors, profile: settings.gestureSettings.swipeProfile))
                    .frame(height: 200)
                    .listRowInsets(EdgeInsets())
                    .listRowBackground(Color(.systemBackground))
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
                            value: sectorBinding(i),
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
                    var gs = settings.gestureSettings
                    gs.swipeProfile.sectors = DirectionSector.defaultSectors
                    settings.gestureSettings = gs
                }
                .foregroundColor(.red)
            }
        }
        .navigationTitle("방향별 각도 범위")
    }

    private func sectorBinding(_ index: Int) -> Binding<Double> {
        Binding(
            get: { settings.gestureSettings.swipeProfile.sectors[index].halfWidth },
            set: { newValue in
                var gs = settings.gestureSettings
                gs.swipeProfile.sectors[index].halfWidth = newValue
                settings.gestureSettings = gs
            }
        )
    }
}

// MARK: - Sector Angle Diagram

// SectorAngleDiagram removed — replaced by DirectionPieChart

// SectorShape removed — DirectionPieChart uses Canvas directly
