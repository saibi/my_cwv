# [SWT] 첫 페이지에서 스와이프로 목록 복귀, 목록 제목을 페이지 타이틀로

## 1. 목표
- 사이트 안에서 이전 페이지가 없는(첫 페이지) 상태에서도 화면 왼쪽 가장자리 스와이프로 사이트 목록으로 돌아간다. 이전 페이지가 있으면 지금처럼 웹 뒤로가기가 먼저다.
- 목록의 사이트 이름: CSV 제목이나 사용자가 입력한 이름이 없으면, 도메인 대신 그 페이지의 `<title>`을 자동으로 쓴다.
- 범위 밖: 스와이프 중 화면이 손가락을 따라오는 인터랙티브 전환, 앱 시작 때 모든 사이트를 미리 불러와 제목을 채우는 것(SWT-Q2), 페이지 제목 백업(Keychain).

## 2. 전체 흐름
```
[목록] -탭-> [사이트 첫 페이지] -링크-> [글 상세] ...
  글 상세에서 가장자리 스와이프: 웹 뒤로가기 (WKWebView 기본 제스처)
  첫 페이지(뒤로 갈 곳 없음)에서 가장자리 스와이프: 목록으로 (이 계획)
첫 페이지의 title 확정 -> 목록 이름에 반영 (이 계획)
```

## 3. 단계별 상세
### 1) 첫 페이지에서 스와이프로 목록 복귀
- 현재: `SiteWebView`는 `allowsBackForwardNavigationGestures = true`라서 웹 기록이 있을 때만 뒤로 스와이프가 된다. 기록이 없으면 아무 일도 일어나지 않는다. 목록 복귀는 플로팅 메뉴의 "목록으로"뿐이다.
- 방법: `SiteWebView.init`에서 `UIScreenEdgePanGestureRecognizer(edges: .left)`를 웹뷰에 붙인다.
  - `gestureRecognizerShouldBegin`에서 `!web.canGoBack`일 때만 시작한다. 그래서 웹 기록이 있을 땐 WebKit의 뒤로가기 제스처와 겹치지 않는다.
  - 제스처가 끝났을 때(`.ended`) 오른쪽으로 충분히 이동했거나(`translation.x > 80`) 빠르게 밀었으면(`velocity.x > 500`) `onBack()`을 호출한다. 이 값은 실기기에서 조정한다.
  - `onBack`은 `onExternal`처럼 `WebView.sync`에서 최신 클로저를 받는다. `BrowserView`가 `onClose`를 넘기고 `CWVApp`이 `currentID = nil` + `lastSiteID = nil`을 처리한다(기존 동작과 동일).
- 전환 모양: `CWVApp`에서 화면 교체를 `withAnimation`과 `.transition(.move(edge: .leading))` 정도로 감싸 목록이 왼쪽에서 들어오게 한다. 메뉴의 "목록으로"도 같은 전환을 쓴다.
- 주의: SPA 사이트(다모앙은 Svelte)는 `pushState`로 이동해도 웹 기록에 쌓이므로 `canGoBack`이 true가 되어 기존 동작을 유지한다. 리다이렉트로 시작한 첫 페이지는 기록이 비어 있다.
- 한계: 스와이프 중에 화면이 따라오지는 않고 손을 뗄 때 전환된다. 가장자리에서 시작해야 하며, 페이지 안 가로 스크롤 영역과는 가장자리에서만 겹친다.

### 2) 목록 제목을 페이지 타이틀로
- 의미 변경: `Site.name`이 빈 문자열이면 "자동"이다. 표시 이름 = `name`이 있으면 그것, 없으면 저장해 둔 페이지 타이틀, 그것도 없으면 도메인(`host`). 순수 함수 `Site.displayName(cached:)`를 `Site.swift`에 두고 테스트한다.
  - `parseDefaultPages`는 제목이 없는 줄의 `name`을 도메인 대신 `""`(자동)로 둔다 (PRS의 "제목 없으면 도메인"을 "제목 없으면 페이지 타이틀, 아직 모르면 도메인"으로 바꾼다).
  - `SiteEditView`는 이름을 비우면 `""`로 저장한다 (입력칸 안내는 "비우면 페이지 제목"). 지금처럼 도메인을 박아 넣지 않는다.
  - 이미 저장된 사용자 사이트 중 이름이 도메인과 똑같은 것은 자동으로 간주한다 (`name == url.host`).
- 타이틀 수집: `SiteWebView`가 `web.title`을 KVO로 지켜보고, **웹 기록이 비어 있는 상태(`backForwardList.backList.isEmpty`), 즉 첫 페이지에 있을 때만** 비어 있지 않은 제목을 `onTitle`로 전달한다. 글 상세의 제목이 사이트 이름이 되지 않게 하기 위함이고, 리다이렉트가 있어도 동작한다.
- 저장: `SiteStore`에 `@Published pageTitles: [String: String]`(사이트 id -> 제목)을 두고 UserDefaults 키 `pageTitles`에 저장한다. **한 번 받은 제목은 앱을 다시 실행해도, 덮어쓰기 설치를 해도 유지된다**(시작할 때 `pageTitles`를 읽어 목록에 바로 적용). 캐시일 뿐이라 Keychain 백업에는 넣지 않는다(SWT-Q3). 제목은 앞뒤 공백을 지우고, 첫 페이지에 올 때마다 갱신한다.
- 목록은 `SiteListView.row`에서 표시 이름을 쓴다. 이름을 못 받은 사이트는 처음엔 도메인으로 보이고, 한 번 열어 보면 제목으로 바뀐다 (사이트를 닫고 나가는 순간 반영된 상태).
- 전제 확인: 다모앙 공감 페이지의 `document.title`이 `날짜별 공감글 | 다모앙`임을 UXP 조사 중 시뮬레이터에서 확인했다 (2026-11-15). 사이트가 `title`을 클라이언트에서 늦게 바꿔도 KVO가 받는다. `curl`은 Cloudflare에 막혀(403) 목록 시점에 제목을 미리 가져올 수 없다.

## 4. 공통 모듈
- 재사용: `SiteWebView`의 콜백 전달 방식(`sync`), `SiteStore` 저장 패턴(UserDefaults), `Site.swift` 순수 함수 테스트 방식.
- 신규 순수 함수: `Site.displayName(cached:)`.

## 5. 구현 구조
- 수정: `WebView.swift`(엣지 팬 제스처, title KVO, `onBack`/`onTitle`), `BrowserView.swift`(`onBack` 전달), `CWVApp.swift`(전환 애니메이션), `Site.swift`(`displayName`, `parseDefaultPages`의 빈 이름), `SiteStore.swift`(`pageTitles`, `setPageTitle`), `SiteListView.swift`(표시 이름, 입력칸 안내와 빈 이름 저장), `test_site.swift`, `cwv/README.md`
- 새 의존성과 새 파일 없음.

## 6. 결정 사항
- **SWT-Q1** 첫 페이지에서 스와이프했을 때 동작 - [확정] 한 번 스와이프로 바로 목록으로 (추천안 선택).
- **SWT-Q2** 목록 제목을 채우는 시점 - [확정] 사이트를 열어 보면 채운다 (추천안 선택). 열기 전에는 도메인으로 보인다.

- **SWT-Q3** 앱 삭제 후 재설치 때 제목도 복원할지 - [확정] 복원 안 함 (추천안 선택). 앱 실행/덮어쓰기 설치에서는 유지되고, 삭제 후 재설치하면 도메인으로 돌아갔다가 사이트를 열면 다시 채워진다.

## 7. 마일스톤
| # | 내용 | 완료 기준 |
| :--- | :--- | :--- |
| SWT-M1 | `displayName`, `parseDefaultPages` 빈 이름, 스토어 `pageTitles` | `build/test_site` 통과 (제목 없는 줄은 빈 이름, 캐시/도메인 대체, 이름이 도메인과 같으면 자동) |
| SWT-M2 | 첫 페이지 title 수집과 목록 반영 | 시뮬레이터에서 사이트를 열었다가 나오면 목록에 페이지 제목이 보임, 글 상세 제목으로는 바뀌지 않음, 앱을 종료했다 다시 실행해도 제목 유지 |
| SWT-M3 | 첫 페이지에서 스와이프로 목록 복귀 | 실기기에서 첫 페이지 가장자리 스와이프 -> 목록, 글 상세에서는 기존대로 웹 뒤로가기 |
