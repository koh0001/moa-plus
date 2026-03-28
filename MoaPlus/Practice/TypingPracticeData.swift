import Foundation

struct TypingPracticeItem: Identifiable {
    let id: Int
    let title: String
    let author: String
    let category: PracticeCategory
    let lines: [String]
}

enum PracticeCategory: String, CaseIterable {
    case poem = "시"
    case proverb = "속담"
    case sentence = "문장"

    var icon: String {
        switch self {
        case .poem: return "book"
        case .proverb: return "quote.bubble"
        case .sentence: return "text.alignleft"
        }
    }
}

enum TypingPracticeContent {
    static let items: [TypingPracticeItem] = [
        // MARK: - 고전 시 (저작권 만료)

        TypingPracticeItem(
            id: 1,
            title: "서시",
            author: "윤동주",
            category: .poem,
            lines: [
                "죽는 날까지 하늘을 우러러",
                "한 점 부끄럼이 없기를",
                "잎새에 이는 바람에도",
                "나는 괴로워했다",
            ]
        ),

        TypingPracticeItem(
            id: 2,
            title: "별 헤는 밤",
            author: "윤동주",
            category: .poem,
            lines: [
                "계절이 지나가는 하늘에는",
                "가을로 가득 차 있습니다",
                "나는 아무 걱정도 없이",
                "가을 속의 별들을 다 헤일 듯합니다",
            ]
        ),

        TypingPracticeItem(
            id: 3,
            title: "님의 침묵",
            author: "한용운",
            category: .poem,
            lines: [
                "님은 갔습니다",
                "아아 사랑하는 나의 님은 갔습니다",
                "푸른 산빛을 깨치고",
                "단풍나무 숲을 향하여 난 작은 길을",
                "걸어서 차마 떨치고 갔습니다",
            ]
        ),

        TypingPracticeItem(
            id: 4,
            title: "진달래꽃",
            author: "김소월",
            category: .poem,
            lines: [
                "나 보기가 역겨워",
                "가실 때에는",
                "말없이 고이 보내 드리오리다",
                "영변에 약산",
                "진달래꽃",
                "아름 따다 가실 길에 뿌리오리다",
            ]
        ),

        TypingPracticeItem(
            id: 5,
            title: "풀",
            author: "김수영",
            category: .poem,
            lines: [
                "풀이 눕는다",
                "비를 몰아오는 동풍에 나부껴",
                "풀은 눕고",
                "드디어 울었다",
                "날이 흐려서 더 울다가",
                "다시 누웠다",
            ]
        ),

        TypingPracticeItem(
            id: 6,
            title: "나그네",
            author: "박목월",
            category: .poem,
            lines: [
                "강나루 건너서",
                "밀밭 길을",
                "구름에 달 가듯이",
                "가는 나그네",
            ]
        ),

        TypingPracticeItem(
            id: 7,
            title: "승무",
            author: "조지훈",
            category: .poem,
            lines: [
                "얇은 사 하이얀 고깔은",
                "고이 접어서 나빌레라",
                "파르라니 깎은 머리",
                "박사 고깔에 감추오고",
            ]
        ),

        TypingPracticeItem(
            id: 8,
            title: "광야",
            author: "이육사",
            category: .poem,
            lines: [
                "까마득한 날에",
                "하늘이 처음 열리고",
                "어디 닭 우는 소리 들렸으랴",
                "모든 산맥들이",
                "바다를 연모해 휘달릴 때도",
                "차마 이곳을 범하던 못하였으리라",
            ]
        ),

        // MARK: - 속담 (전래, 저작권 없음)

        TypingPracticeItem(
            id: 9,
            title: "속담 모음 1",
            author: "전래",
            category: .proverb,
            lines: [
                "가는 말이 고와야 오는 말이 곱다",
                "고생 끝에 낙이 온다",
                "구슬이 서 말이라도 꿰어야 보배",
                "남의 떡이 커 보인다",
                "누워서 떡 먹기",
            ]
        ),

        TypingPracticeItem(
            id: 10,
            title: "속담 모음 2",
            author: "전래",
            category: .proverb,
            lines: [
                "돌다리도 두들겨 보고 건너라",
                "등잔 밑이 어둡다",
                "말 한마디에 천 냥 빚을 갚는다",
                "백지장도 맞들면 낫다",
                "세 살 버릇 여든까지 간다",
            ]
        ),

        TypingPracticeItem(
            id: 11,
            title: "속담 모음 3",
            author: "전래",
            category: .proverb,
            lines: [
                "아는 길도 물어가라",
                "열 번 찍어 안 넘어가는 나무 없다",
                "우물 안 개구리",
                "원숭이도 나무에서 떨어진다",
                "콩 심은 데 콩 나고 팥 심은 데 팥 난다",
            ]
        ),

        TypingPracticeItem(
            id: 12,
            title: "속담 모음 4",
            author: "전래",
            category: .proverb,
            lines: [
                "하늘이 무너져도 솟아날 구멍이 있다",
                "호랑이도 제 말 하면 온다",
                "천 리 길도 한 걸음부터",
                "티끌 모아 태산",
                "빈 수레가 요란하다",
            ]
        ),

        // MARK: - 일상 문장 (직접 작성, 저작권 본인)

        TypingPracticeItem(
            id: 13,
            title: "일상 인사",
            author: "연습용",
            category: .sentence,
            lines: [
                "안녕하세요 오늘 하루도 좋은 하루 되세요",
                "오랜만이에요 잘 지내셨어요?",
                "감사합니다 덕분에 잘 해결했습니다",
                "수고하셨습니다 내일 뵙겠습니다",
            ]
        ),

        TypingPracticeItem(
            id: 14,
            title: "업무 문장",
            author: "연습용",
            category: .sentence,
            lines: [
                "회의 시간을 오후 세 시로 변경하겠습니다",
                "첨부 파일 확인 부탁드립니다",
                "진행 상황을 공유해 주시면 감사하겠습니다",
                "다음 주 월요일까지 완료하겠습니다",
            ]
        ),

        TypingPracticeItem(
            id: 15,
            title: "메시지 연습",
            author: "연습용",
            category: .sentence,
            lines: [
                "오늘 저녁에 시간 괜찮으세요?",
                "맛있는 거 먹으러 갈까요?",
                "주말에 같이 영화 보러 갈래요?",
                "조금 늦을 것 같아요 먼저 가 계세요",
            ]
        ),

        TypingPracticeItem(
            id: 16,
            title: "날씨와 계절",
            author: "연습용",
            category: .sentence,
            lines: [
                "오늘 날씨가 정말 좋네요",
                "벚꽃이 활짝 피었습니다",
                "가을 하늘이 높고 맑습니다",
                "첫눈이 내리기 시작했어요",
            ]
        ),

        TypingPracticeItem(
            id: 17,
            title: "음식 이야기",
            author: "연습용",
            category: .sentence,
            lines: [
                "된장찌개와 김치가 잘 어울립니다",
                "이 집 떡볶이는 정말 맛있어요",
                "커피 한 잔 하면서 쉬어 가세요",
                "어머니가 해주신 밥이 제일 맛있다",
            ]
        ),

        TypingPracticeItem(
            id: 18,
            title: "여행 문장",
            author: "연습용",
            category: .sentence,
            lines: [
                "제주도 바다가 정말 아름다워요",
                "서울에서 부산까지 기차로 두 시간 반",
                "여행 가방을 미리 챙겨 놓았어요",
                "다음 휴가에는 어디로 갈까요?",
            ]
        ),

        TypingPracticeItem(
            id: 19,
            title: "개발자 문장",
            author: "연습용",
            category: .sentence,
            lines: [
                "이 버그는 재현이 안 되는데요",
                "코드 리뷰 부탁드립니다",
                "배포 전에 테스트를 한 번 더 돌려 주세요",
                "이 기능은 다음 스프린트에서 진행하겠습니다",
            ]
        ),

        TypingPracticeItem(
            id: 20,
            title: "한글 타자 연습",
            author: "연습용",
            category: .sentence,
            lines: [
                "다람쥐 헌 쳇바퀴에 타고파",
                "키스의 고유 조건은 입술끼리 만나야 한다",
                "꽃이 피는 봄이 오면 나들이를 갑니다",
                "짧은 글에도 긴 생각이 담길 수 있습니다",
            ]
        ),
    ]
}
