# [SPL] 리뷰 반영

## 2026-11-21 review/SPL_review_codex-gpt-6.2-sol.md

| ID | 판단 | 처리 |
| :--- | :--- | :--- |
| SPL-R1 | 타당 (코드 확인: `BrowserView.id(site.id)`는 주소를 바꿔도 그대로인데 `SiteStore.update`는 캐시를 버린다. 분할 화면에서만 가능) | [확정] `.id(ObjectIdentifier(WebCache.view(for: site)))`로 변경. 주소 편집, 목록 초기화/복원으로 캐시의 웹뷰가 교체되면 `BrowserView`(와 Coordinator)도 새로 만든다. 확대%/데스크톱 전환은 같은 웹뷰라 그대로 이어진다 |
| SPL-R2 | 타당 (코드 확인: `translation`은 누적값인데 기준 `w`는 `dragWidth`를 따라 바뀐다) | [확정] 시작 너비를 `dragStart`에 한 번만 잡고 누적 이동량을 더한다. `@GestureState dragging`이 false가 될 때(끝남 또는 취소) 저장하고 임시값을 지운다. 창이 좁아져 분할이 풀리면(`onDisappear`) 임시값도 지운다 |
| SPL-R3 | 타당 (코드 확인: `if/else` 분기마다 목록의 구조상 위치가 달라 위치를 바꾸면 `SiteListView`가 새로 만들어진다) | [일부 확정] 좌우 순서는 `ForEach(order, id: \.self)`로 그려 같은 뷰로 이어지게 했다 (옵션에서 위치를 바꿔도 옵션 시트가 닫히지 않음). 크기 등급(regular/compact)이 바뀔 때의 시트/파일 작업 상태 유지는 하지 않음: 상태를 `RootView`로 올려야 해서 범위가 크고, 사용 중 창 크기를 바꾸는 일이 드물다 (남은 한계에 기록) |
| SPL-R4 | 타당 | [확정] 경계에 접근성 레이블("목록 너비"), 값(현재 pt), 조절 동작(위/아래로 쓸어 20pt씩, 범위 제한은 드래그와 같은 `clampSidebarWidth`) 추가 |
| SPL-R5 | 타당 (코드 확인: 안내 문구가 위치/너비로 고정) | [확정] `SidebarLayout.Partial.summary`(Site.swift)로 파일에 있는 항목("위치, 너비, 숨김" 중)만 안내. 숨김만 있는 파일도 안내에 나온다 |

리뷰의 테스트 보강 지적도 반영: 너비 쓰기/읽기(`apply` 후 `load`), 헤더가 있어도 사이트 전체 필드(`Site ==`) 해석이 같은지, `summary`.

### 결정
- 결정이 필요한 지적은 없었다.

### 검증
- `build/test_site` 통과 (추가: summary, 너비 apply/load, 헤더 유무 사이트 전체 비교), iPhone 시뮬레이터 빌드 성공.
- iPad 시뮬레이터에서 `ForEach` 구조로 바꾼 뒤에도 오른쪽 배치, 선택 행 강조, 웹 표시가 정상 (스크린샷).
- 확인 못함 (조작 수단 없음, SPL-M3 실기기): R1(분할 화면에서 열린 사이트의 주소 편집 후 화면/Safari 대상 일치), R2(연속/반전 드래그, 드래그 중 창 크기 변경), R3(옵션 시트가 열린 채 위치 변경), R4(VoiceOver 조절).
