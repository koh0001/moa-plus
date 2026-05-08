import SwiftUI

struct EditSecondaryKeyView: View {
    let action: SecondaryKeyAction
    let onSave: (SecondaryKeyAction) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var visibleHint: String = ""
    @State private var primaryOutput: String = ""
    @State private var popupText: String = ""  // space-separated

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    HStack {
                        Text("자음 키")
                        Spacer()
                        Text(action.keyId)
                            .font(.title2)
                    }
                } header: {
                    Text("키 정보")
                }

                Section {
                    HStack {
                        Text("힌트 라벨")
                        Spacer()
                        TextField("예: 1", text: $visibleHint)
                            .multilineTextAlignment(.trailing)
                            .frame(width: 80)
                    }
                } header: {
                    Text("표시")
                } footer: {
                    Text("키 우상단에 작게 표시되는 문자입니다.")
                }

                Section {
                    HStack {
                        Text("롱프레스 출력")
                        Spacer()
                        TextField("예: 1", text: $primaryOutput)
                            .multilineTextAlignment(.trailing)
                            .frame(width: 80)
                    }
                } header: {
                    Text("롱프레스")
                } footer: {
                    Text("길게 누르면 입력되는 대표 문자입니다.")
                }

                Section {
                    TextField("예: 1 ! ~", text: $popupText)
                } header: {
                    Text("팝업 후보")
                } footer: {
                    Text("공백으로 구분하여 입력하세요. 길게 누른 후 드래그하면 선택할 수 있습니다.")
                }

                // Preview
                Section {
                    HStack(spacing: 16) {
                        // Key preview
                        ZStack {
                            RoundedRectangle(cornerRadius: 8)
                                .fill(Color(.systemGray5))
                                .frame(width: 50, height: 50)

                            Text(action.keyId)
                                .font(.title2)

                            if !visibleHint.isEmpty {
                                Text(visibleHint)
                                    .font(.system(size: 9))
                                    .foregroundColor(.secondary)
                                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing)
                                    .padding(4)
                            }
                        }
                        .frame(width: 50, height: 50)

                        Image(systemName: "hand.tap")
                            .foregroundColor(.secondary)

                        VStack(alignment: .leading, spacing: 2) {
                            Text("롱프레스 → \(primaryOutput.isEmpty ? "-" : primaryOutput)")
                                .font(.callout)
                            Text("후보: \(popupText.isEmpty ? "없음" : popupText)")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                } header: {
                    Text("미리보기")
                }
            }
            .navigationTitle("\(action.keyId) 편집")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("취소") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("저장") {
                        let popupList = popupText
                            .split(separator: " ")
                            .map(String.init)
                        var updated = action
                        updated.visibleHint = visibleHint
                        updated.primaryLongPressOutput = primaryOutput
                        updated.popupOutputs = popupList
                        onSave(updated)
                        dismiss()
                    }
                    .disabled(primaryOutput.isEmpty)
                }
            }
            .onAppear {
                visibleHint = action.visibleHint
                primaryOutput = action.primaryLongPressOutput
                popupText = action.popupOutputs.joined(separator: " ")
            }
        }
    }
}
