# [SWT] 리뷰 반영

## 2026-11-15 review/SWT_review_codex-gpt-6.1-sol.md

| ID | 판단 | 처리 |
| :--- | :--- | :--- |
| SWT-R1 | 타당 (주소 변경 시 웹뷰만 버리고 같은 id의 제목 캐시는 남음, 코드로 확인) | [확정] `SiteStore.update`에서 주소가 바뀌면 `pageTitles`의 해당 id도 삭제. 주소 변경 후 새 도메인 표시, 재실행 후 유지 테스트 추가 |
| SWT-R2 | 일부 타당 (KVO/웹 기록 판정과 실제 제스처는 자체 검증 밖. 제스처는 GUI 없이 검증 불가) | [확정] 실제 WebKit(macOS)에서 웹 기록 판정을 확인: 첫 페이지 로드 시 제목 이벤트의 `backList`=0, `history.pushState` 직후와 다른 페이지로 이동하면 `backList`>=1이라 수집 조건에서 제외됨, SPA 이동 후 `canGoBack`=true. 제스처와 M3는 실기기 확인 항목으로 남김 (impl 노트의 미확인 목록 유지) |
| SWT-R3 | 타당 (`displayName`이 출처와 무관하게 도메인과 같은 이름을 자동 처리해 CSV에 명시한 `a.com,a.com`도 무시됨) | [확정] 이전 버전이 저장한 사용자 사이트의 도메인 이름은 로드/마이그레이션 때 빈 이름으로 변환하고, `displayName`은 비어 있지 않은 이름을 항상 우선. CSV 명시 제목 우선, 이전 데이터 변환 테스트 추가. 편집 화면의 이름 칸은 저장된 이름을 그대로 보여 준다 |

### 검증
- `build/test_site` OK (R1, R3 케이스 포함), 시뮬레이터 빌드 성공.
- macOS WebKit 실험(일회성 스크립트): 첫 페이지 `title` 이벤트 시 `backForwardList.backList.count == 0`, `pushState` 후 1, 다른 페이지 2.
- 미확인: 실기기 가장자리 스와이프(첫 페이지 목록 복귀, 상세에서 웹 뒤로가기), 전환 애니메이션.
