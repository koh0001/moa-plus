import SwiftUI

struct LayoutCustomizationView: View {
    @ObservedObject private var settings = KeyboardSettings.shared
    @State private var highlightedSlot: HighlightedSlot? = nil
    @State private var editingCellIndex: Int? = nil
    @State private var cellEditText: String = ""
    @State private var showingCellEdit = false
    @State private var editingSlotAIndex: Int? = nil
    @State private var slotAEditText: String = ""
    @State private var showingSlotAEdit = false
    @State private var previewVowelOutput: String = ""
    /// True when the user touched the LEFT half of the preview (so the
    /// result bubble should appear on the right, opposite the finger).
    @State private var previewBubbleOnRight: Bool = false

    enum HighlightedSlot { case a, b, c }

    var body: some View {
        List {
            // Live preview
            Section {
                // GeometryReader gives us the preview's pixel width so the
                // result bubble can render on the half OPPOSITE the gesture
                // start point — keeps the user's finger from covering it.
                GeometryReader { geo in
                    ZStack(alignment: .topLeading) {
                        KeyboardPreviewView(
                            // slot B 모음 키(확장형 / B1 vowelKey) 드래그 미리보기.
                            onVowelPreviewWithPoint: { vowel, startPoint in
                                previewVowelOutput = String(vowel.compatibilityCharacter)
                                // startPoint.x is in the keyboardPreview
                                // coordinate space (== this GeometryReader's
                                // width). Touch on left half → bubble right.
                                previewBubbleOnRight = startPoint.x < geo.size.width / 2
                            },
                            // 자음 키 / ㅣ·ㅡ 전용 키(모던) 드래그 미리보기. 모든
                            // 레이아웃에서 결과 모음을 버블로 보여준다(실제 입력 X).
                            // `.moved` 단계의 vowel 은 키 타입별로 정확히 계산되므로
                            // (vowelPrimitive 는 resolveVowelFromPrimitiveDrag) 그 값을
                            // 사용한다. `.ended` 는 vowelResolver 로만 해석돼
                            // ㅣ/ㅡ 키에서 부정확할 수 있어 무시한다.
                            onConsonantPreview: { phase, _, vowel in
                                switch phase {
                                case .began(let startPoint, _):
                                    previewBubbleOnRight = startPoint.x < geo.size.width / 2
                                    previewVowelOutput = ""
                                case .moved:
                                    if let vowel {
                                        previewVowelOutput = String(vowel.compatibilityCharacter)
                                    }
                                case .ended:
                                    break
                                }
                            }
                        )
                        SlotHighlightOverlay(slot: highlightedSlot)
                            .allowsHitTesting(false)

                        if !previewVowelOutput.isEmpty {
                            VowelResultBubble(
                                text: previewVowelOutput,
                                onClear: { previewVowelOutput = "" }
                            )
                            .padding(8)
                            .frame(
                                maxWidth: .infinity,
                                maxHeight: .infinity,
                                alignment: previewBubbleOnRight ? .topTrailing : .topLeading
                            )
                            .allowsHitTesting(true)
                        }
                    }
                }
                .aspectRatio(375.0 / 260.0, contentMode: .fit)
                .padding(.vertical, 4)
            } header: {
                Text("미리보기")
            } footer: {
                Text("자음 키나 모음 키를 직접 드래그하면 어떤 모음이 입력되는지 결과가 표시됩니다(실제 입력은 되지 않습니다). 결과는 손가락 반대편에 나타납니다.")
            }

            // Slot A
            Section {
                slotARadioRow(.vowel, title: "모던", desc: "⌫ + ㅣ ㅡ ㆍ")
                slotARadioRow(.classic11, title: "클래식", desc: "! ? . + 가로 ⌫")
                slotARadioRow(.fullPackage, title: "확장형", desc: "클래식 + 우측 컬럼에 모음·특수문자 + 긴 스페이스")
                if settings.layoutCustomization.slotA == .vowel {
                    Toggle("백스페이스 ↔ ㆍ 위치 swap", isOn: Binding(
                        get: { settings.layoutCustomization.slotABackspaceSwap },
                        set: { newValue in
                            var c = settings.layoutCustomization
                            c.slotABackspaceSwap = newValue
                            settings.layoutCustomization = c
                        }
                    ))
                    Toggle("4방향 전용 모드", isOn: fourWayModeBinding)
                    Text("상하좌우 4방향만 인식하고 대각선을 끕니다. 각 방향이 90°씩 차지해 ㅗ/ㅜ/ㅏ/ㅓ가 안정적으로 입력됩니다. ㅣ/ㅡ는 전용 키로 입력합니다. (긋기 각도·방향 설정은 무시)")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
            } header: {
                slotHeader(label: "우측 컬럼", slot: .a, systemImage: "rectangle.righthalf.inset.filled")
            } footer: {
                Text("우측 끝 컬럼의 키 매핑. 4방향 전용 모드는 ㅣ/ㅡ 전용 키가 있는 ‘모던’에서만 사용할 수 있습니다.")
            }

            // Slot A right column — always visible, preset-aware
            let currentPreset = settings.layoutCustomization.slotA
            let presetLabel: String = {
                switch currentPreset {
                case .vowel:       return "모던"
                case .classic11:   return "클래식"
                case .fullPackage: return "확장형"
                }
            }()
            let isFullPackage = currentPreset == .fullPackage
            let isVowelPreset = currentPreset == .vowel
            let row0AsPunct = settings.layoutCustomization.slotARightColumnTopAsPunctuation
            let editableCount: Int = {
                switch currentPreset {
                case .vowel:       return 0
                case .fullPackage: return 1
                case .classic11:   return 3
                }
            }()
            Section {
                // 확장형: row 0 특수키 토글
                if isFullPackage {
                    Toggle("1번 셀을 특수키로 사용", isOn: Binding(
                        get: { settings.layoutCustomization.slotARightColumnTopAsPunctuation },
                        set: { newValue in
                            var lc = settings.layoutCustomization
                            lc.slotARightColumnTopAsPunctuation = newValue
                            settings.layoutCustomization = lc
                        }
                    ))
                    if row0AsPunct {
                        Text("1번 셀이 특수키로 교체됩니다.")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                }

                // 모던: row 0 (#) 고정 표시 + 특수키 적용 토글
                if isVowelPreset {
                    Toggle("# 자리에 특수키 적용", isOn: Binding(
                        get: { settings.layoutCustomization.slotARightColumnTopAsPunctuation },
                        set: { newValue in
                            var lc = settings.layoutCustomization
                            lc.slotARightColumnTopAsPunctuation = newValue
                            settings.layoutCustomization = lc
                        }
                    ))
                    Text("# 자리를 특수키로 교체합니다.")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                    HStack {
                        Text("1번 셀")
                        Spacer()
                        Text("#")
                            .foregroundColor(.secondary)
                    }
                }

                // 클래식/확장형: 편집 가능 셀 목록
                // 확장형 + 펑크 토글 ON 이면 1번 셀 텍스트가 무시되므로 행 자체를 숨김
                let showEditableCells = editableCount > 0 && !(isFullPackage && row0AsPunct)
                if showEditableCells {
                    ForEach(0..<editableCount, id: \.self) { i in
                        HStack {
                            Text("\(i + 1)번 셀")
                            Spacer()
                            Button(settings.layoutCustomization.slotARightColumn[i]) {
                                startSlotAEdit(index: i)
                            }
                            .font(.system(size: 16, weight: .medium))
                        }
                    }
                    Button(isFullPackage ? "1번 셀 기본값으로 되돌리기" : "기본값으로 되돌리기 (! ? .)",
                           action: resetSlotARightColumn)
                        .foregroundColor(.accentColor)
                }

                // 우측 컬럼 특수키 슬롯 편집 — 토글 ON 일 때만 노출 (slot B 슬롯과 독립)
                if (isVowelPreset || isFullPackage) && row0AsPunct {
                    PunctuationSlotsEditor(
                        slots: Binding(
                            get: { settings.layoutCustomization.slotARightColumnPunctuationSlots },
                            set: { newValue in
                                var lc = settings.layoutCustomization
                                lc.slotARightColumnPunctuationSlots = newValue
                                settings.layoutCustomization = lc
                            }
                        ),
                        defaults: .defaultKorean,
                        isEnabled: true
                    )
                }
            } header: {
                Text("우측 컬럼 (\(presetLabel))")
            } footer: {
                if isFullPackage {
                    Text("1번 셀에 1~4자 입력. 스페이스 옆 특수키와 독립적으로 설정됩니다.")
                } else if isVowelPreset {
                    Text("# 자리에만 적용. 스페이스 옆 특수키와 독립적으로 설정됩니다.")
                } else {
                    Text("각 셀에 1~4자 입력. 모음·특수문자·글자 모두 가능.")
                }
            }

            // Slot B
            Section {
                // 확장형은 슬롯 B 가 우측 컬럼으로 이동했으므로 토글/라디오 모두 숨김
                let punctEnabled = settings.layoutCustomization.koreanPunctuationEnabled
                if !isFullPackage {
                    Toggle("스페이스 옆 특수키 사용", isOn: Binding(
                        get: { settings.layoutCustomization.koreanPunctuationEnabled },
                        set: { newValue in
                            var lc = settings.layoutCustomization
                            lc.koreanPunctuationEnabled = newValue
                            settings.layoutCustomization = lc
                        }
                    ))
                    if punctEnabled {
                        slotBRadioRow(.punctuation, title: "특수문자", desc: "tap=. ←=? →=! ↑=, ↓=.")
                        slotBRadioRow(.vowelKey, title: "모음 키", desc: "tap=ㆍ + 8방향 모음")
                    }
                }

                // 특수키 슬롯 편집기 — 확장형(우측 컬럼 임베드) 또는 한글 + 토글 ON + .punctuation 일 때 노출
                let slotBPunctActive = isFullPackage
                    || (punctEnabled && settings.layoutCustomization.slotB == .punctuation)
                if slotBPunctActive {
                    PunctuationSlotsEditor(
                        slots: Binding(
                            get: { settings.layoutCustomization.koreanPunctuationSlots },
                            set: { newValue in
                                var lc = settings.layoutCustomization
                                lc.koreanPunctuationSlots = newValue
                                settings.layoutCustomization = lc
                            }
                        ),
                        defaults: .defaultKorean,
                        isEnabled: true
                    )
                }
            } header: {
                if isFullPackage {
                    // 확장형은 슬롯 B 가 col 6 으로 이동했으므로 위치 하이라이트도 우측 컬럼(.a)을 가리킴
                    slotHeader(label: "우측 컬럼 임베드 특수키", slot: .a, systemImage: "rectangle.righthalf.inset.filled")
                } else {
                    slotHeader(label: "스페이스 옆 키", slot: .b, systemImage: "rectangle.bottomthird.inset.filled")
                }
            } footer: {
                if isFullPackage {
                    Text("우측 컬럼 3번째 행에 위치한 특수키 슬롯.")
                } else if !settings.layoutCustomization.koreanPunctuationEnabled {
                    Text("OFF 시 스페이스바·엔터가 확장되고 엔터가 백스페이스에 2셀 정렬됩니다.")
                } else {
                    Text("스페이스바 옆 키 동작.")
                }
            }

            // Slot C
            Section {
                ForEach(0..<4, id: \.self) { i in
                    HStack {
                        Text("\(i + 1)번 셀")
                        Spacer()
                        Button(settings.layoutCustomization.slotC[i]) {
                            startCellEdit(index: i)
                        }
                        .font(.system(size: 16, weight: .medium))
                    }
                }
                Button("기본값으로 되돌리기", action: resetSlotC)
                    .foregroundColor(.accentColor)
            } header: {
                slotHeader(label: "좌측 컬럼", slot: .c, systemImage: "rectangle.lefthalf.inset.filled")
            } footer: {
                Text("각 셀에 1~4자 입력.")
            }

            // Key size (moved from InputSettingsView)
            Section {
                HStack {
                    Text("좌우 특수키")
                    Spacer()
                    Text("\(Int(settings.sideKeyWidthRatio * 100))%").foregroundColor(.secondary)
                }
                Slider(value: $settings.sideKeyWidthRatio, in: 0.15...1.0, step: 0.05)
            } header: {
                Text("키 크기")
            } footer: {
                Text("좌우 끝 키의 너비. 기본 70% (정사각).")
            }

            // iPad 분리(확장) 레이아웃
            Section {
                Toggle("세로에서도 분리 레이아웃", isOn: iPadPortraitSplitBinding)
                Picker("숫자패드 위치", selection: numberPadSideBinding) {
                    Text("왼쪽").tag(NumberPadSide.left)
                    Text("오른쪽").tag(NumberPadSide.right)
                }
                .pickerStyle(.segmented)
                Text("아이패드 가로에서는 숫자패드와 한글 자판이 항상 좌우로 나뉩니다. ‘세로에서도 분리’를 켜면 세로에서도 같은 확장 레이아웃을 씁니다. ‘숫자패드 위치’는 숫자패드를 좌·우 어느 쪽에 둘지 정합니다(가로·세로 공통).")
                    .font(.footnote)
                    .foregroundColor(.secondary)
            } header: {
                Text("iPad 레이아웃")
            }

            Section("특수키 — 영문 자판") {
                Toggle("사용 (스페이스 폭이 줄어듭니다)", isOn: Binding(
                    get: { settings.layoutCustomization.englishPunctuationEnabled },
                    set: { newValue in
                        var lc = settings.layoutCustomization
                        lc.englishPunctuationEnabled = newValue
                        settings.layoutCustomization = lc
                    }
                ))

                PunctuationSlotsEditor(
                    slots: Binding(
                        get: { settings.layoutCustomization.englishPunctuationSlots },
                        set: { newValue in
                            var lc = settings.layoutCustomization
                            lc.englishPunctuationSlots = newValue
                            settings.layoutCustomization = lc
                        }
                    ),
                    defaults: .defaultEnglish,
                    isEnabled: settings.layoutCustomization.englishPunctuationEnabled
                )
            }
        }
        .navigationTitle("레이아웃 커스터마이즈")
        .alert("셀 편집", isPresented: $showingCellEdit) {
            TextField("문자", text: $cellEditText)
            Button("취소", role: .cancel) {}
            Button("저장", action: commitCellEdit)
        } message: {
            Text("1~4 자 입력")
        }
        .alert("우측 셀 편집", isPresented: $showingSlotAEdit) {
            TextField("문자", text: $slotAEditText)
            Button("취소", role: .cancel) {}
            Button("저장", action: commitSlotAEdit)
        } message: {
            Text("1~4 자 입력 (모음/특수문자/일반 글자)")
        }
    }

    /// 4방향 전용 모드(긋기 설정 소속이지만 모던 레이아웃에서만 의미가 있어
    /// 이 화면의 모던 옵션 하위에 노출)를 KeyboardSettings 에 바인딩.
    private var fourWayModeBinding: Binding<Bool> {
        Binding(
            get: { settings.gestureSettings.swipeProfile.fourWayMode },
            set: { newValue in
                var gs = settings.gestureSettings
                gs.swipeProfile.fourWayMode = newValue
                settings.gestureSettings = gs
            }
        )
    }

    private var numberPadSideBinding: Binding<NumberPadSide> {
        Binding(
            get: { settings.layoutCustomization.numberPadSide },
            set: { newValue in
                var lc = settings.layoutCustomization
                lc.numberPadSide = newValue
                settings.layoutCustomization = lc
            }
        )
    }

    private var iPadPortraitSplitBinding: Binding<Bool> {
        Binding(
            get: { settings.layoutCustomization.iPadPortraitSplitEnabled },
            set: { newValue in
                var lc = settings.layoutCustomization
                lc.iPadPortraitSplitEnabled = newValue
                settings.layoutCustomization = lc
            }
        )
    }

    private func slotARadioRow(_ preset: SlotAPreset, title: String, desc: String) -> some View {
        Button(action: {
            var c = settings.layoutCustomization
            c.slotA = preset
            settings.layoutCustomization = c
            // 4방향 전용 모드는 ㅣ/ㅡ 전용 키가 있는 모던(.vowel)에서만 유효하다.
            // 비모던으로 바꾸면 ㅣ/ㅡ 입력이 막히므로 자동으로 끈다.
            if preset != .vowel && settings.gestureSettings.swipeProfile.fourWayMode {
                var gs = settings.gestureSettings
                gs.swipeProfile.fourWayMode = false
                settings.gestureSettings = gs
            }
        }) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(title).foregroundColor(.primary)
                    Text(desc).font(.caption).foregroundColor(.secondary)
                }
                Spacer()
                if settings.layoutCustomization.slotA == preset {
                    Image(systemName: "checkmark").foregroundColor(.accentColor)
                }
            }
        }
    }

    @ViewBuilder
    private func slotBRadioRow(_ preset: SlotBPreset, title: String, desc: String) -> some View {
        Button(action: {
            var c = settings.layoutCustomization
            c.slotB = preset
            settings.layoutCustomization = c
        }) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(title).foregroundColor(.primary)
                    Text(desc).font(.caption).foregroundColor(.secondary)
                }
                Spacer()
                if settings.layoutCustomization.slotB == preset {
                    Image(systemName: "checkmark").foregroundColor(.accentColor)
                }
            }
        }
    }

    @ViewBuilder
    private func slotHeader(label: String, slot: HighlightedSlot, systemImage: String) -> some View {
        Button(action: {
            withAnimation(.easeInOut(duration: 0.2)) {
                highlightedSlot = (highlightedSlot == slot) ? nil : slot
            }
        }) {
            HStack {
                Text(label)
                Image(systemName: systemImage)
                    .font(.caption)
                    .foregroundColor(highlightedSlot == slot ? .accentColor : .secondary)
            }
        }
    }

    private func startCellEdit(index: Int) {
        editingCellIndex = index
        cellEditText = settings.layoutCustomization.slotC[index]
        showingCellEdit = true
    }

    private func commitCellEdit() {
        guard let i = editingCellIndex else { return }
        let trimmed = String(cellEditText.prefix(4))
        guard !trimmed.isEmpty else {
            editingCellIndex = nil
            return
        }
        var c = settings.layoutCustomization
        c.slotC[i] = trimmed
        settings.layoutCustomization = c
        editingCellIndex = nil
    }

    private func resetSlotC() {
        var c = settings.layoutCustomization
        c.slotC = LayoutCustomization.defaultSlotC
        settings.layoutCustomization = c
    }

    private func startSlotAEdit(index: Int) {
        editingSlotAIndex = index
        slotAEditText = settings.layoutCustomization.slotARightColumn[index]
        showingSlotAEdit = true
    }

    private func commitSlotAEdit() {
        guard let i = editingSlotAIndex else { return }
        let trimmed = String(slotAEditText.prefix(4))
        guard !trimmed.isEmpty else {
            editingSlotAIndex = nil
            return
        }
        var c = settings.layoutCustomization
        c.slotARightColumn[i] = trimmed
        settings.layoutCustomization = c
        editingSlotAIndex = nil
    }

    private func resetSlotARightColumn() {
        var c = settings.layoutCustomization
        c.slotARightColumn = LayoutCustomization.defaultSlotARightColumn
        settings.layoutCustomization = c
    }
}

/// Renders a colored highlight rectangle over the keyboard preview to indicate
/// which slot the user just tapped in the settings list. Uses approximate
/// fractions of the preview area — the real keyboard layout is non-uniform but
/// this visual hint is intentionally rough.
struct SlotHighlightOverlay: View {
    let slot: LayoutCustomizationView.HighlightedSlot?

    var body: some View {
        GeometryReader { geo in
            Group {
                switch slot {
                case .a:
                    // Right column (col 6) - rightmost ~13% of width
                    highlightRect(geo: geo, x: 0.86, y: 0.0, width: 0.14, height: 0.85)
                case .b:
                    // Function row middle (where slot B lives) - bottom ~17% of height
                    highlightRect(geo: geo, x: 0.65, y: 0.85, width: 0.12, height: 0.15)
                case .c:
                    // Left column (col 0) - leftmost ~9% of width
                    highlightRect(geo: geo, x: 0.0, y: 0.0, width: 0.09, height: 0.85)
                case nil:
                    EmptyView()
                }
            }
            .animation(.easeInOut(duration: 0.25), value: slot)
        }
    }

    private func highlightRect(geo: GeometryProxy, x: CGFloat, y: CGFloat, width: CGFloat, height: CGFloat) -> some View {
        RoundedRectangle(cornerRadius: 6)
            .stroke(Color.accentColor.opacity(0.85), lineWidth: 3)
            .background(
                RoundedRectangle(cornerRadius: 6).fill(Color.accentColor.opacity(0.18))
            )
            .frame(width: geo.size.width * width, height: geo.size.height * height)
            .position(x: geo.size.width * x + (geo.size.width * width) / 2,
                      y: geo.size.height * y + (geo.size.height * height) / 2)
    }
}

/// Floating callout that surfaces the resolved vowel from a slot-B-vowel
/// preview gesture. Positioned by the parent (`LayoutCustomizationView`) on
/// the half opposite the gesture start point so the user's finger doesn't
/// cover the result.
private struct VowelResultBubble: View {
    let text: String
    let onClear: () -> Void

    var body: some View {
        HStack(spacing: 6) {
            Text(text)
                .font(.title2.bold())
                .foregroundColor(.accentColor)
            Button(action: onClear) {
                Image(systemName: "xmark.circle.fill")
                    .foregroundColor(.secondary)
                    .imageScale(.medium)
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(Color(.tertiarySystemBackground))
        )
        .shadow(color: .black.opacity(0.18), radius: 4, y: 2)
    }
}

private struct PunctuationSlotsEditor: View {
    @Binding var slots: PunctuationSlots
    let defaults: PunctuationSlots
    let isEnabled: Bool

    var body: some View {
        Group {
            // 라이브 미리보기
            HStack {
                Text("미리보기")
                Spacer()
                preview
                    .frame(width: 56, height: 56)
                    .background(
                        RoundedRectangle(cornerRadius: 8)
                            .fill(Color(.tertiarySystemFill))
                    )
            }

            slotRow(label: "탭",     binding: $slots.tap,   placeholder: defaults.tap)
            slotRow(label: "← 왼",   binding: $slots.left,  placeholder: defaults.left)
            slotRow(label: "→ 오",   binding: $slots.right, placeholder: defaults.right)
            slotRow(label: "↑ 위",   binding: $slots.up,    placeholder: defaults.up)
            slotRow(label: "↓ 아래", binding: $slots.down,  placeholder: defaults.down)

            Text("비우면 해당 방향이 비활성화됩니다.")
                .font(.caption2)
                .foregroundColor(.secondary)

            Button("기본값으로 되돌리기") {
                slots = defaults
            }
            .foregroundColor(.accentColor)
        }
        .disabled(!isEnabled)
        .opacity(isEnabled ? 1.0 : 0.4)
    }

    private var preview: some View {
        VStack(spacing: 1) {
            previewHint(slots.up)
            HStack(spacing: 4) {
                previewHint(slots.left)
                Text(slots.tap.isEmpty ? " " : slots.tap)
                    .font(.system(size: previewMainSize(slots.tap), weight: .medium))
                previewHint(slots.right)
            }
            previewHint(slots.down)
        }
    }

    @ViewBuilder
    private func previewHint(_ text: String) -> some View {
        if text.isEmpty {
            Text(" ").font(.system(size: 9)).foregroundColor(.clear)
        } else {
            Text(text).font(.system(size: previewHintSize(text))).foregroundColor(.secondary)
        }
    }

    private func previewMainSize(_ text: String) -> CGFloat {
        switch text.count {
        case 0, 1: return 16
        case 2:    return 12
        default:   return 10
        }
    }
    private func previewHintSize(_ text: String) -> CGFloat {
        switch text.count {
        case 0, 1: return 9
        case 2:    return 8
        default:   return 7
        }
    }

    private func slotRow(label: String, binding: Binding<String>, placeholder: String) -> some View {
        HStack {
            Text(label).frame(width: 56, alignment: .leading)
            TextField(placeholder, text: binding)
                .textFieldStyle(.roundedBorder)
                .autocorrectionDisabled()
                .textInputAutocapitalization(.never)
        }
    }
}

#Preview {
    NavigationStack {
        LayoutCustomizationView()
    }
}
