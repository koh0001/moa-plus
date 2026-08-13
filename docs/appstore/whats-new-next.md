# 다음 버전 "무엇이 새로운지" (App Store 릴리스 노트)

> 대상: 2.0.0(build 16). 입력 엔진 대규모 업데이트.
> 규칙(appstore_submission.txt 준수): ASCII 구두점 + 한글 완성형. 화살표/단독 자모/도형문자/통화기호/특수기호 배제 — App Store "유효하지 않은 문자" 회피.
> (아래 본문에서 모음은 완성형 예시 글자로 표기: "애" = 아이 모음)

## 포함된 변경 (개발 요약 — 내부용, 제출문 아님)
- 순정 모아키 관찰 영상 47편 프레임 판독 → 입력 규칙 실측 확정 (docs/MOAKEY_VIDEO_FINDINGS.md)
- 대각선 왕복 ㅐ/ㅔ/ㅢ (재해석 2-pass + 0.6 키폭 게이트), 세로 체인 7간선, 수평 뒤 직각 스냅, ㆍ 토글, 자소 백스페이스
- 튜토리얼/연습/설정 문구 재구성, 모음 키 라벨 순정화

## 한국어 (복사용 - 안전본)
삼성 모아키의 실제 입력 동작을 영상으로 정밀 분석해, 입력 방식을 순정 모아키와 같게 맞춘 대규모 업데이트입니다.

- 애, 에, 의 모음을 삼성 모아키처럼 대각선으로 나갔다가 되돌아오는 방식으로 입력할 수 있습니다. 기존 좌우 왕복 방식도 그대로 됩니다.
- 위아래로 왕복한 뒤 이어 긋는 조합(와, 왜, 여, 예, 유 등)을 순정과 동일하게 인식합니다.
- 옆으로 긋고 위나 아래로 꺾으면 애, 에가 입력됩니다.
- 가운뎃점 키를 반복해서 누르면 오와 요, 우와 유가 번갈아 바뀝니다.
- 지우기가 삼성 모아키처럼 받침, 모음, 자음 순서로 한 단계씩 지워집니다.
- 튜토리얼과 타이핑 연습을 새 입력 방식에 맞춰 새로 구성했습니다.

기본 입력은 전체 접근 권한 없이 동작합니다. 햅틱 진동을 쓰려면 iOS 제약상 전체 접근 허용이 필요하지만(선택), 켜더라도 입력하신 내용은 외부로 전송되지 않습니다.

## English (paste-ready)
A major update that aligns typing behavior with the original Samsung MoaKey, based on frame-by-frame analysis of real device recordings.

- Type ae, e, and ui vowels with a diagonal out-and-back stroke, just like Samsung MoaKey. The existing horizontal round-trip still works.
- Vertical round-trip chains (wa, wae, yeo, ye, yu and more) are now recognized exactly like the original.
- Swipe sideways then bend up or down to get ae or e.
- Tapping the dot key repeatedly now toggles o/yo and u/yu.
- Backspace now deletes one jamo at a time (final consonant, then vowel, then consonant), matching Samsung MoaKey.
- The tutorial and typing practice have been rebuilt around the new input paths.

Core typing works without Full Access. Haptic feedback requires iOS Full Access (optional); your input is never transmitted off your device even when it is enabled.

## 프로모션 텍스트 대안 (선택, 최대 170자)
삼성 모아키 실측 분석으로 입력 방식을 순정과 동일하게 맞춘 2.0 업데이트. 대각선 왕복 모음, 자소 단위 지우기, 새 튜토리얼.
