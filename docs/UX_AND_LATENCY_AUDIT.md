# 조사 결과 — 설정 UX 재설계 + 입력 반응속도 근본 원인

> 출처: 워크플로 `wf_1789e35f-f0b` (5개 렌즈 병렬 감사 + 합성, 에이전트 6). 수령 2026-08-10.
> 기준선: `feat/symbol-pages-space-scroll` 워킹트리(미커밋). 수령 직후 `git status` + 실험 마커 grep 으로
> **작업트리 오염 없음** 확인함(HANDOFF §0-1 절차).
>
> ⚠️ **모든 수치는 Instruments 실측이 아니라 코드 정적 분석 기반 추정이다.** 파일:라인 인용은
> 에이전트가 직접 확인했다고 보고한 것이나, 착수 전 해당 라인을 다시 읽고 검증할 것.

---

## 1. 설정 UX 재설계

### 진단

핵심 문제는 "설정이 없다"가 아니라 "있는 설정에 도달할 수 없다"이다. 앱스토어 리뷰 7건 중 5건(진입앵글·힌트·특수문자·반응속도·지구본)은 해당 기능이 이미 존재하거나 인접 기능이 존재하는데도 사용자가 찾지 못한 발견성 실패다.

근거가 있는 구조적 원인 6가지:

(1) 키보드 안에 설정 진입점이 0개 — `grep -rn "openURL|extensionContext" MoaPlusKeyboard/` → 0건(직접 확인). 오타는 전부 카톡/메모 같은 호스트 앱 안에서 발생하는데, 거기서 설정으로 가려면 앱 이탈 → 홈 → 모아+ 실행 → 설정(1) → 키보드(2) → 제스처(3) → 방향별 좌/우 각도(4). 명목 깊이 4, 실사용 깊이 6.

(2) 전역 검색 없음 — 앱 전체에서 `.searchable` 은 단 1곳, 단축어 화면뿐이다(MoaPlus/Settings/AbbreviationSettingsView.swift:127). 즉 SwiftUI searchable 패턴은 이미 이 코드베이스에 동작하는 형태로 존재하는데 설정 루트에는 적용돼 있지 않다. 기능의 앱 내부 명칭(멀티스트로크, 섹터 각도, 보조 매핑)을 모르면 도달 수단이 물리적으로 0이다.

(3) '도움말'이 도움말이 아님 — MoaPlus/Settings/HelpView.swift 는 전체 56줄, 버튼 2개(튜토리얼 다시보기·타이핑 연습)뿐. FAQ도 '증상→설정' 인덱스도 없다.

(4) 서로 무력화하는 설정이 다른 화면에 산다 — '4방향 전용 모드' 스위치는 레이아웃 화면(LayoutCustomizationView.swift:97)에 있는데, 무력화 대상은 전부 제스처 화면(GestureSettingsView.swift:73,143,185-187 의 .disabled)이다. 사용자는 각도를 고치러 들어갔다 회색 컨트롤과 '레이아웃에서 변경하세요' 각주만 본다. 더 나쁜 건 프리셋을 모던 이외로 바꾸면 fourWayMode 가 조용히 false 로 기록된다는 점(LayoutCustomizationView.swift:397-399, 확인함) — 알림 없음, 복귀 시 복원 없음.

(5) 효과 없는 컨트롤이 활성 상태로 남아 있음 — 4방향 모드에서 열별 'ㅣ/ㅡ 인식 폭 보정' 슬라이더는 코드상 무시된다. GestureDirection.swift:72-86 의 fourWay 분기는 주석까지 "Sector half-widths are ignored here — the quadrant split is fixed at 45°"라고 명시하는데(직접 확인), 같은 화면의 회전 보정(rotationOffset, :70)은 분기 이전에 적용돼 실제로 동작한다. 같은 화면에서 어떤 슬라이더는 먹고 어떤 건 안 먹는데 UI가 구분하지 않는다 = "뭘 만져도 소용없다"는 인상의 직접 원인.

(6) 끌 수 없는 힌트 — ConsonantKeyView.swift:45 의 `if let action = secondaryAction, showSecondaryHints` 게이트는 보조 매핑 힌트 하나만 가린다. ㅣ/ㅡ 모음 키의 방향 힌트(:177-200, 9pt·opacity 0.5 의 ㅕㅓㅏㅑ / ㅗㅛㅠㅜ)는 showSecondaryHints 검사 없이 무조건 렌더된다(직접 확인). 리뷰 '글자 힌트를 지우지 못한다'는 설정 부재가 맞다 — 이것만 유일하게 재배치가 아니라 신규 설정이 필요하다.

추가로: '반응'이라는 최상위 메뉴가 사운드/햅틱 전용이라 '반응속도가 느리다'는 사용자를 정확히 오도하고(네이밍 트랩), 전역 초기화 UI가 없으며(KeyboardSettings.swift:398 resetAll 구현 완료, 호출처 0건 — 직접 확인), 도달 불가능한 고아 화면 SpecialCharSettingsView 가 존재하지 않는 동작('지구본 탭 = 특수문자 레이어')을 설명하고 있다.

### 제안 구조

```
원칙: ① 증상으로 진입할 길을 최상단에 둔다 ② 통증이 발생하는 곳(키보드)에서 설정으로 가는 길을 만든다 ③ 서로 무력화하는 설정은 같은 화면에 둔다 ④ 레이블은 결과로 말한다 ⑤ 기능 삭제 없음 — 재배치·재명명·묶기만.

[키보드 익스텐션 — 신설 진입점]
기능행 '123' 또는 '한/영' 키 롱프레스 → 미니 시트
  ├ 오타가 잦아요 → moaplus://settings/accuracy
  ├ 키가 너무 커요/작아요 → moaplus://settings/size
  └ 모든 설정 열기 → moaplus://settings
  * extensionContext.open() 사용, Full Access 불필요. responder chain 우회 필요.

[메인 앱]
홈
├ 키보드 배우기 (튜토리얼 · 타이핑 연습)  ← 기존
└ 설정  ★ 루트에 .searchable 추가 (AbbreviationSettingsView.swift:127 패턴 재사용)
   │
   ├ 0. 이럴 때 어떻게 하나요  ★ HelpView 를 '증상 → 설정' 라우터로 재작성 (삭제 아님)
   │    · "오타가 잦아요"              → 1. 입력 정확도
   │    · "빨리 치면 ㅛ·ㅠ·ㅢ 가 안 나와요" → 1 > 멀티스트로크 민감도 (앵커 스크롤)
   │    · "키에 작은 글자가 보여요"      → 4 > 키 힌트
   │    · "다른 키보드(지구본)로 못 바꿔요" → 2 > 지구본 키
   │    · "특수문자를 바꾸고 싶어요"      → 3 > 특수문자 구성
   │    · "키보드가 너무 커요/작아요"     → 2. 크기와 여백
   │    · 튜토리얼 다시 보기 / 타이핑 연습 (기존 버튼 유지)
   │
   ├ 1. 입력 정확도  ← 구 '제스처(긋기)' + 레이아웃에서 이관된 4방향 토글
   │    [정확도 프리셋] 안정 우선 / 균형(기본) / 속도 우선   ★신설(기존 노브 묶음, 새 저장키 1)
   │    · 대각선 끄고 상하좌우만 인식      ← 구 '4방향 전용 모드' (레이아웃에서 이동)
   │        └ ON 시 아래 '진입 각도' 블록 전체가 회색 + 인라인 사유 표시 (같은 화면이라 관계가 보임)
   │        └ 모던 레이아웃에서만 가능 — 다른 프리셋 선택 시 인라인 경고 + 모던 복귀 시 복원
   │    · 긋기 진입 각도                 ← 구 '긋기 각도' 프리셋 (개명: '진입' 단어 추가)
   │    · 긋기 길이
   │    · ㅛ·ㅑ·ㅕ 가 잘 안 써질 때       ← 구 '멀티스트로크 민감도' (증상 기반 개명, 값 이름은 유지)
   │    · 복합모음 입력 방식: 순정 모아키(기본) / 확장 — 대각선 진입, 오타 위험
   │        ← 워킹트리의 consonantDiagonalDerivationEnabled 와 동일 스위치
   │    · 실시간 테스트 (GestureTestView)
   │    └ 고급 ▸
   │         ├ 방향별 좌/우 각도 (8방향 × 좌우 폭 · 전체 회전)
   │         ├ 세로 라인별 보정 (열별 회전 · ㅣ/ㅡ 폭 · 전환 거리)
   │         │    ★ 4방향 ON 이면 ㅣ/ㅡ 폭 슬라이더를 .disabled + "4방향에서는 각 방향이 고정 90° 구역을 쓰므로 효과 없음" 표기 (회전 보정은 계속 활성 — 실제로 동작하므로)
   │         └ 방향별 모음 매핑 (↖↗↙↘)
   │              ★ 순정 모드일 때 "현재 순정 방식이라 이 매핑은 ㅣ/ㅡ 단독 입력에만 적용" 표기
   │
   ├ 2. 크기와 여백  ← 구 '크기 · 전환 키' + 레이아웃의 키 폭 슬라이더 통합
   │    · 키보드 높이 (0.85~1.35)                     ← 기존(워킹트리)
   │    · 좌우 끝 키 폭 (0.15~1.0)                    ← 레이아웃에서 이동 (sideKeyWidthRatio)
   │    · 좌우 여백 / 하단 여백                        ★신설 (저장키 2개 신규)
   │    · 지구본 키(다른 키보드로 전환) 표시           ← 개명: 레이블에 '지구본' 명시
   │    · 미리보기 (라이브)
   │
   ├ 3. 키 배치  ← 구 '레이아웃 커스터마이즈' (4방향 토글·키 폭 슬라이더 이관 후)
   │    · 우측 컬럼 프리셋 (모던/클래식/확장형)
   │    · 백스페이스 위치 (모던일 때만 조절 가능 — 다른 프리셋에선 '프리셋이 결정' 캡션)
   │    · 좌측 컬럼 셀 / 우측 컬럼 셀
   │    · 스페이스 옆 키 사용  ← 개명(구 '스페이스 옆 특수키 사용')
   │         └ 특수문자 / 모음 키(tap=ㆍ + 8방향)  — OFF 여도 선택값을 회색으로 계속 표시
   │    · iPad 세로 분리 / 숫자패드 위치
   │    └ 특수문자 구성 ▸  ★ 고아 화면 SpecialCharSettingsView 를 여기로 되살림(삭제 아님, 내용 재작성)
   │         ├ 123 키패드 1페이지 / 2페이지     ★신설 (현재 KeyboardMetrics.symbolLayout 하드코딩)
   │         ├ 우측 컬럼 특수키 슬롯 (탭/←/→/↑/↓)   ← 기존
   │         ├ 스페이스 옆 특수키 슬롯              ← 기존
   │         └ 영문 자판 특수키 슬롯                ← 기존
   │
   ├ 4. 화면에 보이는 것  ← 구 '외형' + 롱프레스에서 이관된 힌트 3종
   │    · 테마 모드 / 버튼 색상 / 커스텀 색 / 투명도 / 배경 이미지   ← 기존
   │    · 키 힌트(숫자·기호) 표시            ← showSecondaryHints, 롱프레스에서 이동
   │    · 모음 방향 힌트(ㅏㅑㅓㅕ·ㅗㅛㅜㅠ) 표시  ★신설 토글 (저장키 1개 신규)
   │    · 힌트 크기 / 전체 후보 표시          ← 롱프레스에서 이동
   │    · 입력 중 긋기 방향 표시              ← 구 '제스처 미리보기' (개명: 설정화면 미리보기와 구분)
   │
   ├ 5. 반응 속도  ★신설 묶음 — '반응' 네이밍 트랩 해소
   │    · 롱프레스 반응 시간                 ← 롱프레스에서 이동
   │    · 백스페이스 반복 속도               ← 백스페이스에서 이동
   │    · 커서 연속 이동 속도                ← 입력 동작에서 이동
   │    · [링크 행] 긋기 길이 · 멀티스트로크 민감도 → 1. 입력 정확도 (값 요약 뱃지 표시)
   │       ★ 값을 복제하지 않고 링크만 — 설명 문구는 상수 1곳에서 공유 (현재 GestureSettingsView:95-116 과 GestureTestView:308-330 이 같은 설정을 다른 문구로 2번 노출)
   │
   ├ 6. 소리와 진동  ← 구 '반응' 개명 (내용 그대로)
   │
   ├ 7. 입력 편의  ← 구 '입력 동작' + 백스페이스 잔여 + 단축어
   │    · 괄호 자동 닫기 / 더블 스페이스 마침표 / 스페이스 드래그 커서 / 마지막 모드 기억
   │    · 단어 단위 삭제 + 전환 시간
   │    · 롱프레스 키 매핑 29키 (구 '롱프레스(보조 매핑)' 의 본체)
   │    · 단축어 (CRUD)
   │
   └ 8. 앱 정보
        · 크레딧 / 라이선스 / 링크
        · 모든 설정 초기화  ★신설 — KeyboardSettings.resetAll() (KeyboardSettings.swift:398, 현재 호출처 0건) 을 확인 알림과 함께 연결

깊이 비교: 각도 프리셋 3→2, 4방향 토글 3→2, 힌트 3→2, 지구본 2(레이블에 단어 노출), 특수문자 구성 3(기존 3, 그러나 '특수문자' 단어로 검색 가능), 열별 보정 4(유지 — 전문 설정은 접어두되 도달 가능).
```

### 근거

1) 증상 라우터(0번)와 전역 검색이 최우선인 이유: 리뷰 5건은 전부 마지막 관문이 같다 — 앱 내부 명칭을 모르면 도달 불가. '진입앵글'·'지구봉'·'글자 힌트'는 전부 사용자 어휘이고 앱 어휘가 아니다. IA를 아무리 잘 짜도 어휘 다리가 없으면 같은 리뷰가 반복된다. 검색은 AbbreviationSettingsView.swift:127 에 이미 동작하는 .searchable 이 있어 구현 비용이 낮다.

2) 키보드 내 딥링크가 IA 재배치보다 앞서는 이유: 통증은 호스트 앱 안에서 발생하는데 거기서 나가는 문이 없다. 명목 4탭을 3탭으로 줄여도 실사용 6→5일 뿐이다. 문 하나가 6→1이 된다.

3) 4방향 토글을 각도 화면으로 옮기는 이유: 킬 스위치는 자신이 죽이는 설정과 같은 화면에 있어야 관계가 보인다. 현재는 스위치(LayoutCustomizationView:97)와 시체(GestureSettingsView:73,143,185-187 의 .disabled)가 다른 화면에 있어, 사용자는 원인을 볼 수 없는 결과만 본다. 같은 화면에 두면 '회색이 된 이유'가 바로 위 줄에 있다.

4) 레이블을 결과로 바꾸는 근거: '멀티스트로크 민감도'는 증상('ㅛ가 안 써짐')과 언어적 연결이 0이다. '4방향 전용 모드'도 뭐가 좋아지는지 말하지 않는다. footer 는 이미 결과를 정확히 설명하고 있으므로(끔 = "처음 위치로 정확히 되돌아와야 인식"), 그 문장을 제목 높이로 끌어올리는 것이 비용 대비 효과가 가장 크다.

5) 힌트 3종을 외형으로 옮기는 이유: 사용자는 '키에 작은 글자가 보인다'를 시각 문제로 인식한다. 탐색 경로는 '외형'이지 '롱프레스'가 아니다. 현재 외형 화면에는 힌트 항목이 하나도 없고, 롱프레스 행은 요약 텍스트조차 없어 안에 뭐가 있는지 단서가 0이다.

6) 크기 3종 통합의 이유: '높이'(크기 화면)와 '좌우 끝 키 폭'(레이아웃 화면 맨 아래)이 같은 '크기' 개념인데 두 화면에 흩어져 있다. 리뷰 '좌우 여백설정으로 크기를 줄일수있으면'은 sideKeyWidthRatio 로 부분 충족 가능한데 레이블이 '좌우 특수키'라 연결되지 않는다. 한 화면에 모으면 기존 기능이 즉시 회수되고, 신설할 여백 2종의 자리도 자연스럽다.

7) 삭제 대신 재활용: SpecialCharSettingsView 는 도달 불가 + 내용 오류(존재하지 않는 '지구본 탭 = 특수문자 레이어')지만, 삭제하면 다음 사람이 '특수문자 설정을 새로 만들자'며 처음부터 시작한다. '특수문자 구성' 진입점으로 되살리면 리뷰(쪼꼬파이원츄)가 요청한 123 키패드 커스터마이즈의 착지점이 생기고, 동시에 이미 구현돼 있으나 '레이아웃'에 숨어 있던 슬롯 편집기 3벌이 '특수문자'라는 단어 아래로 회수된다.

8) '반응 속도'를 분리하는 이유: 최상위 '반응' 메뉴가 사용자 단어와 정확히 일치하는데 내용은 사운드/햅틱뿐이라, '반응속도가 느리다'는 사용자를 끌어들여 빈손으로 돌려보낸다. 속도 노브 4개는 실제로 4개 화면에 흩어져 있다. 이름을 바꾸고(→소리와 진동) 진짜 속도 화면을 만드는 것이 최소 수술이다. 단, 값 복제는 금지 — 같은 설정이 다른 문구로 두 번 나타나는 현행 문제(GestureSettingsView:95-116 vs GestureTestView:308-330)를 확대하지 않기 위해 링크 행 + 공유 문구 상수를 쓴다.

9) 전역 초기화: 각도·열 보정을 실험하다 입력이 망가진 사용자가 현재 할 수 있는 건 11개 화면을 돌며 개별 복원 버튼을 찾는 것뿐이다. resetAll() 은 이미 구현돼 있고 호출처만 없다 — 앱 삭제 대신 복구할 길을 여는 데 드는 비용이 사실상 UI 1개다.

### 마이그레이션 위험

[A. 저장 키 — 가장 큰 위험, 그러나 회피 가능]
App Group `group.com.moaki.keyboard` 의 키 이름을 바꾸면 기존 사용자 설정이 소실된다(CLAUDE.md: 변경 금지). 본 제안은 원칙적으로 뷰 트리 재배치 + 레이블 변경만이므로 **기존 24개 영속 키는 단 하나도 이름을 바꾸지 않는다**. showSecondaryHints/hintSize/showAllCandidates 를 롱프레스→외형으로, sideKeyWidthRatio 를 레이아웃→크기로 옮기는 것은 NavigationLink 위치 변경일 뿐 저장 계층과 무관하다.
신규 키가 필요한 항목은 5개뿐: 모음 방향 힌트 토글, 좌우 여백, 하단 여백, 심볼 레이아웃 커스터마이즈, 정확도 프리셋(+4방향 복원용 직전값 1개). 전부 CLAUDE.md 체크리스트대로 ①@Published + isLoading 가드 ②loadAll() 로드 라인 ③resetAll() 기본값 라인 3곳을 모두 건드려야 한다 — 워킹트리가 keyboardHeightScale/showGlobeKey/consonantDiagonalDerivation 을 추가하며 정확히 그 3곳을 수정한 전례가 있으니(KeyboardSettings.swift:18-20,113-145,348-350,408-410) 그대로 따르면 된다.

[B. 위치 이동으로 인한 재학습 비용]
기존 사용자는 근육 기억으로 '롱프레스 → 힌트', '레이아웃 → 키 폭'을 찾는다. 완화책: 구 위치에 최소 1개 릴리스 동안 '이동됨' stub 행을 남긴다(예: 롱프레스 화면에 "힌트 표시 → '화면에 보이는 것'으로 이동했습니다" 링크 행). 검색이 함께 들어가면 stub 없이도 회수되지만, 검색은 구현이 늦어질 수 있으므로 stub 을 선행 안전망으로 둔다.

[C. 4방향 토글 이동 시 동작 변경 주의]
fourWayMode 저장값 자체는 그대로다. 그러나 현행 '프리셋을 모던 이외로 바꾸면 조용히 false' 동작(LayoutCustomizationView.swift:397-399)을 '인라인 경고 + 모던 복귀 시 복원'으로 바꾸려면 직전값 기억 키가 1개 필요하고, 이때 **기존 사용자 중 이미 false 로 기록된 사람의 원래 의도는 복원할 수 없다**(기록이 없음). 복원 로직은 신규 기록 시점 이후부터만 동작하며, 이를 릴리스 노트에 명시해야 한다.

[D. 기본값 변경은 이번 재설계에 포함하지 않는다]
멀티스트로크 민감도 기본값 0→1 은 리뷰(ㅛ·ㅜ·ㅢ)를 직접 겨냥하지만, 이미 '끔'에 적응한 기존 사용자 전원의 입력 특성을 말없이 바꾼다. footer 가 스스로 경고하듯 '보통/민감'은 ㅗ·ㅜ·ㅏ·ㅓ 를 ㅚ·ㅛ·ㅐ·ㅑ 로 오인식할 수 있다. 게다가 지연 개선(랭킹 1~2번)만으로 같은 증상이 해소될 가능성이 있으므로, **성능 수정 후 재측정 전까지 기본값은 건드리지 않는다**(openQuestions 참조). 재설계는 이름·위치만 바꾸고 값은 그대로 둔다 — 이것이 마이그레이션 리스크가 가장 낮은 조합이다.

[E. 안내 채널 자체의 결함을 함께 고치지 않으면 재설계가 전달되지 않는다]
What's New 모달의 features 배열은 하드코딩이며 1.7.2 이후 갱신되지 않아 1.8.0 사용자가 1.7 기능 목록을 본다. 더 심각한 건 신규 설치자가 ContentView.swift:104-113 에서 lastSeenWhatsNewVersion 을 미리 현재 버전으로 기록해 모달을 **영구히 건너뛴다**는 점이다. IA 를 바꾸면 '설정이 어디로 갔는지' 알릴 채널이 필요한데 그 채널이 지금 새고 있다. 완화책: (1) features 배열 갱신을 릴리스 체크리스트에 넣고 (2) 신규 설치자 스킵 로직을 재검토하며 (3) 모달을 1회성으로 소멸시키지 말고 '앱 정보'에서 다시 볼 수 있게 한다.

[F. 문구 오류 동반 수정 필수]
홈 화면 상태 카드의 '🌐 버튼으로 키보드 전환'(ContentView.swift:156)과 SpecialCharSettingsView.swift:31 의 '지구본 짧게 탭 = 특수문자 레이어'는 현재 UI 와 불일치한다. 워킹트리에 showGlobeKey 토글이 들어오는 중이므로, 이 두 문구를 함께 정정하지 않으면 '지구봉 어디 있나요' 리뷰가 그대로 재발한다.

---

## 2. 입력 반응속도 — 우선순위 계획 (12건)

> **진행 상황 (2026-08-10)** — 1~6·9 구현 완료. 각 항목을 **하나씩 적용하고 매번 전체
> 테스트를 돌린 뒤** 커밋했다(효과를 항목별로 귀속시키기 위해). 전부 통과.
>
> | # | 커밋 |
> |---|---|
> | 1 | `bb3b4dc` 제스처 상태 포워딩 setter 중복 발행 제거 |
> | 2 | `8ebd730` 활성 키 내용 제스처 시작 시 1회 조회 |
> | 3 | `ecf3b0e` KeyGridView 레이아웃 body 당 1회 |
> | 4 | `c3b0b36` 롱프레스 매핑 딕셔너리 인덱스 |
> | 5 | `1e62a50` 키 색상 캐시 |
> | 6 | `03ee130` loadAll 동등성 가드 |
> | 9 | `abe9a46` 죽은 feedbackGenerator 제거 + pow 제거 |
>
> **7·10·11·12 는 미착수.** 특히 **7번은 의도적으로 남겼다** — 감사가 유일하게
> "인식률에 직접 닿는 경로"로 표시했고, 그 전제(임계값·섹터 폭이 제스처 중 불변)가
> 아래 미해결 질문 2번에 미검증으로 남아 있다. 착수하려면 그 두 경로를 먼저 읽을 것.
>
> **아직 실측은 하지 않았다.** 미해결 질문 3번의 검증 순서(os_signpost + Time Profiler
> → ㅛ/ㅠ/ㅢ 빠른 입력 재현)가 그대로 남아 있고, 그게 "리뷰 증상 = 렌더 병목" 인과를
> 확정하는 유일한 방법이다.
>
> 구현 중 확인한 것 하나: 6번을 넣으면서 5번의 색 캐시와 4번의 인덱스 캐시가
> "값이 같으면 didSet 이 안 돌아 재빌드가 생략"되는데, 값이 같으니 재계산할 것도
> 없어 안전하다. 세 항목을 같이 넣을 때 이 상호작용을 확인할 것.

| # | 항목 | 규모 | 위험 |
|---|---|---|---|
| 1 | gestureMoved 의 @Published 무조건 대입 → 동등성 가드 (터치 포인트당 전체 키보드 리렌더 제거) | small | 매우 낮음 |
| 2 | gestureMoved 가 셀 1개 읽으려고 4×7 레이아웃 배열을 매 포인트마다 재생성 → gestureStarted 시점  | small | 낮음 |
| 3 | KeyGridView 가 한 번의 body 평가에서 activeLayout 을 6회 재구축 | small | 낮음-중간 |
| 4 | secondaryAction 조회가 키마다 29개 배열 선형 String 탐색 → 딕셔너리 인덱스 | small | 낮음 |
| 5 | 키마다 themeSettings 재조회 → 구조체 복사·Color 재생성·ARC 트래픽 (상위 1회 조회 후 prop 하향) | medium | 낮음-중간 |
| 6 | loadAll() 의 @Published 28개 무조건 재대입 → 동등성 가드 (콜드스타트 3중 호출 + 크로스프로세스 전체  | small | 낮음 |
| 7 | GestureAnalyzer 가 터치 포인트마다 섹터 배열 복사 + 컬럼 오버라이드 5~8회 선형 탐색 → 제스처 시작 시점  | medium | **중간 |
| 8 | 조합 중 프록시 IPC 5~12회/글자 → updateComposingText 공통 접두 스킵 + textDidChange 컨 | medium | **높음 |
| 9 | 무손실 정리 묶음 — 미사용 feedbackGenerator, pow() 2회/포인트, viewDidLoad 중복 loadAl | small | 매우 낮음 |
| 10 | FunctionKeyView 의 AnyView 타입 소거 제거 (제네릭화) | medium | 낮음-중간 |
| 11 | 구조 리팩터 — KeyView Equatable 화(KeyEventRouter) + gestureState/popupState | large | 중간-높음 |
| 12 | 배경 이미지 상주 비트맵 축소 + touchPoints 무제한 증가 (지연보다 메모리 항목) | medium | (a) 낮음-중간 |

### 1. gestureMoved 의 @Published 무조건 대입 → 동등성 가드 (터치 포인트당 전체 키보드 리렌더 제거)

**원인**

gestureMoved(to:) 가 매 터치 포인트마다 `gestureDirections = directions` 와 `previewVowel = ...` 을 값 비교 없이 대입한다. @Published 는 동일 값에도 objectWillChange 를 발행하고, KeyboardView 가 gestureState 를 루트에서 @ObservedObject 로 관찰하므로 KeyboardView.body → KeyGridView → 28개 KeyView → FunctionRowView 가 전부 재평가된다. 실제 directions 배열은 한 번의 긋기에서 2~4회만 바뀌는데, 120Hz 200ms 긋기 = 약 24회 전체 리빌드가 발생한다. 하위에서 단락이 불가능한 이유는 KeyGridView 가 body 마다 키별로 row/column 을 캡처한 클로저 9개를 새로 만들어 KeyView 에 넘기기 때문(SwiftUI 필드 비교가 절대 일치하지 않음).

**수정**

대입 전 값 비교 가드를 넣는다. `if gestureState.directions != directions { gestureState.directions = directions }`, previewVowel 도 동일. [GestureDirection] 과 Jungseong? 모두 Equatable 이라 코드 3줄. 동일 가드를 dismissPopup()/resetGestureState() 의 7개 @Published 순차 대입에도 적용한다(대부분 이미 nil 인데 매 제스처 종료마다 발화). 중요: previewVowel 을 '오버레이 꺼져 있으면 발행 안 함'으로 억제하면 안 된다 — previewVowel 은 키 자체의 미리보기 라벨(ConsonantKeyView.swift:143-148,171,188)에도 쓰이므로 억제가 아니라 dedupe 가 정답.

**기대 효과**

긋기 1회당 전체 트리 리빌드 ~24회 → ~3회. 파생 효과로 항목 3~5의 비용(레이아웃 배열 36개/렌더, 문자열 비교 ~812회/렌더, ThemeSettings 복사 56회/렌더)이 같은 배수로 줄어든다. 메인 스레드 여유가 생기면 UIKit 의 터치 코얼레싱/드롭이 줄어 GestureAnalyzer 가 받는 샘플 밀도가 올라간다 → 반전 획이 필요한 ㅛ(↑↓↑)·ㅠ(↓↑↓)·ㅢ 의 인식률이 **올라간다**. 지연과 인식률이 같은 방향으로 움직이는 유일한 항목.

**위험** (small)

매우 낮음. 순수 중복 발행 제거이며 값이 실제로 바뀌면 그대로 발행된다. 유일한 주의점은 dedupe 를 previewVowel 억제로 잘못 구현하는 것(키 위 미리보기가 사라짐). 인식 파라미터를 전혀 건드리지 않으므로 GestureAnalyzer 계열 테스트에 영향 없음. 이 수정을 먼저 넣고 ㅛ/ㅠ/ㅢ 빠른 입력을 재측정한 뒤에야 각도·임계값을 손대야 한다.

**근거**

기준선: 워킹트리 feat/symbol-pages-space-scroll(미커밋 17파일). git diff 확인 결과 이 수정은 워킹트리에 없음. 직접 확인: MoaPlusKeyboard/ViewModels/KeyboardViewModel.swift:790-825 (gestureMoved — 가드 없는 대입 확인), Views/KeyboardView.swift:8 (@ObservedObject gestureState), Views/ConsonantGridView.swift:150-200 (렌더마다 새 클로저 9개 × 28키 생성 확인). 3개 렌즈(latency-input-path #1, latency-render #1, latency-lifecycle #4)가 독립적으로 같은 지점을 지목.

### 2. gestureMoved 가 셀 1개 읽으려고 4×7 레이아웃 배열을 매 포인트마다 재생성 → gestureStarted 시점 캐시

**원인**

gestureMoved 안에서 `KeyboardMetrics.keyContent(at:column:mode:layout:symbolPage:)` 를 호출해 활성 키가 자음인지 모음키인지 판정한다(KeyboardViewModel.swift:798-799, 직접 확인). 이 함수는 캐시 없이 activeLayout → koreanLayout(layout) 을 타고 매번 `layout.slotC.map` + 4개 행 배열 + 외곽 배열 = 배열 6개와 KeyContent 28개를 새로 만든다. 그런데 이 판정 결과는 한 제스처 동안 절대 바뀌지 않고, gestureStarted(:752-753)가 이미 동일한 조회를 해서 columnId/forceCardinalOnly 를 정하고 있다. 같은 재생성이 gestureEnded → handleKoreanModeGesture(:928) 와 resolvedPreviewVowel 경로에서 또 일어난다.

**수정**

KeyboardViewModel 에 `private var activeKeyContent: KeyContent?` 를 두고 gestureStarted 에서 이미 하는 조회 결과를 저장, gestureMoved/gestureEnded 는 저장값만 읽는다. resetGestureState 에서 nil 로 초기화. 부가적으로 KeyboardMetrics 에 (mode, layout, symbolPage) 키의 1-entry 메모 캐시를 두면 렌더 경로까지 함께 해소된다 — LayoutCustomization 이 Equatable 이라 값 비교 캐시가 성립한다.

**기대 효과**

120Hz 긋기 1회 기준 배열 약 144개 + KeyContent 약 672개의 순수 낭비 할당 제거. 익스텐션 ~30MB 한계에서 단명 할당에 의한 allocator 압박이 줄어든다. 항목 1과 곱해지므로 둘을 함께 넣어야 실효가 크다.

**위험** (small)

낮음. 캐시 무효화 지점만 정확하면 동작 동일. 주의: 캐시 수명이 '제스처 1회'여야 하며 resetGestureState/모드 전환/symbolPage 토글 시 반드시 비워야 한다 — 안 비우면 한/영·123 전환 직후 첫 제스처가 이전 레이아웃으로 해석되는 오동작이 난다. KeyboardMetrics 메모 캐시를 함께 넣을 경우 KeyboardMetricsLayoutTests(특히 testSymbolPages_essentialCharsReachableForEveryPreset)를 통과시킬 것.

**근거**

기준선: 워킹트리(미적용 확인). 직접 확인: KeyboardViewModel.swift:798-799 (move 마다 keyContent 조회), :752-753 (start 에서 동일 조회 존재), Utilities/KeyboardMetrics.swift:248-254/266-298/450-457 (매 호출 신규 배열 생성). latency-input-path #2, latency-render #4, latency-lifecycle #4 가 동일 지적.

### 3. KeyGridView 가 한 번의 body 평가에서 activeLayout 을 6회 재구축

**원인**

ConsonantGridView.swift 에서 activeLayout(for:layout:symbolPage:) 이 body(:62) 1회 + rowCount(:58) 1회 + `.frame(width: rowWidth(for: row))`(:204)로 행마다 1회 = 총 6회 호출된다(직접 확인). 각 호출이 koreanLayout/symbolLayout 을 실행해 4×7 KeyContent 배열과 leftCol String 배열을 새로 할당한다. 게다가 rowWidth 는 셀마다 cellWidth → keyWidth → KeyboardMetrics.symbolWidthRatio 를 타고 KeyboardSettings.shared.sideKeyWidthRatio 를 읽어, 폭 계산에만 싱글턴 접근이 약 56회 발생한다.

**수정**

body 최상단에서 `let grid = KeyboardMetrics.activeLayout(...)` 을 1회만 계산하고 rowCount/rowWidth 를 grid 를 인자로 받는 순수 함수로 바꾼다. symbolWidthRatio·sideKeyWidthRatio 도 body 시작에서 지역 상수로 1회 읽어 내려보낸다. 행 정렬의 이중 .frame(width:) + .frame(maxWidth:.infinity)(:204-205)도 함께 단순화 가능.

**기대 효과**

렌더 1회당 레이아웃 배열 재구축 6회 → 1회, 폭 계산용 싱글턴 접근 ~56회 → 2회. 항목 1 적용 후에도 남는 '정상 리렌더 3회'와 콜드스타트 첫 body 평가에 그대로 효과가 있다.

**위험** (small)

낮음-중간. 순수 리팩터이나 rowWidth 는 심볼 모드 wide-⌫ 등 폭 계산 분기를 포함하므로 픽셀 단위 회귀 가능성이 있다. KeyboardSnapshotTests / FunctionRowWidthTests(워킹트리 신규) 로 가드할 것.

**근거**

기준선: 워킹트리(미적용 확인). 직접 확인: MoaPlusKeyboard/Views/ConsonantGridView.swift:43, :58, :62, :204-205 (activeLayout 3지점 + 행별 호출), Utilities/KeyboardMetrics.swift:48-50 (symbolWidthRatio 가 싱글턴을 읽는 computed static var).

### 4. secondaryAction 조회가 키마다 29개 배열 선형 String 탐색 → 딕셔너리 인덱스

**원인**

SecondaryKeyAction.action(forKey:from:) 이 `source.first(where: { $0.keyId == keyId })` 로 29개 배열을 선형 탐색한다. ConsonantGridView 가 이 조회를 키마다 최대 2회(:98 영문 숫자 경로, :114 일반 경로) 수행하므로, 전체 그리드 렌더 1회당 최대 812회 String 비교가 발생한다(직접 확인).

**수정**

KeyboardSettings 에 `private(set) var secondaryActionIndex: [String: SecondaryKeyAction]` 를 두고 secondaryKeyActions 의 didSet 과 loadAll() 에서 1회만 빌드한다. 조회는 O(1). 기존 API(secondaryAction(forKey:))는 시그니처를 유지한 채 내부만 딕셔너리 조회로 교체하면 호출부 변경이 없다.

**기대 효과**

렌더당 String 비교 ~800회 → 28회 해시 조회. 항목 1로 렌더 빈도가 줄어든 뒤에도 콜드스타트 첫 body 와 정상 리렌더에서 그대로 효과가 있다.

**위험** (small)

낮음. 순수 자료구조 교체. 인덱스 재빌드 지점(didSet + loadAll + resetAll)을 빠짐없이 넣어야 하며, 빠지면 '설정에서 롱프레스 매핑을 고쳤는데 키보드는 예전 걸 낸다'는 stale 버그가 된다. isLoading 가드와의 상호작용을 확인할 것(loadAll 중 didSet 이 억제되므로 loadAll 끝에서 명시적 재빌드 필요).

**근거**

기준선: 워킹트리(미적용 확인). 직접 확인: MoaPlusKeyboard/Views/ConsonantGridView.swift:98, :114 (키마다 KeyboardSettings.shared.secondaryAction 호출), Models/SecondaryKeyAction.swift:77-80 (first(where:) 선형 탐색), Utilities/KeyboardSettings.swift:450-452.

### 5. 키마다 themeSettings 재조회 → 구조체 복사·Color 재생성·ARC 트래픽 (상위 1회 조회 후 prop 하향)

**원인**

ConsonantKeyView 가 키마다 `KeyboardSettings.shared.themeSettings`(:283, :309)를 읽고, ThemeSettings 는 값 타입 struct 이며 backgroundImageId: String? 를 포함해 복사마다 retain/release 가 발생한다. resolvedKeyBackground/resolvedKeyText 는 호출마다 Color 를 새로 박싱 생성한다(ThemeSettings.swift:151-161, 캐시 없음). 한 라벨에서 themedTextColor 를 5회 부르는 경로도 있다(vowelPrimitive .bar/.dash, :177-200). 전체 그리드 렌더 1회당 싱글턴 접근 150~250회 + ThemeSettings 복사 약 56회 + Color 할당 56회.

**수정**

(a) KeyboardSettings 가 loadAll 시점에 resolvedKeyBackground/KeyText/FunctionKeyBackground 3색을 미리 계산해 저장하거나 ThemeSettings 에 lazy 캐시를 둔다. (b) ConsonantGridView.body 에서 3색 + showSecondaryHints/hintSize/showDetailedHints 를 1회 읽어 KeyView 에 let prop 으로 내려보낸다. CLAUDE.md 가 '매번 직접 읽음'을 제약으로 명시한 것은 HapticManager 이며(키 입력당 1회, 비용 무시 가능) 렌더 경로에는 해당하지 않는다 — HapticManager 는 건드리지 말 것.

**기대 효과**

렌더당 싱글턴 접근 150~250회 → 5~8회, ThemeSettings 구조체 복사 56회 → 1회, Color 할당 56회 → 3회. 항목 2와 함께 익스텐션 메모리 압박(단명 할당) 완화에도 기여.

**위험** (medium)

낮음-중간. 색상 캐시의 무효화 지점(테마 변경·darwin 크로스프로세스 수신)을 놓치면 '설정에서 색을 바꿨는데 키보드가 안 변함'이 된다. loadAll() 끝에서 재계산하도록 묶으면 안전. 시각 회귀는 KeyboardSnapshotTests 로 가드.

**근거**

기준선: 워킹트리(미적용 확인). 직접 확인: MoaPlusKeyboard/Views/ConsonantKeyView.swift:283, :309, :46, :177-200 (한 라벨에서 themedTextColor 다회 호출), Models/ThemeSettings.swift:129(String? 필드), :151-161(매 호출 Color 생성), Views/ConsonantGridView.swift:158-159.

### 6. loadAll() 의 @Published 28개 무조건 재대입 → 동등성 가드 (콜드스타트 3중 호출 + 크로스프로세스 전체 재구성 동시 해소)

**원인**

loadAll() 은 Codable 5개(gestureSettings/themeSettings/secondaryKeyActions/shortcutExpansionStore/layoutCustomization)를 디코드하고 @Published 28개를 값 비교 없이 전부 재대입한다. load<T>() 는 호출마다 JSONDecoder 를 새로 할당한다(KeyboardSettings.swift:388-390, 직접 확인). 이게 콜드스타트 1회에 3번 돈다: ①저장 프로퍼티 `private let viewModel = KeyboardViewModel()` 가 viewDidLoad 이전에 KeyboardSettings.shared 를 깨우며 init 내 loadAll ②viewDidLoad:72 ③viewWillAppear:92 (②③ 직접 확인). 결과적으로 디코딩 15회 + JSONDecoder 15개 할당. 나아가 darwin 알림 수신 시에도 무관한 설정 하나만 바뀌면 KeyboardView(루트 @ObservedObject settings)가 통째로 재구성된다 — 코드베이스가 이미 자인하고 있다(KeyboardViewController.swift:154-155 주석 "loadAll() reassigns every @Published on each cross-process change, so removeDuplicates() is required", 직접 확인).

**수정**

loadAll() 안에서 값이 다를 때만 대입하는 equality guard 를 넣는다. GestureSettings/ThemeSettings/LayoutCustomization/SecondaryKeyAction 은 이미 Equatable 이고, ShortcutExpansionStore 만 `: Equatable` 한 줄 추가로 합성 가능(ShortcutExpansion 이 이미 Equatable). 부가로 viewDidLoad:72 의 loadAll() 은 삭제해도 안전하다(init 이 같은 defaults 에서 이미 로드했고 setupKeyboardView() 는 그 뒤에 온다). viewWillAppear 의 호출은 서스펜드 중 놓친 darwin 알림의 안전망이므로 유지하되, 가드가 들어가면 비용이 사실상 0이 된다.

**기대 효과**

콜드스타트 loadAll 3회 → 2회 + 값 동일 시 발행 0. 크로스프로세스 변경 시 '무관한 설정으로 전체 트리 재구성'이 사라져 각 구독자가 removeDuplicates() 를 개별로 붙여야 하는 현행 구조가 해소된다. 첫 프레임 지연에 직접 기여(디코딩 15회 → 10회, JSONDecoder 할당 15 → 10). 덤으로 AbbreviationEngine 의 stale trie 정확성 버그를 같은 작업으로 고칠 수 있다 — 현재 가드가 store.expansions.count 를 비교하는데 trie 는 enabledExpansions 로 만들어, 약어 텍스트 수정이나 개별 on/off 토글이 반영되지 않는다.

**위험** (small)

낮음. 다만 '값이 같으면 발행 안 함'이 되므로, 현재 우연히 발행에 의존하던 뷰가 있으면 갱신이 멈출 수 있다 — 배경 이미지 로드 트리거(KeyboardView.onChange(backgroundImageId))처럼 값 기반 onChange 는 안전하나, onReceive(objectWillChange) 류가 있으면 점검할 것. **명시적 안티-권고**: 여기서 'UserDefaults 캐싱을 추가한다'로 가면 안 된다 — KeyboardSettings 의 모든 값은 이미 @Published 메모리 상주이고 UserDefaults 접근은 loadAll/save 에만 있다(:339-369, :371-391 직접 확인). hot path 에 디스크 I/O 는 없다. 정답은 캐싱이 아니라 발행 억제다.

**근거**

기준선: 워킹트리(미적용 확인 — 워킹트리 diff 는 keyboardHeightScale/showGlobeKey/consonantDiagonalDerivation 3개 키 추가일 뿐 가드 없음). 직접 확인: KeyboardSettings.swift:339-369(loadAll), :388-390(호출마다 JSONDecoder), KeyboardViewController.swift:12/72/92(3중 호출 경로), :154-158(주석이 문제를 자인 + removeDuplicates 워크어라운드).

### 7. GestureAnalyzer 가 터치 포인트마다 섹터 배열 복사 + 컬럼 오버라이드 5~8회 선형 탐색 → 제스처 시작 시점 1회 계산

**원인**

analyzeLatestMovement() 가 매 addPoint 마다 캐시 없이 전부 재계산한다. columnId > 0 인 정상 경로에서 포인트당 ColumnGestureOverride.override(forColumn:from:) 가 5회(effectiveSectors 2 + rotationOffset 1 + directionWindow 1 + directionThreshold 1), 방향 전환이 감지되는 포인트에서는 8회 호출된다. 각 호출은 columnOverrides(5요소)를 first(where:)로 훑고 실패 시 defaults(5요소)를 한 번 더 훑는 이중 선형 탐색이다. 추가로 effectiveSectors 는 applyingDiagonalDeltas 에서 `var copy = self` 로 8×DirectionSector 배열을 통째로 복사한다 → 포인트당 약 256B, 120Hz 긋기 1회면 약 6KB 의 단명 할당.

**수정**

gestureStarted 시점에 settings 와 columnId 가 확정되므로, effectiveSectors·rotationOffset·각 임계값을 그때 1회 계산해 프로퍼티에 저장하고 addPoint 는 저장값만 읽는다. 값이 제스처 중간에 바뀔 수 없다는 전제가 성립하는지(설정 변경 darwin 알림이 제스처 도중 도착하는 경우)를 먼저 확인하고, 필요하면 reset() 에서만 재계산하도록 수명을 제스처 단위로 고정한다.

**기대 효과**

포인트당 이중 선형 탐색 5~8회 → 0, 배열 복사 1회 → 0. 항목 1~2 적용 후 메인 스레드에 남는 제스처 경로 비용의 상당 부분을 제거해 샘플 처리 지연을 더 줄인다.

**위험** (medium)

**중간 — 인식률에 직접 닿는 유일한 경로**. 임계값·섹터 폭이 제스처 중 불변이라는 가정이 깨지면 방향 판정이 미묘하게 달라져 오/미인식이 생긴다. 지연을 줄이려다 인식을 망가뜨리지 말라는 제약이 정확히 여기에 걸린다. 반드시 게이트: GestureAnalyzerTests + GestureOverDetectionCharacterizationTests(워킹트리 신규 — 누군가 이미 이 영역의 특성화 가드를 만들고 있다는 신호). 또한 워킹트리가 GestureAnalyzer 를 이미 수정 중이므로(strokeOriginPoint 도입, directionMagnitudes 를 실제 획 길이로 갱신 — 인식 정확도 수정이며 성능과 무관) **그 작업이 커밋된 뒤에 착수**해 충돌을 피할 것.

**근거**

기준선: 워킹트리. git diff MoaPlusKeyboard/Engine/GestureAnalyzer.swift 직접 확인 결과 현재 diff 는 strokeOriginPoint/trailingNoiseRatio 추가(인식 정확도)이며 **캐싱은 포함돼 있지 않다** — 본 항목은 여전히 유효. 근거: GestureAnalyzer.swift:105-124(effectiveSectors/effectiveRotationOffset computed), :168-197, :284-290; Models/SwipeProfile.swift:269-280(applyingDiagonalDeltas 배열 복사); Models/ColumnGestureOverride.swift:52-59(이중 선형 탐색).

### 8. 조합 중 프록시 IPC 5~12회/글자 → updateComposingText 공통 접두 스킵 + textDidChange 컨텍스트 읽기 축소

**원인**

marked text 미지원이라 조합 글자를 delete+insert 로 시뮬레이션하는데(KeyboardViewController.swift:242-256), textDidChange 가 매 변형마다 documentContextBeforeInput(nil 이면 AfterInput)을 무조건 읽고 DispatchQueue.main.async 를 예약해 증폭한다(:202-216). documentContextBefore/AfterInput 은 호스트 프로세스와의 크로스프로세스 왕복으로 이 경로에서 가장 비싼 단일 호출이다. '한'(ㅎ+ㅏ+ㄴ) 1글자에 프록시 변형 5회 + 컨텍스트 읽기 7~12회 + dispatch 5회. 최악은 dotPending(천지인 3-stroke): composingDisplay 가 멀티 문자('ㅇㆍㆍ')를 반환하는데 updateComposingText 는 공통 접두 비교 없이 이전 문자열 전체를 지우고 새 문자열 전체를 삽입하므로 ㅇ+ㆍ+ㆍ+ㅣ → '여' 가 1+2+3+4 = 프록시 변형 10회. 공통 접두를 건너뛰면 4회면 충분하다.

**수정**

(a) updateComposingText 에 공통 접두 비교를 넣어 바뀐 꼬리만 delete+insert 한다. (b) textDidChange 의 '필드가 완전히 빈 경우' 판정을 매번 두 컨텍스트를 읽는 대신 조합 중일 때는 건너뛰거나 다른 신호로 대체한다. (c) applyPeriodShortcut(:646)·약어 델리게이트(:1318-1348)가 추가로 documentContextBeforeInput 을 읽는 지점을 정리한다.

**기대 효과**

천지인 '여' 기준 프록시 변형 10회 → 4회, 컨텍스트 크로스프로세스 읽기 10회 → 4회. 일반 3자모 글자도 5회 → 3~4회. 키 입력 후 화면 반영까지의 체감 지연('반응속도가 느리다')에 직접 작용하는 유일한 IPC 항목.

**위험** (medium)

**높음 — 회귀 이력 있음**. CLAUDE.md 가 이 경로를 명시적으로 경고한다: 일부 호스트(SwiftUI TextField 등)는 커서 탭 시 selectionDidChange 를 발화하지 않아 freezeComposerIfCaretMoved() 백스톱이 textBeforeCursor() 로 조합 상태를 판단한다. 컨텍스트 읽기를 줄이면 이 백스톱을 우회해 **v1.7.2 커서 탭 중복 삽입 버그가 회귀**한다. 필수 게이트: KeyboardViewModelCaretMoveTests. before/after 컨텍스트가 둘 다 nil 인 호스트(시큐어 필드)의 no-op 동작도 보존해야 한다. 랭킹 1~6이 끝나고 실측으로 IPC 가 여전히 병목임이 확인된 뒤에만 착수할 것.

**근거**

기준선: 워킹트리(미적용 확인). 직접 확인: KeyboardViewController.swift:202-216(textDidChange 무조건 컨텍스트 읽기 + async), :242-256(delete+insert 루프); KeyboardViewModel.swift:356-365(freezeComposerIfCaretMoved), :1146-1192; Engine/HangulComposer.swift:47-58(dotPending 멀티 문자 composingDisplay); CLAUDE.md 주의사항(v1.7.2 회귀 경고).

### 9. 무손실 정리 묶음 — 미사용 feedbackGenerator, pow() 2회/포인트, viewDidLoad 중복 loadAll

**원인**

(a) KeyboardViewController.swift:13/191-192 에서 UIImpactFeedbackGenerator 를 할당하고 prepare() 를 부르지만 읽는 곳이 없다 — 실제 햅틱은 :262-267 이 HapticManager.shared.playTap() 으로 처리한다. 콜드스타트마다 미사용 객체 할당 + Taptic Engine 을 수 초간 켜둔 채 대기(배터리·시작 지연 낭비). (b) ConsonantKeyView.swift:96 이 롱프레스 취소 판정에 sqrt(pow(w,2)+pow(h,2)) 를 써서 터치 포인트마다 Double 지수 함수를 2회 호출한다 — GestureAnalyzer 는 같은 계산을 이미 dx*dx+dy*dy 로 한다. (c) viewDidLoad:72 의 loadAll() 은 init 시점 로드와 100% 중복(항목 6 참조).

**수정**

(a) feedbackGenerator 프로퍼티와 setupHapticFeedback() 의 해당 2줄 삭제. (b) pow(_:2) → 곱셈으로 교체(한 줄, 동작 동일). (c) viewDidLoad:72 loadAll() 삭제(viewWillAppear 는 유지).

**기대 효과**

개별로는 작다. 콜드스타트에서 Taptic prepare 1회와 디코딩 5회를 없애고, 터치 포인트당 Double pow 2회를 없앤다. 합쳐서 '리스크 0으로 즉시 넣을 수 있는' 묶음이라 랭킹 1~6과 같은 PR 에 태우기 좋다.

**위험** (small)

매우 낮음. (a)는 참조가 0건임을 확인했으므로 순수 죽은 코드 제거. (b)는 수학적으로 동일. (c)만 확인 필요 — setupKeyboardView() 가 loadAll 이후 실행되는 순서가 유지되는지 점검(init 로드가 선행하므로 성립). HapticManager 의 computed settings 는 CLAUDE.md 가 의도적 제약으로 명시했으므로 **건드리지 말 것**.

**근거**

기준선: 워킹트리. 직접 확인: KeyboardViewController.swift:13, :191-192(할당+prepare, 파일 내 출현이 이 3줄뿐), :262-267(실제 햅틱 경로); ConsonantKeyView.swift:96(pow 2회); KeyboardSettings.swift:273(init 내 loadAll).

### 10. FunctionKeyView 의 AnyView 타입 소거 제거 (제네릭화)

**원인**

FunctionKeyView 가 `let content: AnyView` 를 받고, FunctionRowView 가 호출 지점 15곳에서 AnyView(Text(...))/AnyView(Image(...)) 를 매 렌더마다 새로 박싱한다. AnyView 는 타입 소거이므로 SwiftUI 가 이전 값과 구조 비교를 할 수 없고 해당 서브트리를 무조건 재생성한다. 항목 1로 FunctionRowView 가 긋기 프레임마다 재평가되므로 기능키 4~6개가 매 프레임 통째로 재구축되며, 각 FunctionKeyView 는 themeSettings 도 2회 읽는다.

**수정**

`struct FunctionKeyView<Content: View> { let content: Content }` 로 제네릭화하고 호출부의 `AnyView(` 래핑만 제거(그 외 변경 없음). 또는 라벨을 `enum FunctionKeyLabel { case text(String), symbol(String) }` 로 값 표현.

**기대 효과**

기능행 서브트리의 무조건 재생성 제거. 항목 1을 넣으면 재평가 빈도 자체가 줄어 효과가 겹치므로, 항목 1 이후 실측에서 기능행이 여전히 보이면 진행한다.

**위험** (medium)

낮음-중간. 순수 타입 변경이나 워킹트리가 FunctionRowView.swift 를 179줄 수정 중(지구본 키·심볼 페이지 토글)이라 **충돌이 확실하다**. 그 작업이 커밋된 뒤에 착수할 것. 시각 회귀는 KeyboardSnapshotTests/FunctionRowWidthTests 로 가드.

**근거**

기준선: 워킹트리 — git diff --stat 확인 결과 FunctionRowView.swift 가 +179 수정 중(미커밋). 근거: MoaPlusKeyboard/Views/FunctionRowView.swift:869(let content: AnyView), AnyView 생성 15지점(:99,:109,:128,:148,:175,:197,:208,:223,:248,:259,:281,:331,:343,:353,:379), 테마 재조회 :876-882.

### 11. 구조 리팩터 — KeyView Equatable 화(KeyEventRouter) + gestureState/popupState 관찰 분리 + isPressed prop 제거

**원인**

KeyView 는 17개 저장 프로퍼티 중 9개가 클로저라 SwiftUI 의 리플렉션 기반 비교가 포기되고, KeyGridView 가 렌더마다 28세트 클로저를 새로 만들어 하위 단락이 원천 불가능하다. 또 KeyboardViewModel.swift:12-27 의 주석은 GestureState/PopupState 분리 목적을 'reduce unnecessary redraws'라고 선언하지만, KeyboardView.swift:5-9 가 viewModel/settings/gestureState/popupState 4개를 **모두 루트에서** 관찰해 분리 효과를 무력화한다. 눌림 하이라이트도 KeyView 가 이미 로컬 @State isHighlighted 로 완결하는데(:30, :286-304 의 `isPressed || isHighlighted`) 전역 activeKey 를 28키에 전파해 그리드 전체를 무효화한다.

**수정**

(a) KeyView 의 isPressed prop 제거 — 눌림 표시는 로컬 @State 로 일원화, 전역 activeKey 는 팝업 위치 계산과 previewVowel 오버레이에만 사용. (b) 콜백 9개를 `final class KeyEventRouter` 참조 1개 + row/column 으로 대체하고 KeyView 를 Equatable 로 만들어 실제로 바뀐 키만 다시 그린다. (c) GestureOverlayView·팝업 오버레이를 각자 @ObservedObject 를 가진 별도 서브뷰로 추출해 KeyboardView 가 gestureState/popupState 를 직접 관찰하지 않게 한다.

**기대 효과**

구조적으로 가장 큰 상한(리렌더 시 28키 → 변경된 1키). 다만 항목 1의 3줄 가드가 이미 리렌더 **빈도** 를 24→3으로 줄이므로, 실효 이득은 그 위에 얹히는 잔여분이다.

**위험** (large)

중간-높음. 광범위한 뷰 구조 변경이라 롱프레스 팝업 z-order(CLAUDE.md: 최상위 ZStack 렌더 제약), 스페이스 드래그 커서, shift 롱프레스 등 이벤트 라우팅 회귀 위험이 크다. **항목 1~6 이후에만 착수**할 것 — 먼저 하면 인식 회귀와 성능 개선이 뒤섞여 원인 분리가 불가능해진다. 게이트: KeyboardSnapshotTests + ViewModel 계열 테스트 전체(Cursor/CaretMove/Shift/VowelDrag/LongPress).

**근거**

기준선: 워킹트리(미적용 확인). 직접 확인: ConsonantKeyView.swift:3-28(prop 목록), :30(@State isHighlighted), :286-304; ConsonantGridView.swift:150-200(28세트 클로저 생성 확인), :70(isActive 계산); KeyboardView.swift:5-9(4개 모두 루트 관찰); KeyboardViewModel.swift:12-27(분리 의도 주석), :746.

### 12. 배경 이미지 상주 비트맵 축소 + touchPoints 무제한 증가 (지연보다 메모리 항목)

**원인**

(a) 배경 이미지를 설정한 사용자는 1536px 캡에서도 최대 ~9MB 비트맵이 상주한다(BackgroundImageManager.swift:8-17 주석). 익스텐션은 표시마다 새 프로세스로 뜨는 경우가 많아 실질적으로 '키보드 올릴 때마다 1회 동기 ImageIO 디코드'가 되며, 이것이 30~60MB 예산의 단일 최대 항목이자 첫 프레임 지연 요인이다. (b) GestureAnalyzer.touchPoints 는 상한 없이 누적되고 reset 이 keepingCapacity: true 라 capacity 도 최대치로 유지된다. windowReferenceIndex 는 매 포인트마다 역방향 순회하며 sqrt 를 계산하는데, 손가락이 거의 멈춘 미세 지터 구간에서는 누적 호 길이가 임계에 도달하지 못해 매번 인덱스 0까지 되돌아가 O(n²)로 커진다.

**수정**

(a) 키보드 실제 픽셀 크기(아이폰 ~1170×780)에 맞춘 더 작은 썸네일을 저장 시점에 별도로 구워두고 익스텐션은 그것만 읽는다 → 상주 비트맵 ~9MB → ~3MB. 로드를 .onAppear 동기에서 첫 프레임 이후 비동기로 미뤄 첫 프레임 지연을 제거한다. (b) touchPoints 를 임계 arcLength 를 채우는 데 필요한 최근 N개만 유지하는 링 버퍼 또는 상한 클램프로 교체.

**기대 효과**

(a) 배경 이미지 사용자의 메모리 여유 확보(=키보드 강제 종료 = '키보드 멈춤' 리스크 감소)와 첫 프레임 지연 단축. (b) 지터 구간 최악 케이스 제거 + 제스처 길이에 비례하는 메모리 증가 차단. 둘 다 평상시 지연 개선폭은 작다 — 이 항목은 '멈춤 방지'에 가깝다.

**위험** (medium)

(a) 낮음-중간 — 워킹트리가 BackgroundImageManager 를 이미 +60줄 수정 중이므로 충돌 회피 필요. 신규 테스트 BackgroundImageMemoryTests(워킹트리 신규)가 게이트로 존재한다. (b) **중간 — 인식률 주의**. 버퍼 상한을 너무 작게 잡으면 windowReferenceIndex 가 필요한 과거 점에 도달하지 못해 방향 전환 판정이 달라진다. 상한은 reversal 임계 arcLength 를 채우고도 남을 여유로 잡고 GestureAnalyzerTests/GestureOverDetectionCharacterizationTests 로 검증할 것.

**근거**

기준선: 워킹트리 — git diff --stat 확인 결과 BackgroundImageManager.swift +60 수정 중, BackgroundImageMemoryTests.swift 신규 untracked. 근거: BackgroundImageManager.swift:8-17(30-60MB 한계·캡 주석), :105-122(ImageIO 썸네일 디코드); KeyboardView.swift:257-270(onAppear 동기 로드 + cachedBgImageId 가드); GestureAnalyzer.swift:155-158(무제한 append), :266-280(역방향 순회), :146-153(reset keepingCapacity).

---

## 3. 미해결 질문 (착수 전 결정 필요)

1. 멀티스트로크 민감도 기본값을 0(끔)→1(보통)로 바꿔야 하는가? 리뷰 'ㅛ,ㅜ,ㅢ 빨리 치면 인식 안 됨'은 '끔' 모드의 정의된 동작(처음 위치로 정확히 복귀 요구, GestureSettings.swift:28 기본값 0 확인)과 정확히 일치하므로 기본값 변경이 직격탄으로 보인다. 그러나 (a) footer 스스로 '보통/민감'이 ㅗ·ㅜ·ㅏ·ㅓ 를 ㅚ·ㅛ·ㅐ·ㅑ 로 오인식할 수 있다고 경고하고 (b) 랭킹 1~2번 성능 수정만으로 샘플 밀도가 회복돼 같은 증상이 해소될 가능성이 있다. 권장: 성능 수정 후 ㅛ/ㅠ/ㅢ 빠른 입력 재현 테스트를 먼저 돌리고, 그래도 남으면 그때 기본값을 논의한다. 지금 바꾸면 기존 사용자 전원의 입력 특성이 말없이 바뀌고 성능 수정의 효과 측정도 불가능해진다.

2. 랭킹 7(GestureAnalyzer 파라미터 캐시)의 전제 — effectiveSectors·rotationOffset·각 임계값이 '한 제스처 동안 불변'이 실제로 성립하는가? darwin 알림이 제스처 도중 도착해 gestureSettings 가 교체되는 시나리오, 그리고 컬럼 오버라이드가 방향 전환 시점에 재평가되는 경로(effectiveDirectionChangeThreshold/effectiveReversalThreshold 가 전환 포인트에서만 추가 호출됨)를 코드로 확인하지 못했다. 캐시 수명을 제스처 단위로 고정하기 전에 이 두 경로를 먼저 읽어야 한다.

3. 본 계획의 모든 수치는 Instruments 트레이스가 아니라 코드 정적 분석 기반 추정이다. 실측 검증 순서 제안: ①os_signpost 를 gestureMoved 와 KeyGridView.body 에 넣고 실기기 익스텐션에 Time Profiler 를 붙여 긋기 중 메인 스레드 점유율과 body 호출 횟수를 실측 ②랭킹 1만 적용 후 동일 측정 반복 — 리렌더가 24회→3회 수준으로 줄어드는지 확인 ③그 상태에서 ㅛ/ㅠ/ㅢ 빠른 입력 회귀 시나리오 재현 — 인식률이 개선되면 '리뷰 증상 = 렌더 병목' 인과가 확정되고, 각도·임계 설정을 건드릴 필요가 없어진다.

4. 안티-권고 확인 요청: 'KeyboardSettings 를 캐싱하자'는 방향은 틀렸다. 모든 값이 @Published 메모리 상주이고 UserDefaults 접근은 loadAll()/save() 에만 있어 hot path 에 디스크 I/O 가 없음을 직접 확인했다(KeyboardSettings.swift:339-369, 371-391). 실제 비용은 구조체 복사·Color 재생성·리렌더 횟수다. 구현자가 이 오해로 시간을 쓰지 않도록 팀 내 합의가 필요하다.

5. 워킹트리 미커밋 작업(17파일 수정 + 6파일 신규: keyboardHeightScale, showGlobeKey, consonantDiagonalDerivationEnabled, GestureAnalyzer strokeOriginPoint 인식 정확도 수정)이 언제 커밋되는가? 랭킹 7·10·12 는 각각 GestureAnalyzer·FunctionRowView·BackgroundImageManager 와 확실히 충돌한다. 랭킹 1~6·9 는 충돌 없이 지금 착수 가능하므로, 이 둘을 분리해 진행하는 것이 안전하다.

6. UX 재설계 관련 — 123 심볼 키패드 커스터마이즈(리뷰 '쪼꼬파이원츄')는 현재 KeyboardMetrics.symbolLayout 하드코딩이고 메인 앱에 symbolLayout/symbolPage 참조가 0건이다. 신규 저장 키 + 편집 UI + 2페이지 geometry 제약(classic11/fullPackage 는 wide-⌫ 로 2셀 적음, '/' 누락이 회귀라 KeyboardMetricsLayoutTests 가 가드 중)까지 고려하면 large 작업이다. 이번 IA 재설계에 포함할지, 자리('특수문자 구성' 진입점 + 기존 슬롯 편집기 3벌 회수)만 먼저 만들고 123 페이지 편집은 다음 릴리스로 미룰지 제품 결정이 필요하다.
