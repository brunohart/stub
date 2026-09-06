#!/usr/bin/env bash
# Install and launch the last build on the simulator, then screenshot it.
# Usage: scripts/run.sh [--seed] [--reset] [--shot path.png]
set -euo pipefail
cd "$(dirname "$0")/.."
export DEVELOPER_DIR="${DEVELOPER_DIR:-/Applications/Xcode.app/Contents/Developer}"
ARGS=(); SHOT=""
while [ $# -gt 0 ]; do case "$1" in
  --seed) ARGS+=(-seed);; --reset) ARGS+=(-reset);; --shot) SHOT="$2"; shift;; *) echo "unknown $1" >&2; exit 2;; esac; shift; done
SIM="$(scripts/sim.sh)"
APP=build/Build/Products/Debug-iphonesimulator/Stub.app
xcrun simctl terminate "$SIM" com.designedbybruno.stub 2>/dev/null || true
xcrun simctl install "$SIM" "$APP"
xcrun simctl launch "$SIM" com.designedbybruno.stub "${ARGS[@]}" >/dev/null
sleep "${STUB_SETTLE:-12}"
if [ -n "$SHOT" ]; then xcrun simctl io "$SIM" screenshot "$SHOT" >/dev/null 2>&1 && echo "screenshot: $SHOT"; fi
# What the reader did, for the log.
xcrun simctl spawn "$SIM" log show --last 60s --info --predicate 'subsystem == "com.designedbybruno.stub"' --style compact 2>/dev/null \
  | sed 's/^.*Stub\[[0-9:]*\] //' | grep -vE "^Timestamp|CoreData" | cut -c1-220 || true
