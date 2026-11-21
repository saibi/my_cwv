# [OPT] 구현 노트

- 계획: plan/OPT_plan_claude-sonnet-5-5.md
- 구현 커밋: 39b6b23

## 아키텍처
| 파일 | 역할 |
| :--- | :--- |
| `Site.swift` | `parseZoomToken`, `splitNameZoom`(마지막 쉼표 뒤가 숫자면 확대%), `parseSites(defaultZoom:)`, `exportCSV(_:titles:)`, `importCSV(_:defaultZoom:)` |
| `SiteStore.swift` | `defaultZoom`(UserDefaults `defaultZoom`, 기본 120%), `add(zoom:)`, `update`의 zoom 보정, `reset()`/`exportCSV()` |
| `SiteListView.swift` | `SiteRow`(편집 모드 탭=편집), 길게 누르기 메뉴, `SettingsView`, 편집/추가 시트의 확대% Stepper |

## 핵심 설계 결정
- `defaultPages`를 `[Site]`에서 `(Double) -> [Site]`로 바꿨다 - 초기화할 때 지금의 기본 확대%를 `default_page.csv`의 % 없는 줄에 적용하려면 매번 다시 해석해야 한다. `[Site]`를 받는 convenience init을 남겨 기존 테스트와 호출을 유지했다.
- 내보내기는 항상 3칸 - 마지막 칸이 항상 확대%라 name에 쉼표/숫자가 있어도 해석이 모호하지 않다. 옛 2칸 파일에서 `이름, 100`처럼 끝이 숫자인 이름은 확대%로 읽힌다 (알려진 한계).
- 편집 모드 판별은 List 안쪽 뷰(`SiteRow`)에서 `\.editMode`를 읽는다 - 바깥 뷰에서는 값이 갱신되지 않는다.

## 진행 기록
- OPT-M1/M2: 옵션, CSV 3칸 해석/내보내기 구현. `build/test_site`에 토큰/3-2-1칸/쉼표 이름/범위 밖/왕복/옵션 저장/초기화 반영 검증 추가, 통과.
- OPT-M3: 편집 시트 확대%, 편집 모드 탭 편집, 옵션 시트 구현. 시뮬레이터 빌드 성공.

## 계획 대비 변경
| 항목 | 계획 | 최종 구현 | 상황과 근본 이유 |
| :--- | :--- | :--- | :--- |
| 신규 파일 | `SettingsView.swift` | `SiteListView.swift` 안에 둠 | 새 파일은 `project.pbxproj`에 등록해야 하는데 그 파일에는 커밋하면 안 되는 개인 Team ID 변경이 섞여 있다. 작은 뷰라 같은 파일에 둔다. |
| 복원/가져오기의 글자 크기 | (LST) 항상 100% | 파일의 확대%, 없으면 기본 확대% | OPT-Q1 결정 |
| `replace(with:)` | - | 변경 없음 | 호출하는 쪽에서 이미 확대%가 채워진 목록을 넘긴다 |

## 검증 결과
- `build/test_site` 통과, 시뮬레이터 빌드 성공.
- 확인 못함: 실기기에서 편집 모드 탭, 길게 누르기, 옵션 화면 동작 (시뮬레이터는 제스처를 조작할 수 없음).

## 남은 한계
- 옛 2칸 CSV에서 이름이 `, 숫자`로 끝나면 확대%로 오인한다.
- 복원한 이름은 고정되어 페이지 제목이 바뀌어도 따라가지 않는다 (OPT-Q4).
- 옵션은 Keychain 백업 대상이 아니라 앱 삭제 후 재설치하면 120%로 돌아간다.
