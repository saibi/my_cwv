# [JOY] 교차리뷰 (codex)

## 요약

`ae04c48`의 방향 판정, 메뉴 항목, 버전 변경은 계획과 일치합니다. 다만 전체 화면의 기본 버튼 위치에서는 버튼 중심에서 오른쪽으로 끌어도 앞으로 가기에 필요한 거리에 닿을 수 없습니다. 드래그가 시스템에 의해 취소되면 버튼과 말풍선도 화면에 남습니다. 두 문제를 수정한 뒤 JOY-M3에서 확인해야 합니다.

| 계획 항목 | 구현 및 검증 상태 |
| --- | --- |
| JOY-Q1 모서리 이동 | 3배 거리, 가장 가까운 모서리 판정, 목표 윤곽, 현재 위치를 표시하는 하위 메뉴를 구현했습니다. 놓은 뒤 결과 말풍선은 빠져 있습니다. |
| JOY-Q2 놓은 위치로 판정 | 실제 이동량과 우세 축을 사용합니다. 화면 가장자리에서 바깥쪽으로 끄는 동작은 판정 거리를 확보하기 어렵습니다. |
| JOY-Q3 기기별 거리 | iPhone 60pt, iPad 52pt, 모서리 이동 180pt/156pt를 적용했습니다. |
| JOY-Q4 탭과 탐색 메뉴 | 기존 탭 메뉴에 뒤로/앞으로를 추가했습니다. 원위치로 돌아와 놓았을 때 메뉴가 열리지 않는지는 실기기 확인이 필요합니다. 기존 `Menu`를 재사용한 이유는 타당하며, 이 동작은 계획에 적힌 대로 별도 확인이 필요합니다. |
| JOY-Q5 기존 스와이프 | SWB 경로를 유지했습니다. |
| 말풍선 및 햅틱 | 방향과 글자 크기 힌트, 탐색 및 글자 크기 결과를 구현했습니다. 햅틱 추가는 판정이 바뀌는 순간을 손끝으로 알린다는 목적에 부합합니다. 드래그 중 화면 경계와 연속 조작의 말풍선 처리가 빠져 있습니다. |
| 문서 및 버전 | README에 조작 방법을 추가했고 `Version.xcconfig`를 `0.2.0`으로 올렸습니다. |
| JOY-M1 순수 함수 | 구현 노트에 통과가 기록되어 있습니다. 네 방향, 대각선, 모서리 이동, 0과 작은 최종 이동량을 검사합니다. 방향별 임계값 검사는 일부 빠져 있습니다. |
| JOY-M2 시뮬레이터 | 구현 노트에 iPhone/iPad 빌드 성공과 iPad 화면 확인이 기록되어 있습니다. 열린 메뉴의 스크린샷은 검토 범위에서 확인할 수 없었습니다. |
| JOY-M3 실기기 | 미확인입니다. 순수 함수 검사는 실제 터치, 메뉴 표시 여부, 웹 기록 이동을 다루지 않습니다. |

JOY가 추가한 입력은 터치 이동량과 고정 메뉴 선택입니다. 웹 기록 이동은 기존 `WKWebView`의 탐색 정책을 따릅니다. 변경 범위에서 다운로드, 파일명, 외부 텍스트를 새로 처리하거나 서브프로세스와 외부 CLI를 실행하는 경로는 발견하지 못했습니다.

## 지적사항

### JOY-R1 화면 가장자리에 붙은 버튼은 바깥쪽 방향의 판정 거리를 확보하지 못합니다

- **분류** `확실한 문제`
- **심각도** 높음
- **위치** [BrowserView.swift:23](/Users/saibi/work_space/saibi/my_cwv/cwv/CWV/BrowserView.swift:23), [BrowserView.swift:136](/Users/saibi/work_space/saibi/my_cwv/cwv/CWV/BrowserView.swift:136), [Site.swift:403](/Users/saibi/work_space/saibi/my_cwv/cwv/CWV/Site.swift:403)
- **내용** 가로 안전 영역 여백이 없는 세로 iPhone 전체 화면에서 기본 오른쪽 아래 버튼의 중심은 오른쪽 화면 끝에서 `16 + 22 = 38pt` 떨어져 있습니다. 글 A에서 B를 열고 A로 돌아온 뒤, 버튼 중심을 눌러 오른쪽 끝까지 끌어도 앞으로 가기에 필요한 `60pt`에 못 미쳐 B로 이동하지 않습니다. 왼쪽 화면 끝에 붙인 버튼에서는 뒤로 가기에 같은 문제가 생깁니다.
- **제안** 화면 끝과 맞닿는 모서리에서는 버튼 중심을 기기별 판정 거리보다 충분히 안쪽에 두십시오. 버튼 배치, 목표 윤곽, 목표 모서리 계산에 같은 좌표를 쓰고, 기본 위치에서 버튼 중심을 눌러 네 방향을 각각 시험하십시오.

### JOY-R2 시스템이 드래그를 취소하면 버튼과 힌트가 남습니다

- **분류** `확실한 문제`
- **심각도** 중간
- **위치** [BrowserView.swift:18](/Users/saibi/work_space/saibi/my_cwv/cwv/CWV/BrowserView.swift:18), [BrowserView.swift:38](/Users/saibi/work_space/saibi/my_cwv/cwv/CWV/BrowserView.swift:38)
- **내용** `drag`, `live`, `moveTarget`을 `@State`에 저장하고 정상 종료 콜백에서만 초기화합니다. 멀리 끄는 도중 전화 수신으로 제스처가 취소되고 같은 화면으로 돌아오면 버튼이 마지막 드래그 위치에 남고 목표 모서리 윤곽도 계속 표시됩니다. SwiftUI는 제스처가 성공적으로 끝났을 때만 `onEnded`를 호출합니다. [Apple 제스처 문서](https://developer.apple.com/documentation/SwiftUI/Adding-Interactivity-with-Gestures), [Apple 제스처 취소 문서](https://developer.apple.com/documentation/uikit/about-the-gesture-recognizer-state-machine)
- **제안** 임시 이동량을 `@GestureState`로 관리하고 힌트와 목표 모서리를 그 값에서 계산하십시오. 기록 이동, 글자 크기 저장, 모서리 저장은 정상 종료 때 실행하십시오.

### JOY-R3 드래그 중 말풍선이 화면 밖으로 나갑니다

- **분류** `확실한 문제`
- **심각도** 중간
- **위치** [BrowserView.swift:37](/Users/saibi/work_space/saibi/my_cwv/cwv/CWV/BrowserView.swift:37), [BrowserView.swift:112](/Users/saibi/work_space/saibi/my_cwv/cwv/CWV/BrowserView.swift:112)
- **내용** 말풍선은 저장된 모서리를 기준으로 정렬된 뒤 버튼과 함께 이동합니다. 예를 들어 오른쪽 아래 버튼을 화면 왼쪽 끝에서 `10pt` 떨어진 곳까지 가로로 끌면, 말풍선의 오른쪽 끝은 화면 왼쪽에서 약 `32pt`인 곳에 놓입니다. 고정 너비로 표시되는 "여기로 이동" 말풍선의 왼쪽이 화면 밖으로 나갑니다. 구현 노트에 적힌 정렬 방식은 버튼이 원래 모서리에 있을 때를 기준으로 합니다.
- **제안** 드래그 중인 버튼의 현재 위치와 말풍선 크기를 기준으로 배치하십시오. 가로 위치를 웹 영역 안으로 제한하고, 세로 공간이 부족하면 버튼의 반대편에 표시하십시오.

### JOY-R4 연속 조작에서 이전 결과가 현재 동작의 피드백으로 보입니다

- **분류** `확실한 문제`
- **심각도** 낮음
- **위치** [BrowserView.swift:39](/Users/saibi/work_space/saibi/my_cwv/cwv/CWV/BrowserView.swift:39), [BrowserView.swift:52](/Users/saibi/work_space/saibi/my_cwv/cwv/CWV/BrowserView.swift:52), [BrowserView.swift:101](/Users/saibi/work_space/saibi/my_cwv/cwv/CWV/BrowserView.swift:101)
- **내용** 글자를 키워 "글자 130%"가 보이는 동안 새 드래그를 시작하고 `8pt`를 넘긴 뒤 방향 판정 거리 안쪽에 머물면, 힌트가 없어야 할 구간에 이전 결과가 따라다닙니다. 이어서 모서리를 옮기면 `.move`는 새 결과를 표시하지 않으므로 이전 타이머가 끝날 때까지 새 모서리에 "글자 130%"가 나타날 수 있습니다.
- **제안** 새 드래그가 인식되면 이전 결과와 타이머를 지우십시오. 모서리가 실제로 바뀌면 계획의 1.2초 결과 표시를 적용하십시오.

### JOY-R5 네 방향 모두에서 판정 경계를 검사하지 않습니다

- **분류** `확실한 문제`
- **심각도** 낮음
- **위치** [test_site.swift:444](/Users/saibi/work_space/saibi/my_cwv/cwv/test_site.swift:444), [JOY 계획:40](/Users/saibi/work_space/saibi/my_cwv/plan/JOY_plan_claude-sonnet-5-5.md:40)
- **내용** 오른쪽과 아래의 `59pt` 미동작, 오른쪽과 위의 정확한 `60pt` 동작을 검사하지 않습니다. 예를 들어 오른쪽만 `60pt`에서 무시하고 `61pt`부터 동작하도록 바뀌어도 현재 검사로는 잡을 수 없습니다.
- **제안** 네 방향 각각에 대해 임계값 직전과 정확한 임계값을 검사하십시오. 드래그 후 원위치로 돌아왔을 때 메뉴가 열리지 않는지는 JOY-M3에서 실제 터치로 확인하십시오.

## 확인하지 못한 항목

전체 자체 검증은 임시 CSV와 `UserDefaults`에 쓰므로 읽기 전용 검토에서는 재실행하지 않았습니다. 시뮬레이터 재빌드, 열린 메뉴 스크린샷, iPhone/iPad 실기기 터치와 취소 후 복귀, `www.clien.net` 탐색, 네트워크 실패 시 화면 동작은 확인하지 못했습니다.