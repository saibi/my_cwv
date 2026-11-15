# [SWT] 구현 노트

- 계획: plan/SWT_plan_claude-sonnet-5-5.md
- 구현 커밋: 2412b07 (리뷰 반영 커밋은 review/SWT_refine_*.md)

## 아키텍처
| 파일 | 역할 |
| :--- | :--- |
| `CWV/Site.swift` | `Site.displayName(cached:)`, `usableTitle`, `shouldCloseOnEdgeSwipe` (순수 함수), `parseDefaultPages`가 제목 없는 줄을 빈 이름으로 |
| `CWV/SiteStore.swift` | `pageTitles` (UserDefaults 캐시), `setPageTitle`, `title(for:)` |
| `CWV/WebView.swift` | 왼쪽 가장자리 팬 제스처(`!canGoBack`일 때만), `web.title` KVO, `onBack`/`onTitle` |
| `CWV/BrowserView.swift`, `CWVApp.swift` | 콜백 연결, 목록/브라우저 전환 애니메이션 |
| `CWV/SiteListView.swift` | 표시 이름 사용, 이름 입력칸 안내와 빈 이름 저장 |

흐름: 첫 페이지(`backForwardList.backList`가 비어 있을 때)의 타이틀 -> `usableTitle` 통과 -> `store.setPageTitle` -> UserDefaults -> 목록 `store.title(for:)`.

## 핵심 설계 결정
- 타이틀은 "웹 기록이 비어 있을 때"만 받는다 - 글 상세 제목이 사이트 이름이 되지 않고, 리다이렉트로 주소가 달라져도 첫 페이지로 인식한다.
- `usableTitle`이 Cloudflare 확인 화면 제목("Just a moment...", "Attention Required")을 거른다 - 확인 화면에서 나가면 그 제목이 사이트 이름으로 남을 수 있어서(계획에 없던 보완).
- 이름이 도메인과 같으면 자동으로 간주 - 이전 버전이 빈 이름을 도메인으로 저장해 둔 사이트도 별도 마이그레이션 없이 페이지 제목을 쓴다.
- 제스처는 `gestureRecognizerShouldBegin`에서 `!canGoBack`일 때만 시작 - 웹 기록이 있을 때 WebKit의 뒤로가기와 겹치지 않는다.
- `reportTitle`은 다음 런루프에서 콜백 - 뷰 갱신 중 `@Published`를 바꾸는 경고를 피한다.

## 진행 기록
- SWT-M1: 순수 함수와 스토어 `pageTitles`를 구현하고 `build/test_site`로 확인 (빈 이름/캐시/도메인 대체, 이전 도메인 이름 자동 처리, 차단 화면 제목 무시, 재실행 유지, 스와이프 기준).
- SWT-M2: 시뮬레이터에서 마지막 사이트를 지정해 다모앙을 열고 `pageTitles`에 `날짜별 공감글 | 다모앙`이 저장됨을 확인. 앱을 다시 실행한 목록에 그 제목이 보이고 나머지 사이트는 도메인으로 보임.
- SWT-M3: 엣지 팬 제스처와 전환 애니메이션을 구현하고 빌드 성공. 제스처는 시뮬레이터에서 보낼 수 없어 실기기 확인이 필요.

## 계획 대비 변경
| 항목 | 계획 | 최종 구현 | 상황과 근본 이유 |
| :--- | :--- | :--- | :--- |
| 타이틀 거르기 | 비어 있지 않은 제목 | 빈 값과 Cloudflare 확인 화면 제목 제외 | Cloudflare를 쓰는 사이트에서 확인 화면을 보다 나가면 "Just a moment..."가 이름으로 남을 수 있다 |

## 검증 결과
- `build/test_site` OK, 시뮬레이터 빌드 성공.
- 시뮬레이터에서 제목 수집, 저장, 재실행 후 목록 반영 확인.
- 미확인: 가장자리 스와이프로 목록 복귀(실기기), 글 상세에서 스와이프가 기존 웹 뒤로가기로 동작하는지, SPA 사이트의 `canGoBack`, 전환 애니메이션의 모양, 글 상세 제목이 사이트 이름을 덮어쓰지 않는지(실기기에서 이동 후 확인).

## 남은 한계
- 스와이프 중 화면이 손가락을 따라오지 않고 손을 뗄 때 전환된다.
- 제목은 사이트를 한 번 열어야 채워진다. 앱을 삭제하고 재설치하면 다시 열기 전까지 도메인으로 보인다 (SWT-Q3).
- 사이트가 첫 페이지 제목을 바꾸면(예: 날짜가 들어간 제목) 열 때마다 갱신된다.
