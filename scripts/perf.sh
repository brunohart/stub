#!/usr/bin/env bash
# The performance budgets (docs/decisions/004-budgets.md): StubUITests/PerformanceTests against the Performance
# configuration, judged by scripts/budgets.py against perf/budgets.json. Fails if a metric is over its ceiling, or if a
# budgeted metric was not measured.
#
# Usage: scripts/perf.sh                 the simulator lane, on a "Stub Perf SE2" simulator (made if missing)
#        scripts/perf.sh --device <udid> the device lane: the oldest phone Stub supports, plugged in and unlocked
#        scripts/perf.sh --ci            the simulator lane on whatever iOS simulator the CI image has
set -euo pipefail
cd "$(dirname "$0")/.."
export DEVELOPER_DIR="${DEVELOPER_DIR:-/Applications/Xcode.app/Contents/Developer}"
LANE=simulator
case "${1:-}" in
  --device) LANE=device; DEST="id=${2:?a device UDID}";;
  --ci)     LANE=ci;;
esac
if [ "$LANE" != device ]; then
  RUNTIME=$(xcrun simctl list runtimes -j | python3 -c 'import json,sys; r=[x for x in json.load(sys.stdin)["runtimes"] if x["platform"]=="iOS" and x["isAvailable"]]; print(r[-1]["identifier"])')
  NAME="Stub Perf SE2"
  UDID=$(xcrun simctl list devices -j | python3 -c "import json,sys; d=json.load(sys.stdin)['devices']; print(next((x['udid'] for v in d.values() for x in v if x['name']=='$NAME' and x['isAvailable']), ''))")
  [ -n "$UDID" ] || UDID=$(xcrun simctl create "$NAME" com.apple.CoreSimulator.SimDeviceType.iPhone-SE--2nd-generation- "$RUNTIME")
  xcrun simctl boot "$UDID" 2>/dev/null || true
  xcrun simctl bootstatus "$UDID" -b >/dev/null
  DEST="id=$UDID"
fi
DD="${STUB_DERIVED_DATA:-$HOME/Library/Developer/Xcode/DerivedData/Stub-perf}"
xcodegen generate --quiet
mkdir -p build
RESULT=build/perf.xcresult
rm -rf "$RESULT"
# Apple's advice for performance tests: a Release-optimised build, no debugger, no coverage, no sanitizers.
xcodebuild -project Stub.xcodeproj -scheme StubUI -destination "$DEST" -derivedDataPath "$DD" -resultBundlePath "$RESULT" \
     -only-testing:StubUITests/PerformanceTests -enableCodeCoverage NO test 2>&1 \
     | tee build/last-perf.log | grep --line-buffered -E "measured \[|Test Case.*(passed|failed)|error:|TEST (SUCCEEDED|FAILED)" \
     | sed -E 's/, performanceMetricID.*//' || true
python3 scripts/budgets.py "$RESULT" "$LANE" --markdown build/budgets.md
