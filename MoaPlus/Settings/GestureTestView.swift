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

    /// 현재 민감도에서 직각(90°) 방향 전환이 새 획으로 인식되는 변위 임계.
    /// 캔버스에 "방향 전환 인식 범위" 원으로 표시 — 민감도를 올릴수록 작아진다
    /// (= 더 짧게 꺾어도 인식). `GestureAnalyzer.turnRegistrationThreshold`(gap 90°)와
    /// 동일한 식.
    var turnThreshold: CGFloat {
        let s = settings.gestureSettings
        let reversal = s.effectiveReversalThreshold(forColumn: selectedColumn, keyWidth: deviceCenterKeyWidth)
        let change = s.effectiveDirectionChangeThreshold(forColumn: selectedColumn)
        let mid = (reversal + change) / 2
        switch s.multiStrokeTurnSensitivity {
        case 0:  return change
        case 1:  return mid
        default: return reversal
        }
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

    var lastCharacter: String {
        guard let last = typedText.last else { return "" }
        return String(last)
    }

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
    @ObservedObject private var settings = KeyboardSettings.shared

    private static let canvasDimension: CGFloat = 280

    var body: some View {
        ScrollView {
            VStack(spacing: 18) {
                sensitivitySection
                canvasSection
                keyboardPreviewSection
                resultCards
            }
            .padding()
        }
        .navigationTitle("긋기 테스트")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear { model.configureEngine() }
    }

    // MARK: - Multi-stroke sensitivity (live adjust)

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

    private var sensitivityDescription: String {
        switch settings.gestureSettings.multiStrokeTurnSensitivity {
        case 0:  return "방향을 꺾은 뒤 처음 위치로 되돌아와야 새 획으로 인식됩니다 (기존 방식)."
        case 1:  return "적당히 꺾으면 끝까지 되돌아오지 않아도 새 획으로 인식됩니다."
        default: return "살짝만 꺾어도 새 획으로 인식됩니다. ㅗ·ㅜ·ㅏ·ㅓ 오인식에 주의하세요."
        }
    }

    private var sensitivitySection: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 6) {
                Image(systemName: "dial.medium")
                    .foregroundColor(.accentColor)
                Text("멀티스트로크 민감도")
                    .font(.subheadline.weight(.semibold))
                Spacer()
            }
            Picker("민감도", selection: sensitivityBinding) {
                Text("끔").tag(0)
                Text("보통").tag(1)
                Text("민감").tag(2)
            }
            .pickerStyle(.segmented)

            Text(sensitivityDescription)
                .font(.caption)
                .foregroundColor(.secondary)
                .frame(maxWidth: .infinity, alignment: .leading)
                .fixedSize(horizontal: false, vertical: true)

            Text("아래 키보드에서 ㅛ(위·아래·위)처럼 방향을 꺾어 긋고, 위 캔버스의 인식 결과가 어떻게 달라지는지 확인하세요.")
                .font(.caption2)
                .foregroundColor(.secondary)
                .frame(maxWidth: .infinity, alignment: .leading)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(.secondarySystemBackground))
        )
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
                Button("글자 지우기") {
                    inputDelegate.typedText = ""
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
                .disabled(inputDelegate.typedText.isEmpty)
                Button("초기화") {
                    model.reset()
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
            }

            visualization

            HStack(spacing: 14) {
                legendItem(color: .gray, label: "필요 길이 (첫 획)")
                legendItem(color: .orange, label: "방향 전환 인식")
            }

            Text("아래 키보드에서 ㅛ(위·아래·위)처럼 방향을 꺾어 그어 보세요. 주황 원보다 크게 꺾으면 새 획으로 인식됩니다. 민감도를 올리면 주황 원이 작아져 더 짧게 꺾어도 인식됩니다.")
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

            Text("실제 키보드와 동일하게 동작합니다.")
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
                    directions: model.liveDirections,
                    accent: .blue
                )
                resultCard(
                    title: "최종 결과",
                    vowel: finalVowelLabel,
                    directions: model.finalDirections,
                    accent: .accentColor
                )
            }

            metricsCard
        }
    }

    private func resultCard(title: String, vowel: String, directions: [GestureDirection], accent: Color) -> some View {
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
            strokeArrowChips(directions, accent: accent)
        }
        .padding(12)
        .frame(maxWidth: .infinity)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(.secondarySystemBackground))
        )
    }

    /// 인식된 방향 시퀀스를 화살표 칩 체인으로 — ↑↓↑ 처럼 어떻게 인식됐는지 한눈에.
    private func strokeArrowChips(_ directions: [GestureDirection], accent: Color) -> some View {
        Group {
            if directions.isEmpty {
                Text("—")
                    .font(.body)
                    .foregroundColor(.secondary)
            } else {
                // 화살표가 많아도 카드 폭을 넘기지 않도록 가로 스크롤.
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 4) {
                        ForEach(Array(directions.enumerated()), id: \.offset) { item in
                            Text(item.element.symbol)
                                .font(.headline)
                                .foregroundColor(accent)
                                .frame(width: 26, height: 26)
                                .background(Circle().fill(accent.opacity(0.18)))
                        }
                    }
                    .padding(.horizontal, 2)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .center)
    }

    private var sensitivityLabel: String {
        switch settings.gestureSettings.multiStrokeTurnSensitivity {
        case 0:  return "끔"
        case 1:  return "보통"
        default: return "민감"
        }
    }

    private func legendItem(color: Color, label: String) -> some View {
        HStack(spacing: 4) {
            Circle()
                .stroke(color.opacity(0.8), style: StrokeStyle(lineWidth: 1.5, dash: [3, 2]))
                .frame(width: 11, height: 11)
            Text(label)
                .font(.caption2)
                .foregroundColor(.secondary)
        }
    }

    private var metricsCard: some View {
        VStack(alignment: .leading, spacing: 6) {
            metricRow("멀티스트로크 민감도", sensitivityLabel)
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
                fourWay: model.swipeProfile.fourWayMode,
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

            // Threshold ring (effective swipe length — 첫 획 인식 거리)
            Circle()
                .stroke(Color.gray.opacity(0.4), style: StrokeStyle(lineWidth: 1, dash: [3, 3]))
                .frame(width: model.effectiveThreshold * 2, height: model.effectiveThreshold * 2)
                .position(x: model.canvasSize.width / 2, y: model.canvasSize.height / 2)

            // Turn-registration ring (방향 전환 인식 범위 — 민감도에 따라 변함)
            Circle()
                .stroke(Color.orange.opacity(0.75), style: StrokeStyle(lineWidth: 1.5, dash: [4, 3]))
                .frame(width: model.turnThreshold * 2, height: model.turnThreshold * 2)
                .position(x: model.canvasSize.width / 2, y: model.canvasSize.height / 2)

            // Start point marker
            if let sp = model.startPoint {
                Circle()
                    .stroke(Color.green, lineWidth: 2)
                    .frame(width: 10, height: 10)
                    .position(sp)
            }

            // Last typed character — shown at canvas centre so the TextField
            // section is no longer needed for visual feedback.
            if !inputDelegate.lastCharacter.isEmpty {
                Text(inputDelegate.lastCharacter)
                    .font(.system(size: 36, weight: .bold))
                    .foregroundColor(.white.opacity(0.9))
                    .shadow(color: .black.opacity(0.4), radius: 2, x: 0, y: 1)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .allowsHitTesting(false)
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
    /// When true, only the four cardinals are drawn, each spanning a full
    /// 90° quadrant — mirrors `GestureDirection.from`'s four-way branch so
    /// the test canvas matches what the keyboard actually recognises.
    var fourWay: Bool = false
    let detectedIndex: Int?

    /// Sector indices to render: cardinals only in four-way mode, otherwise
    /// the full 8-direction ring.
    private var activeIndices: [Int] {
        fourWay ? [0, 2, 4, 6] : Array(0..<min(sectors.count, 8))
    }

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
                for i in activeIndices {
                    var s = sectors[i]
                    if fourWay {
                        s.halfWidth = 45
                    } else {
                        switch i {
                        case 1, 3: s.halfWidth += iDelta
                        case 5, 7: s.halfWidth += euDelta
                        default: break
                        }
                    }
                    // Per-side wedge: CW edge = centre − rightHalfWidth (start),
                    // CCW edge = centre + leftHalfWidth (end). `halfWidth`
                    // assignments above mirror into both sides via didSet, so
                    // four-way (45) and column deltas are already reflected.
                    let startDeg = s.centerAngle - s.rightHalfWidth + rotationOffset
                    let endDeg = s.centerAngle + s.leftHalfWidth + rotationOffset

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
            ForEach(activeIndices, id: \.self) { i in
                let mid = sectors[i].centerAngle + rotationOffset
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
