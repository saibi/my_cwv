# [SNS] 구현 노트

- 계획: plan/SNS_plan_claude-sonnet-5-5.md
- 구현 커밋: (커밋 후 기재)
- 버전: 0.2.2 -> 0.3.0 (계획과 같음, 구현 직전 현재 버전이 계획의 시작 버전 0.2.2와 같아 재계산 없음)

## 아키텍처
| 파일 | 역할 |
| :--- | :--- |
| `Site.swift` | `joystickCmKey`/`joystickCmRange`(0.2...1.0)/`defaultJoystickCm`(0.3), `joystickPtPerCm`(iPhone 60, iPad 52), `clampJoystickCm`(NaN/무한대는 기본값, 범위 자르기, 0.05 단위), `joystickDistance(isPad:cm:)`, `fabMoveDistance(isPad:cm:)`(감도의 5배). cm 인자는 기본값이라 기존 호출과 테스트가 그대로 동작 |
| `BrowserView.swift` | `@AppStorage(joystickCmKey)`에서 읽은 cm를 `joystickDistance`/`fabMoveDistance`에 넘긴다. `margin`(`fabMargin`)도 같은 값에서 나와 감도를 따라간다 |
| `SettingsView.swift` | 새 "조이스틱" 섹션 (iPhone/iPad 모두): 슬라이더(민감/둔감 라벨), 현재 값 `0.30cm`, "기본값으로 (0.3cm)" 버튼 |
| `cwv/Version.xcconfig`, `cwv/README.md` | 0.3.0, 설정 안내 |

흐름: 슬라이더 -> `@AppStorage("joystickCm")`(기기별) -> BrowserView가 다시 그려지며 새 거리로 판정 (앱 재시작 불필요).

## 핵심 설계 결정
- 설정은 pt가 아니라 cm로 저장 - 기기마다 pt가 달라 cm가 의미를 보존한다 (환산은 기존 근사값 60/52pt).
- 읽을 때마다 `clampJoystickCm`을 거친다 - 저장값이 깨졌거나 범위 밖이어도 안전하게 쓰기 위해 (UserDefaults는 외부에서 바뀔 수 있다). 슬라이더의 `Binding`도 같은 함수를 거친다.
- 기본 0.3cm에서 기존 상수와 정확히 같은 값 (18/90, 16/78) - 반올림 순서를 맞춰 확인하고 기존 테스트 단언을 그대로 통과시켰다.
- CSV 백업에는 넣지 않는다 (SNS-Q3) - 기기마다 화면 밀도와 손 크기가 다르다.

## 진행 기록
- SNS-M1: 순수 함수와 `build/test_site` 검증 추가. 기본값 동일(18/90, 16/78), 양끝(0.2cm: 12/10pt, 1.0cm: 60/52pt, 모서리 이동 300/260pt), NaN/무한대/범위 밖/0.05 단위, 범위 전체(0.20~1.00, 17단계)에서 탭 판정(8pt)보다 큼, 단조 증가, 이동은 약 5배, `fabMargin` 불변식 유지. 통과.
- SNS-M2: BrowserView 연결과 옵션 슬라이더. iPhone/iPad 시뮬레이터 빌드 성공.

## 계획 대비 변경
| 항목 | 계획 | 최종 구현 | 상황과 근본 이유 |
| :--- | :--- | :--- | :--- |
| (없음) | | | 계획대로 구현 |

## 검증 결과
- `build/test_site` 통과, iPhone/iPad 시뮬레이터 빌드 성공.
- 확인 못함: 옵션 화면 표시(슬라이더 모양, 라벨, 현재 값, 기본값 버튼 활성/비활성 - 시뮬레이터에서 화면을 열 조작 수단이 없음), 슬라이더를 움직였을 때 실제 조이스틱 민감도 변화와 양끝(0.2/1.0cm) 동작, 둔감하게 했을 때 버튼이 안쪽으로 들어와도 네 방향이 닿는지 (SNS-M3 실기기).

## 남은 한계
- 슬라이더 값마다 정확한 cm는 기기 종류별 근사값(60/52pt)이다 (iPad mini는 실제로 조금 다름).
- 가장 민감한 0.2cm에서 iPad는 10pt라 탭 판정(8pt)과 2pt 차이뿐이다 (탭하다 흔들리면 조이스틱으로 인식될 수 있음).
- 감도를 바꾸면 버튼의 화면 끝 여백도 달라져 버튼 위치가 약간 움직인다 (SNS-Q6).
