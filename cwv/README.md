# CWV - 커뮤니티 웹 모아보기

자주 가는 커뮤니티 사이트를 앱 하나에 모아 보고, 사이트별 글자 크기를 조절해 기억하는 개인용 iOS 앱입니다 (SwiftUI + WKWebView).

## 사용
- 목록: 위쪽은 기본 페이지(`default_page.csv`), 아래 "추가한 사이트"는 `+`로 추가한 것입니다. 추가한 사이트만 왼쪽으로 밀어 편집/삭제하고 `편집` 버튼으로 순서를 바꿉니다.
- 추가한 사이트와 사이트별 글자 크기는 Keychain에 백업되어, 앱을 지우고 다시 설치해도 같은 서명(Team ID/번들 ID)이면 복원됩니다. 버튼 위치와 마지막으로 연 사이트는 복원되지 않습니다.
- 웹뷰: 말풍선 모양 플로팅 버튼(기본 오른쪽 아래)에서 글자 크기(50~300%), `Safari에서 열기`(지금 보는 페이지), `목록으로`. 버튼을 끌거나 튕기면 그 방향 모서리로 붙고 위치는 저장됩니다. 가장자리 스와이프로 뒤로/앞으로, 당겨서 새로고침.
- 다른 도메인 링크는 앱 안의 Safari 시트로 열립니다 (시트 하단 "Safari에서 열기"로 Safari 앱 이동 가능).
- 광고(Google 광고, 카카오 애드핏)는 `cwv/CWV/adblock.json` 규칙으로 차단/숨깁니다. 사이트가 늘면 이 파일에 도메인이나 선택자를 추가하세요.
- Google 소셜 로그인은 내장 웹뷰에서 Google이 차단합니다.

## 기본 페이지 파일 (빌드 전 필수)
기본 페이지 목록은 `cwv/CWV/default_page.csv`입니다. 개인 목록이라 git에 올리지 않으므로 **빌드 전에 직접 만들어야 합니다**. 없으면 빌드 때 경고가 나오고 기본 페이지는 Google 하나가 됩니다.
```
cp cwv/default_page.csv.example cwv/CWV/default_page.csv   # 견본을 복사해 고친다
```
- 한 줄에 사이트 하나: `주소[,제목]`. 예: `https://damoang.net/empathy,다모앙-공감`
- 제목은 옵션이고 없으면 도메인이 이름이 됩니다. 첫 쉼표 앞이 주소입니다 (주소에는 쉼표를 쓸 수 없고 제목에는 써도 됩니다).
- `#`으로 시작하는 줄, 빈 줄, 잘못된 주소 줄은 무시합니다. 앱에서는 기본 페이지를 삭제/편집할 수 없고 이 파일을 고쳐서 다시 설치합니다.

## 개발
- 앱 아이콘 재생성: `swiftc -parse-as-library cwv/CWV/AppGlyph.swift cwv/make_icon.swift -o build/make_icon && build/make_icon out.png && cp out.png cwv/CWV/Assets.xcassets/AppIcon.appiconset/icon.png` (버튼과 같은 `AppGlyph`로 그림)
- 자체 검증: `swiftc -parse-as-library cwv/CWV/Site.swift cwv/CWV/SiteStore.swift cwv/test_site.swift -o build/test_site && build/test_site`
- 실기기 확인: Xcode에서 `cwv/CWV.xcodeproj`를 열고 Signing에 본인 Apple ID 팀을 지정한 뒤 Run.

## 상시 설치 (SideStore, 무료 Apple ID)
1. `sh cwv/make_ipa.sh` 로 `build/CWV.ipa`(무서명)를 만든다.
2. AirDrop이나 파일 앱으로 아이폰에 옮긴다.
3. SideStore에서 IPA를 설치한다. SideStore 설치와 7일 자동 갱신(단축어 자동화) 설정은 SideStore 공식 문서를 따른다.

## 7일마다 재설치 (SideStore 없이)
무료 Apple ID로 설치한 앱은 7일 뒤에 만료됩니다. 아이폰을 USB로 연결하고 잠금을 푼 뒤 실행합니다. Xcode Signing에서 Team을 한 번 지정해 두어야 합니다.
```
xcodebuild -project cwv/CWV.xcodeproj -scheme CWV -configuration Debug \
  -destination 'id=<아이폰 UDID>' -derivedDataPath build/dev -allowProvisioningUpdates build
xcrun devicectl device install app --device <아이폰 UDID> build/dev/Build/Products/Debug-iphoneos/CWV.app
```
UDID는 `xcrun devicectl list devices`로 확인합니다. 처음 설치한 기기는 설정 > 일반 > VPN 및 기기 관리에서 개발자 프로필을 신뢰해야 실행됩니다.
