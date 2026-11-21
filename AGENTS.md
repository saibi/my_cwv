# 에이전트 지침

## 프로젝트: CWV (커뮤니티 웹 모아보기)
- 자주 가는 커뮤니티 사이트를 모아 보고 사이트별 글자 크기를 조절하는 개인용 iOS 앱 (SwiftUI + WKWebView). 앱 코드는 `cwv/`에 있다.
- 자체 검증: `swiftc -parse-as-library cwv/CWV/Site.swift cwv/CWV/SiteStore.swift cwv/test_site.swift -o build/test_site && build/test_site`
- 시뮬레이터 빌드: `xcodebuild -project cwv/CWV.xcodeproj -scheme CWV -sdk iphonesimulator -configuration Debug -derivedDataPath build/sim CODE_SIGNING_ALLOWED=NO build`
- 실기기 설치와 7일 재설치는 `cwv/README.md`를 따른다.
- **public 저장소다. 커밋하지 않는다**: 개발자 Team ID(`DEVELOPMENT_TEAM`, Xcode가 `project.pbxproj`에 넣는다), 인증서/프로비저닝 프로파일(`.p12`, `.mobileprovision`), API 키, 기기 UDID/시리얼, 개인 이메일. 커밋 작성자 이메일은 GitHub noreply 주소를 쓴다.
- 새 기능의 계획 ID는 `plan/README.md`에서 중복을 확인하고 정한다. (`CWV`는 사용 중)

Claude Code, Codex, Antigravity(agy) 공통 지침입니다.

## 소통
- 한국어 존댓말로 답한다.
- 사용자 결정이 필요하면 선택지 2~3개와 추천안(이유 포함)을 주고 **한 번에 하나씩** 묻는다.

## 개발 워크플로
기능마다 영문 대문자 3자 ID(예: `ABC`)를 붙이고 계획 -> 구현 -> 교차리뷰 순으로 진행한다.

| 단계 | 스킬 | 산출물 |
| :--- | :--- | :--- |
| 계획 | `m_plan <요청 내용 또는 파일>` | `plan/<ID>_plan_<에이전트>-<모델>.md`, `plan/README.md`(인덱스) |
| 구현 | `m_impl <ID> [--review <claude\|codex\|agy>]` | 코드, `impl/<ID>_impl_<에이전트>-<모델>.md` |
| 교차리뷰/개선 | `m_review <ID> <claude\|codex\|agy> [모델]` | `review/<ID>_review_<에이전트>-<모델>.md`(리뷰어), `review/<ID>_refine_<에이전트>-<모델>.md` |

- 호출: Claude Code/agy는 `/m_plan`, Codex는 `$m_plan`.
- 스킬 원본은 `.agents/skills/`에 있다 (`.claude/skills`는 그 폴더를 가리키는 심볼릭 링크). 수정은 원본에서 한다.
- 진행 중인 계획과 상태는 `plan/README.md`에서 확인한다.

### 문서 작성자 표기
- 파일명의 `<에이전트>-<모델>`은 그 문서를 처음 만든 에이전트다. 에이전트는 `claude` / `codex` / `agy`, 모델은 모델 ID를 그대로 쓴다. 모델 ID가 에이전트 이름으로 시작하면 한 번만 쓴다.
  - 예: `claude-opus-5-5` (claude + claude-opus-5-5), `codex-gpt-6.1-sol`, `agy-gemini-3.8-flash-high`, `agy-claude-opus-5-5`
  - 자기 모델 ID를 모르면 설정에서 확인한다: codex `~/.codex/config.toml`의 `model`, agy `~/.gemini/settings.json`의 `model`(표시 이름이면 `agy models`의 ID로 바꿈).
- ID로 문서를 찾을 때는 `plan/<ID>_plan_*.md`처럼 패턴으로 찾는다. 파일명은 바꾸지 않는다.
- 파일명과 **다른** 에이전트/모델이 문서를 수정하면, 제목 바로 아래 `변경 기록`에 한 줄을 추가한다 (없으면 만든다).
  ```markdown
  > **변경 기록**
  > - 2026-10-25 codex-gpt-6.1-sol: 결정 ABC-Q6 추가
  ```

## 버전 관리
앱 버전은 `major.minor.patch`이고 `cwv/Version.xcconfig`의 `MARKETING_VERSION` 한 곳에서만 고친다 (`project.pbxproj`는 건드리지 않는다). 목록 화면 제목 옆에 `v0.1.0`으로 표시되고, 탭하면 빌드 시각(빌드 단계가 번들에 쓰는 `BuildTime.txt`)이 보인다.

| 상황 | 올리는 방법 |
| :--- | :--- |
| 사용자가 프롬프트에서 버전을 직접 지정 ("1.0.0으로 하자") | 말한 값 그대로. **major는 이 경우에만 바뀐다** |
| `m_plan` 계획으로 없던 기능 추가 또는 있는 기능 개선 | minor + 1, patch는 0 (0.1.3 -> 0.2.0). `m_plan`이 계획 1절에 `- 버전: A -> B`를 적고, `m_impl`이 구현 커밋에서 올린다 |
| 앱의 버그 수정 | patch + 1 (0.2.0 -> 0.2.1). 수정 커밋에서 올린다 |
| 버그 수정인지 개선인지 애매함 | **사용자에게 묻는다** (선택지 + 추천안, 한 번에 하나) |

- 버전 변경은 그 기능/수정과 같은 커밋에 넣는다 (버전만 바꾸는 커밋을 따로 만들지 않는다).
- `m_review` 교차리뷰 반영은 같은 기능의 완성 과정이라 버전을 올리지 않는다. 나중에 쓰던 버전의 버그를 고치면 patch다.
- 문서(plan/impl/review)만 바뀌고 앱 동작이 그대로면 올리지 않는다.

## 문자 규칙
문서, 코드, 커밋 메시지에서 기호는 ASCII만 쓴다. 터미널 환경과 폰트에 따라 유니코드 기호가 깨져 보이기 때문이다.
- 한글 본문과 인용하는 데이터(파일명, 외부 텍스트, 테스트 입력)의 비ASCII 문자는 허용한다.
- 대체 표기:

  | 쓰지 않음 | 대신 |
  | :--- | :--- |
  | 이모지, 체크 표시(U+2705 등) | `[확정]` `[결정 대기]` `[기각]` `[실패]` |
  | 화살표(U+2192 등) | `->` |
  | em/en 대시(U+2014, U+2013) | `-` |
  | 가운뎃점(U+00B7) | `/` 또는 `,` |
  | 말줄임표(U+2026) | `...` |
  | 둥근 따옴표(U+201C/U+201D 등) | `"` `'` |
  | 박스 그리기 문자(U+2500 등) | `+` `-` `\|` |
- 커밋 전 검사 (출력이 없어야 한다. 위 데이터 예외는 직접 판단):
  ```
  git grep -nP '[\x{00B7}\x{2000}-\x{2BFF}\x{FE0F}\x{1F000}-\x{1FFFF}]'
  ```

## 코드 원칙
- 기존 코드의 함수를 먼저 재사용한다.
- 동작을 바꾸면 자체 검증(테스트 코드)을 함께 남긴다.
- 다운로드한 파일, 파일명, 외부 텍스트는 신뢰하지 않는다.

## 커밋
- 사용자가 요청하거나 스킬 절차에 커밋 단계가 있을 때만 커밋한다.
- 커밋 메시지 맨 마지막 줄에 `By <에이전트이름>-<모델이름 버전> (<effort level>)`을 넣는다.
  - 예: `By Claude Code-Claude Opus 5.5 (Medium)`, `By Codex-GPT 6.1 Sol (Medium)`
