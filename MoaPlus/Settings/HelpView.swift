import SwiftUI

/// 증상으로 설정을 찾는 화면.
///
/// 원래는 튜토리얼·연습 버튼 2개짜리였다. 그런데 앱스토어 리뷰의 불만 상당수가
/// **해당 설정이 이미 있는데 못 찾은** 경우였다 — 사용자는 "오타가 잦다"고
/// 말하지 도착지인 "섹터 각도"를 알지 못한다. 그래서 증상 → 설정 라우터를 앞에 둔다.
/// 항목은 `SettingsCatalog.symptoms` 에 있고 설정 검색과 같은 목적지를 공유한다.
struct HelpView: View {
    @State private var showTutorial = false
    @State private var showPractice = false

    var body: some View {
        List {
            Section {
                ForEach(SettingsCatalog.symptoms) { symptom in
                    NavigationLink(destination: symptom.destination.view) {
                        HStack(alignment: .top, spacing: 12) {
                            Image(systemName: symptom.icon)
                                .foregroundColor(.accentColor)
                                .frame(width: 24)
                            VStack(alignment: .leading, spacing: 3) {
                                Text(symptom.symptom)
                                    .font(.subheadline)
                                    .foregroundColor(.primary)
                                Text(symptom.remedy)
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                        }
                        .padding(.vertical, 2)
                    }
                }
            } header: {
                Text("이럴 때 어떻게 하나요")
            } footer: {
                Text("찾는 항목이 없으면 설정 화면 위쪽 검색창에 ‘각도’, ‘지구본’, ‘힌트’처럼 떠오르는 단어를 넣어 보세요.")
            }

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
