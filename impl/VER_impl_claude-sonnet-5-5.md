# [VER] 구현 노트

- 계획: plan/VER_plan_claude-sonnet-5-5.md
- 구현 커밋: ce64637

## 아키텍처
| 파일 | 역할 |
| :--- | :--- |
| `cwv/Version.xcconfig` (신규) | `MARKETING_VERSION = 0.1.0`. 버전의 단일 출처 |
| `project.pbxproj` | xcconfig 파일 참조와 메인 그룹 등록, 타깃 Debug/Release의 `baseConfigurationReference`, 기존 `MARKETING_VERSION = 1.0` 두 줄 제거, 빌드 단계 "Stamp build time"(Resources 뒤, `alwaysOutOfDate`, 출력 `BuildTime.txt` 선언) |
| `SiteListView.swift` | 목록 섹션 헤더 `TitleHeader`("커뮤니티" + `VersionLabel`), `navigationTitle` 대신 inline 바. `VersionLabel`은 `CFBundleShortVersionString`과 `BuildTime.txt`를 읽고 탭하면 popover |
| `AGENTS.md`, `.agents/skills/m_plan,m_impl,m_review` | 버전 규칙, 계획의 `버전: A -> B` 줄, 구현 때 올리기, 리뷰 반영은 올리지 않기 |
| `cwv/README.md` | 버전 올리는 방법 |

흐름: `Version.xcconfig` -> 빌드 설정 -> 앱 `Info.plist`. 빌드 단계 -> 번들 `BuildTime.txt` (`yyyy-MM-dd HH:mm`, 맥 로컬 시각). 앱은 둘을 읽어 헤더에 표시.

## 핵심 설계 결정
- 빌드 시각은 `Info.plist`가 아니라 번들 안 별도 파일 - 계획 실험에서 Info.plist 방식은 샌드박스 선언 충돌과 증분 빌드에서 값이 지워지는 문제가 있었다. 출력 파일을 선언해 `ENABLE_USER_SCRIPT_SANDBOXING = YES`를 유지했다.
- 제목 줄은 `List`의 섹션 헤더로 그린다 - 시스템 큰 제목 옆에는 다른 뷰를 놓을 수 없다 (VER-Q1). 첫 행으로 넣으면 첫 사이트 행의 모서리 둥글림이 어긋나서 헤더로 했다. 편집(`onMove/onDelete`)은 `ForEach` 안의 행만 대상이라 영향이 없다.
- 제목 색은 `Color(.label)`로 명시 - 섹션 헤더의 기본 회색 스타일이 `.primary`를 덮어서 제목이 회색으로 나왔다 (시뮬레이터 스크린샷으로 확인).
- 버전/빌드 시각을 못 읽으면 그 부분만 숨긴다 (앱 동작에 영향 없음).

## 진행 기록
- VER-M1: xcconfig/pbxproj/빌드 단계를 실제 프로젝트에 적용. 시뮬레이터 빌드 결과물의 `CFBundleShortVersionString`=0.1.0과 `BuildTime.txt` 확인, 실기기(saibi-iphone16) 서명 빌드 성공(`codesign -v` 통과, `BuildTime.txt` 포함, Team ID는 xcodebuild 인자로만 넘김). pbxproj diff에 `DEVELOPMENT_TEAM` 0건.
- VER-M2: iPhone 15 Pro / iPad Pro 11 시뮬레이터 스크린샷에서 "커뮤니티 v0.1.0"이 제목 오른쪽에 작게 보이고, iPad 사이드바(320pt)에서도 한 줄.
- VER-M3: AGENTS.md 버전 관리 절, m_plan(3-1 단계와 템플릿), m_impl, m_review에 한 줄씩, README. 문자 규칙 검사 통과.

## 계획 대비 변경
| 항목 | 계획 | 최종 구현 | 상황과 근본 이유 |
| :--- | :--- | :--- | :--- |
| 제목 줄 구현 | 목록 맨 위 행 (`listRowInsets` 등) | 섹션 헤더 | 첫 행으로 두면 사이트 행들과 같은 섹션이라 첫 사이트 행의 둥근 모서리가 어긋난다. 헤더는 같은 효과에 레이아웃 부작용이 없다 |
| 제목 색 | (명시 없음) | `Color(.label)` | 헤더 기본 스타일이 회색이라 제목이 흐리게 나왔다 |

## 검증 결과
- 시뮬레이터(iPhone/iPad) 빌드와 스크린샷, 실기기 서명 빌드 성공, 번들 `Info.plist`/`BuildTime.txt` 값 확인, 증분 빌드에서 빌드 시각 갱신(계획 실험 14:16 -> 14:17), 문자 규칙 검사.
- 확인 못함: 버전을 탭했을 때의 말풍선 표시와 글씨 크기(시뮬레이터에서 탭 조작 수단이 없음, 코드와 빌드만 확인), 실기기 설치 후 화면, 스크롤 시 헤더 동작과 편집 모드 순서 변경.
- 테스트 코드: 순수 로직이 없어(문자열 앞에 `v`) 추가하지 않았다 (계획 5절).

## 남은 한계
- 빌드 시각은 맥의 로컬 시각이다 (다른 시간대의 맥에서 빌드하면 그 시각).
- 시스템 큰 제목과 달리 스크롤하면 제목이 위로 사라지고 위쪽 바에는 제목이 없다 (VER-Q1 선택).
