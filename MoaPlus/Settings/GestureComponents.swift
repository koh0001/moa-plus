import SwiftUI

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

                HStack {
                    Text("방향 전환 거리 보정")
                    Spacer()
                    Text("\(binding.wrappedValue.directionChangeThresholdDelta, specifier: "%+.0f")pt")
                }
                Slider(value: binding.directionChangeThresholdDelta, in: -5...15, step: 1)
            } header: {
                Text("보정값")
            } footer: {
                Text("'방향 전환 거리 보정'이 클수록 두 번째 방향 stroke 등록이 까다로워집니다. 정수직 ↑로 그었는데 끝부분이 살짝 휘어 ㅘ로 잡힐 때 +값으로 올리세요.")
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

        // Apply the ㅣ/ㅡ deltas exactly the way the recogniser does (per-side,
        // asymmetry-preserving). With deltas 0 this is a no-op, so the mapping /
        // editor pies render the user's per-side widths unchanged.
        let adjusted = sectors.applyingDiagonalDeltas(iDelta: iDelta, euDelta: euDelta)

        return (0..<min(adjusted.count, 8)).map { i in
            let s = adjusted[i]
            // Per-side wedge: CW edge = centre − rightHalfWidth (start),
            // CCW edge = centre + leftHalfWidth (end). Matches recognition.
            return (
                start: s.centerAngle - s.rightHalfWidth + rotationOffset,
                end: s.centerAngle + s.leftHalfWidth + rotationOffset,
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
        // Mirror GestureAnalyzer.effectiveRotationOffset: the global axis
        // rotation applies on top of the per-column rotation, so the column
        // preview shows the same ring the recogniser uses for this column.
        let bases = baseSlices(sectors: profile.sectors, profile: profile,
                               rotationOffset: rotationOffset + profile.axisRotation,
                               iDelta: iDelta, euDelta: euDelta)
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

// MARK: - Sector Angle Hybrid View (per-side widths)

/// Direction selection + per-side width editor. Replaces `SectorAngleView`.
///
/// Interaction model (plan §3): tap a direction in the pie to select it, then
/// adjust its **left/right** recognition widths independently via two drag
/// handles on the selected sector's boundaries *and* two precise sliders.
///
/// - Angle/sign convention matches `GestureDirection.from`: a positive signed
///   angular distance from the sector centre (CCW, increasing angle) is the
///   **left** side → `leftHalfWidth`; negative (CW) is the **right** side →
///   `rightHalfWidth`. Boundaries draw at `centre + leftHalfWidth` (CCW edge)
///   and `centre − rightHalfWidth` (CW edge).
/// - **Phase 1 invariant:** the UI only ever assigns `leftHalfWidth` /
///   `rightHalfWidth` directly. Assigning `halfWidth` would reset both sides to
///   the symmetric base via its `didSet`, so it is never touched here.
struct SectorAngleHybridView: View {
    @ObservedObject private var settings = KeyboardSettings.shared
    @State private var selectedIndex: Int = 0
    @State private var draggingHandle: HandleSide?
    @State private var lastHapticAtLimit = false

    private typealias HandleSide = SectorAngleHybridView_HandleSide

    private static let widthRange: ClosedRange<Double> = 10...40
    private static let defaultHalfWidth: Double = 22.5
    private let selectionHaptic = UISelectionFeedbackGenerator()

    /// → ㅏ blue, ↗ ㅣ cyan, ↑ ㅗ orange, ↖ ㅣ cyan, ← ㅓ red, ↙ ㅡ purple,
    /// ↓ ㅜ green, ↘ ㅡ purple — same order/palette as the other pie charts.
    private static let directionColors: [Color] = [
        DirectionPieChart.vowelColors["ㅏ"]!, DirectionPieChart.vowelColors["ㅣ"]!,
        DirectionPieChart.vowelColors["ㅗ"]!, DirectionPieChart.vowelColors["ㅣ"]!,
        DirectionPieChart.vowelColors["ㅓ"]!, DirectionPieChart.vowelColors["ㅡ"]!,
        DirectionPieChart.vowelColors["ㅜ"]!, DirectionPieChart.vowelColors["ㅡ"]!,
    ]

    private var profile: SwipeProfile { settings.gestureSettings.swipeProfile }
    private var sectors: [DirectionSector] { profile.sectors }
    private var isFourWay: Bool { profile.fourWayMode }
    private var selectedSector: DirectionSector { sectors[selectedIndex] }

    var body: some View {
        List {
            pieSection
            if isFourWay {
                fourWayNoticeSection
            }
            selectedDirectionSection
            globalRotationSection
            resetSection
        }
        .navigationTitle("방향별 좌/우 각도")
    }

    // MARK: Pie (selection + drag)

    private var pieSection: some View {
        Section {
            PerSidePieChart(
                sectors: sectors,
                profile: profile,
                colors: Self.directionColors,
                selectedIndex: selectedIndex,
                draggingHandle: draggingHandle,
                onSelect: { i in
                    guard !isFourWay, i != selectedIndex else { return }
                    selectedIndex = i
                    selectionHaptic.selectionChanged()
                },
                onDrag: { side, angle in handleDrag(side: side, touchAngle: angle) },
                onDragEnded: {
                    draggingHandle = nil
                    lastHapticAtLimit = false
                }
            )
            .frame(height: 240)
            .listRowInsets(EdgeInsets())
            .listRowBackground(Color(.systemBackground))
            .opacity(isFourWay ? 0.4 : 1)
            .disabled(isFourWay)
        } header: {
            Text("인식 범위")
        } footer: {
            Text("방향을 탭해 선택한 뒤, 선택된 방향의 좌/우 경계 손잡이를 끌거나 아래 슬라이더로 폭을 조절합니다. 점선은 기본값(±22.5°)입니다. (미리보기는 폭만 보여주며 전체 회전은 제외됩니다.)")
        }
    }

    private var fourWayNoticeSection: some View {
        Section {
            Text("4방향 전용 모드가 켜져 있어 각도 설정은 적용되지 않습니다. (레이아웃 설정 ‘모던’에서 변경)")
                .font(.footnote)
                .foregroundColor(.secondary)
        }
    }

    // MARK: Selected direction (left/right sliders)

    private var selectedDirectionSection: some View {
        Section {
            HStack {
                Text(directionLabel(selectedIndex))
                    .font(.headline)
                Spacer()
                Text("선택됨")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            widthRow(title: "왼쪽 폭", side: .left)
            widthRow(title: "오른쪽 폭", side: .right)
        } header: {
            Text("선택한 방향")
        } footer: {
            Text("‘왼쪽/오른쪽’은 화면 기준 반시계/시계 방향 경계입니다. 한쪽을 넓히면 그 방향으로 비스듬히 그어도 같은 모음으로 인식됩니다.")
        }
        .disabled(isFourWay)
        .opacity(isFourWay ? 0.4 : 1)
    }

    private func widthRow(title: String, side: HandleSide) -> some View {
        let binding = sideBinding(side)
        let value = binding.wrappedValue
        return VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(title)
                Spacer()
                Text("\(value, specifier: "%.1f")°")
                    .font(.caption)
                    .foregroundColor(atLimit(value) ? .orange : .secondary)
            }
            Slider(value: binding, in: Self.widthRange, step: 0.5)
                .accessibilityLabel("\(directionLabel(selectedIndex)) \(title)")
                .accessibilityValue("\(value, specifier: "%.1f")도")
        }
        .padding(.vertical, 2)
    }

    // MARK: Global rotation

    private var globalRotationSection: some View {
        Section {
            HStack {
                Text("전체 회전")
                Spacer()
                Text("\(profile.axisRotation, specifier: "%+.1f")°")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            Slider(value: axisRotationBinding, in: -20...20, step: 0.5)
                .accessibilityLabel("전체 인식 축 회전")
                .accessibilityValue("\(profile.axisRotation, specifier: "%.1f")도")
        } header: {
            Text("전체 회전")
        } footer: {
            Text("키별 회전 보정과 별개로 전체 인식 축을 돌립니다.")
        }
        .disabled(isFourWay)
        .opacity(isFourWay ? 0.4 : 1)
    }

    // MARK: Reset

    private var resetSection: some View {
        Section {
            Button("이 방향 초기화") {
                var gs = settings.gestureSettings
                gs.swipeProfile.sectors[selectedIndex].halfWidth = Self.defaultHalfWidth
                settings.gestureSettings = gs
            }
            .disabled(isFourWay)

            Button("전체 초기화") {
                var gs = settings.gestureSettings
                gs.swipeProfile.sectors = DirectionSector.defaultSectors
                gs.swipeProfile.axisRotation = 0
                settings.gestureSettings = gs
            }
            .foregroundColor(.red)
            .disabled(isFourWay)
        }
    }

    // MARK: - Drag handling

    /// Convert a touch angle (math degrees) into a per-side width for the
    /// selected sector and write it back, clamped to 10…40°.
    private func handleDrag(side: HandleSide, touchAngle: Double) {
        guard !isFourWay else { return }
        draggingHandle = side
        let centre = selectedSector.centerAngle
        let signed = signedDelta(from: centre, to: touchAngle)
        // Left handle lives on the CCW (+) edge, right handle on the CW (−) edge.
        let raw = side == .left ? signed : -signed
        let clamped = min(max(raw, Self.widthRange.lowerBound), Self.widthRange.upperBound)

        let atEdge = clamped <= Self.widthRange.lowerBound || clamped >= Self.widthRange.upperBound
        if atEdge {
            if !lastHapticAtLimit { selectionHaptic.selectionChanged() }
            lastHapticAtLimit = true
        } else {
            lastHapticAtLimit = false
        }

        sideBinding(side).wrappedValue = clamped
    }

    /// Smallest signed angular distance from `a` to `b` in (−180, 180],
    /// mirroring `GestureDirection.signedAngularDistance`.
    private func signedDelta(from a: Double, to b: Double) -> Double {
        let diff = (b - a).truncatingRemainder(dividingBy: 360)
        if diff > 180 { return diff - 360 }
        if diff <= -180 { return diff + 360 }
        return diff
    }

    // MARK: - Bindings

    private func sideBinding(_ side: HandleSide) -> Binding<Double> {
        Binding(
            get: {
                let s = settings.gestureSettings.swipeProfile.sectors[selectedIndex]
                return side == .left ? s.leftHalfWidth : s.rightHalfWidth
            },
            set: { newValue in
                var gs = settings.gestureSettings
                // Phase 1 invariant: assign the side directly; never halfWidth.
                if side == .left {
                    gs.swipeProfile.sectors[selectedIndex].leftHalfWidth = newValue
                } else {
                    gs.swipeProfile.sectors[selectedIndex].rightHalfWidth = newValue
                }
                settings.gestureSettings = gs
            }
        )
    }

    private var axisRotationBinding: Binding<Double> {
        Binding(
            get: { settings.gestureSettings.swipeProfile.axisRotation },
            set: { newValue in
                var gs = settings.gestureSettings
                gs.swipeProfile.axisRotation = newValue
                settings.gestureSettings = gs
            }
        )
    }

    // MARK: - Helpers

    private func atLimit(_ value: Double) -> Bool {
        value <= Self.widthRange.lowerBound || value >= Self.widthRange.upperBound
    }

    private func directionLabel(_ i: Int) -> String {
        let fixed = ["→ ㅏ", nil, "↑ ㅗ", nil, "← ㅓ", nil, "↓ ㅜ", nil]
        if let f = fixed[i] { return f }
        let symbols = ["→", "↗", "↑", "↖", "←", "↙", "↓", "↘"]
        let mapping: DiagonalMapping
        switch i {
        case 1: mapping = profile.upRightMapping
        case 3: mapping = profile.upLeftMapping
        case 5: mapping = profile.downLeftMapping
        default: mapping = profile.downRightMapping
        }
        return "\(symbols[i]) \(DirectionPieChart.labelForMapping(mapping, symbol: symbols[i]))"
    }
}

// MARK: - Per-side pie chart (selectable + draggable handles)

/// Renders the 8 direction sectors using **per-side** half-widths and exposes
/// tap selection plus two drag handles on the selected sector. Kept private to
/// `SectorAngleHybridView`; the read-only `DirectionPieChart` is unchanged.
private struct PerSidePieChart: View {
    let sectors: [DirectionSector]
    let profile: SwipeProfile
    let colors: [Color]
    let selectedIndex: Int
    let draggingHandle: SectorAngleHybridView_HandleSide?
    let onSelect: (Int) -> Void
    let onDrag: (SectorAngleHybridView_HandleSide, Double) -> Void
    let onDragEnded: () -> Void

    private var count: Int { min(sectors.count, 8) }

    var body: some View {
        GeometryReader { geo in
            let cx = geo.size.width / 2
            let cy = geo.size.height / 2
            let radius = min(geo.size.width, geo.size.height) / 2 - 28
            let centre = CGPoint(x: cx, y: cy)

            ZStack {
                Canvas { ctx, _ in
                    for i in 0..<count {
                        let s = sectors[i]
                        // CCW edge = centre + leftHalfWidth; CW edge = centre − rightHalfWidth.
                        let startDeg = s.centerAngle - s.rightHalfWidth
                        let endDeg = s.centerAngle + s.leftHalfWidth
                        let path = wedgePath(cx: cx, cy: cy, radius: radius,
                                             fromDeg: startDeg, toDeg: endDeg)
                        let isSel = i == selectedIndex
                        ctx.fill(path, with: .color(colors[i].opacity(isSel ? 0.85 : 0.28)))
                        ctx.stroke(path, with: .color(colors[i].opacity(isSel ? 0.9 : 0.45)),
                                   lineWidth: isSel ? 2 : 0.5)
                    }

                    // Default ±22.5° dotted reference on the selected sector.
                    if selectedIndex < count {
                        let c = sectors[selectedIndex].centerAngle
                        for edge in [c - 22.5, c + 22.5] {
                            var line = Path()
                            line.move(to: centre)
                            line.addLine(to: point(cx: cx, cy: cy, radius: radius, deg: edge))
                            ctx.stroke(line, with: .color(Color(.label).opacity(0.45)),
                                       style: StrokeStyle(lineWidth: 1, dash: [3, 3]))
                        }
                    }

                    let dot = CGRect(x: cx - 3, y: cy - 3, width: 6, height: 6)
                    ctx.fill(Ellipse().path(in: dot), with: .color(Color(.label)))
                }

                // Tap-selectable labels per direction.
                ForEach(0..<count, id: \.self) { i in
                    let mid = sectors[i].centerAngle
                    let lp = point(cx: cx, cy: cy, radius: radius * 0.66, deg: mid)
                    Text(label(at: i))
                        .font(.system(size: 13, weight: .heavy))
                        .foregroundColor(Color(.label))
                        .padding(6)
                        .contentShape(Rectangle())
                        .position(x: lp.x, y: lp.y)
                        .onTapGesture { onSelect(i) }
                        .accessibilityElement(children: .ignore)
                        .accessibilityLabel(accessibilityLabel(i))
                        .accessibilityValue(accessibilityValue(i))
                        .accessibilityAddTraits(i == selectedIndex ? [.isSelected, .isButton] : .isButton)
                }

                // Drag handles on the selected sector's two boundaries.
                if selectedIndex < count {
                    let s = sectors[selectedIndex]
                    handle(side: .left,
                           deg: s.centerAngle + s.leftHalfWidth,
                           cx: cx, cy: cy, radius: radius, centre: centre)
                    handle(side: .right,
                           deg: s.centerAngle - s.rightHalfWidth,
                           cx: cx, cy: cy, radius: radius, centre: centre)
                }
            }
        }
    }

    // MARK: Handles

    @ViewBuilder
    private func handle(side: SectorAngleHybridView_HandleSide,
                        deg: Double, cx: CGFloat, cy: CGFloat,
                        radius: CGFloat, centre: CGPoint) -> some View {
        let p = point(cx: cx, cy: cy, radius: radius, deg: deg)
        let active = draggingHandle == side
        Circle()
            .fill(Color.accentColor)
            .frame(width: active ? 26 : 18, height: active ? 26 : 18)
            .overlay(Circle().stroke(Color.white, lineWidth: 2))
            .shadow(radius: active ? 4 : 1)
            // 44pt minimum touch target regardless of visual size.
            .frame(width: 44, height: 44)
            .contentShape(Circle())
            .position(x: p.x, y: p.y)
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { value in
                        let angle = mathAngle(of: value.location, centre: centre)
                        onDrag(side, angle)
                    }
                    .onEnded { _ in onDragEnded() }
            )
            .accessibilityHidden(true)  // sliders carry the adjustable path
    }

    /// Math angle (0°=right, CCW positive) of a screen point about the centre.
    private func mathAngle(of pt: CGPoint, centre: CGPoint) -> Double {
        let dx = Double(pt.x - centre.x)
        let dy = Double(pt.y - centre.y)
        // Screen y is down; negate to convert to math convention.
        return atan2(-dy, dx) * 180 / .pi
    }

    // MARK: Geometry helpers

    private func point(cx: CGFloat, cy: CGFloat, radius: CGFloat, deg: Double) -> CGPoint {
        CGPoint(x: cx + radius * cos(deg * .pi / 180),
                y: cy - radius * sin(deg * .pi / 180))
    }

    private func wedgePath(cx: CGFloat, cy: CGFloat, radius: CGFloat,
                           fromDeg: Double, toDeg: Double) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: cx, y: cy))
        let steps = 28
        for step in 0...steps {
            let t = Double(step) / Double(steps)
            let a = (fromDeg + (toDeg - fromDeg) * t) * .pi / 180
            path.addLine(to: CGPoint(x: cx + radius * cos(a), y: cy - radius * sin(a)))
        }
        path.closeSubpath()
        return path
    }

    // MARK: Labels

    private func label(at i: Int) -> String {
        let fixed = ["ㅏ", nil, "ㅗ", nil, "ㅓ", nil, "ㅜ", nil]
        if let f = fixed[i] { return f }
        return diagonalLabel(at: i)
    }

    private func diagonalLabel(at i: Int) -> String {
        let symbols = ["→", "↗", "↑", "↖", "←", "↙", "↓", "↘"]
        let mapping: DiagonalMapping
        switch i {
        case 1: mapping = profile.upRightMapping
        case 3: mapping = profile.upLeftMapping
        case 5: mapping = profile.downLeftMapping
        default: mapping = profile.downRightMapping
        }
        return DirectionPieChart.labelForMapping(mapping, symbol: symbols[i])
    }

    private func accessibilityLabel(_ i: Int) -> String {
        let symbols = ["오른쪽", "오른쪽 위", "위", "왼쪽 위", "왼쪽", "왼쪽 아래", "아래", "오른쪽 아래"]
        return "\(symbols[i]) 방향, \(label(at: i))"
    }

    private func accessibilityValue(_ i: Int) -> String {
        let s = sectors[i]
        return "왼쪽 폭 \(String(format: "%.1f", s.leftHalfWidth))도, 오른쪽 폭 \(String(format: "%.1f", s.rightHalfWidth))도"
    }
}

/// File-scoped so both `SectorAngleHybridView` and the private `PerSidePieChart`
/// (same file) can reference it, without leaking a symbol into the app module.
fileprivate enum SectorAngleHybridView_HandleSide { case left, right }
