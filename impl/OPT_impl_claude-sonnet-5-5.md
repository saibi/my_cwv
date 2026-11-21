# [OPT] 구현 노트

- 계획: plan/OPT_plan_claude-sonnet-5-5.md
- 구현 커밋: 39b6b23

## 아키텍처
| 파일 | 역할 |
| :--- | :--- |
| `Site.swift` | `parseZoomToken`, `splitNameZoom`(마지막 쉼표 뒤가 숫자면 확대%), `parseSites(defaultZoom:)`, `exportCSV(_:titles:)`, `importCSV(_:defaultZoom:)` |
| `SiteStore.swift` | `defaultZoom`(UserDefaults `defaultZoom`, 기본 120%), `add(zoom:)`, `update`의 zoom 보정, `reset()`/`exportCSV()` |
| `SiteListView.swift` | `SiteRow`(편집 모드 탭=편집), 길게 누르기 메뉴, 편집/추가 시트의 확대% Stepper |
| `SettingsView.swift` | 옵션 시트, 공유 `zoomStepper` |

## 핵심 설계 결정
- `defaultPages`를 `[Site]`에서 `(Double) -> [Site]`로 바꿨다 - 초기화할 때 지금의 기본 확대%를 `default_page.csv`의 % 없는 줄에 적용하려면 매번 다시 해석해야 한다. `[Site]`를 받는 convenience init을 남겨 기존 테스트와 호출을 유지했다.
- CSV 버전: 첫 줄 `# v2`면 v2(`주소,"이름",확대%`, 이름은 항상 따옴표, `\"`/`\\` 이스케이프), 없으면 v1(`주소[,이름]`) - 사용자 지시(OPT-Q5). v1을 확대% 없는 형식으로 고정해서 "이름이 `, 숫자`로 끝나면 확대%로 오인"하는 모호함이 사라졌다.
- 편집 모드 판별은 List 안쪽 뷰(`SiteRow`)에서 `\.editMode`를 읽는다 - 바깥 뷰에서는 값이 갱신되지 않는다.

## 진행 기록
- OPT-M1/M2: 옵션, CSV 3칸 해석/내보내기 구현. `build/test_site`에 토큰/3-2-1칸/쉼표 이름/범위 밖/왕복/옵션 저장/초기화 반영 검증 추가, 통과.
- OPT-M3: 편집 시트 확대%, 편집 모드 탭 편집, 옵션 시트 구현. 시뮬레이터 빌드 성공.

## 계획 대비 변경
| 항목 | 계획 | 최종 구현 | 상황과 근본 이유 |
| :--- | :--- | :--- | :--- |
| CSV 형식 | `url,name,%` (이름 쉼표는 마지막 쉼표 규칙) | 첫 줄 `# v2` 버전 + 이름 따옴표/이스케이프 | 사용자 지시(OPT-Q5). 옛 형식과 새 형식이 같은 문자열에서 모호했기 때문 |
| 복원/가져오기의 글자 크기 | (LST) 항상 100% | 파일의 확대%, 없으면 기본 확대% | OPT-Q1 결정 |
| `replace(with:)` | - | 변경 없음 | 호출하는 쪽에서 이미 확대%가 채워진 목록을 넘긴다 |

## 검증 결과
- `build/test_site` 통과, 시뮬레이터 빌드 성공.
- 확인 못함: 실기기에서 편집 모드 탭, 길게 누르기, 옵션 화면 동작 (시뮬레이터는 제스처를 조작할 수 없음).

## 남은 한계
- 헤더가 없는 파일은 항상 v1이라 확대%를 읽지 않는다 (`default_page.csv`에 확대%를 쓰려면 `# v2`를 첫 줄에 둬야 함).
- 복원한 이름은 고정되어 페이지 제목이 바뀌어도 따라가지 않는다 (OPT-Q4).
- 옵션은 Keychain 백업 대상이 아니라 앱 삭제 후 재설치하면 120%로 돌아간다.
