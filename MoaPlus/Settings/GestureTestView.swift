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

        // Re-configure when the selected column changes. The column is now
        // driven by the live keyboard preview (whichever consonant key the
        // user is touching), so we only refresh engine settings — clearing
        // the trail would race against the very same gesture that updated
        // the column.
        $selectedColumn
            .dropFirst()
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in self?.configureEngine() }
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

    // MARK: Real-keyboard preview ingestion

    /// Receive a `(phase, directions, vowel)` snapshot from the real keyboard
    /// preview's consonant gesture pipeline. Mirrors the abstract canvas's
    /// `liveDirections / finalDirections` fields plus the touch trail so the
    /// canvas can redraw the user's path live without running its own
    /// gesture analyzer.
    func ingestKeyboardPreview(phase: KeyboardViewModel.PreviewGesturePhase,
                               directions: [GestureDirection],
                               vowel: Jungseong?) {
        switch phase {
        case .began(let startPoint, let columnId):
            liveDirections = []
            liveVowel = nil
            liveDirectionIndex = nil
            finalDirections = []
            finalVowel = nil
            // Adopt the column the user just touched so sector geometry and
            // per-column overrides reflect the real key under their finger.
            applyColumn(columnId)
            keyboardOriginPoint = startPoint
            self.startPoint = canvasCenter
            points = [canvasCenter]
        case .moved(_, let trail, let columnId):
            applyColumn(columnId)
            liveDirections = directions
            liveVowel = vowel
            liveDirectionIndex = directions.last.flatMap { Self.sectorIndex[$0] }
            points = mappedPoints(trail)
        case .ended(let trail, let columnId):
            applyColumn(columnId)
            finalDirections = directions
            finalVowel = vowel ?? liveVowel
            liveDirections = directions
            liveDirectionIndex = directions.last.flatMap { Self.sectorIndex[$0] }
            points = mappedPoints(trail)
        }
    }

    /// Origin of the live keyboard gesture in the keyboard's own coordinate
    /// space. We translate every subsequent point relative to this origin
    /// and re-anchor it on the canvas centre so the trail mirrors the user's
    /// actual stroke geometry without depending on screen-space alignment.
    private var keyboardOriginPoint: CGPoint = .zero

    private var canvasCenter: CGPoint {
        CGPoint(x: canvasSize.width / 2, y: canvasSize.height / 2)
    }

    private func mappedPoints(_ trail: [CGPoint]) -> [CGPoint] {
        guard !trail.isEmpty else { return [canvasCenter] }
        let origin = keyboardOriginPoint
        let centre = canvasCenter
        return trail.map { CGPoint(x: centre.x + ($0.x - origin.x),
                                   y: centre.y + ($0.y - origin.y)) }
    }

    /// Adopt a column id from the live keyboard so sector visualisation and
    /// per-column corrections track whichever key the user just pressed.
    /// Avoids the Combine sink in `init` that would `reset()` the trail.
    private func applyColumn(_ columnId: Int) {
        guard columnId != selectedColumn else { return }
        selectedColumn = columnId
        configureEngine()
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

// MARK: - Live input delegate

/// In-memory `KeyboardViewModelDelegate` that captures everything the live
/// keyboard inserts into a `typedText` buffer the host TextField binds to.
/// Cursor / haptic / next-keyboard methods no-op — there's no real
/// document proxy to drive in this host-app context.
final class GestureTestKeyboardDelegate: ObservableObject, KeyboardViewModelDelegate {
    @Published var typedText: String = ""

    func insertText(_ text: String) {
        typedText.append(text)
    }

    func deleteBackward() {
        if !typedText.isEmpty {
            typedText.removeLast()
        }
    }

    func updateComposingText(from previous: String, to current: String) {
        // Simulate the extension's marked-text emulation: drop the previous
        // composing characters from the buffer, then append the new ones.
        // Each character in `previous` was inserted via insertText, so we
        // remove that many graphemes from the tail.
        var remaining = previous.count
        while remaining > 0, !typedText.isEmpty {
            typedText.removeLast()
            remaining -= 1
        }
        if !current.isEmpty {
            typedText.append(current)
        }
    }

    func switchToNextKeyboard() {
        // No-op: there is no input switcher in the host app preview.
    }

    func triggerHapticFeedback() {
        // No-op: HapticManager already runs from KeyboardViewModel on its own.
    }

    func moveCursor(by offset: Int) {
        // No-op: a plain string buffer has no cursor concept here.
        _ = offset
    }
}

// MARK: - View

/// Live visualization for swipe gestures.
///
/// The screen now centres on the **real keyboard** (`KeyboardPreviewView`
/// running with a live input delegate, not preview-mode) so users test
/// gestures by actually typing. The sector canvas is rendered above the
/// keyboard and mirrors every stroke; a TextField between them shows what
/// the keyboard committed via the production input pipeline.
struct GestureTestView: View {
    @StateObject private var model = GestureTestModel()
    @StateObject private var inputDelegate = GestureTestKeyboardDelegate()

    private static let canvasDimension: CGFloat = 280

    var body: some View {
        ScrollView {
            VStack(spacing: 18) {
                canvasSection
                typedTextSection
                keyboardPreviewSection
                resultCards
            }
            .padding()
        }
        .navigationTitle("긋기 테스트")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear { model.configureEngine() }
    }

    // MARK: - Sector canvas (top)

    private var canvasSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 6) {
                Image(systemName: "scope")
                    .foregroundColor(.accentColor)
                Text("실시간 분석")
                    .font(.subheadline.weight(.semibold))
                Spacer()
                Button("초기화") {
                    model.reset()
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
            }

            visualization

            Text("아래 키보드에서 자음 키를 끌면 같은 동작이 이 캔버스에 그대로 그려져 8방향 섹터와 어떻게 만나는지 확인할 수 있습니다.")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(.secondarySystemBackground))
        )
    }

    // MARK: - Typed-text TextField (middle)

    private var typedTextSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 6) {
                Image(systemName: "text.cursor")
                    .foregroundColor(.accentColor)
                Text("입력 결과")
                    .font(.subheadline.weight(.semibold))
                Spacer()
                Button("지우기") {
                    inputDelegate.typedText = ""
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
                .disabled(inputDelegate.typedText.isEmpty)
            }

            TextField("여기에 입력됨", text: $inputDelegate.typedText, axis: .vertical)
                .lineLimit(2...4)
                .textFieldStyle(.roundedBorder)
                .disabled(true)  // Read-only: the live keyboard below is the only writer.
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(.secondarySystemBackground))
        )
    }

    // MARK: - Real keyboard (bottom)

    private var keyboardPreviewSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 6) {
                Image(systemName: "keyboard")
                    .foregroundColor(.accentColor)
                Text("실제 키보드 입력")
                    .font(.subheadline.weight(.semibold))
            }

            KeyboardPreviewView(
                onConsonantPreview: { phase, directions, vowel in
                    model.ingestKeyboardPreview(phase: phase, directions: directions, vowel: vowel)
                },
                forceShowGesturePreview: true,
                liveInputDelegate: inputDelegate
            )

            Text("실제 키보드와 동일하게 동작합니다. 입력한 글자는 위쪽 ‘입력 결과’에 그대로 들어갑니다.")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(.secondarySystemBackground))
        )
    }

    // MARK: - Result cards

    private var resultCards: some View {
        VStack(spacing: 10) {
            HStack(spacing: 10) {
                resultCard(
                    title: "실시간",
                    vowel: liveVowelLabel,
                    sequence: liveStrokeSequence,
                    accent: .blue
                )
                resultCard(
                    title: "최종 결과",
                    vowel: finalVowelLabel,
                    sequence: finalStrokeSequence,
                    accent: .accentColor
                )
            }

            metricsCard
        }
    }

    private func resultCard(title: String, vowel: String, sequence: String, accent: Color) -> some View {
        VStack(spacing: 6) {
            Text(title)
                .font(.caption.weight(.semibold))
                .foregroundColor(.secondary)
                .frame(maxWidth: .infinity, alignment: .leading)
            Text(vowel)
                .font(.system(size: 44, weight: .bold))
                .foregroundColor(accent)
                .frame(maxWidth: .infinity)
                .frame(minHeight: 56)
            Text(sequence)
                .font(.system(.body, design: .monospaced))
                .foregroundColor(.primary)
                .frame(maxWidth: .infinity, alignment: .center)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
        }
        .padding(12)
        .frame(maxWidth: .infinity)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(.secondarySystemBackground))
        )
    }

    private var metricsCard: some View {
        VStack(alignment: .leading, spacing: 6) {
            metricRow("스트로크 수", "\(model.liveDirections.count)")
            metricRow("적용된 회전 보정", String(format: "%.1f°", model.rotationOffset))
            metricRow("ㅣ 폭 보정", String(format: "+%.1f°", model.iDelta))
            metricRow("ㅡ 폭 보정", String(format: "+%.1f°", model.euDelta))
            metricRow("필요 길이", String(format: "%.0f pt", model.effectiveThreshold))
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(.secondarySystemBackground))
        )
    }

    private func metricRow(_ title: String, _ value: String) -> some View {
        HStack {
            Text(title)
                .font(.subheadline)
                .foregroundColor(.secondary)
            Spacer()
            Text(value)
                .font(.system(.subheadline, design: .monospaced))
                .fontWeight(.medium)
        }
    }

    /// Read-only mirror of the live keyboard gesture. The canvas no longer
    /// captures its own touches — it draws sector geometry plus the trail
    /// fed by `model.ingestKeyboardPreview`.
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

            // Stroke path mirrored from the keyboard above.
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
        .allowsHitTesting(false)
        .frame(maxWidth: .infinity)
    }

    // MARK: - Computed labels

    private var liveStrokeSequence: String {
        guard !model.liveDirections.isEmpty else { return "—" }
        return model.liveDirections.map { $0.symbol }.joined()
    }

    private var finalStrokeSequence: String {
        guard !model.finalDirections.isEmpty else { return "—" }
        return model.finalDirections.map { $0.symbol }.joined()
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
