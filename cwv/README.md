# CWV - 커뮤니티 웹 모아보기

자주 가는 커뮤니티 사이트를 앱 하나에 모아 보고, 사이트별 글자 크기를 조절해 기억하는 개인용 iOS 앱입니다 (SwiftUI + WKWebView).

## 사용
- 목록: `+` 추가, 행을 왼쪽으로 밀면 편집/삭제, `편집` 버튼으로 순서 변경.
- 웹뷰: 말풍선 모양 플로팅 버튼(기본 오른쪽 아래)에서 글자 크기(50~300%), `목록으로`. 버튼을 끌어 놓으면 가까운 모서리로 붙고 위치는 저장됩니다. 가장자리 스와이프로 뒤로/앞으로, 당겨서 새로고침.
- 다른 도메인 링크는 앱 안의 Safari 시트로 열립니다 (시트 하단 "Safari에서 열기"로 Safari 앱 이동 가능).
- 광고(Google 광고, 카카오 애드핏)는 `cwv/CWV/adblock.json` 규칙으로 차단/숨깁니다. 사이트가 늘면 이 파일에 도메인이나 선택자를 추가하세요.
- Google 소셜 로그인은 내장 웹뷰에서 Google이 차단합니다.

## 개발
- 앱 아이콘 재생성: `swiftc -parse-as-library cwv/CWV/AppGlyph.swift cwv/make_icon.swift -o build/make_icon && build/make_icon out.png && magick out.png -alpha off cwv/CWV/Assets.xcassets/AppIcon.appiconset/icon.png` (버튼과 같은 `AppGlyph`로 그림)
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
