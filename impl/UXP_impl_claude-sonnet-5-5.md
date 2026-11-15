# [UXP] 구현 노트

- 계획: plan/UXP_plan_claude-sonnet-5-5.md
- 구현 커밋: 5900089

## 아키텍처
| 파일 | 역할 |
| :--- | :--- |
| `CWV/AppGlyph.swift` | 말풍선+글자줄 글리프(SwiftUI). 아이콘 생성과 FAB가 공유 |
| `make_icon.swift` | macOS용 아이콘 생성 스크립트 (`ImageRenderer` -> 1024px PNG) |
| `CWV/Site.swift` | `FabCorner`(모서리 enum + `nearest`) 추가 |
| `CWV/BrowserView.swift` | FAB를 `AppGlyph`로, 드래그 후 모서리 스냅, `@AppStorage("fabCorner")` |
| `CWV/adblock.json`, `WebView.swift` | `AdBlock`이 규칙을 한 번 컴파일해 각 웹뷰에 붙인 뒤 로드 |

## 핵심 설계 결정
- 글리프의 글자 줄은 `destinationOut`으로 뚫는다 - 아이콘(파란 배경)과 FAB(반투명 원) 양쪽에서 배경색을 따로 지정하지 않아도 된다.
- 드래그는 `simultaneousGesture`로 붙여 Menu 탭을 건드리지 않게 한다.
- 규칙 컴파일이 실패하면(`nil`) 규칙 없이 로드한다.

## 진행 기록
- UXP-M1: 시뮬레이터에 임시 디버그 코드로 DOM/요청 호스트를 덤프해 광고 도메인과 `.dm-display-frame` 확인 (계획 문서 3절에 기록). 디버그 코드는 되돌림.
- UXP-M2: 아이콘 PNG 생성 후 이미지로 확인, 시뮬레이터 스크린샷에서 FAB가 같은 글리프임을 확인.
- UXP-M3: `FabCorner` 테스트 추가 (test_site OK).
- UXP-M4: 시뮬레이터에서 광고 영역이 비고 본문/목록은 정상 로드됨을 스크린샷으로 확인.

## 계획 대비 변경
| 항목 | 계획 | 최종 구현 | 상황과 근본 이유 |
| :--- | :--- | :--- | :--- |
| 광고 숨김 선택자 | 일반 선택자 가정 | 조사 결과 기반 `.dm-display-frame` 등 | M1에서 실제 DOM 확인 |
| 드래그/메뉴 충돌 확인 | 시뮬레이터에서 확인 | 미확인 | Simulator GUI가 실행 중이지 않아 제스처를 보낼 수 없었다 (idb/cliclick도 없음) |

## 검증 결과
- `build/test_site` OK (FabCorner, adblock.json 구조 포함), 시뮬레이터 빌드 성공, 스크린샷으로 아이콘/FAB/광고 숨김 확인.
- 미확인: 실제 드래그 스냅과 탭 메뉴가 함께 동작하는지, 홈 화면 아이콘 표시. 충돌하면 계획대로 `LongPressGesture` 후 드래그로 바꾼다.

## 남은 한계
- 광고 빈 자리(래퍼 여백)가 일부 남는다. `.dm-display-frame`은 다모앙 전용 선택자다.
- 새 광고 업체/도메인은 `adblock.json`을 직접 갱신해야 한다.
