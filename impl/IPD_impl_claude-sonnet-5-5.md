# [IPD] 구현 노트

- 계획: plan/IPD_plan_claude-sonnet-5-5.md
- 구현 커밋: (커밋 후 기재)

## 아키텍처
| 파일 | 역할 |
| :--- | :--- |
| `project.pbxproj` | `TARGETED_DEVICE_FAMILY = "1,2"`, iPad 방향 4개 (별도 커밋, Team ID 제외) |
| `Site.swift` | `Site.desktop`(하위 호환 디코딩), `customUserAgent(desktop:)`, `CSVDevice`, `backupFileName`, `csvDevice(...)`(헤더/파일 이름), `withoutDesktop`, CSV v3 (4번째 칸 m/d, `# device:` 헤더) |
| `SiteStore.swift` | `add(desktop:)`, `setDesktop`, `exportCSV(device:)` |
| `WebView.swift` | `SiteWebView(desktop:)`: 생성 때 `customUserAgent`, `apply(desktop:)`가 바뀌면 UA 교체 후 reload, `decidePolicyFor(preferences:)`에서 `preferredContentMode` 지정 |
| `BrowserView.swift` | 웹 메뉴의 "데스크톱/모바일 사이트로 보기" |
| `SiteListView.swift` | 편집 시트 토글, 목록 폭 700pt 제한, 백업 파일 이름/헤더, 다른 기기 백업 복원 선택지 |

## 핵심 설계 결정
- `Site`에 `init(from:)`을 직접 작성해 `desktop` 키가 없는 이전 저장본을 읽는다 - 키가 없다고 디코딩이 실패하면 목록과 Keychain 백업 복원까지 모두 실패해 목록이 사라진다.
- 기기 표시는 파일 안 `# device:` 헤더가 우선이고 파일 이름 끝(`-ipad`)은 보조 - 파일 이름은 바뀌거나 외부에서 올 수 있다. 값은 `ipad`/`iphone`만 인정한다.
- UA는 데스크톱일 때만 `customUserAgent`를 주고 모바일은 nil(설정의 기본 UA) - 지금까지의 모바일 동작을 그대로 둔다. 콘텐츠 모드는 `decidePolicyFor`에서 사이트 설정으로 항상 지정한다 (iPad의 기본 .recommended가 데스크톱이라 모바일 지정이 필요).

## 진행 기록
- IPD-M1: 패밀리/방향 변경을 Team ID 없이 커밋 (`git show`에서 `DEVELOPMENT_TEAM` 0건). iPad Pro 11 시뮬레이터에서 호환 모드 없이 전체 화면 실행 확인 (스크린샷).
- IPD-M2: 필드/하위 호환 디코딩/UA/CSV v3/기기 표시를 `build/test_site`에 검증 추가, 통과. UI(토글, 복원 선택지, 폭 제한)는 iPhone/iPad 시뮬레이터 빌드 성공, iPad 스크린샷에서 목록 폭 제한 확인.

## 계획 대비 변경
| 항목 | 계획 | 최종 구현 | 상황과 근본 이유 |
| :--- | :--- | :--- | :--- |
| 필드 이름 | `padDesktop` -> `desktop` | `desktop` | IPD-Q4를 "모든 기기"로 확정하면서 계획에서 이미 바꿨고, 구현도 따름 |
| 복원 선택지 표시 조건 | 기기가 다르면 | 기기가 다르고 데스크톱 사이트가 하나라도 있을 때 | 데스크톱 설정이 없으면 고를 내용이 없어서 단일 확인창을 유지 |

## 검증 결과
- `build/test_site` 통과, iPhone/iPad 시뮬레이터 빌드 성공, iPad 시뮬레이터 스크린샷(세로)에서 전체 화면과 목록 폭 확인.
- 확인 못함 (실기기 필요): 데스크톱/모바일 전환 때 실제 UA와 레이아웃, 회전과 분할 화면, 가장자리 스와이프 복귀, iPad에서 확인창/파일 선택기 표시, iCloud 경유 백업/복원.

## 남은 한계
- 데스크톱 모드에서도 글자 크기(text-size-adjust)는 모바일 값 기준이라 사이트에 따라 효과가 다를 수 있다.
- 기기 표시는 백업을 만든 기기 정보일 뿐 설정이 그 기기용인지는 알 수 없다. 사용자가 선택지로 판단한다.
