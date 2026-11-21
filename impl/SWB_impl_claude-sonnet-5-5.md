# [SWB] 구현 노트

- 계획: plan/SWB_plan_claude-sonnet-5-5.md
- 구현 커밋: 4b76ce6
- 버전: 0.1.0 -> 0.1.1 (계획과 같음, 구현 직전 현재 버전이 계획의 시작 버전 0.1.0과 같아 재계산 없음)

## 아키텍처
| 파일 | 역할 |
| :--- | :--- |
| `Site.swift` | `PaneSwipe`(back/forward), `paneSwipeEdge`(24pt), 순수 판단 `paneSwipe(startX:viewWidth:viewMinX:screenWidth:dx:dy:vx:)` (가장자리 24pt, 웹뷰 끝이 화면 끝이면 nil, 이동량/속도는 `shouldCloseOnEdgeSwipe` 재사용, 가로 우세), `paneSwipeStarts`(시작할 때 가로 우세 + 방향) |
| `WebView.swift` | `PaneEdgePan: UIPanGestureRecognizer`(touchesBegan에서 시작 x와 허용 방향 `canBack`/`canForward` 기록, 조건이 안 맞으면 즉시 `.failed`), `SiteWebView`에 등록(`paneSwipeEnabled`로 분할 화면에서만 켬), `panePan`이 끝날 때 `paneSwipe` 결과로 `goBack()`/`goForward()`, `gestureRecognizerShouldBegin`에서 `paneSwipeStarts`(가로 우세 + 방향)로 시작 판단 |
| `SiteListView.swift` | 버전 글자 `Color(.label)` 70% + medium, 말풍선 직접 지정한 진한 파랑 배경 + 흰 글씨 (`.background` + `presentationBackground`) |
| `Version.xcconfig` | 0.1.1 |

## 핵심 설계 결정
- 웹뷰 끝이 화면(창) 끝에 닿은 쪽은 새 제스처가 실패하게 했다 - WebKit 기본 제스처와 둘 다 동작하면 한 번 밀 때 두 번 이동한다 (목록 숨김, 목록 오른쪽의 뒤로, 목록 왼쪽의 앞으로, iPhone).
- 시작 조건은 `touchesBegan`에서 판단해 바로 실패시킨다 - 가장자리 밖 터치에서 웹뷰 스크롤/링크 탭이 지연되지 않는다. 가로가 우세하지 않으면(`gestureRecognizerShouldBegin`) 세로 스크롤에 양보한다.
- 판단은 순수 함수로 빼서 `test_site.swift`로 검증한다 - 제스처 자체는 시뮬레이터에서 시험할 수 없어 로직만이라도 테스트로 고정한다.
- 말풍선 배경은 직접 지정한 진한 파랑 - `AccentColor` 에셋에는 값이 없어 `Color.accentColor`는 시스템 파랑이다 (리뷰 SWB-R3).
- 새 제스처는 분할 화면에서만 켠다 - 가로 iPhone은 안전 영역 때문에 웹뷰가 창 끝에서 떨어져 "화면 끝에 닿았는가" 검사만으로는 꺼지지 않는다 (리뷰 SWB-R1).
- 시작 조건에 방향을 넣는다 - 틀린 방향 드래그가 웹 콘텐츠(슬라이더 등) 터치를 취소시키지 않게 (리뷰 SWB-R2).

## 진행 기록
- SWB-M1: 버전 글자/말풍선 색 변경. iPad 시뮬레이터 스크린샷에서 `v0.1.1`이 진하고 읽힌다 (이전 `.secondary`는 흐렸다).
- SWB-M2: `paneSwipe`를 `build/test_site`에 검증 추가 (양쪽 영역, 화면 끝에 닿은 쪽 거절, 이동량/속도, 방향, 세로 우세), 통과. `PaneEdgePan` 등록으로 iPhone/iPad 시뮬레이터 빌드 성공.

## 계획 대비 변경
| 항목 | 계획 | 최종 구현 | 상황과 근본 이유 |
| :--- | :--- | :--- | :--- |
| 속도 판정 | `abs(velocity)` | 방향 있는 `shouldCloseOnEdgeSwipe` 재사용 | 첫 구현이 계획과 달랐고 구현 노트에 없었다. 리뷰 D1에서 구현을 유지하기로 하고 계획을 맞췄다 (반대로 튕기면 취소, 기존 목록 복귀 스와이프와 일관) |
| 새 제스처를 켜는 범위 | 웹뷰 끝이 화면 끝이 아닐 때 | 분할 화면에서만 | 리뷰 SWB-R1: 가로 iPhone에서도 조건을 통과했다 |
| 시작 조건 | 가로 우세 | 가로 우세 + 방향 | 리뷰 SWB-R2 |
| 제스처 시험 | 시뮬레이터로 시도, 안 되면 실기기 | 시험 못 함 (실기기로) | 이 환경에서 시뮬레이터 창이 열리지 않아 마우스/터치 이벤트를 넣을 수 없었다 (`Simulator.app` 창 0개, `osascript`로 activate 실패) |

## 검증 결과
- `build/test_site` 통과, iPhone/iPad 시뮬레이터 빌드 성공, 버전 `v0.1.1` 표시와 색을 iPad 스크린샷으로 확인.
- 교차리뷰 후: `paneSwipeStarts`와 반대 방향 튕김 테스트 추가, 새 제스처를 분할 화면에서만 켬 (review/SWB_refine_claude-sonnet-5-5.md).
- 확인 못함 (SWB-M3, 실기기): 실제 스와이프로 뒤로/앞으로 이동, 이중 이동이 없는지, 핸들 드래그와 충돌, 세로 스크롤 방해, 가로 iPhone에서 꺼져 있는지, 말풍선 색과 화살표(탭 조작 수단 없음).

## 후속 수정 (2026-11-21, 0.1.1 -> 0.1.2, 사용자 요청)
- 증상: iPad에서 뒤로/앞으로 스와이프가 매우 빠르게 밀 때만 인식된다.
- 원인: `gestureRecognizerShouldBegin`이 팬이 막 시작하는 순간의 `velocity`로 방향/가로 우세를 판단했다. 천천히 밀면 그 순간 속도가 작고 흔들려 방향 검사에서 탈락한다. 끝 기준도 이동량 80pt라 짧고 느린 스와이프가 걸렸다.
- 수정: 시작 판단을 누적 이동량(`translation`)으로 바꿨다 (`paneSwipeStarts(dx:dy:)`). 끝 기준을 `paneSwipeDone`(이동량 50pt 또는 그 방향 300pt/s)으로 낮췄다. 가장자리 팬이 웹뷰 스크롤 팬과 동시에 인식되게 했다. 영역 24pt는 그대로 (넓히면 페이지 안 가로 스크롤과 충돌, 계속 어려우면 조정).
- 같이 변경: 백업 파일 이름 끝 `-ipad`와 파일 이름 보조 판독(`csvDevice(fromFileName:)`, `importCSV(fileName:)`)을 폐지하고 파일 안 `# device:` 헤더만 쓴다 (헤더로 식별되므로 중복, IPD-Q7 변경).
- 검증: `build/test_site`(느린 스와이프 50pt, 속도 300pt/s, 이동량 기준 시작 판단), 시뮬레이터 빌드. 실제 스와이프는 실기기에서 확인해야 한다.

## 남은 한계
- 스와이프 중 화면이 손가락을 따라오는 효과는 없다 (손을 뗄 때 기준을 넘으면 이동, SWB-Q5).
- 이동량 기준은 화면 폭과 무관하게 80pt/500pt/s로 고정이다.
