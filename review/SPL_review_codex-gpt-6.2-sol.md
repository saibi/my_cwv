# [SPL] 교차리뷰 (codex)

## 요약

`c70b84d`는 iPad 분할 화면의 주요 기능과 CSV 호환성을 구현했습니다. 다만 열린 사이트의 주소를 편집하면 이전 페이지가 계속 표시되고, 너비 드래그는 시작 너비를 고정하지 않습니다. 두 문제를 수정한 뒤 SPL-M3에서 창 크기 변경, 설정 화면, CSV 복원까지 확인하는 것이 좋겠습니다.

| 계획 항목 | 구현 및 검증 상태 |
| --- | --- |
| SPL-Q1 목록 숨기기/보이기 | 툴바와 플로팅 메뉴에 구현했습니다. 숨겨진 왼쪽 목록만 가장자리 스와이프로 복귀합니다. 선택한 사이트가 없을 때 목록을 강제로 표시하는 보완은 다시 열 수단을 확보한다는 점에서 타당합니다. |
| SPL-Q2 분할 조건 | `.regular`인 iPad로 제한했습니다. iPhone의 기존 전환을 유지한다는 목표와 iPad 전용 설정 범위에 부합하므로 변경 이유는 타당합니다. |
| SPL-Q3 위치 및 너비 조절 | 위치 선택, 경계 드래그, 기본값 복원을 구현했습니다. 주소 편집 및 위치 변경 시 뷰 상태 유지에 문제가 있습니다. SPL-R1, SPL-R3을 참고해 주세요. |
| SPL-Q4 너비 범위 및 저장 | 기본 320pt, 최소 240pt, 최대 480pt 및 창 축소 시 표시 너비 제한을 구현했습니다. 480pt 미만 입력에서는 최소 240pt가 창의 50% 제한보다 우선하며 테스트도 이 동작을 명시합니다. 드래그와 저장에는 SPL-R2의 문제가 있습니다. |
| SPL-Q5 CSV 백업/복원 | iPad에서 세 설정을 내보내고, iPad에서 복원할 때 유효한 키만 적용합니다. 기존 파서가 주석 줄을 건너뛰고 데이터 열 형식도 동일하므로 v3 유지가 타당합니다. 복원 안내는 적용되는 설정을 정확히 표시하지 않습니다. |
| SPL-M1 순수 로직 자체 검증 | 최소/최대/창 축소, 헤더 왕복, 잘못된 값, 범위 제한, 뒤쪽 헤더 무시, 기존 v3 회귀를 테스트합니다. `load/apply` 테스트는 위치와 숨김 쓰기, 너비 생략을 확인합니다. 유효한 너비를 실제로 써서 다시 읽는 경로와 헤더 유무에 따른 사이트 전체 필드 비교는 빠져 있습니다. 구현 노트에 통과가 기록되어 있습니다. |
| SPL-M2 시뮬레이터 | 구현 노트에 iPad/iPhone 빌드, iPad 세로 좌/우/숨김 화면, iPhone 기존 전환 확인이 기록되어 있습니다. 계획에 적힌 iPad 가로 화면, 위치 Picker 조작, 가장자리 스와이프는 확인 기록이 없습니다. |
| SPL-M3 실기기 | 미확인입니다. 자체 검증은 SwiftUI나 실제 `WebCache`를 실행하지 않아 회전, 창 크기 변경, 드래그와 저장 유지, 사이트 재선택 시 페이지 유지, 파일 앱을 통한 백업/복원까지 검증하지 못합니다. |

개인용 앱의 CSV 경로는 최대 1MB만 허용하고, UTF-8 및 데이터 500줄 제한을 적용합니다. 사이트 주소는 HTTP/HTTPS로 제한하고, 외부 파일명은 기기 분류의 보조 힌트로만 사용합니다. SPL에서 추가한 헤더는 검증을 거쳐 레이아웃 설정에만 적용되며, 새 다운로드나 외부 CLI 호출 경로는 없습니다.

## 지적사항

### SPL-R1. 열린 사이트의 주소를 편집해도 이전 페이지가 남습니다

- **분류** `확실한 문제`
- **심각도** 중간
- **위치** [cwv/CWV/CWVApp.swift:67](/Users/saibi/work_space/saibi/my_cwv/cwv/CWV/CWVApp.swift:67), [cwv/CWV/SiteStore.swift:99](/Users/saibi/work_space/saibi/my_cwv/cwv/CWV/SiteStore.swift:99), [cwv/CWV/WebView.swift:198](/Users/saibi/work_space/saibi/my_cwv/cwv/CWV/WebView.swift:198)
- **내용** 분할 화면에서 A 사이트를 연 채 목록에서 주소를 B로 바꾸면 저장소는 A의 캐시를 제거하지만 사이트 UUID는 유지합니다. `BrowserView`의 식별자가 같아서 기존 코디네이터가 A의 웹뷰를 계속 보유합니다. 같은 행을 다시 눌러도 식별자가 같으며, 이 상태에서 `Safari에서 열기`는 캐시에서 B를 가져오므로 화면과 다른 주소를 열 수 있습니다. 목록 초기화나 복원에서 현재 UUID를 다시 사용하는 경우에도 캐시 제거와 화면의 웹뷰 교체가 일치하지 않습니다.
- **제안** 주소 변경이나 목록 교체로 캐시를 무효화할 때 표시 중인 웹뷰도 같은 시점에 교체하세요. 확대율이나 표시 모드 변경은 기존 웹뷰를 계속 사용하도록 하고, 열린 행의 주소 편집 직후 표시 페이지와 Safari 대상이 일치하는지 검증하세요.

### SPL-R2. 드래그 기준 너비에 직전 드래그 결과가 다시 들어갑니다

- **분류** `확실한 문제`
- **심각도** 중간
- **위치** [cwv/CWV/CWVApp.swift:51](/Users/saibi/work_space/saibi/my_cwv/cwv/CWV/CWVApp.swift:51), [cwv/CWV/CWVApp.swift:82](/Users/saibi/work_space/saibi/my_cwv/cwv/CWV/CWVApp.swift:82)
- **내용** `translation.width`는 제스처 시작부터의 누적 이동량인데, 기준 `w`는 드래그 중에 바뀌는 `dragWidth`를 사용합니다. 다음 이벤트가 갱신된 뷰의 클로저에 전달되면, 320pt에서 누적 이동량 10pt와 20pt가 들어왔을 때 330pt와 340pt가 되어야 할 너비가 330pt와 350pt로 계산됩니다. 전역 좌표를 써도 이 중복 계산은 남습니다. 임시 너비를 지우는 경로도 `onEnded`뿐이라, 드래그 도중 창이 compact로 바뀌어 핸들이 사라지면 regular 복귀 후 임시값이 우선될 수 있습니다.
- **제안** 표시 너비와 이동 방향을 드래그 시작 시 한 번 잡고, 각 이벤트의 누적 이동량을 그 기준에 더하세요. 임시값은 취소 시에도 자동 해제되는 제스처 상태로 관리하고, 정상 종료 시 최종값만 저장하세요. 좌우 양쪽에서 연속 이동, 방향 반전, 드래그 중 창 크기 변경을 확인하세요.

### SPL-R3. 목록의 표시 상태가 레이아웃 분기에 묶여 있습니다

- **분류** `확실한 문제`
- **심각도** 중간
- **위치** [cwv/CWV/CWVApp.swift:27](/Users/saibi/work_space/saibi/my_cwv/cwv/CWV/CWVApp.swift:27), [cwv/CWV/CWVApp.swift:55](/Users/saibi/work_space/saibi/my_cwv/cwv/CWV/CWVApp.swift:55), [cwv/CWV/SiteListView.swift:14](/Users/saibi/work_space/saibi/my_cwv/cwv/CWV/SiteListView.swift:14)
- **내용** 왼쪽/오른쪽 배치와 regular/compact 전환은 서로 다른 `SiteListView`를 만듭니다. 옵션 시트, 편집 시트, 파일 선택, 복원 대기 상태는 해당 목록의 `@State`에 있습니다. 옵션에서 오른쪽을 고르면 옵션을 연 목록 자체가 교체되어 `showSettings`가 초기화됩니다. 파일 선택이나 복원 확인 중 창 크기 등급이 바뀌어도 원래 목록에 있던 진행 상태가 새 목록으로 이어지지 않습니다.
- **제안** 좌우 순서만 바꿀 때 동일한 목록 뷰의 식별자를 유지하고, 크기 등급이 바뀌어도 이어져야 하는 시트와 파일 작업 상태는 레이아웃 분기 위에서 소유하게 하세요.

### SPL-R4. VoiceOver로 목록 너비를 조절할 수 없습니다

- **분류** `확실한 문제`
- **심각도** 낮음
- **위치** [cwv/CWV/CWVApp.swift:75](/Users/saibi/work_space/saibi/my_cwv/cwv/CWV/CWVApp.swift:75), [cwv/CWV/SettingsView.swift:26](/Users/saibi/work_space/saibi/my_cwv/cwv/CWV/SettingsView.swift:26)
- **내용** 너비를 바꾸는 유일한 경로는 12pt 경계의 드래그입니다. 경계에 접근성 레이블이나 조절 동작이 없고 옵션에는 기본값 복원만 있어서, VoiceOver 사용자는 원하는 너비를 선택할 수 없습니다.
- **제안** 경계에 접근성 레이블, 현재 너비, 증가/감소 동작을 추가하세요. 드래그와 같은 범위 제한 및 저장 경로를 사용하면 됩니다.

### SPL-R5. 복원 확인창이 실제 적용할 설정을 잘못 알립니다

- **분류** `확실한 문제`
- **심각도** 낮음
- **위치** [cwv/CWV/SiteListView.swift:29](/Users/saibi/work_space/saibi/my_cwv/cwv/CWV/SiteListView.swift:29), [cwv/CWV/SiteListView.swift:103](/Users/saibi/work_space/saibi/my_cwv/cwv/CWV/SiteListView.swift:103)
- **내용** 유효한 헤더가 하나라도 있으면 확인창은 위치와 너비가 바뀐다고 표시합니다. `# sidebar-hidden: 1`만 유효한 파일을 복원하면 실제로는 숨김 설정만 바뀌고, 사이트를 열었을 때 목록이 사라집니다. 일반 iPad 백업의 숨김 설정 변경도 현재 문구에는 나오지 않습니다.
- **제안** 유효한 키를 기준으로 위치, 너비, 숨김 중 적용할 항목을 확인창에 표시하세요. 숨김 값만 있는 파일도 검증에 포함하세요.

## 확인하지 못한 항목

자체 검증은 임시 CSV와 `UserDefaults`를 쓰므로 이번 읽기 전용 리뷰에서는 재실행하지 않았습니다. 시뮬레이터와 실기기에서 드래그 이벤트, 시트의 실제 표시 상태, 회전 및 창 크기 변경 후 웹뷰 상태, iCloud 파일 읽기 실패와 복원 왕복도 재현하지 못했습니다.