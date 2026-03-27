# Moakey iOS Custom Keyboard
## 기획 문서 / PRD v0.1

목적: 갤럭시 원본 양손 모아키 사용감을 iOS 커스텀 키보드로 최대한 복원하고, iOS 제약 안에서 생산성 기능을 확장한다.

## 문서 개요

| 항목 | 내용 |
|---|---|
| 대상 저장소 | https://github.com/koh0001/ios-moaki-custom |
| 문서 범위 | 레이아웃, 제스처 엔진, 보조 입력, 약어 확장, 설정 구조, 외형/햅틱, 구현 우선순위 |
| 기준 레퍼런스 | 사용자 제공 갤럭시/현행 iOS 스크린샷 + 삼성/Apple 공개 자료 |
| 작성일 | 2026-03-27 |

> 핵심 원칙  
> 1) 입력 정확도 우선  
> 2) 원본 모아키 감각 유지  
> 3) 설정은 많아도 단계별로 노출  
> 4) iOS 제약은 우회하되 사용감은 삼성 키보드에 가깝게 맞춘다.

## 1. 프로젝트 목표와 범위

이번 문서는 iOS 포크 저장소를 기준으로 원본 갤럭시 양손 모아키 레이아웃, 제스처 입력, 설정 구조, 보조 입력, 약어 확장, 외형 기능을 단계적으로 복원/확장하기 위한 실행 가능한 PRD 초안이다.

범위 밖 항목은 음성 입력, 클라우드 동기화, 계정 시스템, AI 추천 입력, 다국어 고급 예측 기능이다. 이번 버전은 개인 사용 기준의 고정밀 입력 경험을 우선한다.

## 2. 비주얼 레퍼런스 스냅샷

아래 이미지는 이번 기획의 기준이 되는 사용자 제공 레퍼런스다. 좌상단은 갤럭시 양손 모아키 원본 레이아웃, 우상단은 현행 iOS 포크 버전, 하단은 긋기 각도/설정 화면이다.

| 갤럭시 양손 모아키 기준 레이아웃 | 현재 iOS 포크 레이아웃 |
|---|---|
| ![](assets/01_galaxy_bimanual_layout_reference.png) | ![](assets/02_current_ios_fork_layout.png) |

| 긋기 각도 - 양손용 45도 프리셋 | 모아키 설정 - 각도/길이 진입 화면 |
|---|---|
| ![](assets/03_gesture_angle_reference.png) | ![](assets/04_moakey_settings_reference.png) |

## 3. 현재 상태와 갭 분석

| 항목 | 원본 갤럭시 기준 | 현행 iOS 포크 기준 / 갭 |
|---|---|---|
| 레이아웃 | 좌우 분산형 양손 모아키, 우측 모음 키와 하단 기능열이 삼성식으로 노출 | iOS 기본 키보드 구조 영향이 강함. 하단/우측 기능 배치와 모음 키 의미가 갤럭시판과 다름 |
| 모음 입력 | 점(ㆍ) / ㅣ / ㅡ 계열을 별도 모음 프리미티브로 사용 | 겉보기 기호 키로 오인되기 쉬움. 내부 semantic 재정의 필요 |
| 긋기 설정 | 각도 프리셋 + 길이 3단계 + 원본 사용감 | 전역값만으로는 끝열/사이드 자음의 바깥쪽 스와이프 보정이 부족 |
| 보조 입력 | 삼성 키보드 감성의 작은 힌트와 빠른 보조 입력 필요 | 롱프레스 구조/보조문자 표시/기호 레이어 설계 미정 |
| 생산성 기능 | 단축어/확장 입력은 개인 사용에서 가치 큼 | 약어 확장 엔진과 설정/백스페이스 복원 규칙 필요 |

## 4. 기능 요구사항 우선순위

| 등급 | 기능 | 설명 | 상태 |
|---|---|---|---|
| P0 | 양손 모아키 레이아웃 복원 | 좌우 분산형 자음 배열, 우측 모음 프리미티브, 하단 기능열 재설계 | 필수 |
| P0 | 모음 프리미티브 재정의 | 점(ㆍ), ㅣ, ㅡ 키를 기호가 아닌 모음 입력 엔진 primitive로 처리 | 필수 |
| P0 | 긋기 각도/길이 | 각도 프리셋 + 길이 enum(짧게/보통/길게) + 판정 로직 분리 | 필수 |
| P0 | 세로 라인별 제스처 보정 | 1~5열별 회전 보정, ㅣ/ㅡ 허용폭 보정, 끝열 바깥쪽 스와이프 강화 | 필수 |
| P0 | 롱프레스 즉시 보조 입력 | 숫자 1~0 + 일부 특수문자 + 키 내부 작은 힌트 표시 | 필수 |
| P0 | 약어 확장 | 예: ㅎㅅㅁㅇ -> koh@move.kr, delimiter 확정 + backspace 복원 | 필수 |
| P1 | 확장 특수문자 레이어 | 언어 변환 계열 키 짧게 탭 진입, 많은 특수문자/숫자/개발 기호 제공 | 중요 |
| P1 | 보조문자 크기/위치 조정 | 사이드 키 오입력 완화용. 보조 힌트 크기와 안쪽 정렬 제공 | 중요 |
| P2 | 테마/외형 | 시스템/라이트/다크, 버튼 색상 테마, 이미지 배경 + 투명도 | 부가 |
| P2 | 햅틱/사운드 | 탭/확정/레이어 전환/롱프레스 진입 중심의 약한 햅틱 + 클릭 | 부가 |

## 5. 핵심 입력 엔진 설계

### 5.1 모음 프리미티브

우측 점과 ㅣ, 하단 ㅡ는 일반 문장부호가 아니라 모음 primitive로 처리한다. UI glyph와 semantic value를 분리하여 내부적으로는 ㆍ / ㅣ / ㅡ 값을 사용한다.

- DotVowelKey -> ㆍ
- BarVowelKey -> ㅣ
- DashVowelKey -> ㅡ
- 자음+긋기와 별도 모음 직접 입력을 함께 지원하는 하이브리드 구조

### 5.2 긋기 각도

긋기 각도는 방향 분류 규칙이다. 양손용 프리셋은 8방향 균등 45도 기준이며, 오른손용/왼손용/직접 설정은 이 기본판을 보정하는 상위 레이어다.

### 5.3 긋기 길이

긋기 길이는 스와이프 인정 최소 이동 거리 threshold다. UI는 3단계 enum만 노출하고 내부에서는 pt 단위 실수값으로 매핑한다.

| 값 | 의미 | 사용감 |
|---|---|---|
| 짧게 | 조금만 움직여도 swipe 인정 | 빠르고 민감하지만 오입력 증가 가능 |
| 보통 | 기본 threshold | 탭/스와이프 균형형 |
| 길게 | 더 크게 움직여야 swipe 인정 | 오입력 방지에 유리하지만 둔하게 느낄 수 있음 |

### 5.4 세로 라인별 제스처 보정

전역 각도 1세트만으로는 끝열/사이드 자음의 바깥쪽 긋기 오인식을 해결하기 어렵다. 그래서 각 자음 키를 완전 개별화하기보다 먼저 세로 라인 단위 override를 둔다.

| 라인 | 키 그룹 | 보정 파라미터 |
|---|---|---|
| 1열 | ㅃ / ㅂ / ㅁ / ㅋ | rotationOffsetDeg, verticalIWidthDelta, horizontalEuWidthDelta, outwardDistanceMultiplier |
| 2열 | ㅉ / ㅈ / ㄴ / ㅌ | rotationOffsetDeg, verticalIWidthDelta, horizontalEuWidthDelta |
| 3열 | ㄸ / ㄷ / ㅇ / ㅊ | 기본 전역값 사용, 필요 시 최소 보정 |
| 4열 | ㄲ / ㄱ / ㄹ / ㅍ | rotationOffsetDeg, verticalIWidthDelta, horizontalEuWidthDelta |
| 5열 | ㅆ / ㅅ / ㅎ | rotationOffsetDeg, verticalIWidthDelta, horizontalEuWidthDelta, outwardDistanceMultiplier |

## 6. 입력/보조 입력 설계

### 6.1 키 내부 작은 힌트와 롱프레스

각 버튼을 길게 눌렀을 때 숫자와 일부 특수문자를 즉시 입력할 수 있도록 한다. 중앙 큰 라벨은 자음, 우상단 작은 라벨은 대표 숫자/기호로 처리한다. 단, 끝열은 작은 라벨을 안쪽으로 약간 당겨 배치한다.

### 6.2 많은 특수문자 레이어

많은 특수문자는 별도 레이어로 분리한다. 언어 변환 계열 키를 짧게 탭하면 내부 특수문자 레이어로 진입하고, 길게 누르면 실제 시스템 키보드 전환 기능을 유지하는 방향으로 설계한다.

### 6.3 약어 확장

문구 자동 삽입은 일반 자동완성보다 약어 확장(expansion) 엔진으로 처리한다. 예: `ㅎㅅㅁㅇ` -> `koh@move.kr`. 사용자가 delimiter(스페이스, 엔터, 문장부호)를 입력하면 후보를 확정 치환하고, 직후 backspace 1회로 원문 약어를 복원할 수 있어야 한다.

| 예시 약어 | 확장 결과 | 비고 |
|---|---|---|
| ㅎㅅㅁㅇ | koh@move.kr | 개인 이메일 |
| ㅈㅅㅎㄴㄷ | 죄송합니다. 확인 후 다시 회신드리겠습니다. | 자주 쓰는 회신 문구 |
| ㅁㅂㅊㅋ | move branch merge check | 개발용 단축어 예시 |

## 7. 설정 IA와 사용자 옵션

| 메뉴 | 항목 |
|---|---|
| 모아키 입력 | 긋기 각도(오른손/왼손/양손/직접 설정), 긋기 길이(짧게/보통/길게), 세로 라인별 제스처 보정 |
| 보조 입력 | 키 내부 작은 힌트 표시 on/off, 힌트 크기(작게/보통/크게), 힌트 위치(기본/안쪽), 롱프레스 보조 입력 편집 |
| 특수문자 | 확장 특수문자 레이어 진입키, 기본 탭 구성, 개발용 기호 표시 |
| 단축어/약어 확장 | 추가/수정/삭제, delimiter 확정, backspace 복원, 후보 표시 방식 |
| 외형 | 시스템/라이트/다크, 버튼 색상 테마, 이미지 배경, 배경 투명도 |
| 반응 | 클릭 사운드, 햅틱 on/off, 이벤트별 햅틱 강도 |

## 8. 아키텍처 및 데이터 모델

키보드 확장과 컨테이너 앱은 App Group 기반으로 설정/리소스를 공유한다. 이미지 배경, 테마 설정, 약어 확장 데이터, 제스처 override는 shared defaults 혹은 shared container 파일로 저장한다.

```text
GestureSettings
- globalAnglePreset: right | left | both | custom
- swipeLengthPreset: short | normal | long
- columnOverrides[1...5]
- leftEdgeOutwardDistanceMultiplier
- rightEdgeOutwardDistanceMultiplier

SecondaryKeyAction
- keyId
- visibleHint
- primaryLongPressOutput
- popupOutputs[]

ShortcutExpansion
- trigger
- replacement
- autoCommitMode: suggestion | onDelimiter
- isEnabled

ThemeSettings
- appearanceMode: system | light | dark
- buttonThemeId
- backgroundImageId
- backgroundOpacity
- hapticMode
```

## 9. 구현 우선순위와 마일스톤

| 단계 | 기간(가안) | 범위 |
|---|---|---|
| M1 | 입력 엔진 기반 | 레이아웃 복원, 모음 primitive, 각도/길이, 세로 라인별 보정, 기본 삭제/공백/엔터 |
| M2 | 보조 입력/생산성 | 롱프레스 숫자/기호, 작은 힌트 표시, 특수문자 레이어, 약어 확장 |
| M3 | 튜닝/외형 | 보조문자 크기/위치, 테마, 이미지 배경+투명도, 햅틱, 디버그 테스트 모드 |

## 10. 오픈 이슈와 추가 검증 필요 항목

1. 원본 갤럭시 양손 모아키의 숫자/기호 롱프레스 실제 매핑표 추가 확보 필요
2. 오른손용/왼손용 각도 프리셋의 실수치 테이블은 현재 미확정
3. 직접 설정에서 방향별 각도 편집 UI 캡처가 더 있으면 복원 정밀도가 올라감
4. iOS 포크 저장소 기준 현재 키/제스처 엔진 구조를 코드 레벨로 다시 뜯어보는 작업 필요
5. 햅틱 강도는 실제 디바이스 테스트 없이 최종 확정하면 안 됨

## 부록 A. 외부 참고자료

아래 링크는 본 PRD 작성에 참고한 공개 자료다. 실제 구현 시에는 저장소 코드와 추가 디바이스 캡처로 다시 대조하는 것을 전제로 한다.

- Samsung Service - 삼성 키보드의 한손 모아키 / 양손 모아키 지원 안내
- Moakey 공식 Facebook - 2021년부터 Samsung Galaxy 기본 입력 모드 추가 및 Play Store 종료 안내
- APKPure - `org.samsung.app.MoAKey` 버전 히스토리 / 기능 소개 / custom skin 관련 업데이트 흔적
- Apple Developer - Configuring a custom keyboard interface
- Apple Developer - Configuring open access for a custom keyboard
- Apple Developer - App Groups / ExtensionScenarios / shared defaults
- Apple Developer - `playInputClick` / `UIInputViewAudioFeedback` / `UIFeedbackGenerator`
