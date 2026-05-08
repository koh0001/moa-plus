import SwiftUI

struct KeyboardSettingsView: View {
    @ObservedObject private var settings = KeyboardSettings.shared

    var body: some View {
        List {
            Section {
                NavigationLink(destination: LayoutCustomizationView()) {
                    HStack {
                        Label("레이아웃", systemImage: "rectangle.3.group")
                        Spacer()
                        Text(layoutSummary).font(.caption).foregroundColor(.secondary)
                    }
                }
                NavigationLink(destination: GestureSettingsView()) {
                    HStack {
                        Label("제스처 (긋기)", systemImage: "hand.draw")
                        Spacer()
                        Text(gestureSummary).font(.caption).foregroundColor(.secondary)
                    }
                }
                NavigationLink(destination: LongPressSettingsView()) {
                    Label("롱프레스 (보조 매핑)", systemImage: "hand.tap")
                }
            } footer: {
                Text("키보드 입력 관련 모든 설정.")
            }

            Section {
                NavigationLink(destination: BackspaceSettingsView()) {
                    Label("백스페이스", systemImage: "delete.left")
                }
                NavigationLink(destination: InputBehaviorSettingsView()) {
                    Label("입력 동작", systemImage: "gearshape")
                }
            }
        }
        .navigationTitle("키보드")
    }

    private var layoutSummary: String {
        let c = settings.layoutCustomization
        switch c.slotA {
        case .vowel: return c.slotABackspaceSwap ? "모음 (swap)" : "모던"
        case .classic11: return "클래식 1.1"
        case .fullPackage: return "풀 패키지"
        }
    }

    private var gestureSummary: String {
        let p = settings.gestureSettings.swipeProfile
        let mode: String = {
            switch p.mode {
            case .right: return "오른손"
            case .left: return "왼손"
            case .both: return "양손"
            case .custom: return "커스텀"
            }
        }()
        return "\(mode) · \(p.swipeLength.displayName)"
    }
}

#Preview {
    NavigationStack {
        KeyboardSettingsView()
    }
}
