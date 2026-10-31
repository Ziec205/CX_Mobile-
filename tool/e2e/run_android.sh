#!/bin/bash
# Chạy trong máy ảo Android (CI): integration test + chụp thanh thông báo hệ thống khi app báo "CX_SHADE_NOW".
set -u
OUT=${SHOTS_DIR:-build/shots}
mkdir -p "$OUT"
LOG=/tmp/drive.log
: > "$LOG"
(
  tail -F "$LOG" 2>/dev/null | while read -r line; do
    case "$line" in
      *CX_SHADE_NOW*)
        sleep 3
        adb shell cmd statusbar expand-notifications
        sleep 3
        adb exec-out screencap -p > "$OUT/shade.png"
        adb shell cmd statusbar collapse
        echo "Đã chụp thanh thông báo"
        ;;
    esac
  done
) > /tmp/watch.log 2>&1 &
WATCH=$!
SHOTS_DIR="$OUT" flutter drive -d emulator-5554 \
  --driver=test_driver/integration_test.dart --target=integration_test/app_flow_test.dart \
  --dart-define=API_BASE=http://10.0.2.2:5080 \
  --dart-define=LISTING_ID="$LISTING_ID" --dart-define=SELLER_TOKEN="$SELLER_TOKEN" 2>&1 | tee -a "$LOG"
CODE=${PIPESTATUS[0]}
# Dừng hẳn tiến trình theo dõi (kể cả tail -F) để bước CI kết thúc được.
kill $WATCH 2>/dev/null
pkill -f "tail -F $LOG" 2>/dev/null || true
cat /tmp/watch.log 2>/dev/null
if [ "$CODE" != "0" ]; then
  MSG=$(grep -aE "Không thấy|Exception|Error:|Expected|Đang hiện" "$LOG" | grep -v "Test failed" | head -6 | tr '\n' ' ' | cut -c1-1500)
  echo "::error::Integration test lỗi: $MSG"
fi
grep -a "Đã chụp" "$LOG" | tail -3
exit $CODE
