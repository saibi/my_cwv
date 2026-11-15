# [CWV] 리뷰 반영

## 2026-11-15 review/CWV_review_codex-gpt-6.1-sol.md

| ID | 판단 | 처리 |
| :--- | :--- | :--- |
| CWV-R1 | 타당 (코드 확인: `views.removeAll()`이 표시 중인 SiteWebView를 캐시에서 빼고, WKWebView의 delegate는 약한 참조) | [확정] `WebView.Coordinator`가 표시 중인 SiteWebView를 강하게 보유, makeUIView/updateUIView가 같은 객체를 사용 |
| CWV-R2 | 타당 (WKUIDelegate에 alert/confirm/prompt 없음) | [확정] 세 대화상자 구현 (UIAlertController, 최상단 뷰컨트롤러에 표시) |
| CWV-R3 | 타당 (createWebViewWith가 탐색 종류와 무관하게 외부 host를 Safari로 보냄) | [확정] `opensInSafariSheet(url, base, linkActivated)`를 일반 탐색과 새 창이 함께 쓰도록 하고 단위 검증 추가 |
| CWV-R4 | 타당 (비 http scheme을 사용자 동작과 무관하게 `UIApplication.open`) | [확정] D1 |
| CWV-R5 | 타당 (SiteStore 저장/복원 미검증) | [확정] `test_site.swift`에 격리된 UserDefaults로 추가/수정/삭제/이동/zoom/lastSiteID 저장 후 새 인스턴스 복원 검증 추가. UIKit 캐시는 테스트용 `WebCache` 대체 사용 |

### 결정
- [확정] **D1 (CWV-R4)** 클릭 없는 비 http scheme 이동 -> 결정: 직접 누른 링크만 허용 (추천안. 광고나 삽입 프레임의 몰래 앱 실행을 막는다. 자동 리다이렉트로 앱을 여는 일부 로그인 방식은 동작하지 않을 수 있다)

### 검증
- `swiftc -parse-as-library cwv/CWV/Site.swift cwv/CWV/SiteStore.swift cwv/test_site.swift ...` 실행 시 `test_site: OK`.
- 시뮬레이터 빌드 성공, 실행해 다모앙 웹뷰와 글자 크기(150%) 표시 확인.
- 확인 못함: 메모리 경고 후 동작(R1)과 JS 대화상자(R2)의 실제 동작. 시뮬레이터에서 해당 상황을 만들 도구가 없어 코드 검토까지만 했다. R1/R3의 웹뷰 부분은 macOS에서 테스트할 수 없어 R3의 판정 함수만 단위 검증했다.
