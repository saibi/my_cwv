# [UXP] CWV 사용성 개선: 앱 아이콘, 플로팅 버튼 통일/이동, 광고 숨기기

## 1. 목표
- 앱 아이콘을 "커뮤니티 웹 전용 뷰어"가 드러나는 디자인으로 교체한다. (현재: 파란 배경에 흰 "aA" 글자뿐)
- 뷰어의 플로팅 버튼(현재 우측 하단 "aA" 원형)을 같은 형태(글리프)로 바꾼다.
- 플로팅 버튼을 화면 네 모서리로 옮길 수 있게 한다.
- 커뮤니티 페이지의 광고를 차단하거나 숨긴다.
- 범위 밖: 사이트별 광고 규칙 편집 UI, 외부 필터 리스트(EasyList 등) 자동 갱신, 아이콘 다크/틴트 변형, 버튼의 자유 위치(모서리 외) 저장.

## 2. 전체 흐름
- 1) 글리프 설계 (SwiftUI 뷰 하나) -> 2) 같은 뷰로 앱 아이콘 PNG 생성, FAB에도 사용 (아이콘과 버튼이 항상 같은 형태)
- 3) FAB 모서리 이동 (순수 로직은 `Site.swift`, UI는 `BrowserView.swift`)
- 4) 광고 숨기기 (`WKContentRuleList`, `WebView.swift`)
- 구현 순서: 4번 전제 검증(M1) -> 1,2번 -> 3번 -> 4번 구현.

## 3. 단계별 상세
### 1) 앱 아이콘
- 글리프는 SwiftUI 뷰 `AppGlyph` 하나로 정의한다. 앱에서는 FAB에, 아이콘 생성 스크립트에서는 `ImageRenderer`로 1024x1024 PNG 렌더에 쓴다. 코드가 하나라서 둘이 어긋나지 않는다.
- 아이콘 생성은 `cwv/make_icon.swift` (macOS에서 `swiftc`로 실행, 외부 의존성 없음; 시스템에 PIL/rsvg가 없어 확인함 2026-11-15). 결과를 `AppIcon.appiconset/icon.png`에 덮어쓴다. iOS가 모서리를 둥글게 처리하므로 PNG는 꽉 찬 정사각형, 알파 없음.
- 디자인: 둥근 말풍선(커뮤니티) 안에 길이가 다른 글자 줄 3개(맨 위 줄은 굵게; 읽기/글자 크기). 아이콘은 파란 배경(현재 색 유지) + 흰 말풍선, FAB는 같은 글리프를 반투명 원 위에 그린다 (UXP-Q1 확정).

### 2) 플로팅 버튼 글리프 통일
- `BrowserView.menu`의 label을 `Text("aA")` 대신 `AppGlyph`로 교체한다. 크기 44x44 원형 반투명 배경은 유지한다.
- 메뉴 항목(A+/A-/100%/목록으로)은 그대로. 글리프만 바뀌므로 기능을 알아보기 어려워지면 Q1 결과에 따라 보조 표식을 둔다.

### 3) 플로팅 버튼 이동
- 위치는 `enum FabCorner: String { topLeading, topTrailing, bottomLeading, bottomTrailing }` (기본 `bottomTrailing`).
- 순수 로직 `FabCorner.nearest(to point: CGPoint, in size: CGSize)`를 `Site.swift`에 두고 `test_site.swift`에서 검증한다 (화면 중심 기준 사분면).
- 이동 방법: 버튼을 드래그해 놓으면 가장 가까운 모서리로 스냅한다 (UXP-Q2 확정). 버튼이 `Menu`라 탭(메뉴 열기)과 드래그가 충돌하지 않는지 시뮬레이터에서 확인한다. 충돌하면 길게 눌러 드래그(`LongPressGesture` 후 `DragGesture`)로 바꾼다.
- 저장: 전체 공통 `@AppStorage("fabCorner")` 한 줄 (UXP-Q3 확정). `Site` 데이터는 건드리지 않는다.
- 안전 영역(`safeArea`)을 지켜 노치/홈 인디케이터와 겹치지 않게 한다. 웹 페이지의 하단/상단 고정 UI와 겹치면 사용자가 모서리를 바꿔 피한다는 것이 이 기능의 목적이다.

### 4) 광고 숨기기
- 방식: `WKContentRuleList` (WebKit 내장 콘텐츠 차단 JSON). 앱에 규칙 JSON을 번들로 넣고 `WKContentRuleListStore`로 컴파일해 `WKWebViewConfiguration.userContentController.add(_:)`로 붙인다. 네트워크 단계에서 광고 스크립트/프레임 로딩을 막아 `JS 주입`보다 가볍다.
  - `block` 규칙: 광고 도메인 요청 차단 (예: `googlesyndication.com`, `doubleclick.net`, `adservice.google.*`, 카카오 애드핏, 쿠팡 파트너스 등).
  - `css-display-none` 규칙: 차단 후 남는 빈 자리 숨김 (예: `ins.adsbygoogle`, `iframe[src*="ads"]`, 광고 컨테이너 id/class).
- 컴파일은 비동기이므로 규칙 로딩이 끝난 뒤에 `web.load`를 호출한다 (`SiteWebView.init`의 순서 변경 필요). 컴파일 실패 시 광고 숨김 없이 그대로 로드한다 (앱 동작이 막히면 안 됨).
- **[검증 필요] 전제**: 대상 페이지(`damoang.net`)가 어떤 광고를 어떤 DOM/도메인으로 넣는지 확인하지 못했다. `curl`은 Cloudflare 챌린지(HTTP 403, "Just a moment...")에 막혔다 (2026-11-15). 실제 DOM은 시뮬레이터 WKWebView에서 `evaluateJavaScript`로 확인해야 한다 (M1). 확인 전에는 위 규칙 예시는 가정이다.
- 사이트마다 광고가 다르므로 규칙은 공통 도메인 목록 + 사이트별 선택자로 시작하고, 새 사이트가 늘면 JSON에 줄을 추가한다. 모든 사이트에 항상 켜짐이며 토글은 없다 (UXP-Q4 확정). 그래서 규칙은 보수적으로 잡고(로그인/본문을 숨기지 않게), M4에서 대상 페이지의 본문/로그인이 정상인지 확인한다.
- 한계(문서화): 광고 업체가 도메인을 바꾸거나 본문과 같은 도메인으로 서빙하면 못 막는다. 사이트 약관/수익 측면은 개인용 앱이므로 범위 밖.

## 4. 공통 모듈
- `AppGlyph` (SwiftUI 뷰): 앱 아이콘과 FAB가 공유. 파일은 `cwv/CWV/AppGlyph.swift`.
- `FabCorner`: 순수 로직, `Site.swift`.
- 광고 규칙 JSON: `cwv/CWV/adblock.json` (번들 리소스). `project.pbxproj`에 리소스로 등록해야 한다. Team ID 등 개인정보가 섞이지 않게 `git diff`로 확인한다.

## 5. 구현 구조
- 신규: `CWV/AppGlyph.swift`, `CWV/adblock.json`, `make_icon.swift`
- 수정: `BrowserView.swift`(FAB 글리프/위치), `WebView.swift`(규칙 로딩 후 load), `Site.swift`(FabCorner), `test_site.swift`(FabCorner 테스트), `AppIcon.appiconset/icon.png`, `project.pbxproj`(새 파일 등록), `cwv/README.md`(아이콘 재생성/광고 규칙 갱신 방법)
- 새 의존성 없음. 자체 검증은 기존 `swiftc ... test_site.swift` 명령 + 시뮬레이터 빌드/스크린샷.

## 6. 결정 사항
- **UXP-Q1** 아이콘 디자인 컨셉 - [확정] 말풍선 + 글자줄 (추천안 선택).
- **UXP-Q2** FAB 이동 방법 - [확정] 드래그 후 모서리 스냅 (추천안 선택).
- **UXP-Q3** FAB 위치 저장 범위 - [확정] 전체 공통 (추천안 선택).
- **UXP-Q4** 광고 숨기기 적용 방식 - [확정] 항상 켜짐, 토글 없음 (추천안 선택).

## 7. 마일스톤
| # | 내용 | 완료 기준 |
| :--- | :--- | :--- |
| UXP-M1 | 광고 DOM/도메인 조사 (시뮬레이터에서 대상 페이지 DOM 덤프) | 광고 요소 선택자와 도메인 목록이 이 문서에 기록됨 |
| UXP-M2 | `AppGlyph`, 앱 아이콘 생성, FAB 글리프 교체 | 시뮬레이터 스크린샷에서 홈 아이콘과 FAB가 같은 형태 |
| UXP-M3 | FAB 모서리 이동 + 저장 | `FabCorner` 테스트 통과, 앱 재실행 후 위치 유지 |
| UXP-M4 | 광고 규칙 적용 | 시뮬레이터에서 대상 페이지 광고 영역이 보이지 않고, 규칙 컴파일 실패 시에도 페이지 로드됨 |
