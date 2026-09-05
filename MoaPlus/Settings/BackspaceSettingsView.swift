import SwiftUI

struct BackspaceSettingsView: View {
    @ObservedObject private var settings = KeyboardSettings.shared

    /// 푸터 문구 공용 — 삭제 단위 설정에 따라 "한 자소씩 / 한 글자씩" 이 바뀐다.
    private var unitPhrase: String {
        settings.backspaceDeletesWholeSyllable ? "한 글자씩(받침 → 글자)" : "한 자소씩(받침 → 모음 → 자음)"
    }

    var body: some View {
        List {
            // 삭제 단위 — 앱스토어 리뷰 "글자 지울 때 모음만 지워진다, 예전처럼 자음까지"
            // 반영. 기본은 자소 단위(순정 실측)라 기존 사용자는 무변화.
            Section {
                Picker("삭제 단위", selection: $settings.backspaceDeletesWholeSyllable) {
                    Text("자소 단위").tag(false)
                    Text("글자 단위").tag(true)
                }
                .pickerStyle(.segmented)
            } header: {
                Text("삭제 단위")
            } footer: {
                Text(settings.backspaceDeletesWholeSyllable
                     ? "받침 없는 글자를 한 번에 지웁니다 (가 → 빈칸). 받침이 있으면 받침부터 떨어집니다 (한 → 하 → 빈칸). 2.0 이전 모아+ 의 동작입니다."
                     : "기본값. 받침 → 모음 → 자음 순서로 한 자소씩 지웁니다 (가 → ㄱ). 순정 모아키와 같은 동작입니다.")
            }

            Section {
                Picker("속도", selection: $settings.backspaceSpeed) {
                    Text("느리게").tag(0)
                    Text("보통").tag(1)
                    Text("빠르게").tag(2)
                }
                .pickerStyle(.segmented)
            } header: {
                Text("반복 속도")
            } footer: {
                // 실기기 실측 D4: "한 자소씩" 안내가 단어 삭제 OFF 푸터에만 있어
                // 기본 상태(단어 삭제 ON)에서는 보이지 않았다 — 상시 노출로 이동.
                Text("길게 누를 때 글자가 반복 삭제되는 속도입니다. 반복 삭제도 위 삭제 단위를 따라 \(unitPhrase) 이뤄집니다.")
            }

            Section {
                Toggle("단어 단위 삭제", isOn: $settings.wordDeleteEnabled)
                if settings.wordDeleteEnabled {
                    HStack {
                        Text("전환 시간")
                        Spacer()
                        Text("\(settings.wordDeleteDelay, specifier: "%.1f")초")
                            .foregroundColor(.secondary)
                    }
                    Slider(value: $settings.wordDeleteDelay, in: 0.8...3.0, step: 0.1)
                }
            } header: {
                Text("단어 단위 삭제")
            } footer: {
                if settings.wordDeleteEnabled {
                    Text("백스페이스를 \(settings.wordDeleteDelay, specifier: "%.1f")초 이상 누르면 공백 단위로 빠르게 삭제합니다. 그 전까지는 \(unitPhrase) 삭제합니다.")
                } else {
                    Text("백스페이스를 길게 눌러도 \(unitPhrase) 삭제합니다.")
                }
            }

            Section {
                NavigationLink(destination: LayoutCustomizationView()) {
                    HStack {
                        Text("백스페이스 위치 변경")
                        Spacer()
                        Text("레이아웃에서").font(.caption).foregroundColor(.secondary)
                    }
                }
            } footer: {
                Text("위치는 키보드 레이아웃 페이지에서 설정합니다.")
            }
        }
        .navigationTitle("백스페이스")
    }
}

#Preview {
    NavigationStack {
        BackspaceSettingsView()
    }
}
