# [VER] 앱 버전 관리와 표시

## 1. 목표
- 앱에 버전을 부여한다. 시작 버전은 `0.1.0`. 버전은 한 파일에서 관리하고, 앞으로 개발 워크플로(m_plan/m_impl)가 규칙대로 올린다.
- 목록 화면의 "커뮤니티" 제목 오른쪽에 작게 `v0.1.0`을 보이고, 탭하면 빌드 시각을 더 작은 글씨로 말풍선(툴팁 형태)에 보인다.
- 범위 밖: 변경 이력(CHANGELOG), git 태그, 자동 배포, 앱 내 업데이트 확인. 빌드 번호(`CURRENT_PROJECT_VERSION`)는 지금처럼 1로 둔다 (VER-Q4).

## 2. 버전 규칙 (사용자 지정, AGENTS.md에 옮긴다)
형식은 `major.minor.patch`.

| 상황 | 올리는 방법 | 누가 |
| :--- | :--- | :--- |
| 1. 사용자가 프롬프트에서 직접 지정 ("1.0.0으로 하자") | 말한 값 그대로. **major는 이 경우에만 바뀐다** | 에이전트가 그대로 적용 |
| 2. m_plan으로 계획을 세워 없던 기능을 추가하거나 있는 기능을 개선 | minor + 1, patch는 0 (예: 0.1.3 -> 0.2.0) | m_plan이 계획 문서에 "버전: A -> B"를 적고, m_impl이 구현 커밋에서 올린다 |
| 3. 앱의 버그 수정 | patch + 1 (예: 0.2.0 -> 0.2.1) | 수정 커밋에서 올린다 |
| 2와 3이 애매함 (버그 수정 같지만 동작을 바꾸는 개선 등) | **사용자에게 묻는다** (선택지 + 추천안, 한 번에 하나) | 에이전트 |

- 이 VER 계획 자체는 규칙 2이지만 **시작 버전 0.1.0을 정하는 일이라 예외**로 minor를 올리지 않는다.
- 버전만 바꾸는 단독 커밋은 만들지 않는다. 버전 변경은 그 기능/수정과 같은 커밋에 넣는다.
- 문서(plan/impl/review)만 바뀌고 앱 동작이 바뀌지 않으면 버전은 그대로다.
- m_review 교차리뷰 반영은 같은 기능의 완성 과정이라 버전을 올리지 않는다 (VER-Q2). 나중에 쓰던 버전의 버그를 고치면 규칙 3이다.

## 3. 전체 흐름
```
cwv/Version.xcconfig  (MARKETING_VERSION = 0.1.0, 버전의 단일 출처)
   -> project.pbxproj 타깃 설정이 참조 -> 앱 Info.plist의 CFBundleShortVersionString
빌드 단계 "Stamp build time" -> 앱 번들 안 BuildTime.txt ("2026-11-21 14:16")
앱: 목록 화면 상단 "커뮤니티 v0.1.0" -> 탭하면 popover로 빌드 시각
```

## 4. 단계별 상세
### 1) 버전 저장 (VER-Q3)
- 전제 확인(2026-11-21, 복사본 프로젝트로 실험): `cwv/Version.xcconfig`에 `MARKETING_VERSION = 0.1.0`을 두고 타깃 Debug/Release가 `baseConfigurationReference`로 참조하게 하면(`project.pbxproj`의 타깃 설정에서 `MARKETING_VERSION` 줄 제거), 빌드된 앱의 `CFBundleShortVersionString`이 `0.1.0`이 된다. 이제 버전을 올릴 때는 이 파일 한 줄만 고치면 되고 `project.pbxproj`를 건드리지 않는다 (pbxproj에는 커밋하면 안 되는 로컬 Team ID 변경이 섞이기 쉽다).
- `pbxproj` 수정: PBXFileReference(`Version.xcconfig`, `lastKnownFileType = text.xcconfig`)와 메인 그룹 children 추가, 타깃 Debug/Release에 `baseConfigurationReference`, 두 설정의 `MARKETING_VERSION = 1.0;` 제거.

### 2) 빌드 시각 (VER-Q4)
- 빌드 단계(Shell Script) "Stamp build time"을 Resources 단계 뒤에 추가한다. `alwaysOutOfDate = 1`(기존 "Check default_page.csv"와 같음), 출력 파일 선언 `$(TARGET_BUILD_DIR)/$(UNLOCALIZED_RESOURCES_FOLDER_PATH)/BuildTime.txt`, 스크립트 `date '+%Y-%m-%d %H:%M' > "${SCRIPT_OUTPUT_FILE_0}"`. 맥의 로컬 시각(분 단위)을 쓴다.
- 전제 확인(2026-11-21, 같은 실험): 이 방식은 `ENABLE_USER_SCRIPT_SANDBOXING = YES`(프로젝트 설정)를 그대로 둔 채 동작하고, 소스를 바꾸지 않은 증분 빌드를 1분 뒤 다시 해도 시각이 갱신된다 (14:16 -> 14:17).
- 시도했다가 버린 방법: (a) 스크립트가 산출물 `Info.plist`에 키를 넣기 - 입력과 출력을 같은 파일로 선언하면 빌드 시스템이 거부하고(`mutable output but no other virtual output node`), 선언 없이(샌드박스 끔) 하면 증분 빌드에서 Info.plist 재생성이 스크립트 뒤에 일어나 키가 사라진다. (b) 실행 파일의 파일 날짜를 앱에서 읽기 - 기기에 설치될 때 날짜가 설치 시각으로 바뀔 수 있어 믿을 수 없다 (실기기 확인 없이 채택하지 않음).
- 앱: `Bundle.main.url(forResource: "BuildTime", withExtension: "txt")`의 내용을 읽는다. 파일이 없거나 비어 있으면 빌드 시각 줄을 보이지 않는다 (버전은 보인다).

### 3) 화면 표시 (VER-Q1, Q5)
- 버전 문자열: `Bundle.main.infoDictionary?["CFBundleShortVersionString"]` 앞에 `v`. 못 읽으면 표시하지 않는다.
- 위치와 모양(VER-Q1): 위쪽 바는 `.navigationBarTitleDisplayMode(.inline)`에 제목 없이 버튼만 두고, 목록 맨 위 행(`listRowInsets`/배경 없음, 선택/스와이프 대상 아님)에 `HStack(alignment: .firstTextBaseline) { Text("커뮤니티").font(.largeTitle.bold()); 버전 }`을 둔다. 이 제목 행 때문에 빈 목록 안내(`overlay`)와 `onMove/onDelete`(ForEach 안의 행만 대상)가 어긋나지 않는지 시뮬레이터로 확인한다. 버전은 `.caption`(12pt), 빌드 시각은 그보다 작은 10pt, 둘 다 `.secondary`.
- 빌드 시각은 버전 텍스트를 탭하면 뜨는 말풍선(`.popover` + `presentationCompactAdaptation(.popover)`, iPhone에서도 시트가 아니라 말풍선, 다른 곳을 탭하면 닫힘) 안에 보인다 (VER-Q5). iOS에는 마우스 호버 툴팁이 없어 말풍선으로 대신한다.
- iPad 분할 화면의 사이드바(최소 240pt)에서도 제목과 버전이 한 줄에 들어가는지 시뮬레이터로 확인한다.

### 4) 규칙을 워크플로에 기록 (VER-Q6)
- `AGENTS.md`에 "버전 관리" 절을 추가한다: 위 2절 표, 버전 파일 위치(`cwv/Version.xcconfig`), 올리는 시점(기능/수정 커밋에 함께), 리뷰 반영은 올리지 않음.
- `.agents/skills/m_plan/SKILL.md`: 작성 절차에 "이 계획이 올릴 버전을 규칙 2로 계산해 계획 문서 1절에 `- 버전: A -> B`로 적는다. 버그 수정과 개선이 애매하면 결정 사항으로 묻는다"를 한 줄 추가. 템플릿 1절에 그 줄을 넣는다.
- `.agents/skills/m_review/SKILL.md`: 개선 절차에 "리뷰 반영은 버전을 올리지 않는다 (AGENTS.md 버전 관리)"를 한 줄 추가.
- `.agents/skills/m_impl/SKILL.md`: 마무리 절차에 "계획에 적힌 버전으로 `cwv/Version.xcconfig`를 올리고 같은 커밋에 넣는다. 구현 노트에 기록"을 한 줄 추가.
- 새로 만드는 스크립트는 없다 (한 줄 수정이라 손으로 고친다).

## 5. 구현 구조
- 새 파일: `cwv/Version.xcconfig`. 수정: `project.pbxproj`(위 1, 2단계, Team ID 줄은 커밋하지 않는다), `SiteListView.swift`(제목 영역과 버전 말풍선), `AGENTS.md`, `.agents/skills/m_plan/SKILL.md`, `.agents/skills/m_impl/SKILL.md`, `.agents/skills/m_review/SKILL.md`, `cwv/README.md`(버전 올리는 방법 한 줄).
- 순수 로직이 거의 없어 (문자열 앞에 `v`) 별도 테스트 코드는 만들지 않는다. 검증은 빌드 결과물의 `Info.plist`/`BuildTime.txt`와 화면으로 한다.
- 새 의존성 없음.

## 6. 결정 사항
- **VER-Q1** 버전을 보이는 위치와 방식 - [확정] (a) 제목 줄을 목록 맨 위에 직접 그린다 (추천안 선택): "커뮤니티"를 지금 큰 제목과 같은 크기/굵기로 그리고 바로 오른쪽에 작은 `v0.1.0`. 위쪽 바에는 버튼만 남고, 스크롤하면 제목이 목록과 함께 올라간다 (작은 제목으로 접히지 않음). 기각: (b) 위쪽 바 가운데 한 줄 (c) 목록 맨 아래에 작게
- **VER-Q2** m_review 교차리뷰 반영 수정의 버전 처리 - [확정] (a) 올리지 않음 (추천안 선택). 리뷰 반영은 같은 기능의 완성 과정이라 그 기능이 올린 minor에 포함한다. 단, 이미 설치/배포해 쓰는 중인 버전의 버그를 나중에 고치는 경우는 규칙 3(patch)이다. 기각: (b) 반영 커밋마다 patch (c) 리뷰 1회에 patch 1
- **VER-Q3** 버전의 단일 출처 - [확정(기본값)] `cwv/Version.xcconfig`. 실험으로 동작을 확인했고, 올릴 때 pbxproj를 건드리지 않는다. 기각: `project.pbxproj`의 `MARKETING_VERSION`(Debug/Release 두 곳을 같이 고쳐야 하고 pbxproj가 로컬 Team ID와 섞인다).
- **VER-Q4** 빌드 시각을 앱에 넣는 방법과 빌드 번호 - [확정(기본값)] 번들 안 `BuildTime.txt`(로컬 시각, `yyyy-MM-dd HH:mm`). 빌드 번호(`CURRENT_PROJECT_VERSION`)는 1 그대로 (표시하지 않고, 빌드 시각이 빌드를 구분한다). 필요하면 바꾼다.
- **VER-Q5** "툴팁"의 구현 - [확정(기본값)] 버전 탭 -> popover 말풍선 (iOS에 호버 툴팁이 없음).
- **VER-Q6** 규칙을 기록할 곳 - [확정(기본값)] `AGENTS.md`(공통 지침) + m_plan/m_impl/m_review 스킬에 한 줄씩. 에이전트가 달라도(claude/codex/agy) 같은 규칙을 따른다.

## 7. 마일스톤
| # | 내용 | 완료 기준 |
| :--- | :--- | :--- |
| VER-M1 | `Version.xcconfig`, pbxproj 연결, 빌드 시각 단계 | 시뮬레이터 빌드 후 `Info.plist`의 `CFBundleShortVersionString` = 0.1.0, 앱 번들의 `BuildTime.txt`가 빌드 시각, 소스 변경 없는 재빌드에서 시각 갱신, 실기기 빌드(서명)도 성공, 커밋에 Team ID 없음 |
| VER-M2 | 목록 화면 표시 | iPhone/iPad 시뮬레이터 스크린샷에서 제목 오른쪽 버전, 탭하면 더 작은 빌드 시각 말풍선, iPad 사이드바 폭에서도 한 줄 |
| VER-M3 | 규칙 문서화 | AGENTS.md와 세 스킬(m_plan/m_impl/m_review)에 규칙이 있고 문자 규칙 검사 통과, `plan/README.md`에 VER 행 |
