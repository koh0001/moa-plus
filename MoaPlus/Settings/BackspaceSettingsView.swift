import SwiftUI

struct BackspaceSettingsView: View {
    @ObservedObject private var settings = KeyboardSettings.shared

    var body: some View {
        List {
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
                Text("길게 누를 때 글자가 반복 삭제되는 속도입니다. 삭제는 항상 한 자소씩(받침 → 모음 → 자음) 이뤄집니다 — 순정 모아키와 같은 기본 동작입니다.")
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
                    Text("백스페이스를 \(settings.wordDeleteDelay, specifier: "%.1f")초 이상 누르면 공백 단위로 빠르게 삭제합니다. 그 전까지는 한 자소씩 삭제합니다.")
                } else {
                    Text("백스페이스를 길게 눌러도 한 자소씩(받침 → 모음 → 자음) 삭제합니다.")
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
