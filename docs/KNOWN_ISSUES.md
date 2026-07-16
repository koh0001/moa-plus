# 알려진 이슈 (Known Issues)

## KI-1. 지구본 키 연속 전환 시 깜빡임 누적 (iOS 시스템 동작)

- **상태**: 미해결 (iOS 시스템 동작, 익스텐션 코드 해결 불가 — 다각도 검증 완료)
- **확인 환경**: iOS 26.4 (실기기 + 시뮬레이터). **iOS 26 이전 버전(iOS 18 등) 미검증** — 현 Xcode가 iOS 18 SDK/런타임을 제공하지 않아 확인 불가. iOS 26 특정인지 이전부터 있던 동작인지는 미상.
- **영향 버전**: v1.5 (build 9) 시점 확인. 원본 [ios-moaki](https://github.com/vkehfdl1/ios-moaki) 동일 구조·동일 증상.
- **심각도**: 낮음~중간. 일반 사용(1~2회 전환)에서 거의 체감 안 됨. 연속 다회 전환 시 가시적.
- **추적**: Apple Feedback 제출 예정 (v1.7.2 시점 기준 미제출).

### 증상
다른 키보드 ↔ 모아+ 를 지구본 키로 *연속해서* 여러 번 전환하면, 전환 순간 깜빡이는 회색 영역(시스템 입력 컨테이너 배경)의 크기가 전환마다 점점 커진다. 키보드 자체는 매번 정상 위치/크기(260pt)로 **복귀**하므로 입력은 정상 동작하고 입력 결과도 보인다.

### 재현
1. 텍스트 입력란에서 모아+ 키보드 표시
2. 지구본 키로 키보드 전환을 5~10회 연속 반복
3. 전환할수록 깜빡이는 회색 영역이 커짐 (단 매번 정상 복귀)

실기기·시뮬레이터(iOS 26.4) 동일 재현.

### 근본 원인 (확정)
iOS(확인 환경 26.4)가 키보드 전환(`advanceToNextInputMode`) 시 `UIInputViewController` 의 시스템 입력 컨테이너(private input host) frame 을 익스텐션 Auto Layout/제약과 무관하게 직접 누적 조작한다. 익스텐션 인스턴스 수명을 초월한 시스템 keyboard host 레벨 누적이라 익스텐션 코드에서 접근·리셋할 지점이 존재하지 않는다. (iOS 26 이전 버전에서도 동일한지는 미검증.)

**결정적 증거**:
- `hcCount=1`(우리 height constraint 1개·정상)인데 `view.bounds.height`만 누적 → constraint 메커니즘 아님
- height constraint 를 **완전히 0개**로 제거해도 누적 지속
- SwiftUI/`UIHostingController`/`GeometryReader`/셀 크기 계산을 통째로 제거한 **순수 UIKit 더미**에서도 100% 동일 누적
- 누적 카운트 진단: `subviews=3 / children=1 / constraints=8` 12회 전환 내내 완전 고정(우리 측 0 누적), `viewDidLoad` 매 전환 재호출(매번 새 인스턴스, 우리 상태 매번 리셋)

### 검토·반박된 가설 (재논의 불필요)
| 가설 | 결과 |
|------|------|
| 우리 height constraint 가 누적된다 | ✗ `hcCount=1` 고정. constraint 0개로도 누적 |
| SwiftUI / `UIHostingController` self-sizing 문제 | ✗ 순수 UIKit 더미에서도 동일 누적 |
| **셀 크기 기기별 자동 변경(GeometryReader 반응형)이 원인** | ✗ 셀 크기 계산 전체를 제거한 순수 UIKit에서도 동일 누적. (단 셀 자기증폭은 *초기 폭주 3908* 에 일부 기여 → `sizingOptions=[]` 로 별도 해결됨) |
| `subviews`/`childVC` 누적 | ✗ 12회 전환 내내 3/1 고정 |
| `.ignoresSafeArea(.all)` / safe-area 주입 | ✗ 제거해도 누적 |
| 키보드 익스텐션 프로세스 캐시(측정 오염) | ✗ 시뮬레이터 재부팅 클린 환경에서도 동일 |

### 시도하고 효과 없던 코드 (반복 금지)
priority 999/.required, `sizingOptions=[]`, clear+clipsToBounds, Auto Layout bottom-pin, manual frame layout, `UIInputView allowsSelfSizing`, `GeometryReader .frame(height:260)` clamp, viewWillAppear stale constraint strip, `self.view.frame` 강제 재설정, height constraint 완전 제거, `updateViewConstraints()` 재고정, `.ignoresSafeArea` 제거, 순수 UIKit 재작성. 외부 출처(Apple Forums 738465, fanthus 블로그, StackOverflow) 해결책 검증 — 그 출처들은 "constraint 누적" 케이스로 메커니즘이 다름. Codex(gpt-5.5) 독립 코드 분석 + Apple 문서 리서치도 "해결 불가" 동의.

실험 증거 브랜치: `experiment/keyboard-arch`, `experiment/updateconstraints-safearea`, `experiment/revert-to-transient`, `experiment/accumulation-diag`.

### 현재 대응 (프로덕션)
안정화 시도(`sizingOptions=[]`+GeometryReader clamp+manual layout, 커밋 `c6c16ca`)는 시스템 자가복구를 깨뜨려 **영구 누적·입력 가림**으로 악화시켜 롤백함(`a59a234`). 현재 baseline 은 키보드가 커졌다 **복귀**하고 입력이 보이는, 사용자 실측 기준 "덜 나쁜" 상태. 데이터 손상 버그 수정(`b6e91ed`)·전환 높이 점프 완화(priority 999, `b6cff00`)는 유지.

### 권장 사용
지구본 키 대신 앱 내/키보드 내 한·영 전환을 사용하면 시스템 키보드 전환 노출이 줄어 증상이 거의 발생하지 않음.

---

## KI-2. 확장형/클래식 레이아웃 자음 키 대각선 ㅣ/ㅡ 실기기 미작동

- **상태**: 폐기(won't-fix this cycle) — 크로스레이아웃 통일 작업을 사용자가 보류 결정(2026-06-24). 기록만 남기고 종결.
- **심각도**: 낮음. **모던(.vowel) 레이아웃은 전용 ㅣ/ㅡ 키로 정상 입력**되므로 영향 없음. 확장형(.fullPackage)/클래식(.classic11)을 실제로 쓸 때만 해당.

### 증상
확장형/클래식 레이아웃에서 자음 키를 대각선으로 그어 ㅣ(↖↗)/ㅡ(↙↘)를 자음에 붙여 입력하는 게(예: ㄱ↗=기, ㄱ↘=그) 실기기에서 안 나온다고 보고됨.

### 코드 상태 (정상 확정)
- 통합 테스트 `test_fullPackage_consonant_downLeft_yieldsConsonantEu`(ㄱ↙=그), `test_fullPackage_consonant_upRight_yieldsConsonantI`(ㄱ↗=기) 통과 — `driveKeyGesture` 실제 파이프라인에서 코드 경로 **정상** 확정(커밋 `45841f4`).
- 즉 resolver/매핑 로직 결함 아님.

### 의심 원인 (미확정)
실기기에서만 막히는 요인 후보(사용자 긋기-테스트 화살표 확인 미완료로 미확정):
1. **4방향 전용 모드 ON** — 대각선을 카디널로 스냅해 ↗/↘ 자체가 사라짐(가장 유력).
2. 대각선 매핑이 `.disabled` 로 설정됨(SwipeProfile.upRightMapping 등).
3. 대각선 섹터 각도가 좁아 인식 실패.

### 결정 / 권장
- 크로스레이아웃 단일긋기 통일 작업을 사용자가 보류 → 본 항목 폐기. 재개 시 위 1~3을 긋기-테스트 화살표로 분기 진단(↙인데 ㅡ 안나옴→매핑, ←↓로 나옴→각도, 화살표 없음→4방향 모드)부터.
- **ㅣ/ㅡ 입력이 필요하면 모던(.vowel) 레이아웃 사용 권장**(전용 키로 안정 입력).
