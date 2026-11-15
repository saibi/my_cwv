#!/bin/sh
# 7일마다 재설치: 아이폰을 USB로 연결하고 잠금을 푼 뒤 `sh cwv/reinstall.sh`.
# 연결된 실기기를 자동으로 찾는다 (여러 대면 첫 번째). 특정 기기는 `sh cwv/reinstall.sh <UDID>`.
# 덮어쓰기 설치라 사이트 목록과 설정은 유지된다. Xcode Signing에서 Team을 한 번 지정해 두어야 한다.
set -e
cd "$(dirname "$0")/.."

[ -f cwv/CWV/default_page.csv ] || echo "경고: cwv/CWV/default_page.csv 가 없습니다 (cwv/README.md의 '기본 페이지 파일' 참고). 기본 페이지는 Google 하나가 됩니다."

DEVICE="$1"
if [ -z "$DEVICE" ]; then
  TMP=$(mktemp)
  xcrun devicectl list devices --json-output "$TMP" >/dev/null 2>&1 || true
  DEVICE=$(python3 -I - "$TMP" <<'PY'
import json, sys
try:
    devs = json.load(open(sys.argv[1]))["result"]["devices"]
except Exception:
    devs = []
for d in devs:
    if d["hardwareProperties"].get("reality") == "physical" and d["connectionProperties"].get("tunnelState") == "connected":
        print(d["hardwareProperties"]["udid"])
        break
PY
)
  rm -f "$TMP"
fi
[ -n "$DEVICE" ] || { echo "연결된 아이폰이 없습니다. USB로 연결하고 잠금을 푼 뒤 다시 실행하세요."; exit 1; }

mkdir -p build
LOG=build/reinstall.log
echo "빌드 중... (처음이면 몇 분, 서명 단계에서 키체인 허용 창이 뜨면 허용하세요)"
xcodebuild -project cwv/CWV.xcodeproj -scheme CWV -configuration Debug \
  -destination "id=$DEVICE" -derivedDataPath build/dev -allowProvisioningUpdates build >"$LOG" 2>&1 \
  || { tail -20 "$LOG"; echo "빌드 실패 (전체 로그: $LOG)"; exit 1; }
grep -E "warning: cwv/CWV/default_page" "$LOG" | sort -u || true
echo "설치 중..."
xcrun devicectl device install app --device "$DEVICE" build/dev/Build/Products/Debug-iphoneos/CWV.app >>"$LOG" 2>&1 \
  || { tail -20 "$LOG"; echo "설치 실패 (아이폰 잠금을 풀고 신뢰 상태를 확인하세요)"; exit 1; }
echo "완료: 앱을 열어 확인하세요."
