# [SWB] 리뷰 반영

## 2026-11-21 review/SWB_review_codex-gpt-6.2-sol.md

| ID | 판단 | 처리 |
| :--- | :--- | :--- |
| SWB-R1 | 타당 (코드 확인: `PaneEdgePan`이 모든 웹뷰에 붙고 "웹뷰 끝이 창 끝에서 1pt 이상 떨어짐"만 검사한다. 가로 iPhone은 안전 영역 때문에 웹뷰가 창 끝에서 떨어져 조건을 통과한다) | [확정] `SiteWebView.paneSwipeEnabled`(`pane.isEnabled`)를 분할 화면(`RootView.detail`)에서만 켠다. `BrowserView`/`WebView`에 `paneSwipe` 인자 추가 |
| SWB-R2 | 타당 (코드 확인: 시작 조건에 이동 방향이 없어 왼쪽 끝의 슬라이더를 왼쪽으로 끌어도 팬이 시작해 웹 콘텐츠 터치를 취소할 수 있다) | [확정] `PaneEdgePan`이 시작한 쪽의 허용 방향(`canBack`/`canForward`)을 기록하고, `paneSwipeStarts`(Site.swift, 순수 함수)로 가로 우세와 방향이 맞을 때만 시작한다. 방향 조합을 `test_site.swift`에 추가 |
| SWB-R3 | 타당 (확인: `AccentColor` 에셋에 색 값이 없어 시스템 파랑이 나오고 합의한 "진한 파랑"이 아니다) | [확정] 말풍선 배경을 직접 지정한 진한 파랑(`Color(red: 0.05, green: 0.25, blue: 0.65)`, 흰 글씨와 대비 약 9:1)으로 하고 `.background`와 `.presentationBackground` 둘 다 적용했다. 말풍선 본체/화살표의 실제 표시는 탭 조작이 없어 확인하지 못했다 (실기기 확인) |
| SWB-R4 | 일부 타당 (계획은 `abs(velocity)`, 구현은 방향 있는 `shouldCloseOnEdgeSwipe` 재사용으로 달랐다) | [확정] D1 -> (a): 구현 유지, 계획과 구현 노트를 맞췄다. 반대 방향 튕김을 `test_site.swift`에 고정 |

### 결정
- [확정] **D1 (SWB-R4)** 짧게 밀었다가 손을 뗄 때 반대로 튕기면 이동할까 -> 결정: (a) 이동하지 않음, 계획/노트를 구현에 맞춤 (추천안: 반대로 당기는 동작을 취소로 쓸 수 있고, 기존 목록 복귀 스와이프와 같은 판정이라 일관된다. 기각: (b) 절댓값 기준)

### 검증
- `build/test_site` 통과 (추가: `paneSwipeStarts` 방향/세로, 반대 방향 튕김), iPhone/iPad 시뮬레이터 빌드 성공.
- 확인 못함 (SWB-M3, 실기기): 제스처 자체(시뮬레이터에서 터치 주입 불가), 가로 iPhone에서 새 제스처가 꺼져 있는지, 슬라이더 같은 콘텐츠와의 상호작용, 말풍선 색과 화살표.
