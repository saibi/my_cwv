# [SWB] 구현 노트

- 계획: plan/SWB_plan_claude-sonnet-5-5.md
- 구현 커밋: 4b76ce6
- 버전: 0.1.0 -> 0.1.1 (계획과 같음, 구현 직전 현재 버전이 계획의 시작 버전 0.1.0과 같아 재계산 없음)

## 아키텍처
| 파일 | 역할 |
| :--- | :--- |
| `Site.swift` | `PaneSwipe`(back/forward), `paneSwipeEdge`(24pt), 순수 판단 `paneSwipe(startX:viewWidth:viewMinX:screenWidth:dx:dy:vx:)` (가장자리 24pt, 웹뷰 끝이 화면 끝이면 nil, 이동량/속도는 `shouldCloseOnEdgeSwipe` 재사용, 가로 우세) |
| `WebView.swift` | `PaneEdgePan: UIPanGestureRecognizer`(touchesBegan에서 시작 x 기록, 조건이 안 맞으면 즉시 `.failed`), `SiteWebView`에 등록, `panePan`이 끝날 때 `paneSwipe` 결과로 `goBack()`/`goForward()`, `gestureRecognizerShouldBegin`에서 가로 우세만 시작 |
| `SiteListView.swift` | 버전 글자 `Color(.label)` 70% + medium, 말풍선 진한 파랑(`Color.accentColor`) 배경 + 흰 글씨 (`presentationBackground`) |
| `Version.xcconfig` | 0.1.1 |

## 핵심 설계 결정
- 웹뷰 끝이 화면(창) 끝에 닿은 쪽은 새 제스처가 실패하게 했다 - WebKit 기본 제스처와 둘 다 동작하면 한 번 밀 때 두 번 이동한다 (목록 숨김, 목록 오른쪽의 뒤로, 목록 왼쪽의 앞으로, iPhone).
- 시작 조건은 `touchesBegan`에서 판단해 바로 실패시킨다 - 가장자리 밖 터치에서 웹뷰 스크롤/링크 탭이 지연되지 않는다. 가로가 우세하지 않으면(`gestureRecognizerShouldBegin`) 세로 스크롤에 양보한다.
- 판단은 순수 함수로 빼서 `test_site.swift`로 검증한다 - 제스처 자체는 시뮬레이터에서 시험할 수 없어 로직만이라도 테스트로 고정한다.
- 말풍선 배경은 `.presentationBackground(Color.accentColor)` (SWB-Q1).

## 진행 기록
- SWB-M1: 버전 글자/말풍선 색 변경. iPad 시뮬레이터 스크린샷에서 `v0.1.1`이 진하고 읽힌다 (이전 `.secondary`는 흐렸다).
- SWB-M2: `paneSwipe`를 `build/test_site`에 검증 추가 (양쪽 영역, 화면 끝에 닿은 쪽 거절, 이동량/속도, 방향, 세로 우세), 통과. `PaneEdgePan` 등록으로 iPhone/iPad 시뮬레이터 빌드 성공.

## 계획 대비 변경
| 항목 | 계획 | 최종 구현 | 상황과 근본 이유 |
| :--- | :--- | :--- | :--- |
| 제스처 시험 | 시뮬레이터로 시도, 안 되면 실기기 | 시험 못 함 (실기기로) | 이 환경에서 시뮬레이터 창이 열리지 않아 마우스/터치 이벤트를 넣을 수 없었다 (`Simulator.app` 창 0개, `osascript`로 activate 실패) |

## 검증 결과
- `build/test_site` 통과, iPhone/iPad 시뮬레이터 빌드 성공, 버전 `v0.1.1` 표시와 색을 iPad 스크린샷으로 확인.
- 확인 못함 (SWB-M3, 실기기): 실제 스와이프로 뒤로/앞으로 이동, 이중 이동이 없는지, 핸들 드래그와 충돌, 세로 스크롤 방해, 말풍선 색(탭 조작 수단 없음).

## 남은 한계
- 스와이프 중 화면이 손가락을 따라오는 효과는 없다 (손을 뗄 때 기준을 넘으면 이동, SWB-Q5).
- 이동량 기준은 화면 폭과 무관하게 80pt/500pt/s로 고정이다.
