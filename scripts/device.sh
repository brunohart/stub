#!/usr/bin/env bash
# Build Stub signed for a real iPhone, install it and launch it. The phone must be paired with this Mac (plugged in
# once and trusted, then on the same network is enough) and in Developer Mode (Settings › Privacy & Security).
# Usage: scripts/device.sh [--debug] [--device name|udid] [-- app arguments]
# Release by default: that is how the feel, the shaders and the clip should be judged (docs/device.md §3). --debug
# builds the Debug app, which carries the fixtures and the launch flags, so `-- -seed` files the nine fixtures on the
# phone. Never pass -reset to a phone whose drawer holds real stubs: it empties it.
set -euo pipefail
cd "$(dirname "$0")/.."
export DEVELOPER_DIR="${DEVELOPER_DIR:-/Applications/Xcode.app/Contents/Developer}"
CONFIG=Release; DEVICE=""; APP_ARGS=()
while [ $# -gt 0 ]; do case "$1" in
  --debug) CONFIG=Debug;; --device) DEVICE="$2"; shift;;
  --) shift; APP_ARGS=("$@"); break;;
  *) echo "unknown argument $1" >&2; exit 2;;
esac; shift; done
# The first physical iPhone devicectl can reach, unless one is named. Its hardware UDID is what xcodebuild wants.
LIST=$(mktemp); trap 'rm -f "$LIST"' EXIT
xcrun devicectl list devices --json-output "$LIST" >/dev/null 2>&1 || true
UDID=$(python3 - "$LIST" "$DEVICE" <<'EOF'
import json, sys
devices = json.load(open(sys.argv[1])).get("result", {}).get("devices", [])
want = sys.argv[2]
for d in devices:
    hw, props = d.get("hardwareProperties", {}), d.get("deviceProperties", {})
    if hw.get("reality") != "physical" or hw.get("platform") != "iOS": continue
    if want and want not in (hw.get("udid"), d.get("identifier"), props.get("name")): continue
    if not want and hw.get("deviceType") != "iPhone": continue
    print(hw.get("udid", "")); break
EOF
)
[ -n "$UDID" ] || { echo "no paired iPhone found${DEVICE:+ named $DEVICE}; plug it in, trust this Mac, and try again" >&2; exit 1; }
xcodegen generate --quiet
DD="${STUB_DERIVED_DATA:-$HOME/Library/Developer/Xcode/DerivedData/Stub-device}"
mkdir -p build
echo "building Stub ($CONFIG) for $UDID"
# -allowProvisioningUpdates and -allowProvisioningDeviceRegistration: automatic signing registers this phone, the
# bundle IDs and the App Group with the team on first use, as Xcode's Run button would.
xcodebuild -project Stub.xcodeproj -scheme Stub -configuration "$CONFIG" -destination "id=$UDID" \
     -derivedDataPath "$DD" -allowProvisioningUpdates -allowProvisioningDeviceRegistration build 2>&1 \
     | tee build/last-device.log | grep -E "error:|BUILD (SUCCEEDED|FAILED)" || true
grep -q "BUILD SUCCEEDED" build/last-device.log || { echo "build failed; see build/last-device.log" >&2; exit 1; }
xcrun devicectl device install app --device "$UDID" "$DD/Build/Products/$CONFIG-iphoneos/Stub.app"
xcrun devicectl device process launch --device "$UDID" com.designedbybruno.stub ${APP_ARGS[@]+"${APP_ARGS[@]}"}
