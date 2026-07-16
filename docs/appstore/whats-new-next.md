# 다음 버전 "무엇이 새로운지" (App Store 릴리스 노트)

> 대상: 1.7.2(build 14). 버그 수정 패치 릴리스.
> 규칙(appstore_submission.txt 준수): ASCII 구두점 + 한글 완성형. 화살표/단독 자모/도형문자/통화기호/특수기호 배제 — App Store "유효하지 않은 문자" 회피.

## 포함된 변경 (개발 요약)
- 커서 탭 이동 후 재입력 시 직전 조합 글자가 중복 삽입되던 버그 수정. 원인: 커서 탭 시 selectionDidChange 미발생 + 필드 맨 앞에서 documentContextBeforeInput이 nil이라 기존 감지 경로가 모두 침묵 → 입력 시점 backstop(freezeComposerIfCaretMoved)으로 "커서가 조합 글자 바로 뒤"라는 확증이 없으면 조합 동결. before/after 컨텍스트 둘 다 nil인 호스트는 불개입 (PR #18, 커밋 `06c8669`).
- 단축어 확장 직후 스페이스에서 더블스페이스 마침표가 오발동해 마침표가 찍히던 버그 수정. 확장이 삽입한 끝 공백이 "첫 공백"으로 오인되던 것 — 확장 직후 1회에 한해 마침표 단축 억제 (커밋 `7d63cb1`).
- 회귀 테스트 2종 추가 (CaretMoveTests, AbbreviationPeriodTests). 전체 유닛 테스트 통과 + 실기기 재현 시나리오 해소 확인.

## 한국어 (복사용 - 안전본)
입력 안정성을 높인 버그 수정 업데이트입니다.

- 글자를 조합하는 중에 화면을 눌러 커서를 다른 곳으로 옮긴 뒤 이어서 입력하면, 직전에 입력하던 글자가 새 위치에 한 번 더 들어가던 문제를 고쳤습니다.
- 단축어가 펼쳐진 직후에 스페이스를 누르면 마침표가 잘못 찍히던 문제를 고쳤습니다. 더블 스페이스 마침표 기능은 이후 입력부터 정상 동작합니다.

기본 입력은 전체 접근 권한 없이 동작합니다. 햅틱 진동을 쓰려면 iOS 제약상 전체 접근 허용이 필요하지만(선택), 켜더라도 입력하신 내용은 외부로 전송되지 않습니다.

## English (paste-ready)
A bug-fix update for more reliable typing.

- Fixed an issue where, after tapping to move the cursor while composing a syllable, the previous character was inserted again at the new position.
- Fixed an issue where pressing space right after a text shortcut expanded would insert an unwanted period. The double-space period shortcut now behaves correctly afterward.

Core typing works without Full Access. Haptic feedback requires iOS Full Access (optional); your input is never transmitted off your device even when it is enabled.

## 프로모션 텍스트 대안 (선택, 최대 170자)
변경 없음 — 기존 프로모션 텍스트 유지 (버그 수정 릴리스).
