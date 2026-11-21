# [IPD] 교차리뷰 (codex-gpt-6.2-sol)

## 요약

iPad 지원 설정, 사이트별 레이아웃, CSV v3, 목록 폭 제한이 구현됐습니다. 완료 판정은 보류합니다. 웹 메뉴에서 레이아웃을 바꾸면 게시글 등록 같은 POST 요청이 다시 전송될 수 있고, 다른 기기 백업을 복원하는 흐름에는 IPD-Q8과 다른 동작이 있습니다.

| 계획 항목 | 구현 상태 | 검증 범위 |
| --- | --- | --- |
| IPD-Q1, Q4, Q5 / 사이트별 레이아웃, 모든 기기 적용, 기본 모바일 | 편집 시트와 웹 메뉴에서 변경하고 저장합니다. 이전 JSON의 `desktop` 누락을 처리합니다. 계획의 UA 함수 이름을 `customUserAgent`로 바꾸고 모바일에서 `nil`을 반환하는 방식은 기존 모바일 UA 설정을 재사용하므로 타당합니다. 전환 시 재로드에는 IPD-R1, R2가 있습니다. | 자체 검증은 이전 JSON, 저장 왕복, UA 반환값을 검사합니다. 실제 요청 UA, WebKit 콘텐츠 모드, 메뉴 전환은 검사하지 않습니다. |
| IPD-Q2, Q3 / 목록 폭, 방향, 멀티태스킹 | 목록을 최대 700pt로 가운데 정렬합니다. 별도 커밋 `8c69755`에서 Debug와 Release에 iPad 및 4방향을 추가했습니다. | 기존 시뮬레이터 빌드의 `Info.plist`에서 기기 패밀리 `[1,2]`와 iPad 4방향을 확인했습니다. |
| IPD-Q6, Q7 / CSV v3, 백업 기기 표시 | 레이아웃과 기기 헤더를 저장하고, iPad 기본 파일명에 `-ipad`를 붙입니다. 기기 헤더와 파일명 해석에 IPD-R5, R6이 있습니다. | 자체 검증은 v3 왕복, v2 모바일 기본값, 헤더 우선순위, 파일명 보조 판정, 크기와 줄 수 제한, UTF-8 오류를 검사합니다. |
| IPD-Q8 / 다른 기기 백업 복원 | 데스크톱 항목이 있을 때만 기기 안내와 두 복원 선택지를 표시합니다. 결과가 같은 버튼을 하나로 줄이는 이유는 타당합니다. 기기 출처까지 숨기는 것은 IPD-Q4, Q8의 목적과 어긋납니다. 설정 제거 후 백업 왕복에는 IPD-R3이 있습니다. | 자체 검증은 `withoutDesktop`의 레이아웃 초기화와 확대율 보존을 검사합니다. 확인창의 분기와 설정 제거 후 백업 왕복은 검사하지 않습니다. |
| IPD-M1 / 빌드, 전체 화면, Team ID 제외 | 기기 설정과 두 구현 커밋의 프로젝트 파일에서 Team ID 제외를 확인했습니다. | 전체 화면 실행과 스크린샷은 구현 노트에 기록돼 있습니다. `test_site`는 이 기준을 검사하지 않습니다. |
| IPD-M2 / 레이아웃 및 CSV 자체 검증, 목록 폭 스크린샷 | 이전 JSON 디코딩, UA 함수, CSV 왕복에 대한 자체 검증이 계획의 코드 기준을 다룹니다. | 자체 검증 통과와 세로 화면의 목록 폭은 구현 노트에 기록돼 있습니다. 스크린샷과 WebKit 동작은 자체 검증 범위 밖입니다. |
| IPD-M3 / 실기기 확인 | 미완료입니다. | 회전, 분할 화면, 가장자리 스와이프, 파일 앱 백업과 복원은 실기기 확인이 필요합니다. |

외부 CSV는 최대 1MB와 데이터 500줄로 제한하고, UTF-8과 HTTP/HTTPS 주소를 검사한 뒤 교체 확인을 받습니다. 가져온 파일명은 기기 표시 판정에만 쓰입니다. 기존 재설치 스크립트의 `sh -n` 검사를 통과했으며, 코드에서 기기 ID는 외부 CLI에 따옴표로 묶인 인수로 전달됩니다.

## 지적사항

### IPD-R1 / 레이아웃 전환이 POST 요청을 다시 보낼 수 있습니다

- **분류**: `확실한 문제`
- **심각도**: 높음
- **위치**: [WebView.swift:78](/Users/saibi/work_space/saibi/my_cwv/cwv/CWV/WebView.swift:78), [WebView.swift:94](/Users/saibi/work_space/saibi/my_cwv/cwv/CWV/WebView.swift:94)
- **내용**: 글 등록 POST에 리다이렉트 없이 결과 화면을 반환하는 사이트에서 레이아웃 메뉴를 누르면 `web.reload()`가 기존 요청을 재사용합니다. WebKit은 이를 `.formResubmitted`로 전달하고, 현재 delegate는 해당 HTTP/HTTPS 요청을 확인 없이 허용합니다. 서버가 중복 처리를 막지 않으면 같은 글이 다시 등록될 수 있습니다. [WebKit 재로드 구현](https://github.com/WebKit/WebKit/blob/main/Source/WebCore/loader/FrameLoader.cpp#L2174-L2206), [WebKit 탐색 유형 매핑](https://github.com/WebKit/WebKit/blob/main/Source/WebKit/UIProcess/API/Cocoa/WKNavigationAction.mm#L54-L55)
- **제안**: `.formResubmitted`를 감지해 사용자 확인을 받은 경우에만 재전송을 허용하세요. POST 응답 화면에서 레이아웃을 바꿨을 때 승인 전까지 요청이 한 번만 전송되는지 검증하세요.

### IPD-R2 / 첫 접속이 실패하면 레이아웃을 바꿔도 접속을 재시도하지 않을 수 있습니다

- **분류**: `확실한 문제`
- **심각도**: 중간
- **위치**: [WebView.swift:78](/Users/saibi/work_space/saibi/my_cwv/cwv/CWV/WebView.swift:78), [WebView.swift:87](/Users/saibi/work_space/saibi/my_cwv/cwv/CWV/WebView.swift:87)
- **내용**: 오프라인에서 사이트를 처음 열어 문서가 로드되기 전에 실패한 뒤, 연결을 복구하고 데스크톱 모드를 켜는 경우입니다. 최초 탐색 실패 처리는 새 요청을 준비하지 않고, 전환은 `reload()`만 호출합니다. 다시 불러올 문서가 없으면 WebKit은 재요청 없이 재로드를 끝낼 수 있습니다. [WebKit 재로드 처리](https://github.com/WebKit/WebKit/blob/main/Source/WebKit/WebProcess/WebPage/WebPage.cpp#L2800-L2817)
- **제안**: 첫 탐색이 실패해 다시 불러올 페이지가 없으면 전환한 모드로 `base`를 로드하세요. 첫 로드가 아직 진행 중인 경우도 확인해 초기 요청이 중복되지 않게 하세요.

### IPD-R3 / 데스크톱 설정을 뺀 목록은 다음 CSV 복원에서 줄어들 수 있습니다

- **분류**: `결정 필요`
- **심각도**: 중간
- **위치**: [Site.swift:64](/Users/saibi/work_space/saibi/my_cwv/cwv/CWV/Site.swift:64), [Site.swift:227](/Users/saibi/work_space/saibi/my_cwv/cwv/CWV/Site.swift:227), [SiteListView.swift:86](/Users/saibi/work_space/saibi/my_cwv/cwv/CWV/SiteListView.swift:86)
- **내용**: 주소, 이름, 확대율이 같고 레이아웃만 다른 두 항목은 v3에서 각각 보존됩니다. 다른 기기에서 "데스크톱 설정은 빼고 복원"을 누르면 두 항목이 모두 모바일로 남습니다. 이 목록을 다시 백업해 복원하면 두 줄의 값이 같아져 파서가 한 항목을 제거합니다.
- **제안**: (1) **(추천)** 모바일로 바꾼 결과가 동일한 항목은 첫 복원에서 합치고, 선택하기 전에 최종 항목 수를 표시합니다. 기존 CSV 중복 제거 규칙을 유지하면서 실제로 복원될 목록을 알려줄 수 있습니다. (2) 두 항목을 계속 보존해야 한다면 CSV에 항목을 구분할 정보를 저장합니다.

### IPD-R4 / 모든 항목이 모바일이면 다른 기기에서 만든 백업이라는 안내가 사라집니다

- **분류**: `결정 필요`
- **심각도**: 중간
- **위치**: [SiteListView.swift:21](/Users/saibi/work_space/saibi/my_cwv/cwv/CWV/SiteListView.swift:21), [SiteListView.swift:85](/Users/saibi/work_space/saibi/my_cwv/cwv/CWV/SiteListView.swift:85)
- **내용**: `# device: ipad`가 있는 모바일 전용 백업을 iPhone에서 열면 일반 교체 확인창만 나옵니다. 구현 노트는 결과가 같은 선택지를 하나로 줄인 이유를 설명합니다. 같은 조건을 출처 안내에도 적용해, 복원할 때 만든 기기를 알 수 있게 한다는 IPD-Q4, Q8의 요구가 빠졌습니다.
- **제안**: (1) **(추천)** 기기가 다르면 출처를 표시하고, 데스크톱 항목이 있을 때만 두 복원 버튼을 제공합니다. (2) IPD-Q8 문구대로 다른 기기 백업에는 항상 출처와 두 버튼을 표시합니다.

### IPD-R5 / 잘못된 기기 헤더가 뒤의 유효한 헤더를 가립니다

- **분류**: `확실한 문제`
- **심각도**: 낮음
- **위치**: [Site.swift:52](/Users/saibi/work_space/saibi/my_cwv/cwv/CWV/Site.swift:52), [Site.swift:288](/Users/saibi/work_space/saibi/my_cwv/cwv/CWV/Site.swift:288)
- **내용**: 첫 데이터 줄 앞에 `# device: tv`와 `# device: ipad`가 이 순서로 있으면 첫 줄에서 `nil`을 반환합니다. 파일명이 일반 이름이면 출처 안내가 사라지고, 보조 접미사가 있으면 그 값이 유효한 헤더보다 우선합니다. IPD-Q8은 알 수 없는 값을 무시하도록 정했습니다.
- **제안**: `ipad` 또는 `iphone`으로 해석되는 줄을 찾을 때까지 헤더를 계속 읽으세요. 잘못된 헤더 뒤에 유효한 헤더가 오는 사례를 테스트에 추가하세요.

### IPD-R6 / 계획에 없는 `-iphone` 접미사로 백업 출처를 추정합니다

- **분류**: `확실한 문제`
- **심각도**: 낮음
- **위치**: [Site.swift:44](/Users/saibi/work_space/saibi/my_cwv/cwv/CWV/Site.swift:44), [test_site.swift:379](/Users/saibi/work_space/saibi/my_cwv/cwv/test_site.swift:379)
- **내용**: 기기 헤더가 없는 외부 v3 파일을 `favorites-iphone.csv`로 이름 붙이면 iPad에서 iPhone 백업으로 분류합니다. 데스크톱 항목이 있으면 iPhone에서 백업했다는 안내까지 표시합니다. IPD-Q7은 파일명 보조 판정에 `-ipad`만 정했습니다.
- **제안**: 파일명 보조 판정을 `-ipad`로 제한하세요. 헤더 우선 테스트는 `# device: iphone`과 `-ipad.csv`가 충돌하는 사례로 유지할 수 있습니다.

## 확인하지 못한 항목

파일은 수정하지 않았습니다. `test_site`는 임시 CSV와 `UserDefaults`에 쓰므로 재실행하지 않았습니다. 시뮬레이터 재빌드와 스크린샷 확인, 실기기 회전과 멀티태스킹, 팝오버와 스와이프, iCloud 파일 읽기 중단 및 재시도, 실제 사이트의 UA 전환과 POST 동작은 확인하지 못했습니다.