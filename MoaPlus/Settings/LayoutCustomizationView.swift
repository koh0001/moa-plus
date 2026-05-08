import SwiftUI

struct LayoutCustomizationView: View {
    @ObservedObject private var settings = KeyboardSettings.shared
    @State private var highlightedSlot: HighlightedSlot? = nil
    @State private var editingCellIndex: Int? = nil
    @State private var cellEditText: String = ""
    @State private var showingCellEdit = false

    enum HighlightedSlot { case a, b, c }

    var body: some View {
        List {
            // Live preview
            Section {
                ZStack(alignment: .topLeading) {
                    KeyboardPreviewView()
                    SlotHighlightOverlay(slot: highlightedSlot)
                        .allowsHitTesting(false)
                }
                .padding(.vertical, 4)
            } header: {
                Text("미리보기")
            }

            // Slot A
            Section {
                slotARadioRow(.vowel, title: "모음 (현재)", desc: "⌫ + ㅣ ㅡ ㆍ")
                slotARadioRow(.classic11, title: "1.1 특수문자", desc: "! ? . + 가로 ⌫")
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

            // Slot B
            Section {
                slotBRadioRow(.punctuation, title: "특수문자 (현재)", desc: "tap=. ←=? →=! ↑=, ↓=.")
                slotBRadioRow(.vowelKey, title: "모음 키", desc: "tap=ㆍ + 8방향 모음")
            } header: {
                slotHeader(label: "스페이스 옆 키 (슬롯 B)", slot: .b, systemImage: "rectangle.bottomthird.inset.filled")
            } footer: {
                Text("스페이스바 옆 키 동작.")
            }

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
        }
        .navigationTitle("레이아웃 커스터마이즈")
        .alert("셀 편집", isPresented: $showingCellEdit) {
            TextField("문자", text: $cellEditText)
            Button("취소", role: .cancel) {}
            Button("저장", action: commitCellEdit)
        } message: {
            Text("1~4 자 입력")
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

#Preview {
    NavigationStack {
        LayoutCustomizationView()
    }
}
