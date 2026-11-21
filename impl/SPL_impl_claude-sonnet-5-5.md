# [SPL] 구현 노트

- 계획: plan/SPL_plan_claude-opus-5-5.md
- 구현 커밋: c70b84d

## 아키텍처
| 파일 | 역할 |
| :--- | :--- |
| `Site.swift` | `SidebarSide`, `SidebarKey`(UserDefaults 키), `clampSidebarWidth`(240~min(창 50%, 480)), `SidebarLayout`(+`Partial`, `load`/`apply`), `csvHeader`(주석 헤더 공통 읽기, `csvDevice`도 이것으로), `csvSidebar`(값 검증), `exportCSV`/`exportCSVChecked`의 `layout` 인자, `CSVImport.sidebar` |
| `SiteStore.swift` | `exportCSV(device:layout:)`는 넘겨받기만 함 |
| `CWVApp.swift` | `RootView`로 분리 (크기 등급을 읽으려면 View 안이어야 함). 넓은 iPad 창이면 `splitView`(HStack: 목록, 경계 핸들, 웹), 아니면 기존 전환 `stackView` |
| `BrowserView.swift` | `closeTitle`(메뉴 항목 이름), `onSwipe`(가장자리 스와이프 동작, 없으면 `onClose`) 인자 추가 |
| `SiteListView.swift` | `selectedID`(행 강조), `onHide`(숨기기 버튼), 백업 때 현재 레이아웃 전달, 복원 때 iPad면 적용과 확인창 안내 |
| `SettingsView.swift` | iPad에서만 "iPad 분할 화면" 섹션 (위치 Picker, 너비 기본값 버튼) |

## 핵심 설계 결정
- `NavigationSplitView` 대신 `HStack`으로 직접 배치 - 계획 전제 확인대로 SwiftUI는 사이드바를 오른쪽에 둘 수 없고, 사용자가 바꾼 너비를 저장/제어할 수 없다.
- 설정은 `@AppStorage`(키는 `SidebarKey`) - `fabCorner`와 같은 방식. 복원은 같은 키를 `UserDefaults`에 직접 써도 `@AppStorage`가 따라간다.
- 드래그는 전역 좌표 기준 + 드래그 중 임시값(`dragWidth`), 끝날 때(`@GestureState`가 false가 될 때, 취소 포함)만 저장 - 경계가 움직이면서 로컬 좌표 변화량이 튀는 것과 매 프레임 저장을 피한다. 시작 너비(`dragStart`)는 한 번만 잡고 누적 이동량을 더한다 (기준을 매번 `dragWidth`로 읽으면 이동량이 중복된다, SPL-R2). 기준은 `clampSidebarWidth`로 줄어든 표시 너비라서 창이 좁을 때 시작 순간 튀지 않는다.
- `BrowserView.id(ObjectIdentifier(WebCache.view(for: site)))` - `WebView`의 Coordinator가 처음 웹뷰 보유자를 들고 있어, 사이트를 바꾸거나 캐시의 웹뷰가 교체(주소 편집, 초기화/복원)돼도 화면이 이전 웹뷰를 계속 보인다 (리뷰 SPL-R1에서 `site.id`만으로는 부족함이 드러나 변경).
- 좌우 순서는 `ForEach(order, id:)`로 그린다 - 위치로 뷰를 구분하면 옵션에서 위치를 바꿀 때 목록이 새로 만들어져 옵션 시트가 닫힌다 (SPL-R3).
- 고른 사이트가 없으면 목록은 숨겨지지 않고 숨기기 버튼도 없다 - 다시 열 길(플로팅 메뉴)이 없어서.

## 진행 기록
- SPL-M1: `clampSidebarWidth`/`SidebarLayout`/`csvHeader`/`csvSidebar`/`exportCSV(layout:)`를 `build/test_site`에 검증 추가 (범위, 창 축소, 헤더 왕복, 잘못된 값 무시, 범위 자르기, 데이터 줄 뒤 헤더 무시, `load/apply`). 통과.
- SPL-M2: iPad Pro 11 시뮬레이터 빌드와 실행. 왼쪽/오른쪽 배치, 선택 행 강조, 숨김(전체 폭) 스크린샷 확인. iPhone 시뮬레이터에서는 기존처럼 사이트가 전체 화면으로 열리는 것을 확인.

- 리뷰(codex) 반영: R1~R5 (review/SPL_refine_claude-sonnet-5-5.md). 경계에 VoiceOver 조절 동작(R4)을 추가했다.

## 계획 대비 변경
| 항목 | 계획 | 최종 구현 | 상황과 근본 이유 |
| :--- | :--- | :--- | :--- |
| 분할 조건 | 가로 크기 등급이 regular | regular **이고 iPad 기기** | iPhone 가로 Max 기종은 regular가 될 수 있는데, 위치/너비 설정이 iPad 옵션에만 있어 iPhone이 설정할 수 없는 분할로 바뀐다 |
| CSV 형식 | (결정 시 v4를 가정) | v3 유지, 주석 헤더 3줄 | 이미 계획 3단계 5에 반영 (파서가 `#` 줄을 건너뛰므로 버전 변경 불필요) |

## 검증 결과
- `build/test_site` 통과, iPhone/iPad 시뮬레이터 빌드 성공.
- 시뮬레이터 스크린샷: iPad 세로 왼쪽/오른쪽/숨김, 선택 행 강조, iPhone 전환.
- 확인 못함: 회전과 Split View/Stage Manager 창 크기 변경(시뮬레이터에서 조작 수단 없음), 경계 드래그와 웹뷰 스크롤 충돌, 옵션 화면 Picker, 숨김 후 가장자리 스와이프로 복귀, 백업 -> 복원 왕복 UI (SPL-M3 실기기).

## 남은 한계
- 분할 화면에서도 웹 영역은 사이트 하나뿐이다 (다중 웹 영역은 범위 밖).
- 크기 등급이 regular에서 compact로 바뀌면 목록 뷰가 새로 만들어져, 열려 있던 옵션/편집 시트와 파일 선택/복원 확인 상태는 닫힌다 (SPL-R3 중 이 부분은 상태를 `RootView`로 올려야 해서 하지 않음).
- 사이드바를 오른쪽에 두면 가장자리 스와이프로 목록을 다시 열 수 없다 (플로팅 메뉴로만).
