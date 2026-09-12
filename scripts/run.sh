#!/usr/bin/env bash
# Install and launch the last build on the simulator, then screenshot it.
# Usage: scripts/run.sh [--seed] [--reset] [--drive] [--season] [--import] [--type size] [--look metal|swiftui] [--wait-for regex] [--shot path.png]
# --drive: after the seed, press, open, hold and close on a timer (see DebugDrive) so the run can be filmed.
# --season: open the season sheet once the seed has settled.
# --import: open the import sheet once the seed has settled (Day 6).
# --type: set the simulator's Dynamic Type size for the run (medium, extra-extra-large, accessibility-extra-large …)
#   and put it back to medium afterwards.
# --wait-for: instead of sleeping STUB_SETTLE seconds, poll the app's log for a line matching the regex
#   (up to STUB_WAIT_TIMEOUT seconds, default 480) and screenshot two seconds after it appears. The seed
#   reads eight stubs through the model at up to 40 s each; a fixed settle photographs an empty drawer.
set -euo pipefail
cd "$(dirname "$0")/.."
export DEVELOPER_DIR="${DEVELOPER_DIR:-/Applications/Xcode.app/Contents/Developer}"
ARGS=(); SHOT=""; WAIT=""; TYPE=""
while [ $# -gt 0 ]; do case "$1" in
  --seed) ARGS+=(-seed);; --reset) ARGS+=(-reset);; --drive) ARGS+=(-drive);; --season) ARGS+=(-season);;
  --import) ARGS+=(-import);; --type) TYPE="$2"; shift;;
  --look) ARGS+=(-look "$2"); shift;; --wait-for) WAIT="$2"; shift;;
  --shot) SHOT="$2"; shift;; *) echo "unknown $1" >&2; exit 2;; esac; shift; done
SIM="$(scripts/sim.sh)"
APP="${STUB_DERIVED_DATA:-$HOME/Library/Developer/Xcode/DerivedData/Stub-scripts}/Build/Products/Debug-iphonesimulator/Stub.app"
xcrun simctl terminate "$SIM" com.designedbybruno.stub 2>/dev/null || true
if [ -n "$TYPE" ]; then xcrun simctl ui "$SIM" content_size "$TYPE"; trap 'xcrun simctl ui "$SIM" content_size medium' EXIT; fi
xcrun simctl install "$SIM" "$APP"
START="$(date '+%Y-%m-%d %H:%M:%S')"
xcrun simctl launch "$SIM" com.designedbybruno.stub ${ARGS[@]+"${ARGS[@]}"} >/dev/null
applog() {
  xcrun simctl spawn "$SIM" log show --start "$START" --info --predicate 'subsystem == "com.designedbybruno.stub"' --style compact 2>/dev/null \
    | sed 's/^.*Stub\[[0-9:]*\] //' | grep -vE "^Timestamp|CoreData" | cut -c1-220 || true
}
if [ -n "$WAIT" ]; then
  deadline=$(( $(date +%s) + ${STUB_WAIT_TIMEOUT:-480} ))
  until applog | grep -qE "$WAIT"; do
    if [ "$(date +%s)" -ge "$deadline" ]; then echo "gave up waiting for /$WAIT/" >&2; break; fi
    sleep 5
  done
  sleep 2
else
  sleep "${STUB_SETTLE:-12}"
fi
if [ -n "$SHOT" ]; then xcrun simctl io "$SIM" screenshot "$SHOT" >/dev/null 2>&1 && echo "screenshot: $SHOT"; fi
# What the reader did, for the log.
applog
