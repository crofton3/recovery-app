#!/usr/bin/env bash
# Capture LinkedIn / README media from the iOS Simulator, using demo mode (fake data only).
# Run on a Mac with Xcode, XcodeGen and jq:   scripts/capture-launch-media.sh [screens|video|all]
# Output goes to launch-media/ (gitignored). See docs/launch/PLAN.md.
set -euo pipefail

MODE="${1:-all}"
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
OUT="$ROOT/launch-media"
IOS="$ROOT/ios"
DEVICE_NAME="${DEVICE_NAME:-iPhone 16 Pro}"
mkdir -p "$OUT/screens" "$OUT/video"

need() { command -v "$1" >/dev/null || { echo "Missing $1. $2"; exit 1; }; }
need xcodebuild "Install Xcode."
need xcodegen "brew install xcodegen"
need jq "brew install jq"

# Demo mode needs no real keys. Use the placeholder only if you have no Secrets.swift yet.
if [ ! -f "$IOS/AchillesRecovery/Config/Secrets.swift" ]; then
  cp "$IOS/AchillesRecovery/Config/Secrets.example.swift.txt" "$IOS/AchillesRecovery/Config/Secrets.swift"
fi

# Pick the named device, else the newest available iPhone.
UDID=$(xcrun simctl list devices available --json | jq -r --arg n "$DEVICE_NAME" \
  '[.devices | to_entries[] | select(.key | test("iOS")) | .value[] | select(.name == $n)] | last | .udid')
if [ -z "$UDID" ] || [ "$UDID" = null ]; then
  UDID=$(xcrun simctl list devices available --json | jq -r \
    '[.devices | to_entries[] | select(.key | test("iOS")) | .value[] | select(.name | startswith("iPhone"))] | last | .udid')
fi
echo "Simulator: $(xcrun simctl list devices | grep "$UDID")"

(cd "$IOS" && xcodegen generate >/dev/null)
xcodebuild build -project "$IOS/AchillesRecovery.xcodeproj" -scheme AchillesRecovery \
  -destination "id=$UDID" -derivedDataPath "$IOS/build" CODE_SIGNING_ALLOWED=NO -quiet
APP="$IOS/build/Build/Products/Debug-iphonesimulator/AchillesRecovery.app"
BUNDLE=$(/usr/libexec/PlistBuddy -c 'Print :CFBundleIdentifier' "$APP/Info.plist")

xcrun simctl boot "$UDID" 2>/dev/null || true
xcrun simctl bootstatus "$UDID" -b >/dev/null
open -a Simulator --args -CurrentDeviceUDID "$UDID"
xcrun simctl ui "$UDID" appearance dark
xcrun simctl status_bar "$UDID" override --time 9:41 --dataNetwork wifi --wifiBars 3 \
  --cellularMode active --cellularBars 4 --batteryState charged --batteryLevel 100
xcrun simctl install "$UDID" "$APP"

launch() {  # launch <tab>
  xcrun simctl terminate "$UDID" "$BUNDLE" 2>/dev/null || true
  xcrun simctl launch "$UDID" "$BUNDLE" -demoMode YES -startTab "$1" >/dev/null
  sleep 4   # let the rings finish their spring animation
}

if [ "$MODE" = screens ] || [ "$MODE" = all ]; then
  for tab in today train achilles fuel trends; do
    launch "$tab"
    xcrun simctl io "$UDID" screenshot --type=png "$OUT/screens/$tab.png"
    echo "  saved screens/$tab.png"
  done
  echo "Sub-screens (schedule, PT log, food log, body trends): open them in the Simulator and press Cmd+S."
fi

if [ "$MODE" = video ] || [ "$MODE" = all ]; then
  launch today
  echo
  echo "Recording. Follow docs/launch/demo-script.md in the Simulator, then press Enter to stop."
  xcrun simctl io "$UDID" recordVideo --codec=h264 --force "$OUT/video/raw.mov" &
  REC=$!
  read -r _
  kill -INT "$REC"; wait "$REC" || true
  echo "  saved video/raw.mov"
  if command -v ffmpeg >/dev/null; then
    # LinkedIn-friendly vertical 1080x1920 MP4, phone centred on the app background colour.
    ffmpeg -loglevel error -y -i "$OUT/video/raw.mov" \
      -vf "scale=-2:1720,pad=1080:1920:(ow-iw)/2:(oh-ih)/2:color=0x070B14,fps=30" \
      -c:v libx264 -pix_fmt yuv420p -crf 20 -an "$OUT/video/linkedin-1080x1920.mp4"
    echo "  saved video/linkedin-1080x1920.mp4"
  else
    echo "  (brew install ffmpeg to also get a 1080x1920 MP4)"
  fi
fi

xcrun simctl status_bar "$UDID" clear
echo "Done: $OUT"
