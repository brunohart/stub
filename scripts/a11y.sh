#!/usr/bin/env bash
# The accessibility audit (docs/decisions/005-accessibility.md): StubUITests/AccessibilityTests, every screen a common task
# passes through, audited by performAccessibilityAudit at the default size and the largest accessibility size, then again
# with Increase Contrast on. Writes every failing issue to build/a11y.txt and fails if there are any; the issues settled by
# evidence (printed artwork, contrast measured on screen, type measured growing) go to build/a11y-settled.txt.
#
# Usage: scripts/a11y.sh [--ci]
set -euo pipefail
cd "$(dirname "$0")/.."
export DEVELOPER_DIR="${DEVELOPER_DIR:-/Applications/Xcode.app/Contents/Developer}"
RUNTIME=$(xcrun simctl list runtimes -j | python3 -c 'import json,sys; r=[x for x in json.load(sys.stdin)["runtimes"] if x["platform"]=="iOS" and x["isAvailable"]]; print(r[-1]["identifier"])')
NAME="Stub A11y"
UDID=$(xcrun simctl list devices -j | python3 -c "import json,sys; d=json.load(sys.stdin)['devices']; print(next((x['udid'] for v in d.values() for x in v if x['name']=='$NAME' and x['isAvailable']), ''))")
[ -n "$UDID" ] || UDID=$(xcrun simctl create "$NAME" com.apple.CoreSimulator.SimDeviceType.iPhone-SE--2nd-generation- "$RUNTIME")
xcrun simctl boot "$UDID" 2>/dev/null || true
xcrun simctl bootstatus "$UDID" -b >/dev/null
DD="${STUB_DERIVED_DATA:-$HOME/Library/Developer/Xcode/DerivedData/Stub-perf}"
xcodegen generate --quiet
mkdir -p build
: > build/a11y.txt
: > build/a11y-settled.txt
for contrast in disabled enabled; do
  xcrun simctl ui "$UDID" increase_contrast "$contrast"
  xcodebuild -project Stub.xcodeproj -scheme StubUI -destination "id=$UDID" -derivedDataPath "$DD" \
       -only-testing:StubUITests/AccessibilityTests test 2>&1 | tee "build/last-a11y-$contrast.log" \
       | grep --line-buffered -E "^A11Y:|Test Case.*(passed|failed)|TEST (SUCCEEDED|FAILED)" || true
  grep "^A11Y:" "build/last-a11y-$contrast.log" | sed "s/^/[increase contrast $contrast] /" >> build/a11y.txt || true
  grep "^A11Y-OK:" "build/last-a11y-$contrast.log" | sed "s/^/[increase contrast $contrast] /" >> build/a11y-settled.txt || true
done
xcrun simctl ui "$UDID" increase_contrast disabled
COUNT=$(grep -c "A11Y:" build/a11y.txt || true)
echo "accessibility issues: $COUNT (build/a11y.txt); settled by evidence: $(grep -c "" build/a11y-settled.txt) (build/a11y-settled.txt)"
[ "$COUNT" -eq 0 ]
