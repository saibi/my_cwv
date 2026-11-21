# [SWB] 교차리뷰 (codex)

## 요약

`4b76ce6`은 분할 화면의 뒤로/앞으로가기와 버전 표시 개선을 구현했습니다. 다만 가로 모드 iPhone에서도 새 제스처가 활성화될 수 있고, 이동 방향이 틀린 드래그가 웹 콘텐츠의 터치를 가로챌 수 있습니다. 두 경로를 수정하고 SWB-M3 실기기 확인을 마친 뒤 완료로 판단하는 것을 권합니다.

| 계획 항목 | 구현 및 검증 상태 |
| --- | --- |
| SWB-Q1 / SWB-M1 말풍선 색 | 부분 충족. 흰 글씨와 `Color.accentColor`를 적용했지만 색상 에셋에 진한 파랑 값이 없습니다. 말풍선 본체와 화살표는 실제 표시를 확인하지 못했습니다. |
| SWB-Q2 / SWB-M2 웹 영역 24pt 스와이프 | 부분 충족. 순수 함수 테스트는 양쪽 24pt 경계, 창 끝에서 거절, 거리 또는 속도 기준, 방향, 세로 우세를 다룹니다. 테스트는 인식기와 스크롤의 경합, 실제 레이아웃, 방문 기록 상태를 거치지 않습니다. 구현 노트에는 시뮬레이터 빌드 성공이 기록돼 있습니다. |
| SWB-Q3 버전 | 충족. 같은 구현 커밋에서 `Version.xcconfig`를 `0.1.1`로 올렸습니다. |
| SWB-Q4 / SWB-M1 버전 글자 | 코드 충족. `.caption`을 유지하고 라벨색 70%와 `.medium`을 적용했습니다. 구현 노트에는 iPad 스크린샷 확인이 기록돼 있으며, iPhone과 라이트/다크 모드별 대비는 확인 범위가 기록돼 있지 않습니다. |
| SWB-Q5 전환 시점 | 충족. `.ended`에서만 이동하므로 손가락을 따라오는 전환은 없습니다. |
| SWB-M3 실기기 | 미완료. 목록 좌우 배치에서 양방향 이동, 목록을 숨겼을 때와 iPhone에서 한 번만 이동하는지, 핸들 및 스크롤과의 충돌을 확인해야 합니다. 시뮬레이터 입력 불가로 실기기 확인으로 넘긴 이유는 타당하며, 계획에서도 이 경로를 허용합니다. |

변경분에서 다운로드, 파일명, 외부 텍스트 파싱, 서브프로세스 또는 외부 CLI를 받는 새 경로는 발견하지 못했습니다. 제스처는 기존 WebKit 방문 기록 API를 사용하고, 빌드 시각은 앱 번들에서 읽습니다. 취소된 제스처는 이동을 실행하지 않으며, 별도로 재개해야 할 작업 상태를 저장하지 않습니다.

## 지적사항

### SWB-R1. 분할 목록이 없어도 새 제스처가 활성화됩니다

- **분류**: 확실한 문제
- **심각도**: 중간
- **위치**: [cwv/CWV/WebView.swift:12](/Users/saibi/work_space/saibi/my_cwv/cwv/CWV/WebView.swift:12), [cwv/CWV/CWVApp.swift:39](/Users/saibi/work_space/saibi/my_cwv/cwv/CWV/CWVApp.swift:39), [cwv/CWV/BrowserView.swift:20](/Users/saibi/work_space/saibi/my_cwv/cwv/CWV/BrowserView.swift:20)
- **내용**: 모든 웹뷰에 `PaneEdgePan`을 등록하고 창 경계에서 1pt 이상 떨어졌는지만 검사합니다. 예를 들어 가로 모드 iPhone에서 안전 영역 때문에 웹뷰 왼쪽이 창 왼쪽보다 안쪽에 있으면, 방문 기록이 있는 상태에서 웹 콘텐츠 왼쪽 24pt의 드래그가 새 뒤로가기 조건을 충족합니다. 계획은 iPhone의 기존 동작을 유지하도록 정했습니다. [SwiftUI 안전 영역](https://developer.apple.com/documentation/swiftui/view/ignoressafearea%28_%3Aedges%3A%29), [UIKit 좌표 변환](https://developer.apple.com/documentation/uikit/uiview/convert%28_%3Ato%3A%29-2kf3d)
- **제안**: 현재 보이는 분할 목록의 위치를 웹뷰에 전달해 목록에 인접한 방향만 허용하세요. 목록 숨김과 단일 화면에서는 새 인식기를 비활성화하고, 가로 모드 iPhone을 회귀 검증에 포함하세요.

### SWB-R2. 이동 방향이 틀려도 웹 콘텐츠의 터치를 가로챌 수 있습니다

- **분류**: 확실한 문제
- **심각도**: 중간
- **위치**: [cwv/CWV/WebView.swift:18](/Users/saibi/work_space/saibi/my_cwv/cwv/CWV/WebView.swift:18), [cwv/CWV/WebView.swift:79](/Users/saibi/work_space/saibi/my_cwv/cwv/CWV/WebView.swift:79), [cwv/CWV/WebView.swift:91](/Users/saibi/work_space/saibi/my_cwv/cwv/CWV/WebView.swift:91)
- **내용**: 목록이 왼쪽에 있고 뒤로갈 기록이 있을 때, 웹뷰 왼쪽 24pt에 놓인 슬라이더를 왼쪽으로 끌어도 가로 우세 조건을 통과합니다. 인식기가 먼저 시작하면 슬라이더 터치가 취소될 수 있고, 손을 떼면 방향 검사에서 뒤로가기도 거절됩니다. 현재 테스트는 이 경우 `paneSwipe`가 `nil`을 반환하는지만 확인합니다. [UIKit 제스처 시작 조건](https://developer.apple.com/documentation/uikit/uigesturerecognizerdelegate/gesturerecognizershouldbegin%28_%3A%29?changes=_8), [UIKit 터치 취소](https://developer.apple.com/documentation/uikit/uigesturerecognizer/cancelstouchesinview)
- **제안**: 터치 시작 때 허용된 방향을 기록하고, `gestureRecognizerShouldBegin`에서 가로 우세와 이동 방향을 함께 확인하세요. 양쪽 분할 배치에서 반대 방향 드래그가 웹 콘텐츠에 전달되는지, 올바른 방향의 스와이프는 스크롤에 밀리지 않고 한 번 이동하는지 확인하세요.

### SWB-R3. SWB-Q1에서 정한 진한 파랑이 앱에 지정돼 있지 않습니다

- **분류**: 확실한 문제
- **심각도**: 낮음
- **위치**: [cwv/CWV/SiteListView.swift:185](/Users/saibi/work_space/saibi/my_cwv/cwv/CWV/SiteListView.swift:185), [cwv/CWV/Assets.xcassets/AccentColor.colorset/Contents.json:1](/Users/saibi/work_space/saibi/my_cwv/cwv/CWV/Assets.xcassets/AccentColor.colorset/Contents.json:1)
- **내용**: 구현 노트는 `Color.accentColor`를 앱의 진한 파랑으로 설명하지만 `AccentColor` 에셋에 색상 값이 없습니다. 배경 수정자가 적용되더라도 빌드 시각을 열었을 때 합의한 배경색과 흰 글씨의 대비를 보장할 수 없습니다. Apple은 `presentationBackground`를 시트 배경용으로 문서화하므로 말풍선에 적용되는지는 빌드 성공만으로 판단할 수 없습니다. [SwiftUI 강조색](https://developer.apple.com/documentation/swiftui/color/accentcolor), [SwiftUI 프레젠테이션 수정자](https://developer.apple.com/documentation/swiftui/view-presentation?changes=__3)
- **제안**: 말풍선 배경에 대비를 확인한 진한 파랑을 명시하고, iPhone과 iPad의 라이트/다크 모드에서 본체와 화살표까지 확인하세요. 지원 OS에서 배경 수정자가 적용되지 않으면 팝오버 배경색을 설정하는 공개 UIKit API를 사용하세요. [UIKit 팝오버 배경색](https://developer.apple.com/documentation/uikit/uipopoverpresentationcontroller/backgroundcolor)

### SWB-R4. 손을 뗄 때 반대로 튕긴 경우 계획과 판정이 다릅니다

- **분류**: 결정 필요
- **심각도**: 낮음
- **위치**: [plan/SWB_plan_claude-sonnet-5-5.md:36](/Users/saibi/work_space/saibi/my_cwv/plan/SWB_plan_claude-sonnet-5-5.md:36), [cwv/CWV/Site.swift:151](/Users/saibi/work_space/saibi/my_cwv/cwv/CWV/Site.swift:151), [cwv/CWV/Site.swift:162](/Users/saibi/work_space/saibi/my_cwv/cwv/CWV/Site.swift:162)
- **내용**: 계획은 종료 속도의 절댓값을 사용하고, 구현은 기존 함수의 부호 있는 속도 판정을 재사용합니다. 왼쪽 가장자리에서 오른쪽으로 30pt 이동한 상태로 왼쪽을 향해 600pt/s로 손을 떼면, 계획의 식은 뒤로가기를 허용하고 구현은 거절합니다. 구현 노트에 이 차이가 없고 현재 테스트에는 이 입력이 없습니다.
- **제안**: (1) **(추천)** 현재 판정을 유지하고 계획과 구현 노트를 수정하세요. 짧게 밀었다가 반대로 당기는 동작을 취소로 사용할 수 있습니다. (2) 계획의 절댓값 기준을 적용해 이 동작도 이동으로 처리하세요. 선택한 동작을 좌우 양쪽 단위 테스트로 고정하세요.

파일을 수정하지 않았습니다. 전체 자체 검증은 임시 CSV를 쓰므로 다시 실행하지 않았고, 시뮬레이터 재빌드, 실제 제스처, 말풍선 렌더링은 독립적으로 확인하지 못했습니다.