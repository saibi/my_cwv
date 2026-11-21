# [OPT] 옵션(기본 확대%), CSV 형식 개선(url,name,%), 사이트 편집 보완

## 1. 목표
- 옵션 화면을 추가하고 첫 항목으로 **기본 확대%**(기본 120%)를 둔다. 사이트를 새로 추가하면 이 값이 그 사이트의 글자 크기가 된다.
- CSV 백업/복원 형식을 `url,name,확대%`로 확장한다. 백업할 때 이름이 비어 있는(자동) 사이트는 **지금 목록에 보이는 이름(저장해 둔 페이지 타이틀)** 을 name 칸에 적어, 복원하면 접속 없이도 그 이름이 바로 적용된다.
- 이미 등록된 사이트의 **주소, 이름, 확대%** 를 모두 편집할 수 있게 한다. 편집 진입이 눈에 잘 띄게 한다.
- 범위 밖: iCloud 자동 동기화, 기존 사이트의 확대%를 옵션 변경에 맞춰 일괄 변경(옵션은 "새로 추가할 때"만 쓴다), 옵션의 Keychain 백업.

## 2. 전체 흐름
```
메뉴(...) -> 옵션 -> 기본 확대% (50~300%, 10% 단위, 기본 120%)  [UserDefaults "defaultZoom"]
사이트 추가 시트   : 확대% 칸의 초깃값 = 기본 확대%
사이트 편집 시트   : 이름 / 주소 / 확대% (현재 값)
CSV 백업           : url,name,% (name이 비면 저장된 페이지 타이틀)
CSV 복원/기본 목록 : % 칸이 있으면 그 값, 없으면 기본 확대%
```

## 3. 단계별 상세
### 1) 옵션 (기본 확대%)
- `SiteStore.defaultZoom: Double`: `clampZoom` 적용, UserDefaults 키 `defaultZoom`, 값이 없으면 `1.2`. 목록 데이터(`SiteList`)와 분리해서 저장한다.
- `SiteListView` 메뉴에 "옵션" 항목을 추가하고, `SettingsView`(시트)에서 `Stepper`로 50~300% 10% 단위 조절, 현재 값을 "120%"로 표시. 이후 옵션이 늘면 이 화면에 추가한다.
- 적용 범위: `store.add`로 만드는 새 사이트의 `zoom`. 이미 있는 사이트와 `SiteStore.init`의 최초 생성/마이그레이션은 건드리지 않는다.

### 2) CSV 형식
- 한 줄: `url,name,확대%`. `확대%`는 `120` 또는 `120%` 모두 허용한다 (내보낼 때는 `120`). 주소 칸은 지금처럼 쉼표/따옴표가 있으면 따옴표로 감싼다.
- 해석(`splitLine` 확장): 주소를 뗀 나머지에서 **마지막 쉼표 뒤 토큰이 숫자(+선택적 `%`)이면 확대%** 로 보고 떼어낸다. 나머지가 name이다 (name 안의 쉼표는 보존). 확대%가 범위(50~300) 밖이면 `clampZoom`으로 맞추고, 숫자가 아니면 name의 일부로 본다. 옛 2칸 형식(`url[,name]`)과 `default_page.csv`도 그대로 읽힌다.
- 내보내기: 모든 줄에 3칸을 쓴다 (`url,,120`처럼 name이 빈 칸일 수 있음). name은 `store.title` 대신 "name이 비어 있고 저장된 페이지 타이틀이 있으면 그 타이틀"을 쓴다. 타이틀도 없으면 빈 칸. (도메인 fallback은 쓰지 않는다: 자동 이름으로 남겨 둔다.) 줄바꿈은 공백으로 바꾼다. 첫 줄 주석: `# CWV site list: url,name,zoom%`.
- 복원(`parseSites`): `Site.zoom`에 % 값을 넣는다. % 칸이 없으면 `defaultZoom`을 쓴다 (파서에 `defaultZoom` 인자를 받는다). 기본 목록(`default_page.csv`) 해석과 `reset()`도 같은 규칙이다.
- `exportCSV`가 타이틀 캐시를 받아야 하므로 시그니처를 `exportCSV(_ sites: [Site], titles: [String: String])`로 바꾸고 `exportCSVChecked`도 맞춘다.
- 제한(1MB, 500줄, 중복 보존 규칙)은 LST와 같다.

### 3) 사이트 편집 보완
- `SiteEditView`에 확대% 칸(`Stepper`, 50~300%)을 추가한다. 추가 모드의 초깃값은 `store.defaultZoom`, 편집 모드는 현재 `site.zoom`. 저장 시 `store.update`에 zoom도 반영한다 (`clampZoom`).
- 편집 진입을 쉽게: 편집(EditButton) 모드에서 행을 탭하면 열기 대신 **편집 시트**를 연다 (`@Environment(\.editMode)` 확인). 일반 모드의 탭은 열기, 왼쪽 스와이프 "편집"은 그대로 둔다. 길게 누르기(contextMenu)로도 편집/삭제를 제공한다.
- 주소를 바꾸면 웹 캐시와 페이지 타이틀 캐시를 버리는 기존 동작(`SiteStore.update`)을 유지한다. 편집 중 열려 있는 웹뷰가 있으면 `WebCache.drop`으로 새 값(zoom 포함)이 적용되게 한다.

## 4. 공통 모듈
- `Site.swift`: `parseZoomToken(_:) -> Double?`(공유), `splitLine`/`parseSites` 확장, `exportCSV(_:titles:)`.
- `SiteStore.swift`: `defaultZoom`, `add(name:url:zoom:)`, `update`(zoom 포함), `reset()`/`replace`에 `defaultZoom` 적용.

## 5. 구현 구조
- 수정: `Site.swift`, `SiteStore.swift`, `SiteListView.swift`(메뉴, 편집 시트, 편집 모드 탭), `test_site.swift`, `cwv/README.md`(CSV 형식, 옵션), `cwv/default_page.csv.example`(3칸 예시)
- 신규: `CWV/SettingsView.swift` (작은 시트). 새 의존성 없음.
- 자체 검증 항목: 3칸/2칸/1칸 해석, name 쉼표, 범위 밖 %, 내보내기-가져오기 왕복(타이틀 반영), `defaultZoom` 기본 120%와 저장 유지, 새 사이트가 기본 확대%를 받는지.

## 6. 결정 사항
- **OPT-Q1** % 칸이 없는 CSV 줄(옛 백업, 기본 목록 `default_page.csv`)의 확대% - [확정] (a) 기본 확대%를 적용 (추천안 선택)
  - (a) 기본 확대%를 적용 (추천: 새 옵션의 의도와 맞고, 옛 백업을 복원해도 120%로 읽기 편해짐. 단 옛 백업 복원 시 이전 크기 정보는 원래 없었음)
  - (b) 100% 유지 (LST 동작 그대로)
- **OPT-Q2** 이름이 비어 있는 사이트를 백업할 때 name 칸 - [확정] 저장된 페이지 타이틀을 적는다 (사용자 요청). 접속한 적이 없어 타이틀이 없으면 빈 칸.
- **OPT-Q3** 편집 진입 - [확정] 편집 모드에서 행 탭 = 편집 시트 (추천안 선택). 스와이프 편집과 길게 누르기 메뉴도 제공.
- **OPT-Q4** 복원 후에는 name이 고정되어 페이지 타이틀이 바뀌어도 따라가지 않는다 (이름을 비워야 자동). 이 동작을 받아들일지 - [확정] 받아들임 (추천안 선택). 자동 이름으로 되돌리려면 편집에서 이름을 비운다.

## 7. 마일스톤
| # | 내용 | 완료 기준 |
| :--- | :--- | :--- |
| OPT-M1 | 기본 확대% 옵션과 저장, 새 사이트에 적용 | `build/test_site` 통과 (기본 120%, 재생성 시 유지, add가 반영) |
| OPT-M2 | CSV 3칸 형식 해석/내보내기 | `build/test_site` 통과 (3/2/1칸, 쉼표 name, 범위 밖, 왕복, 타이틀 반영) |
| OPT-M3 | 편집 화면에 확대%, 편집 모드 탭 편집, 옵션 화면 | 시뮬레이터 빌드 성공, 실기기에서 주소/이름/% 편집과 옵션 변경 확인 |
