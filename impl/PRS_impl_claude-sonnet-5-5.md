# [PRS] 구현 노트

- 계획: plan/PRS_plan_claude-sonnet-5-5.md
- 구현 커밋: (커밋 후 기재) (리뷰 반영 커밋은 review/PRS_refine_*.md)

## 아키텍처
| 파일 | 역할 |
| :--- | :--- |
| `CWV/default_page.csv` (git 제외), `default_page.csv.example` (견본) | 기본 페이지 목록. 번들 리소스 |
| `CWV/Site.swift` | `parseDefaultPages`, `stableID`, `fallbackSites`(Google), `safariTarget` |
| `CWV/SiteStore.swift` | 기본(`defaultPages`, 읽기 전용) + 사용자(`userSites`) 분리. 저장은 UserDefaults + `KeyValueBackup` |
| `CWV/Backup.swift` | Keychain 구현 (`KeyValueBackup.keychain`) |
| `CWV/SiteListView.swift` | 기본 구역 / "추가한 사이트" 구역 (편집, 삭제, 이동은 추가한 사이트만) |
| `CWV/BrowserView.swift` | `predictedEndTranslation`으로 튕기기, "Safari에서 열기" 항목 |
| `project.pbxproj` | `default_page.csv` 없으면 경고를 내는 Run Script 단계 |

복원 순서: UserDefaults(`userData`) -> Keychain -> 이전 버전의 `sites` 목록(마이그레이션). 시작 때 결과를 두 저장소에 다시 쓴다.

## 핵심 설계 결정
- 기본 사이트 id는 주소에서 만든 고정 UUID - 매 실행 CSV를 새로 읽어도 글자 크기와 마지막 사이트가 유지된다.
- 저장소 접근을 `KeyValueBackup`(closure 두 개)으로 주입 - `test_site`를 Security/UIKit 없이 돌리고, 앱은 `.keychain`을 넘긴다.
- 이전 버전(단일 목록) 데이터 마이그레이션 추가 - 이미 설치된 앱의 사용자 사이트와 글자 크기를 잃지 않으려고(계획에 없던 항목).

## 진행 기록
- PRS-M1: 파서/고정 id/스토어 분리를 구현하고 `build/test_site`로 확인 (정상, BOM, CRLF, 주석, 잘못된 주소, 중복, 제목 쉼표, 제목 없음, 마이그레이션, 재설치 복원).
- PRS-M2: `DragGesture`의 `predictedEndTranslation` 사용으로 변경. 체감은 실기기 확인 필요.
- PRS-M3: macOS에서 Keychain 래퍼 왕복 확인. 시뮬레이터에서 앱 삭제 후 재설치로 추가한 사이트 복원 확인 (임시 시드 코드, 확인 뒤 제거).
- PRS-M4: 메뉴 항목과 `safariTarget`(테스트 통과). 실기기 확인 필요.
- PRS-M5: CSV 있을 때 경고 없음+번들 포함, 없을 때 경고 3줄+빌드 성공+번들 미포함 확인. 앱은 CSV가 없으면 Google 하나.

## 계획 대비 변경
| 항목 | 계획 | 최종 구현 | 상황과 근본 이유 |
| :--- | :--- | :--- | :--- |
| 이전 데이터 | 언급 없음 | `sites` 키 마이그레이션 | 이미 설치된 앱의 저장 형식이 바뀌어 사용자 사이트가 사라질 수 있었다 |
| CSV 위치 | 루트에 둔 파일을 옮김 | `cwv/default_page.csv`에 있던 것을 `cwv/CWV/`로 이동 | 번들되려면 폴더 동기화 그룹(`cwv/CWV/`) 안에 있어야 한다 |

## 검증 결과
- `build/test_site` OK, 시뮬레이터 빌드 성공.
- 서명 없는 시뮬레이터 빌드(`CODE_SIGNING_ALLOWED=NO`)는 Keychain이 `errSecMissingEntitlement(-34018)`로 실패하고 앱은 UserDefaults만 쓴다 (실패해도 동작). ad hoc 서명(`CODE_SIGN_IDENTITY=-`) 빌드에서는 삭제 후 재설치 복원이 동작한다.
- 미확인: 실기기에서 튕기기 체감, Safari에서 열기, 서명된 실기기에서 Keychain 복원, SideStore 재서명 시 복원 여부.

## 남은 한계
- SideStore가 다른 Team ID/번들 ID로 재서명하면 Keychain 복원이 안 될 수 있다.
- 주소에 쉼표가 있는 기본 페이지는 CSV에 쓸 수 없다.
- 버튼 위치와 마지막 사이트는 재설치 후 기본값으로 돌아간다 (PRS-Q3).
