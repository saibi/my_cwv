# [CWV] 구현 노트

- 계획: plan/CWV_plan_claude-opus-5-5.md
- 구현 커밋: d7cb32c (리뷰 반영 커밋은 review/CWV_refine_*.md)

## 아키텍처
| 파일 | 역할 |
| :--- | :--- |
| `cwv/CWV/Site.swift` | 모델 `Site`, `normalizeURL`, `clampZoom`, `isExternal`, `defaultSites` (Foundation만 사용, macOS에서 테스트) |
| `cwv/CWV/SiteStore.swift` | `[Site]`와 `lastSiteID`를 UserDefaults(JSON)에 저장. 추가/수정/삭제/이동/zoom |
| `cwv/CWV/WebView.swift` | `SiteWebView`(WKWebView + delegate, 사이트별 캐시 `WebCache`), `WebView`(UIViewRepresentable), `SafariView` |
| `cwv/CWV/BrowserView.swift` | 웹뷰 + 떠 있는 aA 메뉴 + 외부 링크 Safari 시트 |
| `cwv/CWV/SiteListView.swift` | 목록, 추가/편집 시트 |
| `cwv/CWV/CWVApp.swift` | 목록/웹뷰 전환(`currentID`), 마지막 사이트 복원 |
| `cwv/CWV.xcodeproj` | 직접 작성한 pbxproj (objectVersion 77, 파일 시스템 동기화 그룹) |

흐름: 목록 -> 사이트 선택 -> `WebCache`에서 해당 사이트의 WKWebView를 꺼내 표시 -> `aA`로 zoom 변경(store 저장 + 스크립트 재주입) -> `목록으로`(웹뷰는 캐시에 남음).

## 핵심 설계 결정
- 화면 전환은 NavigationStack 대신 `currentID` 분기 - 네비게이션 뒤로 제스처가 WKWebView 뒤로 제스처와 겹치지 않게 하고 코드를 줄이기 위해서.
- UA에 `Version/18.0 Mobile/15E148 Safari/604.1` 추가 - 기본 WKWebView UA에는 Safari 토큰이 없어 일부 사이트가 거부할 수 있어서(시뮬레이터에서 다모앙/Cloudflare 통과 확인).
- ATS `NSAllowsArbitraryLoadsInWebContent` - 사용자가 http 사이트를 추가해도 열리도록.

## 진행 기록
- CWV-M1: pbxproj 직접 작성, 시뮬레이터(iPhone 15, iOS 17.2) 빌드/실행. damoang.net/empathy가 Cloudflare를 통과해 열리는 것을 스크린샷으로 확인.
- CWV-M2: `test_site.swift` 통과 (URL 정규화, isExternal, clampZoom, JSON 왕복). 테스트 중 `HTTP://`의 scheme이 대문자로 남는 버그를 발견해 소문자로 고침.
- CWV-M3/M4: 시뮬레이터에서 저장된 사이트를 시드해 목록 화면, 웹뷰, 사이트별 zoom(1.0/1.3/1.5) 적용 확인. aA 버튼 표시 확인.
- 리뷰 반영(CWV-R1..R5): review/CWV_refine_claude-sonnet-5-5.md 참고.
- CWV-M5: `make_ipa.sh`로 무서명 IPA 생성 확인(122KB). SideStore 설치는 사용자 기기에서 확인 필요.

## 계획 대비 변경
| 항목 | 계획 | 최종 구현 | 상황과 근본 이유 |
| :--- | :--- | :--- | :--- |
| 글자 크기 방식 | `WKWebView.pageZoom` | `-webkit-text-size-adjust` 주입 | pageZoom 130%에서 레이아웃이 재배치되지 않아 내용이 오른쪽으로 잘림(스크린샷 확인). Safari aA가 쓰는 text-size-adjust는 글자만 키우고 재배치되어 사용 가능. 고정 px 아이콘/요소는 커지지 않는 한계가 있다 |
| 최소 iOS | 18.0 | 17.0 | 설치된 시뮬레이터 런타임이 17.2뿐이라 18.0으로는 실행 검증이 불가했다 |
| 테스트 컴파일 | top-level 코드 | `@main` + `-parse-as-library` | 여러 파일 컴파일에서는 main.swift 외에 top-level 코드를 쓸 수 없다 |
| 화면 전환 | 계획에 구체 방식 없음 | `currentID` 분기 | 위 설계 결정 참고 |

## 검증 결과
- 확인함: 단위 검증 통과, 시뮬레이터에서 목록/웹뷰/Cloudflare 통과/글자 크기 150%, 무서명 IPA 생성.
- 실기기: 2026-11-15 iPhone 16(iOS 27.2.1)에 Xcode 서명(무료 Personal Team)으로 빌드/설치까지 확인했다. 설치 후 실행은 "개발자 프로필 신뢰" 단계가 필요하며, 앱 동작(목록, 글자 크기, 로그인 유지)은 사용자 확인 대기.
- 설치 중 겪은 일: iPhone의 개발자 모드 항목이 처음에는 설정에 보이지 않았고, 기기를 Xcode/devicectl로 연결해 개발자 디스크 이미지를 요청한 뒤에 켤 수 있었다. Xcode 27의 Window 메뉴에는 Devices and Simulators 항목이 없었다.
- 확인 못함: SideStore 설치와 자동 갱신(보류), 외부 링크 Safari 시트와 당겨서 새로고침, 뒤로 스와이프, 목록 추가/편집/삭제 UI 조작(시뮬레이터에 탭을 보낼 도구가 없어 시드 값으로만 확인), 앱 재실행 후 로그인 유지.

## 남은 한계
- text-size-adjust는 글자만 키운다. 고정 px 요소(헤더 아이콘 등)와 일부 레이아웃은 그대로라 150% 이상에서는 줄바꿈/잘림이 생길 수 있다.
- Google 소셜 로그인 불가.
- 무료 계정 7일 갱신은 SideStore 자동 갱신에 의존한다. SideStore는 보류 중이라 당분간 7일마다 Xcode로 재설치해야 한다 (`xcodebuild ... -allowProvisioningUpdates` + `devicectl device install app`).
- 서명용 DEVELOPMENT_TEAM은 개인 ID라 저장소에 커밋하지 않는다. 처음 설치할 때 Xcode Signing에서 직접 지정한다.
