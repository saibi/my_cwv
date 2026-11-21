# [SNS] 조이스틱 감도 설정

## 1. 목표
- 옵션 화면에서 플로팅 버튼 조이스틱의 감도를 슬라이더 하나로 바꾼다. 지금은 거리 기준이 상수(최소 이동 약 0.3cm = iPhone 18pt / iPad 16pt, 모서리 이동 약 1.5cm = iPhone 90pt / iPad 78pt)라 값을 바꿔 보려면 매번 빌드와 재설치(7일마다 하는 그 재설치)를 해야 한다. 기기와 손 크기마다 맞는 값도 다르다.
- 모서리 이동 기준은 최소 이동의 5배로 같이 따라간다 (슬라이더는 하나).
- 범위 밖 (제외하기로 함): 방향별 감도, 탭 판정(8pt) 조절, 숫자 직접 입력, 옵션 안 연습 영역.
- 버전: 0.2.2 -> 0.3.0 (규칙 2: 새 설정 기능 추가)

## 2. 전체 흐름
```
옵션 화면 "조이스틱" 섹션: 슬라이더(0.2 ~ 1.0cm, 0.05 단위) + "기본값으로"
   -> @AppStorage("joystickCm") (기기별, 기본 0.3)
BrowserView: joystickCm -> joystickDistance(isPad:cm:), fabMoveDistance(isPad:cm:), fabMargin(...)
   (같은 순수 함수에 cm를 넘기는 것이 전부. 기본값 0.3cm에서는 지금 상수와 정확히 같은 값이 나온다)
```

## 3. 단계별 상세
### 1) 거리 계산 (Site.swift, 순수 함수, 테스트 대상)
- 단위는 cm로 저장한다 (기기마다 pt가 달라서 pt가 아니라 cm가 설정의 의미를 보존한다). cm에서 pt로의 환산은 기존 근사값(JOY-Q3): 1cm = iPhone 60pt, iPad 52pt.
- 상수: `joystickCmRange = 0.2...1.0`, `joystickCmStep = 0.05`, `defaultJoystickCm = 0.3`, `joystickCmKey = "joystickCm"`.
- `clampJoystickCm(_ cm: Double) -> Double`: NaN/무한대는 기본값, 범위로 자르고 0.05 단위로 반올림 (`(cm * 20).rounded() / 20`). 저장된 값이 깨졌거나 범위 밖이어도 안전하게 쓰기 위해 읽을 때마다 거친다.
- `joystickDistance(isPad:cm:)` = `(clampJoystickCm(cm) * ptPerCm).rounded()`, `fabMoveDistance(isPad:cm:)` = `(clampJoystickCm(cm) * 5 * ptPerCm).rounded()`. `cm` 기본 인자는 `defaultJoystickCm`이라 기존 호출과 테스트가 그대로 동작한다.
- 확인한 사실(2026-11-21, 계산): 기본 0.3cm에서 iPhone 18/90pt, iPad 16/78pt로 지금 상수와 일치한다 (0.3 x 52 = 15.6 -> 16, 0.3 x 5 x 52 = 78). 범위 양끝은 0.2cm = iPhone 12pt / iPad 10pt, 1.0cm = 60/52pt (모서리 이동은 300/260pt). 가장 민감한 값도 탭 판정(8pt)보다 크다 (iPad 10pt).

### 2) 저장과 적용 (BrowserView.swift)
- `@AppStorage(joystickCmKey) private var joystickCm = defaultJoystickCm`. 값이 바뀌면 뷰가 다시 그려지므로 슬라이더를 움직이는 즉시 새 버튼에 반영된다 (앱을 다시 켤 필요 없음).
- `joystick`, 모서리 이동 거리, `margin`(= `fabMargin(joystick:fab:)`)이 모두 `joystickCm`에서 나온다. 감도를 둔하게(큰 cm) 하면 버튼이 끝에서 더 안쪽으로 들어온다 (끝쪽 방향으로 끌 공간 확보, JOY-R1과 같은 이유. SNS-Q6).

### 3) 옵션 화면 (SettingsView.swift)
- 새 `Section("조이스틱")` (iPhone과 iPad 모두): `Slider(value:in:step:)`에 왼쪽 "민감" / 오른쪽 "둔감" 라벨, 현재 값 `0.30cm` 표시, "기본값으로 (0.3cm)" 버튼 (기본값이면 비활성). 푸터: "버튼을 누른 채 이 거리 이상 끌었다 놓으면 뒤로/앞으로/글자 크기가 동작합니다. 모서리 이동은 5배 거리입니다. 기기마다 따로 저장됩니다."
- 슬라이더의 값은 `clampJoystickCm`을 거치는 `Binding`으로 쓴다 (이상한 값이 저장되지 않게).

### 4) 백업과 동기화
- CSV 백업에는 넣지 않는다 (SNS-Q3). 기기마다 화면 밀도와 손 크기가 달라 같은 값이 맞지 않는다. 사이드바 설정(SPL)과 달리 iPad 한정도 아니라 백업 헤더에 넣기 애매하다.

## 4. 공통 모듈
- 거리 계산은 `Site.swift`의 순수 함수에 모은다 (JOY의 `fabAction`, `fabMargin`과 같은 곳). 새 파일 없음.

## 5. 구현 구조
- 수정: `Site.swift`(상수, `clampJoystickCm`, `joystickDistance`/`fabMoveDistance`에 cm 인자), `test_site.swift`, `BrowserView.swift`(@AppStorage 연결), `SettingsView.swift`(조이스틱 섹션), `cwv/Version.xcconfig`(0.3.0), `cwv/README.md`.
- 재사용: 기존 `fabAction`, `fabMargin`, `FabCorner`. 새 의존성 없음.

## 6. 결정 사항
- **SNS-Q1** 슬라이더 범위와 눈금 - [확정] 0.2 ~ 1.0cm, 0.05cm 단위, 기본 0.3cm (사용자가 제안 범위를 승인).
- **SNS-Q2** 모서리 이동 기준 - [확정] 최소 이동의 5배로 자동 (슬라이더 하나, 지금 0.3cm:1.5cm 비율).
- **SNS-Q3** 저장 - [확정] 기기별 `@AppStorage`, CSV 백업에는 넣지 않는다.
- **SNS-Q4** 제외 - [확정] 방향별 감도, 탭 판정 조절, 숫자 직접 입력, 옵션 안 연습 영역은 넣지 않는다.
- **SNS-Q5** 설정 위치 - [확정(기본값)] 옵션 화면의 새 "조이스틱" 섹션, iPhone과 iPad 모두 표시.
- **SNS-Q6** 버튼 여백 - [변경 2026-11-21 리뷰 SNS-R1: 여백 = 조이스틱 거리(최소 16pt), 버튼 안 어디를 잡아도 끝쪽 방향 거리가 확보되도록] [확정(기본값), 당시] 감도(cm)를 따라간다 (`fabMargin`). 둔감하게 할수록 버튼이 끝에서 안쪽으로 들어온다. 기각: 최대값(1cm) 기준으로 고정 (기본값 0.3cm에서 버튼이 쓸데없이 안쪽에 놓임).

## 7. 마일스톤
| # | 내용 | 완료 기준 |
| :--- | :--- | :--- |
| SNS-M1 | 순수 함수 (`clampJoystickCm`, cm 인자 거리 함수) | `build/test_site` 통과: 기본값에서 기존 상수와 동일(18/90, 16/78), 범위 양끝(12/10pt, 60/52pt), 선형 증가, NaN/범위 밖/0.05 단위 처리, `fabMargin` 불변식(중심에서 끝까지 거리 >= 조이스틱 거리 + 16pt)이 범위 전체에서 유지 |
| SNS-M2 | 옵션 슬라이더, BrowserView 연결 | iPhone/iPad 시뮬레이터 빌드 성공, 옵션 화면 스크린샷 (슬라이더, 현재 cm 표시, 기본값 버튼) |
| SNS-M3 | 실기기 확인 | 슬라이더를 움직이면 앱 재시작 없이 조이스틱 민감도가 바뀌고, 0.2cm와 1.0cm 양끝에서도 네 방향이 동작, 둔감하게 할 때 버튼이 안쪽으로 들어와도 모든 방향이 닿는지 |
