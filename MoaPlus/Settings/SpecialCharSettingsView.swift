import SwiftUI

struct SpecialCharSettingsView: View {
    var body: some View {
        List {
            Section {
                HStack {
                    Image(systemName: "hand.tap")
                    VStack(alignment: .leading) {
                        Text("짧게 탭")
                            .font(.body)
                        Text("내부 특수문자 레이어 열기")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }

                HStack {
                    Image(systemName: "hand.tap.fill")
                    VStack(alignment: .leading) {
                        Text("길게 누름")
                            .font(.body)
                        Text("시스템 키보드 전환")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            } header: {
                Text("진입 방식")
            } footer: {
                Text("언어 변환 키(🌐)를 짧게 탭하면 특수문자 레이어가 열리고, 길게 누르면 시스템 키보드를 전환합니다.")
            }

            Section {
                ForEach(SpecialCharCategory.allCases, id: \.self) { category in
                    HStack {
                        Text(category.rawValue)
                        Spacer()
                        Text(category.characters.flatMap { $0 }.prefix(6).joined(separator: " "))
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            } header: {
                Text("카테고리")
            } footer: {
                Text("특수문자 레이어에서 상단 탭으로 카테고리를 전환할 수 있습니다.")
            }
        }
        .navigationTitle("특수문자")
    }
}
