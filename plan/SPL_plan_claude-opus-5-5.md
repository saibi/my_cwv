# [SPL] iPad 분할 화면 (목록 + 웹 페이지)

## 1. 목표
- iPad의 넓은 화면에서 커뮤니티 목록(사이드바)과 고른 사이트의 웹 페이지를 한 화면에 같이 보여 준다. 목록에서 다른 사이트를 누르면 오른쪽(또는 왼쪽) 웹 영역만 바뀐다.
- 사이드바 위치(왼쪽/오른쪽)를 사용자가 고른다. 사이드바 너비를 사용자가 조절하고, 값은 앱을 다시 켜도 유지한다.
- 범위 밖: iPhone 화면 변경(지금처럼 목록 <-> 웹 전환), 여러 사이트를 동시에 띄우는 다중 웹 영역, 탭, 자동 동기화(레이아웃 설정은 CSV 백업/복원으로 옮긴다, SPL-Q5).
- IPD-Q2에서 기각했던 (c) "목록은 사이드바, 웹은 오른쪽 분할 표시"를 이 계획에서 사용자 요청으로 새로 다룬다. 넓은 화면의 목록 폭 제한(`.frame(maxWidth: 700)`)은 분할이 아닌 경우에 그대로 쓴다.

## 2. 전체 흐름
```
CWVApp
  horizontalSizeClass == .regular (SPL-Q2) ?
    yes -> SplitLayout: [사이드바 SiteListView] [경계 핸들] [BrowserView 또는 빈 안내]   (좌우 순서는 sidebarSide)
    no  -> 지금처럼 currentID 유무로 SiteListView / BrowserView 전환
상태: currentID(@State, 기존) / sidebarSide, sidebarWidth, sidebarHidden(@AppStorage, 새로)
```
- 크기 등급이 바뀌어도(회전, Split View/Stage Manager 창 크기 변경) `currentID`는 그대로라 보던 사이트가 유지된다. 웹뷰는 `WebCache`에 있어 레이아웃이 바뀌어도 페이지와 스크롤이 남는다.

## 3. 단계별 상세
### 1) 분할 조건
- 전제 확인(2026-11-21, Xcode 27.2 / iOS SDK 27.2): SwiftUI `NavigationSplitView`는 사이드바를 오른쪽에 둘 수 없다 (SwiftUI 인터페이스에 `primaryEdge` 없음, UIKit `UISplitViewController.primaryEdge`만 있음). 사용자가 끌어서 바꾸는 너비도 SwiftUI에서는 직접 제어/저장할 수 없다 (`navigationSplitViewColumnWidth(min:ideal:max:)`는 고정 범위 지정). 그래서 **`HStack`으로 직접 배치**한다. UIKit 래핑보다 코드가 짧고 좌우/너비를 그대로 제어한다.
- `@Environment(\.horizontalSizeClass)`가 `.regular`일 때만 분할한다 (SPL-Q2). iPad 전체 화면/가로 Split View 절반 이상은 regular, Slide Over와 좁은 분할은 compact라 지금의 iPhone식 전환을 쓴다. iPhone은 항상 compact(가로 Max 기종 포함 여부는 시뮬레이터로 확인, regular면 분할되어도 동작에는 문제 없음).

### 2) 배치 (`SplitLayout`, CWVApp.swift 안 private 뷰)
- `GeometryReader { g in HStack(spacing: 0) { ... } }`. `sidebarSide == .trailing`이면 순서를 뒤집는다 (`[web, handle, list]`).
- 사이드바: 기존 `SiteListView { open($0) }`를 `.frame(width: w)`로 넣는다. 현재 사이트 행은 강조 표시 (`SiteListView`에 `selectedID: UUID?` 인자 추가, `listRowBackground`로 표시).
- 웹 영역: `currentID`의 사이트가 있으면 기존 `BrowserView`, 없으면 안내 문구 ("목록에서 사이트를 고르세요", `.secondary`).
- 경계 핸들: 폭 1pt 구분선 + 투명한 12pt 터치 영역 (`contentShape`), 가운데 짧은 손잡이 모양(capsule). `DragGesture`로 너비를 바꾸고 (`sidebarSide`가 trailing이면 방향 반대), 끝나면 저장한다. 드래그 중에는 `@State` 임시값만 바꿔 웹뷰가 매 프레임 저장 경로를 타지 않게 한다.
- 너비 범위: 순수 함수 `clampSidebarWidth(_ w: Double, total: Double) -> Double` (Site.swift). 최소 240pt, 최대 `min(total * 0.5, 480)`, 기본 320pt (SPL-Q4). 창이 줄어 저장값이 최대를 넘으면 표시만 줄이고 저장값은 두어 창이 다시 커지면 원래 너비로 돌아온다.
- 사이드바 숨기기 (SPL-Q1): `sidebarHidden`이 true면 사이드바와 핸들을 빼고 웹만 전체 폭. 애니메이션 `.easeInOut(0.25)`.

### 3) 분할 화면에서의 기존 동작 (SPL-Q1, Q3)
- `BrowserView`의 `onClose`(플로팅 메뉴 "목록으로", 첫 페이지 가장자리 스와이프)는 분할 화면에서 의미가 바뀐다. `BrowserView`에 넘기는 클로저만 바꾸고 `BrowserView`/`WebView` 내부는 그대로 둔다:
  - 분할: 메뉴 항목 이름을 "목록 숨기기"/"목록 보이기"로 (BrowserView에 `closeTitle: String` 인자), 동작은 `sidebarHidden` 토글.
  - 가장자리 스와이프: 분할에서는 사이드바가 숨겨져 있고 왼쪽에 있을 때만 "목록 보이기"로 쓰고, 그 밖에는 무시한다 (사이드바가 보이는데 스와이프로 닫히면 실수 동작이 된다).
- 목록 쪽 툴바에 사이드바 숨기기 버튼(`sidebar.left`/`sidebar.right` 아이콘)을 분할 화면에서만 추가한다. 숨겼을 때 다시 여는 길은 플로팅 메뉴 "목록 보이기"(와 왼쪽 사이드바의 가장자리 스와이프).
- `store.lastSiteID` 복원은 지금과 같다. 분할 화면에서 사이트를 닫는 동작은 없으므로(숨기기만) `currentID = nil`이 되는 경로는 사이트 삭제/목록 교체뿐이고, 그때는 안내 문구가 보인다.

### 4) 설정 위치 (SPL-Q3)
- 옵션 화면(`SettingsView`)에 "iPad 분할 화면" 섹션: 목록 위치 `Picker`(왼쪽/오른쪽, segmented), "너비 기본값으로" 버튼. `UIDevice.current.userInterfaceIdiom == .pad`일 때만 표시.
- 저장: `@AppStorage("sidebarSide")`(String raw `leading`/`trailing`, 기본 leading), `@AppStorage("sidebarWidth")`(Double, 기본 320), `@AppStorage("sidebarHidden")`(Bool, 기본 false). `SiteStore`/Keychain에는 넣지 않고(기존 `fabCorner`와 같은 방식), CSV 백업에는 넣는다 (SPL-Q5, 6단계).
- `SidebarSide: String` enum은 `FabCorner` 옆(Site.swift)에 둔다.

### 5) CSV 백업/복원에 레이아웃 포함 (SPL-Q5)
- 전제 확인(2026-11-21, 코드 확인): 데이터 줄 파서(`csvDataLines`)는 `#` 주석 줄을 모두 건너뛰고, `csvVersion`은 `# vN`의 N이 3 이상이면 레이아웃 칸을 읽는다. 기존 `# device:`도 주석 헤더로 붙인 정보다. 그래서 **CSV 형식 버전은 v3 그대로 두고 주석 헤더 줄만 추가**한다. 데이터 줄 형식이 바뀌지 않으므로 v4로 올릴 필요가 없고, 이전 버전 앱도 새 백업을 그대로 복원한다 (헤더만 무시). 결정 당시 설명한 "v4"는 이 확인으로 필요 없어져 바꿨다.
- 형식: `# device:` 아래에 키 하나당 한 줄.
  ```
  # v3
  # device: ipad
  # sidebar-side: trailing
  # sidebar-width: 320
  # sidebar-hidden: 0
  # CWV site list: ...
  ```
- 내보내기: iPad(`CSVDevice.ipad`)에서 만들 때만 세 줄을 넣는다. iPhone은 분할 화면이 없어 넣지 않는다. `exportCSV(_:titles:device:layout:)`에 `layout: SidebarLayout?` 인자를 추가하고, nil이면 지금과 같은 출력이 나온다 (기존 테스트 유지).
- 읽기: 순수 함수 `csvSidebar(_ text: String) -> SidebarLayout.Partial`(Site.swift). 기존 `csvDevice`처럼 첫 데이터 줄 앞 주석만 보고, 키 이름은 대소문자를 구분하지 않는다. 외부 파일이므로 값은 검증하고 잘못된 값은 그 키만 무시한다: side는 `leading`/`trailing`, width는 정수이고 240~480 범위로 자른다 (창 크기에 따른 최대는 표시할 때 `clampSidebarWidth`), hidden은 `0`/`1`. 헤더 이름 읽기는 `csvDevice`와 공통 헬퍼 `csvHeader(_ text:, key:) -> [String]`(같은 키의 값들을 위에서부터)로 묶어 재사용한다.
- 복원: `CSVImport`에 `sidebar: SidebarLayout.Partial` 필드를 추가한다. 교체 확인에서 "교체"/"그대로 복원"/"데스크톱 설정은 빼고 복원" 어느 쪽이든 목록을 바꾼 뒤, **지금 기기가 iPad이고** 파일에 유효한 값이 있으면 그 키만 `UserDefaults`(`@AppStorage`와 같은 키)에 쓴다. iPhone에서는 무시한다. 확인창 문구에 값이 있을 때 "목록 위치/너비도 파일 값으로 바뀝니다."를 덧붙인다.
- 테스트(`test_site.swift`): 왕복(iPad 내보내기 -> 읽기 값 동일), layout nil이면 헤더 없음, 잘못된 값(`side: middle`, `width: abc`, `hidden: 2`) 무시, 범위 밖 너비 자르기(100 -> 240, 9999 -> 480), 데이터 줄 뒤의 헤더는 무시, 헤더가 있어도 사이트 목록 해석 결과는 같음.

### 6) 확인할 동작
- 회전/창 크기 변경 시 웹 페이지 유지, 사이드바에서 다른 사이트 선택 시 웹 영역 전환, 플로팅 버튼 모서리 계산(웹 영역 `GeometryReader` 기준이라 사이드바 쪽으로 넘어가지 않는지), 편집/옵션 시트와 파일 앱 창이 분할 화면에서 정상 표시, 사이드바 너비 드래그가 웹뷰 스크롤과 충돌하지 않는지.

## 4. 공통 모듈
- `clampSidebarWidth`, `SidebarSide`, `SidebarLayout`(side/width/hidden, 각 값이 optional인 `Partial`), `csvHeader`, `csvSidebar`, `exportCSV`의 `layout` 인자 (Site.swift, 테스트 대상). `SiteStore.exportCSV(device:layout:)`는 넘겨받기만 한다. 나머지는 뷰 코드.

## 5. 구현 구조
- 수정: `CWVApp.swift`(크기 등급 분기, `SplitLayout`), `SiteListView.swift`(`selectedID` 강조, 분할 화면 사이드바 숨기기 버튼), `BrowserView.swift`(`closeTitle` 인자), `SettingsView.swift`(위치/너비 초기화), `Site.swift`+`test_site.swift`(`clampSidebarWidth`, `SidebarSide`, CSV 레이아웃 헤더), `SiteStore.swift`(`exportCSV`에 layout 전달), `SiteListView.swift`(백업 시 현재 레이아웃 전달, 복원 시 적용과 안내 문구), `cwv/README.md`(iPad 분할 화면 안내).
- 새 파일, 새 의존성 없음.
- 검증: `build/test_site`(너비 범위), iPad 시뮬레이터 스크린샷(왼쪽/오른쪽, 숨김, 세로/가로), iPhone 시뮬레이터에서 기존 전환 동작 그대로.

## 6. 결정 사항
- **SPL-Q1** 사이드바를 숨기는 기능 - [확정] (a) 숨기기/보이기 토글 (추천안 선택). 플로팅 메뉴 "목록으로"가 분할 화면에서 "목록 숨기기"/"목록 보이기"가 되고, 목록 툴바에 숨기기 버튼. 기각: (b) 항상 표시 (c) "목록으로"로 웹을 닫기
- **SPL-Q2** 분할을 쓰는 조건 - [확정] (a) 가로 크기 등급이 regular일 때 (추천안 선택). Slide Over/좁은 분할 창(compact)은 지금의 목록 <-> 웹 전환. 기각: (b) iPad면 항상
- **SPL-Q3** 위치/너비 조절 방법 - [확정] (a) 위치는 옵션 화면 Picker, 너비는 경계 드래그 + 옵션의 "너비 기본값으로" (추천안 선택). 기각: (b) 너비 슬라이더 (c) 목록 메뉴에 위치 빠른 전환
- **SPL-Q4** 너비 범위와 기본값 - [확정] (a) 기본 320pt, 최소 240pt, 최대 min(창 폭 50%, 480pt). 창이 줄면 표시만 줄이고 저장값은 유지 (추천안 선택). 기각: (b) 최소 200pt, 최대 60%
- **SPL-Q5** 레이아웃 설정을 CSV 백업에 넣을지 - [확정] (b) 넣음 (사용자 결정). 위치/너비/숨김을 주석 헤더 3줄로 넣고 iPad에서만 쓰고 읽는다. 확인 결과 주석 헤더 추가만으로 충분해 형식 버전은 v3 유지 (3단계 5). 기각: (a) 넣지 않음

## 7. 마일스톤
| # | 내용 | 완료 기준 |
| :--- | :--- | :--- |
| SPL-M1 | 너비 범위 함수, 위치 enum, CSV 레이아웃 헤더 | `build/test_site` 통과 (최소/최대/창 축소 시, 헤더 왕복/잘못된 값 무시/범위 자르기, 기존 v3 테스트 그대로) |
| SPL-M2 | 분할 배치, 경계 드래그, 숨기기, 옵션 섹션 | iPad 시뮬레이터 빌드 성공, 왼쪽/오른쪽/숨김 스크린샷, iPhone 시뮬레이터에서 기존 전환 동작 그대로 |
| SPL-M3 | 실기기 확인 | iPad(saibi pro11)에서 회전, Split View/Stage Manager 창 크기 변경, 너비 드래그와 유지, 사이트 전환 시 페이지 유지, iPad 백업 -> 설정 변경 -> 복원 시 레이아웃 복귀 |
