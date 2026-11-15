# [PRS] 리뷰 반영

## 2026-11-15 review/PRS_review_codex-gpt-6.1-sol.md

| ID | 판단 | 처리 |
| :--- | :--- | :--- |
| PRS-R1 | 타당 (삭제 후 추가라 중간 실패 시 기존 백업 유실, 코드로 확인) | [확정] `SecItemUpdate`로 갱신하고 `errSecItemNotFound`일 때만 추가. macOS에서 추가/갱신 두 경로 실행 확인 |
| PRS-R2 | 타당 (`userData`가 있으면 Keychain을 읽지 않고, 마지막 `save()`가 정상 백업을 덮어씀) | [확정] 두 저장소를 각각 디코딩해 UserDefaults 실패 시 Keychain을 시도. 깨진 `userData` + 정상 백업 회귀 테스트 추가 |
| PRS-R3 | 타당 (메모리 경고가 캐시를 비우면 `WebCache.view(for:)`가 새 웹뷰를 만들어 기본 주소가 열림) | [확정] 메모리 경고 때 화면에 붙어 있는 웹뷰(`web.window != nil`)는 캐시에 남긴다. 시뮬레이터에서 메모리 경고 후 동작은 재현하지 못함 (아래 검증) |
| PRS-R4 | 타당 (마이그레이션이 `lastSiteID`의 옛 임의 id를 새 고정 id로 바꾸지 않음) | [확정] 옛 목록에서 마지막 사이트를 찾아 기본 사이트로 흡수되면 새 id로 변환. 마이그레이션 테스트에 `lastSiteID` 검증 추가 |

### 검증
- `build/test_site` OK (R2, R4 케이스 포함), 시뮬레이터 빌드 성공.
- macOS에서 Keychain 래퍼가 추가와 갱신을 모두 통과.
- 미확인: 메모리 경고 상황의 Safari에서 열기 (R3는 코드 변경만 확인), 실기기 동작.
