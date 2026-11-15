# [CWV] 커뮤니티 웹 모아보기 iOS 앱 (Community Web Viewer)

> **변경 기록**
> - 2026-11-15 claude-sonnet-5-5: 구현 중 변경 반영. pageZoom -> text-size-adjust 주입, 최소 iOS 17.0, 테스트 빌드 명령(-parse-as-library). 자세한 이유는 impl/CWV_impl_claude-sonnet-5-5.md

## 1. 목표
- 자주 가는 커뮤니티 사이트를 앱 하나에 모아 보고, **사이트별로 글자(페이지) 크기를 조절해 기억**하는 개인용 iOS 앱을 만든다.
- 배경: damoang.net/empathy를 iPhone 16 Safari "홈 화면에 추가" 웹 앱으로 보는데, 웹 앱 모드에는 `aA` 페이지 확대가 없다. Safari 설정에서 확대한 뒤 다시 홈 화면에 추가해야 해서 불편하다.
- 대상: 본인 iPhone 16 한 대. App Store 배포는 하지 않는다.
- 범위 밖: 푸시 알림, 리더 모드, iCloud 동기화, 파비콘 자동 수집, 광고 차단, 여러 기기 지원, iPad 전용 레이아웃.

## 2. 전제 검증 (2026-11-15)
- `curl -I https://damoang.net/empathy` (iPhone UA): `HTTP/2 403` Cloudflare challenge, `x-frame-options: SAMEORIGIN`, CSP `frame-src 'self'`.
  - 그래서 iframe으로 감싸는 PWA는 불가하다. 서버 프록시도 Cloudflare에 막히고 로그인 정보가 프록시를 거치므로 기각한다.
  - WKWebView는 실제 WebKit 브라우저라서 사용자가 Safari에서 하듯 challenge를 통과한다. 이 점은 M1에서 실기기로 확인한다.
- 개발 환경: `/Applications/Xcode.app` (Xcode 27.2, 27B52), Swift 6.4.2.
  - **현재 Xcode 라이선스에 동의하지 않은 상태**이고 active developer dir이 CommandLineTools다. 구현 전에 사용자가 직접 다음을 실행해야 한다.
    `sudo xcode-select -s /Applications/Xcode.app && sudo xcodebuild -license accept`
  - 이 때문에 iOS 시뮬레이터 런타임 설치 여부는 아직 확인하지 못했다. M1에서 확인한다.
- `WKWebView.pageZoom` (iOS 14+): Safari `aA`와 같은 방식으로 레이아웃까지 함께 확대하는 공개 API라고 가정했다. **[기각] 2026-11-15 시뮬레이터 확인: 130%에서 레이아웃이 다시 배치되지 않아 오른쪽이 잘렸다.** `-webkit-text-size-adjust` 주입으로 바꿨다(4-3 참고).
- 무료 Apple ID로 서명하면 유효기간이 7일이다. SideStore는 기기에서 스스로 다시 서명하며, 단축어 자동화로 매일 갱신할 수 있다. 무료 계정은 SideStore를 포함해 앱 3개, 7일마다 App ID 10개로 제한된다. 이 정보는 2025~2026년 제3자 문서 기준이며 설치할 때 공식 문서로 다시 확인한다.
- Google 계정 로그인은 내장 웹뷰(WKWebView)에서 Google이 차단한다(`disallowed_useragent`). 사이트 자체 계정이나 네이버/카카오 로그인을 쓴다.

## 3. 전체 흐름
```
앱 실행 -> 사이트 목록 (마지막으로 본 사이트가 있으면 바로 열기)
  -> 사이트 선택 -> 전체 화면 웹뷰 (사이트별 pageZoom 적용)
       - 가장자리 스와이프: 뒤로/앞으로
       - 당겨서 새로고침
       - 떠 있는 버튼(aA) -> 메뉴: A- / 현재 % / A+ / 100%로 / 목록으로
  -> 목록 화면: 추가 / 편집(이름, URL) / 삭제 / 순서 변경
```

## 4. 단계별 상세
### 1) 데이터 모델과 저장
- `Site { id: UUID, name: String, url: URL, zoom: Double }` (Codable).
- `[Site]`를 JSON으로 만들어 `UserDefaults` 키 `sites`에 저장한다. 처음 실행할 때는 기본값 `[Site(name: "다모앙 공감", url: https://damoang.net/empathy, zoom: 1.0)]`을 넣는다.
- 마지막으로 연 사이트 id는 `UserDefaults` 키 `lastSiteID`에 저장한다.
- zoom 범위: 0.5~3.0, 0.1 단위. 범위를 벗어나면 clamp한다.
- URL 입력 정규화: 앞뒤 공백을 제거하고, scheme이 없으면 `https://`를 붙인다. `http`/`https`만 허용하고 host가 없으면 거부한다(편집 화면에 오류 표시).

### 2) 사이트 목록 화면 (SwiftUI)
- `NavigationStack` + `List`. 행을 누르면 웹뷰로 이동한다. `onMove`로 순서 변경, `onDelete`로 삭제한다.
- 툴바의 `+` 버튼과 행 편집은 같은 시트(이름, URL 입력 폼)를 쓴다. 이름이 비어 있으면 host를 이름으로 쓴다.

### 3) 웹뷰 화면
- `UIViewRepresentable`로 `WKWebView`를 감싼다.
  - `WKWebsiteDataStore.default()`를 써서 쿠키와 로그인을 앱을 다시 실행해도 유지한다.
  - `allowsBackForwardNavigationGestures = true`.
  - `scrollView.refreshControl`에 `UIRefreshControl`을 달아 당기면 `reload()`한다.
  - 글자 크기: `-webkit-text-size-adjust: <zoom*100>%`를 `WKUserScript`(documentStart)로 주입하고 현재 페이지에도 바로 실행한다. 값이 바뀌면 즉시 적용하고 저장한다. (변경: pageZoom은 가로로 넘쳐서 기각)
  - 시스템 바: 상태바 영역까지 웹 콘텐츠를 채우지 않고 safe area를 지킨다. 다모앙 상단 메뉴가 가려지지 않게 하기 위해서다. 내비게이션 바는 숨긴다.
- 사이트별 `WKWebView` 인스턴스를 메모리 dict(`[UUID: WKWebView]`)에 보관한다. 목록에 갔다가 돌아와도 스크롤 위치와 페이지를 유지하기 위해서다.
  - ponytail: 메모리 경고가 오면 dict를 비운다. 그 이상은 하지 않는다.
- 떠 있는 `aA` 버튼(오른쪽 아래, 반투명)은 SwiftUI `Menu`로 만든다: `A-`, `A+`, `100%`, 현재 % 표시, `목록으로`.
- 외부 도메인 링크 처리: `decidePolicyFor navigationAction`에서 외부 링크를 `.cancel`하고 `SFSafariViewController` 시트로 연다(CWV-Q1). host 비교 함수 `isExternal(_:base:)`는 `Site.swift`에 두고 자체 검증한다.
- `target=_blank`나 `window.open`: `WKUIDelegate.createWebViewWith`에서 같은 웹뷰에 load한다. 외부 도메인이면 CWV-Q1 규칙을 따른다.

### 4) 빌드와 설치
- 개발 중: Xcode에서 iPhone을 USB로 연결하고, 무료 Apple ID 개인 팀으로 서명해 Run한다. 동작 확인용이다.
- 상시 사용: CWV-Q2 결정에 따른다.
  - IPA 만들기(서명 없이, SideStore가 다시 서명한다):
    ```
    xcodebuild -project cwv/CWV.xcodeproj -scheme CWV -configuration Release \
      -sdk iphoneos -derivedDataPath build CODE_SIGNING_ALLOWED=NO build
    mkdir -p build/Payload && cp -R build/Build/Products/Release-iphoneos/CWV.app build/Payload/
    (cd build && zip -qr CWV.ipa Payload)
    ```
  - 위 명령을 `cwv/make_ipa.sh`로 둔다. 만든 IPA는 AirDrop이나 파일 앱으로 아이폰에 옮긴 뒤 SideStore에서 설치한다.

## 5. 공통 모듈
- `SiteStore` (ObservableObject): `sites` 배열, 추가/수정/삭제/이동, zoom 변경, 저장. 저장할 때마다 UserDefaults에 JSON을 쓴다. 데이터가 작으므로 그대로 둔다.
- 순수 로직(`normalizeURL`, `clampZoom`, 기본값 생성)은 Foundation만 import하는 `Site.swift`에 둔다. 시뮬레이터 없이 macOS에서 테스트하기 위해서다.

## 6. 구현 구조
```
cwv/
  CWV.xcodeproj/          # 직접 작성한 최소 pbxproj (objectVersion 77, 파일 시스템 동기화 그룹 -> 소스 추가 시 프로젝트 수정 불필요)
  CWV/
    CWVApp.swift          # @main, SiteStore 주입, lastSiteID 복원
    Site.swift            # 모델 + normalizeURL/clampZoom (Foundation only)
    SiteStore.swift       # 저장/편집
    SiteListView.swift    # 목록, 추가/편집 시트
    WebView.swift         # UIViewRepresentable, delegate, 웹뷰 캐시
    BrowserView.swift     # 웹뷰 + aA 메뉴
    Assets.xcassets       # 앱 아이콘 1장 (단색 + 글자, 직접 생성)
  test_site.swift         # assert 기반 자체 검증
  make_ipa.sh             # 무서명 IPA 생성
```
- 외부 의존성 없음 (SwiftUI, WebKit만 사용). xcodegen이나 SPM 패키지는 쓰지 않는다.
- 최소 iOS 버전: 17.0 (변경: 이 Mac의 시뮬레이터 런타임이 iOS 17.2뿐이라 검증을 위해 낮췄다. iPhone 16에서는 문제없다).
- Bundle ID: `local.saibi.cwv`. SideStore가 설치할 때 자기 팀 ID를 붙여 바꾼다.
- 자체 검증: `swiftc -parse-as-library cwv/CWV/Site.swift cwv/CWV/SiteStore.swift cwv/test_site.swift -o build/test_site && build/test_site`
  - 검증 항목: URL 정규화(scheme 없음, 공백, `ftp://` 거부, host 없음 거부), `isExternal`(같은 host, 하위 도메인, www 차이, 다른 도메인), zoom clamp(0.4 -> 0.5, 3.5 -> 3.0), JSON 왕복, 기본값에 다모앙이 포함되는지.
  - `test_site.swift`는 `@main`을 쓰고 `-parse-as-library`로 컴파일한다(여러 파일에서는 main.swift 외 top-level 코드 불가). `Site.swift`에는 `@main`이 없다.

## 7. 결정 사항
- **CWV-Q1** 외부 도메인 링크(유튜브, 기사 등)를 어떻게 열까 - [확정] 기본은 `SFSafariViewController` 시트로 연다. 필요하면 Safari 앱으로 넘길 수 있게 한다.
  - Safari 앱으로 넘기는 기능은 `SFSafariViewController` 하단 툴바에 기본으로 있는 "Safari에서 열기" 버튼을 쓴다. 따로 코드를 넣지 않는다.
  - 외부 도메인 판정: 링크 host가 현재 사이트 host와 같지 않고 그 하위 도메인도 아니면 외부로 본다(`www.` 제외 후 비교). 사용자가 직접 누른 링크(`navigationType == .linkActivated`)에만 적용한다. 리다이렉트나 로그인 흐름(네이버/카카오 OAuth)은 웹뷰 안에 그대로 둔다.
  - `http`/`https`가 아닌 scheme(`tel:`, `mailto:`, 앱 링크)은 `UIApplication.open`으로 넘긴다.
- **CWV-Q2** 상시 설치 방식 - [확정] SideStore 자동 갱신 (무료 Apple ID). 사용자가 2026-11-15 대화에서 선택했다. 유료 계정으로 바꿔도 코드는 그대로이고 Xcode 서명만 바꾸면 된다.
- **CWV-Q3** 사이트 전환 UI - [확정] 목록 화면 -> 전체 화면 웹뷰. `aA` 메뉴의 "목록으로"로 돌아간다. 웹뷰 캐시가 있어서 돌아와도 페이지와 스크롤이 유지된다. 하단 탭바는 화면 높이를 차지하고 탭이 5개를 넘으면 밀려서 기각했다.

## 8. 마일스톤
| # | 내용 | 완료 기준 |
| :--- | :--- | :--- |
| CWV-M1 | 프로젝트 생성, 단일 사이트 웹뷰 + pageZoom | 시뮬레이터(또는 실기기)에서 damoang.net/empathy가 열리고 Cloudflare를 통과한다. 확대를 바꾸면 레이아웃이 함께 커진다 |
| CWV-M2 | 모델/저장 + 자체 검증 | `test_site` 실행 시 assert가 모두 통과한다 |
| CWV-M3 | 목록 추가/편집/삭제/순서 변경, 사이트별 zoom 저장 | 앱을 재실행해도 목록, 순서, zoom, 로그인 상태가 유지된다 |
| CWV-M4 | 제스처, 새로고침, aA 메뉴, 외부 링크(Q1), 웹뷰 캐시 | 실기기에서 뒤로 스와이프와 당겨서 새로고침이 동작한다. 목록에 갔다 와도 스크롤이 유지된다 |
| CWV-M5 | `make_ipa.sh` + SideStore 설치 안내(README) | IPA가 생성된다. 실기기에서 SideStore로 설치하고 갱신 단축어를 설정한다 (사용자 확인) |
