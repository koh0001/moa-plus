import SwiftUI

struct EditSecondaryKeyView: View {
    let action: SecondaryKeyAction
    let onSave: (SecondaryKeyAction) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var visibleHint: String = ""
    @State private var primaryOutput: String = ""
    @State private var popupText: String = ""  // space-separated

    /// 저장될 모습 — 공백 제거·힌트 따라가기까지 반영 (`SecondaryKeyAction.applyingEdit`).
    /// 미리보기와 저장이 같은 값을 쓴다.
    private var draft: SecondaryKeyAction {
        action.applyingEdit(visibleHint: visibleHint, primaryOutput: primaryOutput, popupText: popupText)
    }

    /// 앞뒤 공백을 뺀 롱프레스 출력. 공백만 넣으면 저장할 수 없다.
    private var trimmedPrimary: String {
        primaryOutput.trimmingCharacters(in: .whitespacesAndNewlines)
    }

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
                            .autocorrectionDisabled()
                            .textInputAutocapitalization(.never)
                    }
                } header: {
                    Text("표시")
                } footer: {
                    Text("키 우상단에 작게 표시되는 문자입니다. 롱프레스 출력과 같게 두면 출력을 바꿀 때 함께 바뀝니다.")
                }

                Section {
                    HStack {
                        Text("롱프레스 출력")
                        Spacer()
                        TextField("예: 1", text: $primaryOutput)
                            .multilineTextAlignment(.trailing)
                            .frame(width: 80)
                            .autocorrectionDisabled()
                            .textInputAutocapitalization(.never)
                    }
                } header: {
                    Text("롱프레스")
                } footer: {
                    Text("길게 눌렀다 그대로 떼면 입력되는 문자입니다. 팝업에서도 맨 앞에 놓입니다.")
                }

                Section {
                    TextField("예: 1 ! ~", text: $popupText)
                        .autocorrectionDisabled()
                        .textInputAutocapitalization(.never)
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

                            if !draft.visibleHint.isEmpty {
                                Text(draft.visibleHint)
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
                            Text("롱프레스 → \(trimmedPrimary.isEmpty ? "-" : trimmedPrimary)")
                                .font(.callout)
                            // 키보드 팝업과 같은 출처 — 롱프레스 출력이 맨 앞, 중복 제거.
                            let candidates = draft.effectiveCandidates(filteringClosingBrackets: false)
                            Text("후보: \(candidates.isEmpty ? "없음" : candidates.joined(separator: " "))")
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
                        onSave(draft)
                        dismiss()
                    }
                    .disabled(trimmedPrimary.isEmpty)
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
