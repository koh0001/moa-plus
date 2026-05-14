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

    /// Whether the live preview should accept gestures on the slot B vowel key.
    /// True when the user has selected a layout that exposes a vowel key —
    /// either slot B `.vowelKey` (function row) or slot A `.fullPackage` (col 6 row 3).
    private var isVowelKeyAvailable: Bool {
        let cust = settings.layoutCustomization
        return cust.slotA == .fullPackage || cust.slotB == .vowelKey
    }

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
                            onVowelPreviewWithPoint: isVowelKeyAvailable
                                ? { vowel, startPoint in
                                    previewVowelOutput = String(vowel.compatibilityCharacter)
                                    // startPoint.x is in the keyboardPreview
                                    // coordinate space (== this GeometryReader's
                                    // width). Touch on left half → bubble right.
                                    previewBubbleOnRight = startPoint.x < geo.size.width / 2
                                  }
                                : nil
                        )
                        SlotHighlightOverlay(slot: highlightedSlot)
                            .allowsHitTesting(false)

                        if isVowelKeyAvailable, !previewVowelOutput.isEmpty {
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
                if isVowelKeyAvailable {
                    Text("스페이스 옆 모음 키(또는 확장형의 모음 키)를 직접 드래그하면 어떤 모음이 입력되는지 표시됩니다. 결과 표시 위치는 손가락 반대편에 나타납니다.")
                }
            }

            // Slot A
            Section {
                slotARadioRow(.vowel, title: "모던", desc: "⌫ + ㅣ ㅡ ㆍ")
                slotARadioRow(.classic11, title: "클래식", desc: "! ? . + 가로 ⌫")
                slotARadioRow(.fullPackage, title: "확장형", desc: "Classic 베이스 + col 6 에 모음/특수문자 + 긴 스페이스. 슬롯 B 자동 비활성.")
                if settings.layoutCustomization.slotA == .vowel {
                    Toggle("백스페이스 ↔ ㆍ 위치 swap", isOn: Binding(
                        get: { settings.layoutCustomization.slotABackspaceSwap },
                        set: { newValue in
                            var c = settings.layoutCustomization
                            c.slotABackspaceSwap = newValue
                            settings.layoutCustomization = c
                        }
                    ))
                }
            } header: {
                slotHeader(label: "우측 컬럼 (슬롯 A)", slot: .a, systemImage: "rectangle.righthalf.inset.filled")
            } footer: {
                Text("우측 끝 컬럼의 키 매핑.")
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
                // 확장형: row 0 펑크 토글
                if isFullPackage {
                    Toggle("1번 셀을 긋기 펑크 키로 사용", isOn: Binding(
                        get: { settings.layoutCustomization.slotARightColumnTopAsPunctuation },
                        set: { newValue in
                            var lc = settings.layoutCustomization
                            lc.slotARightColumnTopAsPunctuation = newValue
                            settings.layoutCustomization = lc
                        }
                    ))
                    if row0AsPunct {
                        Text("ON 시 row 0 자리에 한글 펑크 슬롯(아래 슬롯 편집) 적용. 1번 셀 텍스트는 무시됨.")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                }

                // 모던: row 0 (#) 고정 표시 + 펑크 적용 토글
                if isVowelPreset {
                    Toggle("# 자리에 펑크 키 적용", isOn: Binding(
                        get: { settings.layoutCustomization.slotARightColumnTopAsPunctuation },
                        set: { newValue in
                            var lc = settings.layoutCustomization
                            lc.slotARightColumnTopAsPunctuation = newValue
                            settings.layoutCustomization = lc
                        }
                    ))
                    Text("모던 프리셋의 우측 1행 마지막 셀(# 자리)을 긋기 펑크 키로 교체.")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                    HStack {
                        Text("1번 셀 (row 0)")
                        Spacer()
                        Text("#")
                            .foregroundColor(.secondary)
                    }
                }

                // 클래식/확장형: 편집 가능 셀 목록
                if editableCount > 0 {
                    ForEach(0..<editableCount, id: \.self) { i in
                        HStack {
                            Text("\(i + 1)번 셀 (row \(i))")
                            Spacer()
                            Button(settings.layoutCustomization.slotARightColumn[i]) {
                                startSlotAEdit(index: i)
                            }
                            .font(.system(size: 16, weight: .medium))
                        }
                        .disabled(isFullPackage && i == 0 && row0AsPunct)
                        .opacity(isFullPackage && i == 0 && row0AsPunct ? 0.4 : 1.0)
                    }
                    Button("기본값으로 초기화 (! ? .)", action: resetSlotARightColumn)
                        .foregroundColor(.red)
                }

                // 긋기 펑크 슬롯 편집 — 모든 프리셋에서 노출
                Divider()
                Text("긋기 펑크 슬롯")
                    .font(.caption)
                    .foregroundColor(.secondary)
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
            } header: {
                Text("우측 컬럼 셀 (\(presetLabel))")
            } footer: {
                if isFullPackage {
                    Text("col 6 row 0 에 들어갈 문자. row 1·2 는 모음 키 / 특수문자 키로 고정. 1~4 자.")
                } else if isVowelPreset {
                    Text("모던 프리셋의 우측 컬럼 셀. # 고정. 펑크 슬롯은 함수행 펑크 키 및 (옵션) # 자리에 적용됩니다.")
                } else {
                    Text("col 6 row 0/1/2 에 들어갈 문자. 모음(ㅣ ㅡ ㆍ ㅏ 등) / 특수문자 / 일반 글자 모두 가능. 1~4 자.")
                }
            }

            // Slot B
            Section {
                slotBRadioRow(.punctuation, title: "특수문자", desc: "tap=. ←=? →=! ↑=, ↓=.")
                slotBRadioRow(.vowelKey, title: "모음 키", desc: "tap=ㆍ + 8방향 모음")
            } header: {
                slotHeader(label: "스페이스 옆 키 (슬롯 B)", slot: .b, systemImage: "rectangle.bottomthird.inset.filled")
            } footer: {
                if settings.layoutCustomization.slotA == .fullPackage {
                    Text("확장형 모드에서는 슬롯 B 가 col 6 으로 이동했습니다.")
                        .foregroundColor(.orange)
                } else {
                    Text("스페이스바 옆 키 동작.")
                }
            }
            .disabled(settings.layoutCustomization.slotA == .fullPackage)

            // Slot C
            Section {
                ForEach(0..<4, id: \.self) { i in
                    HStack {
                        Text("\(i + 1)번 셀 (row \(i))")
                        Spacer()
                        Button(settings.layoutCustomization.slotC[i]) {
                            startCellEdit(index: i)
                        }
                        .font(.system(size: 16, weight: .medium))
                    }
                }
                Button("기본값으로 초기화", action: resetSlotC)
                    .foregroundColor(.red)
            } header: {
                slotHeader(label: "좌측 컬럼 (슬롯 C)", slot: .c, systemImage: "rectangle.lefthalf.inset.filled")
            } footer: {
                Text("각 셀에 1~4 자 문자 매핑. 빈 입력은 거부됩니다.")
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

            Section("긋기 펑크 키 — 영문 자판") {
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

    @ViewBuilder
    private func slotARadioRow(_ preset: SlotAPreset, title: String, desc: String) -> some View {
        Button(action: {
            var c = settings.layoutCustomization
            c.slotA = preset
            settings.layoutCustomization = c
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
