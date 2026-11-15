# [UXP] 리뷰 반영

## 2026-11-15 review/UXP_review_codex-gpt-6.1-sol.md

| ID | 판단 | 처리 |
| :--- | :--- | :--- |
| UXP-R1 | 타당 (adblock.json 정규식에 호스트 경계가 없음을 코드로 확인) | [확정] url-filter를 `^https?://([a-z0-9-]+\.)*<도메인>[:/]`로 고정, 일치/불일치 사례 8개를 test_site에 추가 |
| UXP-R2 | 타당 (글리프에 접근성 이름이 없음) | [확정] Menu에 `.accessibilityLabel("글자 크기 및 목록 메뉴")` 추가 |
| UXP-R3 | 일부 타당 (테스트가 키 존재만 봄. 제스처/재실행 복원/로그인은 GUI 없이 검증 불가) | [확정] WebKit 규칙 컴파일(macOS 일회성 스크립트)과 시뮬레이터 로드로 보강. 제스처, 재실행 복원, 로그인은 [결정 대기 아님] 실기기 확인 항목으로 남기고 impl 노트에 한계 기록 |
| UXP-R4 | 타당 (README가 magick에 의존) | [확정] make_icon.swift가 알파 없는 CGContext로 직접 저장, README에서 magick 제거. 기존 PNG와 픽셀 동일(compare 0) |

### 검증
- `build/test_site` OK (R1 회귀 케이스 포함).
- 수정한 adblock.json이 macOS WebKit에서 `compile OK`.
- 시뮬레이터 빌드 성공, 스크린샷에서 광고 영역 비어 있고 본문 정상 로드.
- 아이콘 재생성 결과: 1024x1024, 알파 없음, 기존 icon.png와 동일.
- 미확인: 드래그와 메뉴 탭의 공존, 재실행 후 위치 복원, VoiceOver, 대상 사이트 로그인.
