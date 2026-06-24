# 다음 버전 "무엇이 새로운지" (App Store 릴리스 노트)

> 대상: 1.7(build 12). 이번 개발 사이클의 사용자향 변경.
> 규칙(appstore_submission.txt 준수): ASCII 구두점 + 한글 완성형. 화살표/단독 자모/도형문자/통화기호/특수기호 배제 — App Store "유효하지 않은 문자" 회피.

## 포함된 변경 (개발 요약)
- 아이패드 동적 높이 + 가로 좌우 분리 레이아웃(숫자판 + 한글), 숫자판 좌/우 위치 설정 (커밋 `6e7e815`~`45bc0fe`, main 머지/CI green).
- 긋기 인식 각도를 방향별 좌/우 독립 조절(파이 탭선택 + 경계 손잡이 드래그 + 좌/우 폭 슬라이더 + 리셋 + 전체 회전). 코어는 좌/우 폭(per-side) 추가로 기존 동작 무손상.
- 단일 방향 긋기 파생모음 안내 제거(실기기 미작동, 멀티스트로크 경로 유지).
- 한쪽을 좁혀 생긴 빈 각도를 가장 가까운 방향으로 인식해 데드존 제거(STEP3 nearest-center 폴백) + on/off 토글 (커밋 `14a394b`, `27ce484`).
- 설정 파이 4종의 좌/우 비대칭 표시 일관성 + 키별 보정 미리보기 회전 반영 (커밋 `c16f1ae`). CI 빌드 모호성 핫픽스 (`be158c9`).

## 한국어 (복사용 - 안전본)
아이패드 사용성과 긋기 입력 정확도를 높였습니다.

- 아이패드 가로 화면 분리 레이아웃을 추가했습니다. 한쪽은 숫자판, 다른 한쪽은 한글 키보드로 나뉘어 레이어 전환 없이 숫자를 바로 입력합니다.
- 아이패드 화면 크기에 맞춰 키보드 높이가 자동으로 조절됩니다.
- 숫자판을 왼쪽이나 오른쪽 중 원하는 쪽에 둘 수 있습니다.
- 긋기 인식 범위를 방향마다 왼쪽과 오른쪽을 따로 미세 조정하는 설정을 추가했습니다. 자주 잘못 인식되는 방향을 직접 넓히거나 좁혀서 교정할 수 있습니다.
- 한쪽을 좁혀 생긴 빈 각도로 비스듬히 그어도 가장 가까운 방향으로 인식하도록 보정했으며, 이 자동 인식은 설정에서 끌 수 있습니다.
- 그 밖의 안정성 개선이 포함되었습니다.

## English (paste-ready)
Better iPad support and more accurate gesture typing.

- New iPad landscape split layout: a number pad on one side and the Korean keyboard on the other, so you can enter numbers without switching layers.
- Keyboard height now adapts to your iPad screen size.
- Choose whether the number pad sits on the left or the right.
- New setting to fine-tune the gesture recognition range for each direction, left and right independently. Widen or narrow a direction that often gets misread.
- An empty angle left by narrowing a direction is now recognized as the nearest direction so swipes are not dropped, and this auto-fill can be turned off in settings.
- Other stability improvements.

## 프로모션 텍스트 대안 (선택, 최대 170자)
아이패드 가로에서 숫자판과 한글 키보드를 좌우로 나눠 씁니다. 긋기 인식 각도를 방향마다 좌우 따로 미세 조정해 자주 틀리는 방향을 직접 교정할 수 있습니다.
