# [IPD] 아이패드 지원

## 1. 목표
- 앱이 iPhone 전용(`TARGETED_DEVICE_FAMILY = 1`)이라 iPad에서 호환 모드(iPhone 크기 창, 확대 표시)로 실행된다. iPad를 정식 지원 기기로 만들어 전체 화면, 회전, 멀티태스킹(Split View/Slide Over/Stage Manager)에서 쓸 수 있게 한다.
- iPad의 넓은 화면에 맞게 웹 레이아웃(UA)과 목록 화면 폭을 조정한다.
- 사이트별 "데스크톱 사이트로 보기" 선택(IPD-Q1)을 편집 시트, 웹 메뉴, CSV 백업에 넣는다.
- 범위 밖: iPhone과 iPad 사이 자동 동기화(Keychain 백업은 기기별, 옮길 때는 CSV 백업/복원), Mac Catalyst, 목록+웹 분할 화면(NavigationSplitView, IPD-Q2의 선택지).

## 2. 전체 흐름
```
project.pbxproj: TARGETED_DEVICE_FAMILY "1,2", iPad 방향 4개 (INFOPLIST_KEY_UISupportedInterfaceOrientations_iPad)
Site.desktop (사이트별, 기본 모바일) -> WebView: desktop이면 데스크톱 UA/콘텐츠 모드, 편집 시트/웹 메뉴 토글 (IPD-Q1)
SiteListView: 넓은 화면에서 폭 제한 (IPD-Q2)
검증: iPad 시뮬레이터 빌드/스크린샷 + 실기기 iPad(saibi pro11)
```

## 3. 단계별 상세
### 1) 기기 패밀리와 방향
- 전제 확인(2026-11-21): `project.pbxproj`의 Debug/Release 모두 `TARGETED_DEVICE_FAMILY = 1`, 방향 키는 `_iPhone`만 있다. iPad 시뮬레이터(iPad Pro 11, iPad Air 등)가 설치되어 있다 (`xcrun simctl list`).
- `TARGETED_DEVICE_FAMILY = "1,2"`, `INFOPLIST_KEY_UISupportedInterfaceOrientations_iPad`에 세로, 거꾸로 세로, 가로 좌/우 4개 (IPD-Q3). `UIRequiresFullScreen`은 넣지 않아 멀티태스킹을 허용한다.
- `project.pbxproj`에는 커밋하면 안 되는 개인 Team ID(`DEVELOPMENT_TEAM`) 변경이 로컬에 섞여 있다. 이 변경만 `git add -p`로 골라 커밋하고, Team ID 줄은 커밋하지 않는다 (커밋 전 `git diff --cached`로 `DEVELOPMENT_TEAM` 없음을 확인).

### 2) 사이트별 웹 레이아웃 (IPD-Q1, Q4, Q5)
- 지금은 `applicationNameForUserAgent`에 `Mobile/15E148`을 넣어 모든 사이트가 모바일 사이트를 받는다. iPad Safari는 기본적으로 데스크톱 사이트(`Macintosh` UA, 콘텐츠 모드 desktop)를 받는다. 사이트마다 편한 쪽이 달라서 **사이트별로 선택**한다 (IPD-Q1).
- 데이터: `Site.desktop: Bool` (기본 false = 모바일, IPD-Q5). **이미 저장된 목록(UserDefaults/Keychain JSON)에는 이 키가 없으므로** `Site`에 `init(from:)`을 직접 쓰고 `decodeIfPresent(...) ?? false`로 읽는다. 키가 없다고 디코딩이 실패하면 목록 전체가 사라지므로, 이전 형식 JSON을 디코딩해도 목록이 그대로인지 `test_site.swift`로 검증한다.
- 적용 기기: **모든 기기** (IPD-Q4). iPhone에서도 사이트가 데스크톱으로 지정되어 있으면 데스크톱 레이아웃을 받는다. 그래서 필드 이름은 `Site.desktop`으로 한다 (`desktop` 아님). UA 선택은 순수 함수 `userAgentApplicationName(desktop: Bool) -> String`(Site.swift)로 두고 테스트한다.
- 웹뷰 적용: 사이트의 `desktop`이 true면 `web.customUserAgent`를 `Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/18.0 Safari/605.1.15`로 하고, `decidePolicyFor(action, preferences:)`에서 `preferences.preferredContentMode = .desktop`을 준다. false면 `.mobile`과 지금의 UA. 값이 바뀌면(`apply`와 같은 `sync` 경로) 캐시된 웹뷰의 UA/모드를 바꾸고 현재 주소(없으면 사이트 기본 주소)를 GET으로 다시 불러온다 (`reload()`는 POST 결과 화면에서 폼을 재전송하므로 쓰지 않는다, 리뷰 IPD-R1).
- 바꾸는 곳: (1) 사이트 편집/추가 시트에 "데스크톱 사이트로 보기" 토글, (2) 웹 화면 플로팅 메뉴에 같은 토글 항목 (바로 다시 불러옴). 둘 다 모든 기기에 표시. 사이트를 보면서 바로 시험해 볼 수 있게 한다.
- CSV(IPD-Q6, Q7, Q8): 백업 파일 첫 줄 `# v3`, 이어서 `# device: ipad` 또는 `# device: iphone` 주석, v3에서 4번째 칸으로 저장한다 (`url,"name",zoom%,layout`, layout은 `m` 또는 `d`). v2 이하 파일은 모바일.
- 글자 크기(text-size-adjust)는 그대로 동작한다. 기본 확대%(120%)는 iPhone 기준 값이라 iPad에서는 사이트별로 조절한다.

### 3) 목록과 편집 화면 (IPD-Q2)
- `SiteListView`의 `List`가 iPad 가로에서 화면 끝까지 늘어난다. 넓은 화면에서는 내용 폭을 제한한다 (`.frame(maxWidth: 700)` 중앙 정렬 또는 `.listStyle(.insetGrouped)`와 readable content).
- 편집/옵션 시트는 iPad에서 폼 시트로 뜬다 (SwiftUI 기본). `confirmationDialog`는 iPad에서 팝오버로 뜨므로 앵커가 어색하지 않은지 확인한다 (어색하면 `alert`로 바꾼다).
- 플로팅 버튼(`BrowserView`)은 `GeometryReader` 기반이라 크기에 맞게 모서리에 붙는다. iPad Split View 폭 변화에서도 모서리 계산이 맞는지 확인한다.

### 4) 확인할 동작
- 첫 페이지 왼쪽 가장자리 스와이프로 목록 복귀(iPad Split View/Stage Manager에서 시스템 제스처와 충돌 없는지), 파일 앱 내보내기/가져오기(iPad에서는 팝오버/시트), Safari 시트(SFSafariViewController는 iPad에서 폼 시트).

## 4. 공통 모듈
- `Site.swift`: `Site.desktop`(하위 호환 디코딩), UA 선택 순수 함수, CSV 파서/내보내기의 v3 칸. `SiteStore`: `setPadDesktop(id, Bool)`, `add`/`update`/CSV 복원이 필드를 보존.

## 5. 구현 구조
- 수정: `cwv/CWV.xcodeproj/project.pbxproj`(패밀리, 방향), `WebView.swift`(UA/콘텐츠 모드), `BrowserView.swift`(웹 메뉴 토글), `SiteListView.swift`(폭 제한, 편집 시트 토글), `Site.swift`/`SiteStore.swift`+`test_site.swift`(필드, 디코딩 호환, CSV v3), `cwv/README.md`(iPad 지원, iPad 설치 안내)
- 새 의존성 없음.

## 6. 결정 사항
- **IPD-Q1** iPad에서 받을 사이트 레이아웃 - [확정] 사이트별로 선택 (사용자 지시: 사이트마다 편한 쪽이 다름). 편집 시트와 웹 메뉴에서 바꾼다.
- **IPD-Q2** 넓은 화면의 목록 화면 - [확정] (a) 가운데 정렬로 폭 제한 (추천안 선택, 최대 폭 약 700pt). 기각: (b) 지금처럼 전체 폭 (c) 목록은 사이드바, 웹은 오른쪽에 분할 표시.
- **IPD-Q4** 사이트별 설정이 적용되는 기기 - [확정] (b) 모든 기기. CSV 백업/복원으로 설정이 기기 사이를 오가므로 기기 구분 없이 한 값을 쓴다 (사용자 결정). 대신 백업 파일에 만든 기기 표시를 남겨 복원할 때 알 수 있게 한다 (IPD-Q7).
- **IPD-Q5** 새 사이트와 설정이 없는 기존 사이트의 기본 레이아웃 - [확정] (a) 모바일 (추천안 선택). 지금 동작이 유지되고, v2 이하 CSV와 이전 저장 목록도 모바일로 읽는다.
- **IPD-Q6** CSV 백업에 사이트별 레이아웃을 포함할지 - [확정] (a) 포함: 형식 v3 (4번째 칸). 사용자가 백업/복원과 연계해야 한다고 지시했다 (IPD-Q4 논의).
- **IPD-Q7** 백업 파일의 기기 표시 - [변경 2026-11-21: 파일 이름 `-ipad` 접미사와 파일 이름 보조 판독을 폐지하고 파일 안 `# device:` 헤더만 쓴다 (사용자 결정, 헤더로 식별되므로 중복)] [확정, 당시] 백업을 iPad에서 만들면 기본 파일명 끝에 `-ipad`를 붙인다 (예: `cwv_sites_2026-11-21-ipad`), iPhone은 붙이지 않는다 (사용자 지시). 파일명은 사용자가 바꾸거나 외부에서 올 수 있어 믿을 수 없으므로, 같은 정보를 파일 안 주석 헤더(`# device: ipad`)에도 적고 복원은 헤더를 기준으로 판단한다 (헤더가 없으면 파일명 끝 `-ipad`를 보조로 본다). 다른 기기에서 만든 파일을 복원할 때 어떻게 알릴지는 IPD-Q8.
- **IPD-Q8** 다른 기기에서 만든 백업을 복원할 때 - [확정] (b) 교체 확인창에 안내 문구("iPad에서 백업한 파일입니다...")와 함께 "그대로 복원" / "데스크톱 설정은 빼고 복원(모두 모바일)" 중 고르게 한다 (추천안 선택). 기기 표시는 IPD-Q7의 헤더/파일명으로 판단하고, 같은 기기이거나 표시가 없는 파일은 지금처럼 단일 확인창이다. 파일의 `# device:` 값은 `ipad`/`iphone`만 인정하고 그 밖의 값은 무시한다 (외부 파일).
- **IPD-Q3** 방향과 멀티태스킹 - [확정(기본값)] iPad는 4방향 모두 허용하고 Split View/Slide Over/Stage Manager를 허용한다 (iPad 앱 기본 동작, 필요하면 바꾼다).

## 7. 마일스톤
| # | 내용 | 완료 기준 |
| :--- | :--- | :--- |
| IPD-M1 | 기기 패밀리/방향 설정 | iPad 시뮬레이터 빌드 성공, 호환 모드 없이 전체 화면 실행 (스크린샷), 커밋에 Team ID 없음 |
| IPD-M2 | 사이트별 레이아웃(필드, 하위 호환 디코딩, UA/콘텐츠 모드, 편집 시트/웹 메뉴 토글, CSV v3), 목록 폭 | `build/test_site` 통과 (이전 JSON 디코딩, UA 함수, CSV 왕복), iPad 시뮬레이터 스크린샷에서 목록 폭 확인 |
| IPD-M3 | 실기기 확인 | iPad(saibi pro11)에서 회전, 분할 화면, 스와이프 복귀, CSV 백업/복원 동작 |
