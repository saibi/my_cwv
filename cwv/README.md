# CWV - 커뮤니티 웹 모아보기

자주 가는 커뮤니티 사이트를 앱 하나에 모아 보고, 사이트별 글자 크기를 조절해 기억하는 개인용 iOS 앱입니다 (SwiftUI + WKWebView).

## 사용
- 목록: 위쪽은 기본 페이지(`default_page.csv`), 아래 "추가한 사이트"는 `+`로 추가한 것입니다 (이름을 비우면 같은 방식으로 페이지 제목을 씁니다). 추가한 사이트만 왼쪽으로 밀어 편집/삭제하고 `편집` 버튼으로 순서를 바꿉니다.
- 추가한 사이트와 사이트별 글자 크기는 Keychain에 백업되어, 앱을 지우고 다시 설치해도 같은 서명(Team ID/번들 ID)이면 복원됩니다. 버튼 위치와 마지막으로 연 사이트는 복원되지 않습니다.
- 웹뷰: 말풍선 모양 플로팅 버튼(기본 오른쪽 아래)에서 글자 크기(50~300%), `Safari에서 열기`(지금 보는 페이지), `목록으로`. 버튼을 끌거나 튕기면 그 방향 모서리로 붙고 위치는 저장됩니다. 가장자리 스와이프로 뒤로/앞으로(사이트의 첫 페이지에서는 왼쪽 가장자리 스와이프가 목록으로 돌아감), 당겨서 새로고침.
- 다른 도메인 링크는 앱 안의 Safari 시트로 열립니다 (시트 하단 "Safari에서 열기"로 Safari 앱 이동 가능).
- 광고(Google 광고, 카카오 애드핏)는 `cwv/CWV/adblock.json` 규칙으로 차단/숨깁니다. 사이트가 늘면 이 파일에 도메인이나 선택자를 추가하세요.
- Google 소셜 로그인은 내장 웹뷰에서 Google이 차단합니다.

## 기본 페이지 파일 (빌드 전 필수)
기본 페이지 목록은 `cwv/CWV/default_page.csv`입니다. 개인 목록이라 git에 올리지 않으므로 **빌드 전에 직접 만들어야 합니다**. 없으면 빌드 때 경고가 나오고 기본 페이지는 Google 하나가 됩니다.
```
cp cwv/default_page.csv.example cwv/CWV/default_page.csv   # 견본을 복사해 고친다
```
- 한 줄에 사이트 하나: `주소[,제목]`. 예: `https://damoang.net/empathy,다모앙-공감`
- 제목은 옵션입니다. 없으면 사이트를 처음 열었을 때 받은 페이지 제목이 목록 이름이 되고(그 전에는 도메인), 한 번 받은 제목은 앱을 다시 실행해도 유지됩니다. 첫 쉼표 앞이 주소입니다 (주소에는 쉼표를 쓸 수 없고 제목에는 써도 됩니다).
- `#`으로 시작하는 줄, 빈 줄, 잘못된 주소 줄은 무시합니다. 앱에서는 기본 페이지를 삭제/편집할 수 없고 이 파일을 고쳐서 다시 설치합니다.

## 개발
- 앱 아이콘 재생성: `swiftc -parse-as-library cwv/CWV/AppGlyph.swift cwv/make_icon.swift -o build/make_icon && build/make_icon out.png && cp out.png cwv/CWV/Assets.xcassets/AppIcon.appiconset/icon.png` (버튼과 같은 `AppGlyph`로 그림)
- 자체 검증: `swiftc -parse-as-library cwv/CWV/Site.swift cwv/CWV/SiteStore.swift cwv/test_site.swift -o build/test_site && build/test_site`
- 실기기 확인: Xcode에서 `cwv/CWV.xcodeproj`를 열고 Signing에 본인 Apple ID 팀을 지정한 뒤 Run.

## 7일마다 재설치
무료 Apple ID로 설치한 앱은 7일 뒤에 만료됩니다. 만료 전에 아이폰을 USB로 연결하고 잠금을 푼 뒤 실행합니다.
```
sh cwv/reinstall.sh
```
- 연결된 아이폰을 자동으로 찾아 빌드하고 덮어쓰기 설치합니다. 사이트 목록과 설정은 유지됩니다. 기기가 여러 대면 `sh cwv/reinstall.sh <UDID>`.
- Xcode Signing에서 Team을 한 번 지정해 두어야 합니다 (그 설정은 `project.pbxproj`에 들어가지만 커밋하지 않습니다).
- 처음 설치한 기기는 설정 > 일반 > VPN 및 기기 관리에서 개발자 프로필을 신뢰해야 실행됩니다.
- 빌드 중 서명 단계에서 맥이 키체인 접근 허용을 물으면 허용해야 진행됩니다 (화면이 잠겨 있으면 멈춥니다).

### SideStore는 쓰지 않습니다
SideStore(7일 자동 갱신)를 시도했지만 이 프로젝트에서는 설정 중 `Bundle identifier unavailable` 오류로 설치가 막혀 접었습니다 (원인은 확인하지 못했습니다). 맥을 일주일에 한 번 이상 쓴다면 위 방식이 더 간단합니다. `cwv/make_ipa.sh`(무서명 IPA)는 다른 도구로 설치할 때를 위해 남겨 둡니다.
