# 다음 버전 "무엇이 새로운지" (App Store 릴리스 노트)

> 대상: 2.1.0(build 18). 단축어 개편.
> 규칙(appstore_submission.txt 준수): ASCII 구두점 + 한글 완성형. 화살표/단독 자모/도형문자/통화기호/특수기호 배제 — App Store "유효하지 않은 문자" 회피.
> 그래서 아래 본문에는 단축어 예시를 자모로 적지 않고 말로 풀어 쓴다.

## 포함된 변경 (개발 요약 — 내부용, 제출문 아님)
- 사용자 제보 3건 대응: 기호가 포함된 트리거 미동작, 띄어쓰기/기호 트리거 요청, 확장 후 공백 및 되돌리기 문의
- 엔진: 구분자를 경계용(공백/개행)과 내용 겸 확정용(마침표류)으로 분리, 최장 접미 매칭(기호 포함 트리거 한정), 버퍼 상한
- 삭제 산술: 지울 길이를 매칭된 트리거 기준으로 변경, 화면/버퍼 불일치 시 확장 포기(델리게이트가 적용 여부 반환)
- 설정 3종 추가: 변환 후 띄어쓰기 유지, 백스페이스로 되돌리기, 트리거 제한(안전/자유)
- 후보 바 표시 시 키보드 높이 보정(기능행 잘림 수정), 팝업 좌표 보정
- 호스트 앱 백그라운드 복귀 시 터치 전달 복구(NSExtensionHostDidBecomeActive)
- 회귀 테스트 대폭 추가 (기호 확정 경로, 후보 선택 모드, 화면/버퍼 불일치 방어)

> ⚠️ 실제 제출문은 `docs/appstore/fields/07_whatsnew_ko.txt` / `08_whatsnew_en.txt` 다.
> 이 파일은 초안이며 두 곳을 항상 같이 갱신할 것.
>
> **2.0 입력 개편 내용은 두 군데에 남긴다** — 릴리스 노트는 버전이 올라가면 통째로
> 교체되므로, 순정 모아키 정합처럼 "앞으로도 계속 유효한 제품 특성" 은
> `05_description_ko.txt` / `06_description_en.txt`(앱 설명, 버전 무관 상시 노출)에
> 두는 것이 본자리다. 이번 노트에도 요약 섹션으로 한 번 더 싣는다.

## 한국어 (복사용 - 안전본)
단축어를 훨씬 자유롭게 만들 수 있게 정비했습니다. 사용자분들이 보내주신 제보에서 시작한 업데이트입니다.

- 마침표나 물음표 같은 기호가 들어간 단축어를 쓸 수 있습니다. 기호를 앞에 붙여도 되고 뒤에 붙여도 됩니다.
- 문장에 바로 이어 붙여 써도 단축어가 인식됩니다. 앞말과 띄어쓰지 않아도 됩니다.
- 단축어를 확정한 띄어쓰기를 결과 뒤에 남기지 않도록 설정할 수 있습니다. 마침표 같은 문장부호는 문장에 필요한 입력이라 그대로 유지됩니다.
- 변환 직후 지우기를 누르면 원래 글자로 되돌아가는 동작을 설정에서 끄거나 켤 수 있습니다.
- 너무 짧은 단축어는 의도하지 않게 변환되기 쉬워 새로 등록할 때 기본적으로 막아 둡니다. 원하시면 설정에서 제한을 풀 수 있고, 이미 등록해 두신 단축어는 그대로 동작합니다.
- 단축어 후보가 뜰 때 키보드 아래쪽이 잘리던 문제를 고쳤습니다.
- 키보드를 열어 둔 채 다른 앱에 다녀오면 입력이 되지 않던 문제를 고쳤습니다.

기본 입력은 전체 접근 권한 없이 동작합니다. 햅틱 진동을 쓰려면 iOS 제약상 전체 접근 허용이 필요하지만(선택), 켜더라도 입력하신 내용은 외부로 전송되지 않습니다.

## English (paste-ready)
Text shortcuts are far more flexible now. This update started from user reports.

- Shortcuts can now include punctuation such as periods and question marks, at the beginning or at the end.
- A shortcut is recognized even when you type it directly after a word, with no space in between.
- You can choose whether the space that confirms a shortcut stays after the replacement. Punctuation is always kept, since it belongs to your sentence.
- Undo on backspace right after a replacement can now be turned on or off in settings.
- Very short shortcuts trigger by accident easily, so new ones are limited by default. You can lift the limit in settings, and shortcuts you already saved keep working.
- Fixed the keyboard being cut off at the bottom while the shortcut suggestion bar was showing.
- Fixed typing not responding after returning from another app with the keyboard still open.

Core typing works without Full Access. Haptic feedback requires iOS Full Access (optional); your input is never transmitted off your device even when it is enabled.

## 프로모션 텍스트 대안 (선택, 최대 170자)
단축어에 기호를 넣을 수 있고, 문장에 이어 붙여 써도 인식됩니다. 변환 후 띄어쓰기와 되돌리기도 원하는 대로 설정하세요.
