import SwiftUI

struct HelpView: View {
    @State private var showTutorial = false
    @State private var showPractice = false

    var body: some View {
        List {
            Section {
                Button {
                    showTutorial = true
                } label: {
                    Label("튜토리얼 다시 보기", systemImage: "book.pages")
                }
                Button {
                    showPractice = true
                } label: {
                    Label("타이핑 연습", systemImage: "keyboard.badge.eye")
                }
            } footer: {
                Text("8 단계 튜토리얼 또는 33 개 연습 항목으로 모아키 입력 익히기.")
            }
        }
        .navigationTitle("도움말")
        .fullScreenCover(isPresented: $showTutorial) {
            NavigationStack {
                TutorialContainerView()
                    .toolbar {
                        ToolbarItem(placement: .topBarTrailing) {
                            Button("닫기") {
                                showTutorial = false
                            }
                        }
                    }
            }
        }
        .fullScreenCover(isPresented: $showPractice) {
            NavigationStack {
                TypingPracticeListView()
                    .toolbar {
                        ToolbarItem(placement: .topBarTrailing) {
                            Button("닫기") {
                                showPractice = false
                            }
                        }
                    }
            }
        }
    }
}

#Preview {
    NavigationStack {
        HelpView()
    }
}
