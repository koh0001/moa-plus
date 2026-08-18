import SwiftUI
import Combine
import MessageUI

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

    /// 개발자 전송용 리포트 — 기록 + 오타 분석에 필요한 맥락(긋기 설정 요약,
    /// 앱/기기 정보)을 한 덩어리로 묶는다. 임계값 튜닝은 사용자의 설정 상태를
    /// 모르면 판독이 안 되기 때문에 리포트에 반드시 동봉한다.
    var developerReport: String {
        let s = KeyboardSettings.shared
        let g = s.gestureSettings
        let settingsSummary = """
        [설정 요약]
        긋기: 프리셋 \(g.swipeProfile.mode.rawValue) / 길이 \(g.swipeProfile.swipeLength.displayName) / 4방향 \(g.swipeProfile.fourWayMode ? "ON" : "OFF")
        멀티스트로크 민감도: \(g.multiStrokeTurnSensitivity) / 복합모음: \(s.consonantDiagonalDerivationEnabled ? "확장(대각선 진입)" : "순정 모아키")
        반전 임계 비율: \(g.reversalThresholdRatio) / 방향 전환 임계: \(g.directionChangeThreshold)
        높이 배율: \(s.keyboardHeightScale) / 사이드 키 폭: \(s.sideKeyWidthRatio)
        레이아웃: slotA \(s.layoutCustomization.slotA.rawValue) / slotB \(s.layoutCustomization.slotB.rawValue) / 모음키 \(s.layoutCustomization.vowelKeyBehavior.rawValue)
        """
        let records = entries.isEmpty ? "(저장된 기록 없음)" : exportText
        let gestureLog = GestureDebugLog.recentLines()
        let gestureSection = gestureLog.isEmpty
            ? "(제스처 상세 기록 없음)"
            : gestureLog.joined(separator: "\n")
        return """
        [입력 기록]
        \(records)

        [제스처 상세 로그 (최근 \(gestureLog.count)건)]
        \(gestureSection)

        \(settingsSummary)
        \(FeedbackContext.defaultBody())
        """
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
    @ObservedObject private var settings = KeyboardSettings.shared
    @State private var draft = ""
    @State private var gestureLogCount = GestureDebugLog.count
    @FocusState private var editorFocused: Bool
    @State private var showingMailComposer = false
    @State private var showingMailUnavailableAlert = false
    @State private var showingGitHubCopiedAlert = false

    /// AboutView 의 피드백 채널과 동일한 목적지.
    private static let supportEmail = "koh0001@outlook.kr"
    private static let newIssueURL = URL(string: "https://github.com/koh0001/moa-plus/issues/new")!

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

            Section {
                Toggle("제스처 상세 기록", isOn: $settings.gestureDebugLogEnabled)
                if gestureLogCount > 0 {
                    HStack {
                        Text("쌓인 계측")
                        Spacer()
                        Text("\(gestureLogCount)건")
                            .foregroundColor(.secondary)
                        Button("비우기", role: .destructive) {
                            GestureDebugLog.clear()
                            gestureLogCount = 0
                        }
                        .buttonStyle(.borderless)
                    }
                }
            } header: {
                Text("제스처 상세 기록")
            } footer: {
                Text("키보드가 긋기마다 획별 방향·크기·각도(트림 전/후)와 결과 글자를 기록하고, 개발자 리포트에 함께 담습니다. 기록은 이 기기에만 남고(최근 200건 순환), 리포트를 직접 보낼 때만 전송됩니다.")
            }

            if !store.entries.isEmpty {
                Section {
                    Button {
                        if MFMailComposeViewController.canSendMail() {
                            showingMailComposer = true
                        } else {
                            showingMailUnavailableAlert = true
                        }
                    } label: {
                        Label("메일로 보내기", systemImage: "envelope")
                    }
                    Button {
                        // GitHub 이슈 작성 폼은 본문을 URL 로 넘기면 길이 제한에
                        // 걸리기 쉽다 — 리포트를 클립보드에 복사해 두고 폼을 열어
                        // 붙여넣게 한다.
                        UIPasteboard.general.string = store.developerReport
                        showingGitHubCopiedAlert = true
                    } label: {
                        Label("GitHub 이슈로 보내기", systemImage: "ladybug")
                    }
                } header: {
                    Text("개발자에게 보내기")
                } footer: {
                    Text("저장된 기록 전체와 긋기 설정 요약, 앱·기기 정보가 함께 담깁니다. 입력한 내용이 그대로 전송되니 보내기 전에 확인하세요.")
                }

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
        .onAppear { gestureLogCount = GestureDebugLog.count }
        .toolbar {
            if !store.entries.isEmpty {
                ToolbarItem(placement: .topBarTrailing) {
                    ShareLink(item: store.exportText) {
                        Image(systemName: "square.and.arrow.up")
                    }
                }
            }
        }
        .sheet(isPresented: $showingMailComposer) {
            MailComposeView(
                recipient: Self.supportEmail,
                subject: "[모아+] 입력 기록 리포트",
                body: store.developerReport
            )
            .ignoresSafeArea()
        }
        .alert("메일을 보낼 수 없습니다", isPresented: $showingMailUnavailableAlert) {
            Button("확인", role: .cancel) {}
            Button("GitHub 이슈로 보내기") {
                UIPasteboard.general.string = store.developerReport
                showingGitHubCopiedAlert = true
            }
        } message: {
            Text("이 기기에 메일 계정이 설정되어 있지 않습니다. GitHub 이슈나 \(Self.supportEmail) 으로 보내주세요.")
        }
        .alert("리포트가 복사되었습니다", isPresented: $showingGitHubCopiedAlert) {
            Button("취소", role: .cancel) {}
            Button("GitHub 열기") { UIApplication.shared.open(Self.newIssueURL) }
        } message: {
            Text("이슈 작성 화면이 열리면 본문에 붙여넣기 하세요.")
        }
    }
}

#Preview {
    NavigationStack {
        DebugBoardView()
    }
}
