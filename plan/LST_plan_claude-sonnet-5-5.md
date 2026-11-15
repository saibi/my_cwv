# [LST] 사이트 목록 통합, 초기화, CSV 백업/복원

## 1. 목표
- 기본 목록과 사용자 목록의 구분을 없애고 **목록 하나**로 만든다. 앱 첫 실행 때만 내장 기본값(`default_page.csv`)으로 목록을 만들고, 그 뒤로는 앱이 목록에 개입하지 않는다.
- "기본값으로 초기화" 기능을 제공한다 (앱에 내장된 기본값으로 목록을 되돌림).
- 편집 모드에서 모든 항목의 **순서 변경과 삭제**를 할 수 있다 (기본 항목 포함, 전부 삭제 가능). 각 항목의 이름/주소 편집도 모든 항목에 허용한다.
- 목록을 파일 앱(iCloud Drive 포함)에 `.csv`로 **백업(내보내기)** 하고 불러오기(복원)를 할 수 있다.
- 범위 밖: iCloud 자동 동기화(무료 Apple ID는 iCloud 권한이 없음. 파일 앱의 문서 선택기만 쓴다), 글자 크기/페이지 제목의 CSV 백업(LST-Q2), Keychain 백업 제거(PRS의 재설치 복원은 유지).
- PRS-Q1(기본/사용자 분리)을 이 계획이 대체한다.

## 2. 전체 흐름
```
저장 데이터 있음 ---------------------------> 그 목록을 그대로 사용 (앱은 개입하지 않음)
저장 데이터 없음 -> (Keychain 백업 있음 -> 복원) / (없음 -> default_page.csv로 최초 생성)
편집 버튼: 이동/삭제 (전체 항목), 행 스와이프: 편집/삭제
메뉴(...): 기본값으로 초기화 / CSV로 백업 / CSV에서 복원
```

## 3. 단계별 상세
### 1) 단일 목록 저장 모델
- `SiteStore`: `sites: [Site]`(저장되는 하나의 목록)만 둔다. `defaultPages`, `userSites`, `defaultZooms`를 없앤다. 글자 크기는 `Site.zoom`에 그대로 저장한다.
- 저장 형식(새): `SiteList { sites: [Site] }` JSON을 UserDefaults 키 `siteList`와 Keychain 백업에 함께 저장한다 (PRS의 Keychain 복원을 유지).
- 시작 시 불러오는 순서: UserDefaults `siteList` -> Keychain(새 형식) -> **이전 형식 마이그레이션** -> 최초 생성.
  - 이전 형식 마이그레이션(PRS 형식 `userData`, UserDefaults 또는 Keychain): 현재 번들 `default_page.csv` 목록(글자 크기는 `defaultZooms` 적용) 다음에 `userSites`를 이어 붙인 것을 새 목록으로 삼는다. 즉 지금 화면에 보이던 순서 그대로다. 그 뒤 새 형식으로 저장한다.
  - 더 오래된 형식(`sites` 키)이 남아 있으면 그 목록을 그대로 쓴다.
  - 최초 생성: `bundledDefaultPages()`(CSV, 비면 Google)를 목록으로 삼는다.
- 이후에는 `default_page.csv`가 바뀌어도 앱은 목록을 건드리지 않는다. 앱을 새로 빌드해 덮어쓰기 설치해도 같다.
- 기본 항목의 id는 지금처럼 주소 기반 고정 UUID를 유지한다 (초기화 후에도 같은 id라 `pageTitles`/`lastSiteID`가 이어짐).

### 2) 목록 화면과 편집
- `SiteListView`: 구역 없이 `ForEach(store.sites)` 하나. `EditButton`을 누르면 `.onMove`(순서 변경)와 `.onDelete`(삭제)가 모든 항목에 동작한다. 모든 항목을 지울 수 있고, 비어 있으면 안내 문구("오른쪽 위 +로 추가하거나 메뉴에서 기본값으로 초기화하세요")를 보여 준다.
- 행을 왼쪽으로 밀면 편집/삭제 (모든 항목). `SiteEditView`는 그대로 쓰고 기본 항목 구분 코드를 없앤다.
- 삭제/초기화/복원 때 `WebCache.drop`으로 웹뷰 캐시를 비운다.

### 3) 기본값으로 초기화
- 상단 메뉴(`ellipsis` 버튼)의 "기본값으로 초기화": 확인창("현재 목록이 사라지고 앱에 들어 있는 기본 목록으로 바뀝니다")을 거쳐, 목록을 `bundledDefaultPages()`로 교체한다. 글자 크기는 모두 100%가 된다. 페이지 제목 캐시는 같은 id로 이어진다. 열려 있던 웹뷰 캐시는 비운다.

### 4) CSV 백업/복원
- 형식: `default_page.csv`와 같다. 한 줄에 `주소[,제목]`, 첫 쉼표 앞이 주소. 이름이 비어 있는(자동) 항목은 주소만, 이름이 있으면 `주소,이름`으로 쓴다. 제목에 줄바꿈이 있으면 공백으로 바꾼다. 그래서 내보낸 파일을 그대로 `cwv/CWV/default_page.csv`에 복사해 기본값으로 쓸 수 있다. 첫 줄은 `# CWV site list` 주석.
- 내보내기: SwiftUI `.fileExporter`(`FileDocument` 구현 `CSVDocument`, UTType `.commaSeparatedText`). 사용자가 파일 앱의 위치(iCloud Drive 포함)를 고른다. 기본 파일명 `cwv_sites_YYYY-MM-DD`.
- 가져오기: `.fileImporter`(`.commaSeparatedText`, `.plainText`). 선택 후 `startAccessingSecurityScopedResource()`로 읽는다. 복원은 확인창("현재 목록이 파일 내용으로 바뀝니다")을 거쳐 **현재 목록을 파일 내용으로 교체**한다 (LST-Q1). 글자 크기는 100%로 시작한다.
- 신뢰할 수 없는 입력 처리: 파일 크기 1MB 초과는 거부, 줄 수 상한(예: 500), UTF-8이 아니면 거부, 각 줄은 기존 `parseDefaultPages`/`normalizeURL`로 검증하고 잘못된 줄은 건너뛴다. 유효한 줄이 하나도 없으면 목록을 바꾸지 않고 알림창으로 알린다. 결과(가져온 N개, 건너뛴 M줄)를 알림창으로 보여 준다.
- 전제 확인(2026-11-15): 문서 선택기(`fileExporter`/`fileImporter`)는 별도 프로세스로 동작해 iCloud 권한(entitlement) 없이 iCloud Drive 위치를 고를 수 있는 것이 iOS 표준 동작이다. 이 프로젝트는 최소 iOS 17이라 API가 있다. 실기기에서 iCloud Drive 저장/불러오기는 LST-M4에서 확인한다 (시뮬레이터는 제스처/문서 선택기를 조작할 수 없어 단위 테스트로 형식만 검증).

## 4. 공통 모듈
- `Site.swift`: `exportCSV(_ sites: [Site]) -> String`, 기존 `parseDefaultPages` 재사용(가져오기), 크기/줄 수 제한은 `parseCSVBackup(_ data: Data) -> [Site]?` 같은 순수 함수로 모아 테스트한다.
- `SiteStore.swift`: `reset()`, `replace(with:)`, `move`, `remove`, 새 저장 형식과 마이그레이션.
- `CSVDocument.swift`(신규): `FileDocument` 구현.

## 5. 구현 구조
- 수정: `SiteStore.swift`(단일 목록, 마이그레이션, 초기화), `Site.swift`(`exportCSV`, 제한 있는 파서), `SiteListView.swift`(단일 목록, 메뉴, 내보내기/가져오기, 알림), `test_site.swift`, `cwv/README.md`(기본 페이지 파일의 의미가 "첫 실행/초기화용"으로 바뀜, 백업/복원 사용법)
- 신규: `CWV/CSVDocument.swift`
- `default_page.csv`는 계속 번들 리소스이고 git에 올리지 않는다. 없으면 빌드 경고와 Google 한 개 (PRS-Q5 유지).
- 새 의존성 없음.

## 6. 결정 사항
- **LST-Q1** CSV 복원 방식 - [확정] 현재 목록을 교체 (추천안 선택). 확인창을 거친다.
- **LST-Q2** CSV에 글자 크기도 포함할지 - [확정] 포함 안 함 (추천안 선택). CSV는 주소와 이름만 담아 `default_page.csv`와 같은 형식을 유지한다. 복원하면 글자 크기는 100%로 돌아간다 (앱 삭제 후 재설치는 Keychain이 글자 크기까지 복원).

## 7. 마일스톤
| # | 내용 | 완료 기준 |
| :--- | :--- | :--- |
| LST-M1 | 단일 목록 저장 모델, 마이그레이션, 초기화 | `build/test_site` 통과 (최초 생성, 재실행 유지, CSV 변경에도 개입 없음, PRS 형식 마이그레이션 순서 보존, 초기화, 전부 삭제 후 재실행) |
| LST-M2 | 목록 화면: 통합, 이동/삭제, 메뉴, 빈 목록 안내 | 시뮬레이터에서 구역 없이 하나의 목록, 편집 모드 표시, 빌드 성공 |
| LST-M3 | CSV 내보내기/가져오기 로직 | `build/test_site` 통과 (왕복, 제목 쉼표, 자동 이름, 크기/줄 수 제한, 잘못된 줄) |
| LST-M4 | 파일 앱 연동 | 실기기에서 iCloud Drive에 저장하고 다시 불러와 목록 복원 |
