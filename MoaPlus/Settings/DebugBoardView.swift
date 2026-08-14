import SwiftUI
import Combine

/// 실기기 실측용 입력 기록 보드.
///
/// v2.0 실기기 테스트 피드백: "메모장처럼 빈 보드에 입력하고 입력값들을 저장할 수
/// 있는 기능이 있으면 좋겠다" — 메모 앱을 오가며 오타 사례를 옮겨 적는 대신,
/// 앱 안에서 모아+ 키보드로 바로 입력하고 사례를 남긴다. 저장된 기록은 이 기기의
/// 앱 로컬(UserDefaults)에만 남고 어디에도 전송되지 않는다.
struct DebugBoardEntry: Identifiable, Codable, Equatable {
    let id: UUID
    let date: Date
    let text: String
}

final class DebugBoardStore: ObservableObject {
    @Published private(set) var entries: [DebugBoardEntry] = []

    private static let storageKey = "debugBoardEntries"
    /// 오래된 기록부터 밀어내는 상한 — 실측 세션 수십 회 분량이면 충분하다.
    private static let maxEntries = 300

    init() {
        load()
    }

    func save(_ text: String) {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        entries.insert(DebugBoardEntry(id: UUID(), date: Date(), text: text), at: 0)
        if entries.count > Self.maxEntries {
            entries.removeLast(entries.count - Self.maxEntries)
        }
        persist()
    }

    func delete(at offsets: IndexSet) {
        entries.remove(atOffsets: offsets)
        persist()
    }

    func clear() {
        entries.removeAll()
        persist()
    }

    /// 전체 기록을 공유 시트로 내보낼 때 쓰는 마크다운 텍스트.
    var exportText: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
        return entries.reversed().map { entry in
            "[\(formatter.string(from: entry.date))]\n\(entry.text)"
        }.joined(separator: "\n\n---\n\n")
    }

    private func load() {
        guard let data = UserDefaults.standard.data(forKey: Self.storageKey),
              let decoded = try? JSONDecoder().decode([DebugBoardEntry].self, from: data) else { return }
        entries = decoded
    }

    private func persist() {
        guard let data = try? JSONEncoder().encode(entries) else { return }
        UserDefaults.standard.set(data, forKey: Self.storageKey)
    }
}

struct DebugBoardView: View {
    @StateObject private var store = DebugBoardStore()
    @State private var draft = ""
    @FocusState private var editorFocused: Bool

    private var draftIsBlank: Bool {
        draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var body: some View {
        List {
            Section {
                TextEditor(text: $draft)
                    .frame(minHeight: 140)
                    .focused($editorFocused)
                    // 실측 보드에서는 시스템 보정이 관찰을 오염시킨다 — 키보드가
                    // 실제로 출력한 글자를 그대로 봐야 오타 사례로 쓸 수 있다.
                    .autocorrectionDisabled()
                    .textInputAutocapitalization(.never)
                HStack {
                    Button {
                        store.save(draft)
                        draft = ""
                    } label: {
                        Label("기록 저장", systemImage: "tray.and.arrow.down")
                    }
                    .disabled(draftIsBlank)
                    Spacer()
                    Button("비우기", role: .destructive) {
                        draft = ""
                    }
                    .disabled(draft.isEmpty)
                }
                .buttonStyle(.borderless)
            } header: {
                Text("입력 보드")
            } footer: {
                Text("모아+ 키보드로 자유롭게 입력해 보세요. 오타가 나면 그대로 저장해 두면 나중에 사례로 대조할 수 있습니다. 기록은 이 기기에만 저장됩니다.")
            }

            if !store.entries.isEmpty {
                Section {
                    ForEach(store.entries) { entry in
                        VStack(alignment: .leading, spacing: 4) {
                            Text(entry.date, format: .dateTime.year().month().day().hour().minute().second())
                                .font(.caption2)
                                .foregroundColor(.secondary)
                            Text(entry.text)
                                .font(.body)
                                .textSelection(.enabled)
                        }
                        .contextMenu {
                            Button {
                                UIPasteboard.general.string = entry.text
                            } label: {
                                Label("복사", systemImage: "doc.on.doc")
                            }
                        }
                    }
                    .onDelete { store.delete(at: $0) }
                } header: {
                    Text("저장된 기록 \(store.entries.count)개")
                } footer: {
                    Text("항목을 왼쪽으로 밀면 삭제됩니다.")
                }
            }
        }
        .navigationTitle("입력 기록 보드")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            if !store.entries.isEmpty {
                ToolbarItem(placement: .topBarTrailing) {
                    ShareLink(item: store.exportText) {
                        Image(systemName: "square.and.arrow.up")
                    }
                }
            }
        }
    }
}

#Preview {
    NavigationStack {
        DebugBoardView()
    }
}
