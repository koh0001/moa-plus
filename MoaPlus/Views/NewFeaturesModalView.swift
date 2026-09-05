import SwiftUI

/// 업데이트한 기존 사용자에게 1회 표시되는 "새로운 기능" 모달.
/// `FirstLaunchLayoutModalView` 와 같은 sheet 톤(시스템 배경 + 카드)을 따른다.
/// 닫으면 현재 앱 버전을 `lastSeenWhatsNewVersion` 에 기록해 다음 실행부터는
/// 다시 뜨지 않는다. 트리거 분기는 `ContentView.onAppear` 에서 FirstLaunch
/// 모달과 배타적으로 처리한다(신규 사용자는 이 모달을 건너뜀).
struct NewFeaturesModalView: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject private var settings = KeyboardSettings.shared

    fileprivate struct Feature: Identifiable {
        let id = UUID()
        let icon: String
        let tint: Color
        let title: String
        let detail: String
    }

    fileprivate struct FeatureGroup: Identifiable {
        let id = UUID()
        let title: String
        let features: [Feature]
    }

    /// v2.2.1 — 복합모음 경로 옵션(이슈 #29). 기본값이 현재 동작이라 바꾸지 않으면
    /// 달라지는 것이 없으므로 "켜는 경로"와 증상을 적는다. 이전 릴리스 항목들은
    /// 뒤에 남겨 둔다.
    private let groups: [FeatureGroup] = [
        FeatureGroup(title: "ㅘ·ㅝ 긋기 경로를 고를 수 있어요", features: [
            Feature(
                icon: "arrow.turn.right.up",
                tint: .blue,
                title: "복합모음 경로 — 세로 왕복만",
                detail: "위로 긋는 끝이 오른쪽 위로 흘러 '모'가 '뫄'로 찍힌다면, 설정 › 키보드 › 긋기 › 복합모음 경로를 '세로 왕복만'으로 바꿔 보세요. 위 → 오른쪽 직각 경로는 ㅗ 로 남고, 위 → 아래 → 오른쪽 세로 왕복만 ㅘ 가 됩니다. 자음 키, 모음 키, ㅡ 키에 모두 적용됩니다.\n\n기본은 지금까지와 같은 '직각 꺾기 + 세로 왕복'이라 바꾸지 않으면 달라지는 것이 없습니다."
            ),
        ]),
        FeatureGroup(title: "영문 대문자가 편해졌어요", features: [
            Feature(
                icon: "hand.tap.fill",
                tint: .purple,
                title: "길게 눌러 대문자",
                detail: "영문 자판에서 글자 키를 꾹 누르면 대문자가 입력됩니다. 시프트를 따로 누르지 않아도 됩니다.\n\n원하지 않으시면 설정 › 키보드 › 입력 동작 › 영문에서 끌 수 있습니다."
            ),
            Feature(
                icon: "textformat",
                tint: .pink,
                title: "문장 첫 글자 자동 대문자",
                detail: "문장이 시작될 때 시프트가 자동으로 켜집니다. 아이폰 자체 설정은 서드파티 키보드로 전달되지 않아 직접 만들었습니다.\n\n기본은 꺼짐입니다. 설정 › 키보드 › 입력 동작 › 영문에서 켜세요. 이메일 주소나 검색창처럼 대문자가 어색한 입력란에서는 켜도 동작하지 않습니다."
            ),
            Feature(
                icon: "textformat.abc",
                tint: .blue,
                title: "영문 단축어가 대소문자를 가리지 않습니다",
                detail: "hi 로 등록한 단축어가 Hi 로 쳐도 변환됩니다. 자동 대문자를 켜면 문장 첫 글자가 대문자가 되는데, 영문 단축어는 대부분 문장 첫 단어라 그대로 두면 쓸 수 없었습니다. 한글 단축어는 달라지지 않습니다."
            ),
        ]),
        FeatureGroup(title: "키보드가 홈 제스처 구역을 피합니다", features: [
            Feature(
                icon: "iphone.gen3",
                tint: .pink,
                title: "하단 여백 자동 확보",
                detail: "홈 버튼이 없는 아이폰에서 스페이스바를 누르다 홈 화면으로 빠져나가는 일을 막기 위해, 화면 맨 아래 홈 제스처 구역을 비우고 키보드를 그만큼 올렸습니다. 키 크기는 그대로이고 키보드 전체 높이가 늘어납니다.\n\n예전 배치가 익숙하시면 설정 › 키보드 › 크기 · 전환 키 › 하단 여백에서 끌 수 있고, 더 올리고 싶으면 추가 여백으로 조절할 수 있습니다."
            ),
        ]),
        FeatureGroup(title: "진동 반응이 빨라졌어요", features: [
            Feature(
                icon: "hand.tap",
                tint: .orange,
                title: "누르는 순간 진동",
                detail: "키를 뗄 때가 아니라 누르는 순간 진동이 옵니다. 긋기 입력은 손가락이 붙어 있는 시간이 길어서, 획을 다 긋고 뗄 때 울리면 반응이 늦게 느껴졌습니다."
            ),
        ]),
        FeatureGroup(title: "단축어가 훨씬 자유로워졌어요", features: [
            Feature(
                icon: "text.badge.plus",
                tint: .blue,
                title: "기호가 들어간 단축어",
                detail: "마침표나 물음표를 넣은 단축어를 쓸 수 있습니다. 앞에 붙여도(.ㄱㅅ) 뒤에 붙여도(ㅏ..) 동작하고, 문장 뒤에 바로 이어 써도 변환됩니다."
            ),
            Feature(
                icon: "space",
                tint: .indigo,
                title: "변환 후 띄어쓰기 끄기",
                detail: "단축어를 확정한 스페이스를 결과 뒤에 남기지 않도록 설정할 수 있습니다. 마침표 같은 기호는 문장에 필요한 입력이라 그대로 유지됩니다."
            ),
            Feature(
                icon: "arrow.uturn.backward",
                tint: .teal,
                title: "되돌리기 켜고 끄기",
                detail: "변환 직후 백스페이스를 누르면 원래 글자로 되돌아가는 동작을 설정에서 끌 수 있습니다."
            ),
            Feature(
                icon: "shield.lefthalf.filled",
                tint: .green,
                title: "오변환 방지 · 트리거 제한",
                detail: "너무 짧은 단축어는 의도치 않게 변환되기 쉬워 기본적으로 막아 둡니다. 원하시면 설정에서 제한을 풀 수 있고, 이미 등록해 둔 단축어는 그대로 동작합니다."
            ),
        ]),
        FeatureGroup(title: "입력 방식 — 갤럭시 모아키 손버릇 그대로", features: [
            Feature(
                icon: "arrow.uturn.down",
                tint: .blue,
                title: "대각선 왕복으로 ㅐ·ㅔ·ㅢ",
                detail: "↗로 나갔다 ↙로 되돌아오면 ㅐ, ↖↘는 ㅔ, ↙↗는 ㅢ. 갤럭시에서 쓰던 왕복 손버릇이 그대로 통합니다."
            ),
            Feature(
                icon: "arrow.up.arrow.down",
                tint: .indigo,
                title: "ㅚ에서 이어 긋는 세로 체인",
                detail: "위·아래(ㅚ)로 긋고 →면 ㅘ, →←면 ㅙ, ←면 ㅕ. 고→괴→과→괘처럼 떼지 않고 이어집니다."
            ),
            Feature(
                icon: "circle.grid.cross",
                tint: .purple,
                title: "ㆍ 조합 확장",
                detail: "외+ㆍ=와, 위+ㆍ=워, 애+ㆍ=얘, 오+ㆍ=요↔오 토글까지 — 천지인 ㆍ 조합이 순정처럼 이어집니다."
            ),
            Feature(
                icon: "delete.left",
                tint: .teal,
                title: "한 자소씩 지우기",
                detail: "백스페이스가 받침 → 모음 → 자음 순서로 지웁니다. '한'에서 한 번 지우면 '하', '가'에서 지우면 'ㄱ'이 남습니다."
            ),
            Feature(
                icon: "checkmark.shield",
                tint: .green,
                title: "오타 완화",
                detail: "순정 모아키를 실측해 인식 기준을 맞췄습니다. 손을 뗄 때 튕기는 꼬리, 방향을 꺾는 모서리의 흔들림이 엉뚱한 모음으로 바뀌는 오타가 줄었습니다."
            ),
        ]),
        FeatureGroup(title: "새 도구", features: [
            Feature(
                icon: "graduationcap",
                tint: .orange,
                title: "튜토리얼 · 연습 새 단장",
                detail: "새 입력 경로에 맞춰 튜토리얼과 타이핑 연습을 다시 짰습니다. 왕복 ㅐ·ㅔ·ㅢ와 세로 체인을 여기서 익혀보세요."
            ),
            Feature(
                icon: "scope",
                tint: .pink,
                title: "긋기 테스트 — 획별 수치",
                detail: "설정 → 키보드 → 긋기 → 실시간 테스트에서 획마다 방향·각도·길이가 숫자로 보입니다. 어디서 오타가 나는지 직접 확인할 수 있습니다."
            ),
            Feature(
                icon: "note.text",
                tint: .brown,
                title: "입력 기록 보드",
                detail: "설정 하단의 보드에서 자유롭게 입력해 보고, 오타 사례를 저장해 개발자에게 메일로 바로 보낼 수 있습니다. 획별 계측이 함께 담겨 오타 분석이 빨라집니다."
            ),
        ]),
    ]

    var body: some View {
        VStack(spacing: 0) {
            header
            ScrollView {
                VStack(alignment: .leading, spacing: 12) {
                    ForEach(groups) { group in
                        Text(group.title)
                            .font(.footnote.weight(.semibold))
                            .foregroundColor(.secondary)
                            .padding(.horizontal, 4)
                            .padding(.top, 6)
                        ForEach(group.features) { featureRow($0) }
                    }
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 4)
            }
            footer
        }
        .onDisappear { markSeen() }
    }

    private var header: some View {
        VStack(spacing: 8) {
            Image(systemName: "sparkles")
                .font(.system(size: 44))
                .foregroundColor(.accentColor)
            Text("이번 업데이트")
                .font(.title2.bold())
            Text("모아+ v\(Self.appVersion) 새로운 기능")
                .font(.callout)
                .foregroundColor(.secondary)
        }
        .padding(.top, 24)
        .padding(.bottom, 16)
    }

    private var footer: some View {
        VStack(spacing: 10) {
            Button {
                markSeen()
                dismiss()
            } label: {
                Text("시작하기")
                    .font(.headline)
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(RoundedRectangle(cornerRadius: 12).fill(Color.accentColor))
            }
            Text("홈의 ‘제스처 연습하기’와 ‘자판 연습’에서 새 입력법을 익혀보세요.")
                .font(.caption2)
                .foregroundColor(Color(.tertiaryLabel))
                .multilineTextAlignment(.center)
        }
        .padding(.horizontal, 20)
        .padding(.top, 8)
        .padding(.bottom, 16)
    }

    private func featureRow(_ f: Feature) -> some View {
        HStack(alignment: .top, spacing: 14) {
            Image(systemName: f.icon)
                .font(.system(size: 22))
                .foregroundColor(f.tint)
                .frame(width: 38, height: 38)
                .background(Circle().fill(f.tint.opacity(0.15)))
            VStack(alignment: .leading, spacing: 4) {
                Text(f.title)
                    .font(.headline)
                    .foregroundColor(.primary)
                Text(f.detail)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 0)
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: 12).fill(Color(.secondarySystemBackground)))
    }

    /// 현재 앱 버전(CFBundleShortVersionString). 트리거 비교와 동일한 값을 써야
    /// 모달이 닫힌 뒤 재표시되지 않는다.
    static var appVersion: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.7.2"
    }

    private func markSeen() {
        if settings.lastSeenWhatsNewVersion != Self.appVersion {
            settings.lastSeenWhatsNewVersion = Self.appVersion
        }
    }
}

#Preview {
    NewFeaturesModalView()
}
