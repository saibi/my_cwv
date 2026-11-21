# [JOY] 구현 노트

- 계획: plan/JOY_plan_claude-sonnet-5-5.md
- 구현 커밋: ae04c48
- 버전: 0.1.3 -> 0.2.0 (계획과 같음, 구현 직전 현재 버전이 계획의 시작 버전 0.1.3과 같아 재계산 없음)

## 아키텍처
| 파일 | 역할 |
| :--- | :--- |
| `Site.swift` | `FabAction`(none/back/forward/zoomIn/zoomOut/move), `joystickDistance(isPad:)`(iPhone 60pt, iPad 52pt), 순수 판정 `fabAction(dx:dy:joystick:move:)`, `FabCorner`에 `CaseIterable`과 `title` |
| `BrowserView.swift` | 드래그 `onChanged`에서 `live` 동작과 이동 목표 모서리를 갱신하고 말풍선을 보임, `onEnded`에서 손을 뗀 위치(`translation`)로 실행 (`navigate`/`zoom`/모서리 이동), 결과 말풍선 `toast`(1.2초, 취소 가능한 `DispatchWorkItem`), 놓으면 가는 모서리에 윤곽 원, 메뉴에 "뒤로/앞으로/버튼 위치" 추가 |
| `cwv/Version.xcconfig` | 0.2.0 |

흐름: 끌기 -> `action(translation)`(= `fabAction`, 1cm=`joystickDistance`, 이동=3배) -> `live`/말풍선 -> 손 떼면 같은 판정으로 실행.

## 핵심 설계 결정
- 판정은 손을 뗀 위치의 실제 이동량으로만, 튕기는 속도(`predictedEndTranslation`)는 쓰지 않는다 - 기존 PRS의 튕기기는 8pt만 끌어도 모서리로 가서 조이스틱과 공존할 수 없고, 속도를 쓰면 짧게 휙 움직여도 동작한다.
- 판정을 순수 함수로 분리 - 터치를 시뮬레이터에서 시험할 수 없어(입력 주입 도구 없음) 경계값은 `test_site.swift`로 고정한다.
- 끄는 동안 "지금 놓으면 일어날 일"을 버튼 옆 말풍선으로 보이고(놓은 뒤에는 결과), 모서리 이동이면 목표 모서리에 윤곽 원을 그린다 - 메뉴가 안 뜨는 조작이라 피드백이 없으면 무슨 일이 일어났는지/취소됐는지 알 수 없다. 말풍선은 버튼의 바깥쪽 끝에 맞추고 화면 안쪽으로 20pt 띄워 화면 밖으로 나가지 않게 한다.
- `Menu`와 `simultaneousGesture(DragGesture(minimumDistance: 8))`는 그대로 둔다 - UXP/PRS에서 이미 실기기로 쓰고 있어, 끌었다 놓을 때 메뉴가 같이 열리지 않는 것은 같은 경로다. 이번 "돌아와서 놓음"도 같은 경로로 기대하지만 이 환경에서는 시험하지 못했다.
- 1cm = iPhone 60pt, iPad 52pt - 화면 밀도(pt/inch)에서 계산한 근사값이다 (iPad mini는 실제로 조금 더 길다).

## 진행 기록
- JOY-M1: `fabAction`/`joystickDistance`/`FabCorner` 확장을 `build/test_site`에 검증 추가 (방향, 1cm 미만/돌아온 경우, 경계 포함, 대각선, 모서리 이동 경계 179/180pt, 기기별 거리, 모서리 4개 이름 중복 없음), 통과.
- JOY-M2: `BrowserView` 제스처/말풍선/메뉴 구현. iPhone/iPad 시뮬레이터 빌드 성공, iPad에서 앱 실행 후 화면 정상 (스크린샷).

## 계획 대비 변경
| 항목 | 계획 | 최종 구현 | 상황과 근본 이유 |
| :--- | :--- | :--- | :--- |
| 햅틱 | (명시 없음) | 동작이 바뀔 때 가벼운 선택 햅틱 | 임계 거리를 넘었는지 손끝으로 알 수 있게 (코드 한 줄) |

## 검증 결과
- `build/test_site` 통과, iPhone/iPad 시뮬레이터 빌드 성공, iPad 시뮬레이터에서 실행 정상.
- 확인 못함 (JOY-M3, 실기기): 실제 끌기 동작 전부 (방향별 뒤로/앞으로/크게/작게, 원래 자리로 돌아와 놓았을 때 아무 일도 없고 메뉴가 안 열리는지, 탭하면 메뉴, 멀리 끌면 모서리 이동, 놓으면 가는 모서리 윤곽, 말풍선 위치), 메뉴의 "뒤로/앞으로/버튼 위치", www.clien.net에서 뒤로/앞으로, 1cm가 실제로 약 1cm인지.

## 남은 한계
- 가장 가까운 모서리가 지금 모서리면 멀리 끌어도 제자리다.
- 1cm는 기기 종류별 근사값이다 (기기마다 정확한 cm는 아님).
- 스와이프(SWB)는 그대로이고, 조이스틱과 스와이프의 동작이 둘 다 남는다.
