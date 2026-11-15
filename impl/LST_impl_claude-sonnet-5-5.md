# [LST] 구현 노트

- 계획: plan/LST_plan_claude-sonnet-5-5.md
- 구현 커밋: (커밋 후 기재) (리뷰 반영 커밋은 review/LST_refine_*.md)

## 아키텍처
| 파일 | 역할 |
| :--- | :--- |
| `CWV/SiteStore.swift` | 단일 목록 `sites`(UserDefaults `siteList` + Keychain). 첫 실행에만 기본 목록, `reset()`, `replace(with:)`, 이전 형식 마이그레이션 |
| `CWV/Site.swift` | `exportCSV`, `importCSV`(크기/줄 수 검사), `parseDefaultPages` 공통 파서 `parseSites` |
| `CWV/CSVDocument.swift` (신규) | `fileExporter`용 `FileDocument` |
| `CWV/SiteListView.swift` | 구역 없는 목록, 편집 모드 이동/삭제, `...` 메뉴(백업/복원/초기화), 확인창과 알림, `fileExporter`/`fileImporter` |

시작 순서: UserDefaults `siteList` -> Keychain -> 이전 형식(`userData`, 그다음 Keychain의 같은 형식) -> 가장 오래된 `sites` 키 -> 기본 목록으로 최초 생성. 결과를 두 저장소에 다시 쓴다.

## 핵심 설계 결정
- 빈 목록도 정상 저장 상태로 취급 - 전부 지운 뒤 다시 실행해도 기본값이 되살아나지 않는다(키 존재 여부가 아니라 디코딩 성공으로 판단).
- 이전 형식(기본/사용자 분리)은 "기본 항목 + 사용자 항목" 순서로 이어 붙여 화면에 보이던 그대로 옮긴다 - 사용자가 지금 보는 목록이 바뀌지 않게.
- CSV 내보내기에서 주소의 쉼표는 `%2C`로 바꾼다 - "첫 쉼표 앞이 주소" 규칙을 깨지 않으면서 같은 파일을 `default_page.csv`로도 쓸 수 있게.
- 가져오기 파일은 크기(1MB)를 읽기 전에 확인하고, 줄 수(500)/UTF-8/유효 줄 검사를 `importCSV`에 모아 단위 테스트한다 - 외부 파일을 신뢰하지 않는다.

## 진행 기록
- LST-M1: 단일 목록 저장 모델과 마이그레이션, 초기화를 구현. `build/test_site`로 확인 (최초 생성, 재실행 유지, CSV가 달라도 개입 없음, 기본 항목 이동/편집, 전부 삭제 후 유지, 초기화, 재설치 복원, 깨진 저장값, 두 가지 이전 형식).
- LST-M2: 목록 화면을 구역 없이 하나로 바꾸고 메뉴/확인창을 추가. 시뮬레이터 빌드 성공, 첫 실행 스크린샷에서 `default_page.csv`의 기본 목록이 하나의 목록으로 보임.
- LST-M3: `exportCSV`/`importCSV`를 구현. 왕복, 쉼표, 줄바꿈, 건너뛴 줄 수, BOM, 크기/인코딩/줄 수 제한을 테스트.
- LST-M4: `fileExporter`/`fileImporter` 연결은 컴파일까지 확인. iCloud Drive 저장/불러오기는 실기기 확인이 필요.

## 계획 대비 변경
| 항목 | 계획 | 최종 구현 | 상황과 근본 이유 |
| :--- | :--- | :--- | :--- |
| 가장 오래된 `sites` 키 마이그레이션 | 목록을 그대로 사용 | 그대로 사용(이전 PRS의 id 변환/기본 흡수는 제거) | 기본 목록 구분이 없어져 id를 바꿀 이유가 없다 |

## 검증 결과
- `build/test_site` OK, 시뮬레이터 빌드 성공.
- 시뮬레이터에서 앱 삭제 후 설치한 첫 실행 목록이 `default_page.csv` 내용과 같음을 확인. 시뮬레이터 전역 설정에 남아 있던 예전 `sites` 값을 앱이 읽어 가장 오래된 형식의 마이그레이션이 실제로 동작하는 것도 우연히 확인(목록이 그 한 항목).
- 미확인: 편집 모드 이동/삭제 제스처, `...` 메뉴, 파일 앱 저장/불러오기(iCloud Drive), 확인창 모양, 실제 설치본(PRS 형식 데이터)의 마이그레이션 결과 - 실기기에서 확인.

## 남은 한계
- CSV에는 글자 크기와 페이지 제목 캐시가 없다. 복원하면 글자 크기는 100%.
- 주소에 쉼표가 있으면 내보낼 때 `%2C`로 바뀐다 (서버가 같은 주소로 처리하지 않으면 다른 페이지일 수 있음).
- `fileExporter`/`fileImporter`를 한 화면에서 함께 쓰므로 일부 iOS 버전에서 서로 간섭하는지 실기기 확인이 필요하다.
