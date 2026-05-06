import SwiftUI
import Combine

// MARK: - ViewModel

/// Encapsulates all mutable state and engine instances for GestureTestView.
///
/// Backed by `GestureAnalyzer` and `VowelResolver` from the production keyboard
/// engine.  Re-configures automatically when `KeyboardSettings.shared` changes
/// (via Combine) or when `selectedColumn` is mutated.
final class GestureTestModel: ObservableObject {
    // MARK: Published state

    @Published var selectedColumn: Int = 3
    @Published var points: [CGPoint] = []
    @Published var startPoint: CGPoint?
    @Published var canvasSize: CGSize = .zero

    // Live (in-flight) state.
    @Published var liveDirections: [GestureDirection] = []
    @Published var liveVowel: Jungseong?
    @Published var liveDirectionIndex: Int?

    // Final (post-release) state.
    @Published var finalDirections: [GestureDirection] = []
    @Published var finalVowel: Jungseong?

    // MARK: Engine

    private let analyzer = GestureAnalyzer()
    private let resolver = VowelResolver()

    // MARK: Settings observation

    private let settings = KeyboardSettings.shared
    private var cancellables: Set<AnyCancellable> = []

    init() {
        configureEngine()

        // Re-configure when any KeyboardSettings @Published property fires.
        settings.objectWillChange
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in self?.configureEngine() }
            .store(in: &cancellables)

        // Re-configure when the selected column changes.
        $selectedColumn
            .dropFirst()                // skip initial value (already handled in init)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.reset()
                self?.configureEngine()
            }
            .store(in: &cancellables)
    }

    // MARK: Engine configuration

    func configureEngine() {
        let s = settings.gestureSettings
        analyzer.settings = s
        analyzer.columnId = selectedColumn
        analyzer.keyWidth = deviceCenterKeyWidth
        resolver.swipeProfile = s.swipeProfile
    }

    // MARK: Computed values from settings

    var rotationOffset: Double {
        settings.gestureSettings.effectiveRotationOffset(forColumn: selectedColumn)
    }

    var iDelta: Double {
        settings.gestureSettings.verticalIWidthDelta(forColumn: selectedColumn)
    }

    var euDelta: Double {
        settings.gestureSettings.horizontalEuWidthDelta(forColumn: selectedColumn)
    }

    /// Center-key width on the current device — used to keep the test
    /// view's threshold preview honest about what the actual keyboard
    /// will apply at the user's screen size.
    var deviceCenterKeyWidth: CGFloat {
        KeyboardMetrics.centerKeyWidth(for: UIScreen.main.bounds.width)
    }

    var effectiveThreshold: CGFloat {
        settings.gestureSettings.effectiveSwipeThreshold(
            forColumn: selectedColumn,
            keyWidth: deviceCenterKeyWidth
        )
    }

    var sectors: [DirectionSector] {
        settings.gestureSettings.swipeProfile.sectors
    }

    var swipeProfile: SwipeProfile {
        settings.gestureSettings.swipeProfile
    }

    // MARK: Drag handling

    func onDragChanged(_ value: DragGesture.Value) {
        if startPoint == nil {
            startPoint = value.startLocation
            points = [value.startLocation]
            analyzer.reset()
            analyzer.addPoint(value.startLocation)
            finalDirections = []
            finalVowel = nil
        }
        analyzer.addPoint(value.location)
        points.append(value.location)

        liveDirections = analyzer.getDirections()
        liveVowel = resolver.peekVowel(directions: liveDirections)
        liveDirectionIndex = liveDirections.last.flatMap { Self.sectorIndex[$0] }
    }

    func onDragEnded() {
        let normalized = analyzer.finalizeGesture()
        finalDirections = normalized
        let resolution = resolver.resolve(directions: normalized)
        finalVowel = resolution.vowel ?? liveVowel
    }

    func reset() {
        points.removeAll()
        startPoint = nil
        liveDirections = []
        liveVowel = nil
        liveDirectionIndex = nil
        finalDirections = []
        finalVowel = nil
        analyzer.reset()
    }

    // MARK: Static helpers

    /// Order matches DirectionSector.standardSectors8: 0:→ 1:↗ 2:↑ 3:↖ 4:← 5:↙ 6:↓ 7:↘
    static let sectorIndex: [GestureDirection: Int] = [
        .right: 0, .upRight: 1, .up: 2, .upLeft: 3,
        .left: 4, .downLeft: 5, .down: 6, .downRight: 7,
    ]
}

// MARK: - View

/// Live visualization for swipe gestures.
///
/// Now backed by the production keyboard engine: `GestureAnalyzer` performs
/// per-column rotation-aware sector detection, `VowelResolver` handles direct
/// diagonal mapping (↗→ㅣ, ↘→ㅡ, etc.) plus multi-stroke patterns
/// (e.g. ↑→← → ㅙ, ←→← → ㅕ). The test view now mirrors what users actually
/// experience while typing, including ㅙ/ㅞ/ㅖ/ㅒ multi-stroke compounds.
struct GestureTestView: View {
    @StateObject private var model = GestureTestModel()

    private static let canvasDimension: CGFloat = 280

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                columnPicker
                visualization
                statusPanel
                Button("초기화") { model.reset() }
                    .buttonStyle(.bordered)
            }
            .padding()
        }
        .navigationTitle("긋기 테스트")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear { model.configureEngine() }
    }

    // MARK: - Subviews

    private var columnPicker: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("열 선택")
                .font(.subheadline)
                .foregroundColor(.secondary)
            Picker("열", selection: $model.selectedColumn) {
                ForEach(1...5, id: \.self) { col in
                    Text("\(col)열").tag(col)
                }
            }
            .pickerStyle(.segmented)
        }
    }

    private var visualization: some View {
        ZStack {
            SectorOverlay(
                sectors: model.sectors,
                profile: model.swipeProfile,
                rotationOffset: model.rotationOffset,
                iDelta: model.iDelta,
                euDelta: model.euDelta,
                detectedIndex: model.liveDirectionIndex
            )

            // Stroke path
            if model.points.count > 1 {
                Path { path in
                    path.move(to: model.points[0])
                    for p in model.points.dropFirst() {
                        path.addLine(to: p)
                    }
                }
                .stroke(Color.accentColor, style: StrokeStyle(lineWidth: 3, lineCap: .round, lineJoin: .round))
            }

            // Threshold ring (effective swipe length)
            Circle()
                .stroke(Color.gray.opacity(0.4), style: StrokeStyle(lineWidth: 1, dash: [3, 3]))
                .frame(width: model.effectiveThreshold * 2, height: model.effectiveThreshold * 2)
                .position(x: model.canvasSize.width / 2, y: model.canvasSize.height / 2)

            // Virtual key in center
            RoundedRectangle(cornerRadius: 8)
                .fill(Color(.systemGray5))
                .frame(width: 56, height: 44)
                .overlay(
                    Text(centerKeyLabel)
                        .font(.headline)
                )

            // Start point marker
            if let sp = model.startPoint {
                Circle()
                    .stroke(Color.green, lineWidth: 2)
                    .frame(width: 10, height: 10)
                    .position(sp)
            }
        }
        .frame(width: Self.canvasDimension, height: Self.canvasDimension)
        .background(
            GeometryReader { geo in
                Color.clear.onAppear { model.canvasSize = geo.size }
            }
        )
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay(
            RoundedRectangle(cornerRadius: 12).stroke(Color.gray.opacity(0.3), lineWidth: 1)
        )
        .gesture(
            DragGesture(minimumDistance: 0)
                .onChanged { value in model.onDragChanged(value) }
                .onEnded { _ in model.onDragEnded() }
        )
        .frame(maxWidth: .infinity)
    }

    private var statusPanel: some View {
        VStack(alignment: .leading, spacing: 8) {
            row("스트로크", strokeSequence)
            row("스트로크 수", "\(model.liveDirections.count)")
            row("실시간 모음", liveVowelLabel)
            row("최종 모음", finalVowelLabel)
            row("적용된 회전 보정", String(format: "%.1f°", model.rotationOffset))
            row("ㅣ 폭 보정", String(format: "+%.1f°", model.iDelta))
            row("ㅡ 폭 보정", String(format: "+%.1f°", model.euDelta))
            row("필요 길이(threshold)", String(format: "%.0f pt", model.effectiveThreshold))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }

    private func row(_ title: String, _ value: String) -> some View {
        HStack {
            Text(title)
                .foregroundColor(.secondary)
            Spacer()
            Text(value)
                .font(.system(.body, design: .monospaced))
                .fontWeight(.medium)
        }
    }

    // MARK: - Computed labels

    private var centerKeyLabel: String {
        switch model.selectedColumn {
        case 1: return "ㅂ"
        case 2: return "ㄴ"
        case 3: return "ㅇ"
        case 4: return "ㄱ"
        case 5: return "ㅅ"
        default: return ""
        }
    }

    private var strokeSequence: String {
        guard !model.liveDirections.isEmpty else { return "—" }
        return model.liveDirections.map { $0.symbol }.joined()
    }

    private var liveVowelLabel: String {
        guard let v = model.liveVowel else { return "—" }
        return String(v.compatibilityCharacter)
    }

    private var finalVowelLabel: String {
        guard let v = model.finalVowel else { return "—" }
        return String(v.compatibilityCharacter)
    }
}

// MARK: - Sector overlay

private struct SectorOverlay: View {
    let sectors: [DirectionSector]
    let profile: SwipeProfile
    let rotationOffset: Double
    let iDelta: Double
    let euDelta: Double
    let detectedIndex: Int?

    private static let directionColors: [Color] = [
        DirectionPieChart.vowelColors["ㅏ"]!,
        DirectionPieChart.vowelColors["ㅣ"]!,
        DirectionPieChart.vowelColors["ㅗ"]!,
        DirectionPieChart.vowelColors["ㅣ"]!,
        DirectionPieChart.vowelColors["ㅓ"]!,
        DirectionPieChart.vowelColors["ㅡ"]!,
        DirectionPieChart.vowelColors["ㅜ"]!,
        DirectionPieChart.vowelColors["ㅡ"]!,
    ]

    var body: some View {
        GeometryReader { geo in
            let cx = geo.size.width / 2
            let cy = geo.size.height / 2
            let radius = min(geo.size.width, geo.size.height) / 2 - 8

            Canvas { ctx, _ in
                let center = CGPoint(x: cx, y: cy)
                for i in 0..<min(sectors.count, 8) {
                    var s = sectors[i]
                    switch i {
                    case 1, 3: s.halfWidth += iDelta
                    case 5, 7: s.halfWidth += euDelta
                    default: break
                    }
                    let startDeg = s.startAngle + rotationOffset
                    let endDeg = s.endAngle + rotationOffset

                    // Convert math coords (0°=right, CCW) to screen (CW, y down)
                    let startRad = -startDeg * .pi / 180
                    let endRad = -endDeg * .pi / 180

                    var path = Path()
                    path.move(to: center)
                    let steps = 24
                    for step in 0...steps {
                        let t = Double(step) / Double(steps)
                        let a = startRad + (endRad - startRad) * t
                        path.addLine(to: CGPoint(x: cx + radius * cos(a), y: cy + radius * sin(a)))
                    }
                    path.closeSubpath()

                    let baseColor = Self.directionColors[i]
                    let isActive = detectedIndex == i
                    ctx.fill(path, with: .color(baseColor.opacity(isActive ? 0.85 : 0.25)))
                    ctx.stroke(path, with: .color(baseColor.opacity(0.6)),
                               lineWidth: isActive ? 2 : 0.5)
                }
            }

            // Labels
            ForEach(0..<min(sectors.count, 8), id: \.self) { i in
                let s = sectors[i]
                let startDeg = s.startAngle + rotationOffset
                let endDeg = s.endAngle + rotationOffset
                let mid = (startDeg + endDeg) / 2
                let r = radius * 0.7
                Text(label(at: i))
                    .font(.system(size: 13, weight: .heavy))
                    .foregroundColor(Color(.label))
                    .position(
                        x: cx + r * cos(mid * .pi / 180),
                        y: cy - r * sin(mid * .pi / 180)
                    )
            }
        }
    }

    private func label(at i: Int) -> String {
        switch i {
        case 0: return "ㅏ"
        case 2: return "ㅗ"
        case 4: return "ㅓ"
        case 6: return "ㅜ"
        case 1: return diagonalLabel(profile.upRightMapping, fallback: "↗")
        case 3: return diagonalLabel(profile.upLeftMapping, fallback: "↖")
        case 5: return diagonalLabel(profile.downLeftMapping, fallback: "↙")
        case 7: return diagonalLabel(profile.downRightMapping, fallback: "↘")
        default: return ""
        }
    }

    private func diagonalLabel(_ m: DiagonalMapping, fallback: String) -> String {
        switch m {
        case .vowelI:  return "ㅣ"
        case .vowelEu: return "ㅡ"
        case .vowelO:  return "ㅗ"
        case .vowelU:  return "ㅜ"
        case .vowelA:  return "ㅏ"
        case .vowelEo: return "ㅓ"
        case .normalizeUp, .normalizeDown, .normalizeLeft, .normalizeRight:
            return fallback
        case .disabled:
            return "✕"
        }
    }
}
