# [PRS] 플로팅 버튼 튕기기/Safari 열기, 기본 페이지 CSV, 사용자 페이지 재설치 후 유지

## 1. 목표
- 플로팅 버튼을 절반 넘게 끌지 않아도, 원하는 방향으로 빠르게 튕기면(flick) 그 방향 모서리로 붙게 한다.
- 코드에 박힌 기본 사이트(`defaultSites()`)를 없애고, 저장소의 `default_page.csv`로 기본 페이지 목록을 관리한다. 형식은 `주소[,제목]`.
- 7일마다 재설치해도 사용자가 앱에서 추가한 페이지(와 글자 크기, 버튼 위치)가 유지되게 한다.
- 플로팅 버튼 메뉴에 "Safari에서 열기"를 추가해 지금 보는 페이지를 Safari 앱으로 열 수 있게 한다.
- 범위 밖: 링크 복사/공유 시트, 기본 브라우저 선택, iCloud 동기화(무료 Apple ID는 iCloud 권한을 쓸 수 없음), 기본 목록의 원격 갱신, 여러 기기 동기화.

## 2. 전체 흐름
```
앱 시작
  default_page.csv(번들) -> 기본 사이트 목록 (매 실행 새로 읽음)
  사용자 추가 목록 <- UserDefaults, 비어 있으면 Keychain 백업에서 복원
  화면 목록 = 기본 사이트 + 사용자 추가 사이트
사용자가 추가/편집/삭제/글자 크기 변경 -> UserDefaults 저장 + Keychain에 같은 JSON 백업
```

## 3. 단계별 상세
### 1) 플로팅 버튼 튕기기
- 현재 `BrowserView.swift`는 `DragGesture`의 `translation`(놓은 위치)으로 모서리를 고른다.
- `onEnded`에서 `predictedEndTranslation`(손을 뗀 속도를 반영해 SwiftUI가 예측한 도착 이동량)을 쓴다. 느리게 끌면 지금과 같고, 빠르게 튕기면 멀리 던진 것으로 계산돼 그 방향 모서리로 붙는다. 새 상수나 속도 계산 코드가 필요 없다.
- 놓은 뒤 이동은 기존 `withAnimation`을 쓴다 (스프링 애니메이션으로 바꿔 튕기는 느낌을 더할 수 있음).
- 순수 로직 `FabCorner.nearest`는 그대로 두고, 예측 위치를 넘기는 방식이라 단위 테스트는 기존 것으로 충분하다. 체감은 실기기에서 확인하고 필요하면 예측 이동량에 배수를 곱한다.

### 2) 기본 페이지 CSV
- 파일: `cwv/CWV/default_page.csv` (번들 리소스, 폴더 동기화 그룹이라 리소스 등록은 불필요). **git에 올리지 않는다** (개인 목록): `.gitignore`에 `default_page.csv`(어느 폴더든)와 `*.swp`를 추가한다.
- 형식 안내용 견본 `cwv/default_page.csv.example`은 커밋한다 (아래 형식 설명과 예시 포함). 처음 쓰는 사람은 이를 `cwv/CWV/default_page.csv`로 복사해 고친다.
- 파일이 없을 때 (PRS-Q5 확정):
  - 빌드 전 안내: Xcode 빌드 단계(Run Script, `alwaysOutOfDate`)에서 `cwv/CWV/default_page.csv`가 없으면 `warning:` 줄로 안내하고 빌드는 계속한다. 문구에는 파일을 먼저 만들어야 한다는 말, 형식 설명(한 줄에 `주소[,제목]`, `#` 주석, 제목 생략 시 도메인), 견본 복사 명령(`cp cwv/default_page.csv.example cwv/CWV/default_page.csv`)을 넣는다. Xcode, xcodebuild, `make_ipa.sh` 모두 같은 빌드 단계를 거쳐 안내된다. 빌드 단계는 `project.pbxproj`에 추가한다.
  - 앱 동작: 파일이 없거나 유효한 줄이 하나도 없으면 기본 목록 대신 항상 접속 가능한 `Google (https://www.google.com)` 한 개를 쓴다 (`Site.swift`의 `parseDefaultPages` 결과가 비면 대체). 코드에는 이 대체값만 남고 특정 커뮤니티 주소는 없다.
- 형식 (한 줄에 사이트 하나):
  ```
  # 주석(#으로 시작)과 빈 줄은 무시
  https://damoang.net/empathy,다모앙-공감
  https://example.com/board
  ```
  - 첫 번째 쉼표 앞이 주소, 뒤가 제목(옵션). 제목에 쉼표가 있어도 된다. 주소에 쉼표가 있으면 쓸 수 없다 (한계).
  - 제목이 없으면 기존 입력 화면과 같이 도메인(`host`)을 이름으로 쓴다.
  - 주소는 `normalizeURL`로 검증하고, 잘못된 줄은 건너뛴다 (앱이 죽지 않게).
- 파서 `parseDefaultPages(_ text: String) -> [Site]`를 `Site.swift`(Foundation만 사용)에 둔다. 테스트 가능.
- 기본 사이트의 `id`는 주소에서 만든 고정 UUID로 한다. 그래야 매 실행 새로 읽어도 사이트별 글자 크기와 마지막 사이트(`lastSiteID`) 복원이 유지된다.
- `defaultSites()`와 그것을 쓰는 코드/테스트(`st.sites.count == 1`, `damoang.net` 확인)는 제거/수정한다.

### 3) 재설치 후 사용자 페이지 유지
- 가능 여부 (조사):
  - 같은 번들 ID로 덮어쓰기 설치하면 앱 데이터(UserDefaults)는 원래 유지된다 (이미 이전 설치에서 사이트 목록이 유지됨).
  - 앱을 삭제하면 UserDefaults, 문서 폴더는 지워지지만 iOS Keychain 항목은 앱 삭제 후에도 남는다 (Apple 문서화된 동작). 같은 Team ID와 번들 ID로 다시 설치하면 읽을 수 있다. 무료 Apple ID는 iCloud 권한이 없어 iCloud 방식은 불가.
  - 한계: SideStore가 다른 Team ID나 번들 ID 접미사로 다시 서명하면 Keychain 접근 그룹이 달라져 복원되지 않을 수 있다. Xcode로 직접 설치(README의 7일 재설치 절차)는 같은 값을 쓴다. 실기기 검증은 마일스톤 PRS-M3에서 한다.
- 구현: 백업 JSON = 사용자 추가 사이트 목록 + `[사이트 id: 글자 크기]` (기본 사이트의 글자 크기 포함, PRS-Q3). Keychain(`kSecClassGenericPassword`, `kSecAttrAccessibleAfterFirstUnlock`)에 한 덩어리로 저장한다. 저장할 때마다 UserDefaults와 Keychain에 함께 쓰고, 시작할 때 UserDefaults에 값이 없으면 Keychain에서 복원한다. 버튼 위치와 마지막 사이트는 백업하지 않으므로 기존 `@AppStorage`/`lastSiteID` 그대로다.
- Keychain 접근은 UIKit이 아니라 Security 프레임워크(macOS에도 있음)라 테스트 스크립트에서 동작을 확인할 수 있는지 M1에서 본다.

### 4) Safari에서 열기
- `BrowserView.menu`에서 "현재 %" 아래, `Divider` 앞에 `Button("Safari에서 열기")`를 추가한다. 순서: A+/A-/100%/현재%/Safari에서 열기/구분선/목록으로.
- 열 주소: `WebCache.view(for: site).web.url`(지금 보는 페이지). nil이거나 http/https가 아니면 `site.url`로 대체한다. 이 판단은 순수 함수 `safariTarget(current: URL?, fallback: URL) -> URL`(`Site.swift`, `normalizeURL` 재사용)로 두고 `test_site.swift`에서 검증한다.
- 동작: `UIApplication.shared.open(url)`. 사용자가 직접 누른 항목이라 기존 "클릭 없는 이동은 막는다" 원칙(CWV-R4)과 충돌하지 않는다. `UIApplication.open`은 `WebView.swift`에서 tel/mailto에 이미 쓰고 있어 Info.plist 설정이 필요 없다 (실기기 확인은 PRS-M4).
- iOS 기본 브라우저가 Safari가 아니면 그 브라우저가 열린다 (한계).

## 4. 공통 모듈
- `Site.swift`: `parseDefaultPages`, 주소->고정 UUID 함수.
- `SiteStore.swift`: 기본 목록 + 사용자 목록 병합, 저장/복원. 저장소 접근은 주입(테스트용 UserDefaults, Keychain 대체)으로 기존 방식을 따른다.
- 새 Keychain 래퍼는 `Backup.swift` 한 파일, 함수 두 개(`save(Data)`, `load() -> Data?`).

## 5. 구현 구조
- 신규: `cwv/CWV/default_page.csv`, `cwv/CWV/Backup.swift`. 사용자가 저장소 루트에 만들어 둔 `default_page.csv`(주소 4개, 제목 열 없음)는 앱에 번들되려면 `cwv/CWV/` 안에 있어야 하므로 구현 때 그 위치로 옮긴다 (루트의 복사본은 남기지 않는다). 이 파일은 git에 올리지 않는다. 신규 커밋 파일은 `cwv/default_page.csv.example`.
- 수정: `BrowserView.swift`(predictedEndTranslation, Safari에서 열기 메뉴 항목), `Site.swift`, `SiteStore.swift`, `project.pbxproj`(경고용 빌드 단계. 로컬 Team ID 변경이 섞여 있으므로 커밋할 때 이 변경 줄만 골라 넣는다), `.gitignore`, `SiteListView.swift`(기본 사이트 행은 삭제/편집/이동 불가, 사용자 사이트 구역만 편집 가능; PRS-Q1), `test_site.swift`, `cwv/README.md`(CSV 편집법, 재설치 시 유지 범위)
- 새 의존성 없음.

## 6. 결정 사항
- **PRS-Q1** 기본 목록과 사용자 목록의 관계 - [확정] 분리. 기본 사이트는 매 실행 CSV에서 읽고 앱에서 삭제/편집할 수 없다(글자 크기만 조절 가능). 사용자 사이트는 따로 저장한다.
- **PRS-Q2** 재설치(앱 삭제 후 설치) 유지 방법 - [확정] Keychain 백업 (추천안 선택). SideStore 재서명 시 복원 여부는 실기기에서 확인.
- **PRS-Q3** 백업 범위 - [확정] 사용자 사이트 + 사이트별 글자 크기(기본 사이트 포함)만. 버튼 위치(`@AppStorage`)와 마지막 사이트는 재설치 후 기본값으로 돌아간다.
- **PRS-Q4** Safari에서 열 주소 - [확정] 지금 보는 페이지 (추천안 선택). 읽을 수 없으면 사이트 기본 주소로 대체.

## 7. 마일스톤
| # | 내용 | 완료 기준 |
| :--- | :--- | :--- |
| PRS-M1 | CSV 파서, 고정 UUID, SiteStore 병합 | `build/test_site` 통과 (정상/주석/빈 줄/잘못된 주소/제목 쉼표/제목 없음) |
| PRS-M2 | 튕기기 | 시뮬레이터 빌드 성공, 실기기에서 짧게 튕겨도 그 방향 모서리로 이동 |
| PRS-M3 | Keychain 백업/복원 | 시뮬레이터에서 앱 삭제 후 재설치해 사용자 사이트 복원, 가능하면 실기기에서도 확인 |
| PRS-M4 | Safari에서 열기 | `build/test_site`의 `safariTarget` 통과, 실기기에서 글 상세로 이동한 뒤 항목을 누르면 Safari에 그 글이 열림 |
| PRS-M5 | 기본 파일 없음 처리 | 파일을 치운 채 빌드하면 경고가 보이고 빌드가 성공하며, 앱 첫 화면 목록이 Google 하나. 파일을 두면 경고 없이 CSV 목록 |
