#!/usr/bin/env bash
# Install and launch the last build on the simulator, then screenshot it.
# Usage: scripts/run.sh [--seed] [--reset] [--drive] [--season] [--import] [--edition] [--turned] [--tilt x,y]
#                       [--proof spec] [--keeps]
#                       [--type size] [--look metal|swiftui] [--wait-for regex] [--shot path.png]
# --drive: after the seed, press, open, hold and close on a timer (see DebugDrive) so the run can be filmed.
# --season: open the season sheet once the seed has settled.
# --import: open the import sheet once the seed has settled (Day 6).
# --edition: open the newest stub once the seed has settled, so its edition is printed and can be screenshotted
#   (Day 21, ADR-015); --turned shows its back; --tilt x,y holds the light there (the simulator has no gyroscope).
#   The edition is chosen and printed on first sight: wait for "Edition '" and give the press STUB_AFTER=4 seconds.
# --proof "disc=14,bars=3": pull a proof over each edition the press shows that has none (Day 23, ADR-016). Parts by
#   their last word or whole id; movement=, inks= and stock= choose from the genome. --keeps: with --edition, open
#   "What the press keeps" in the detail.
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
  --edition) ARGS+=(-edition);; --turned) ARGS+=(-turned);; --tilt) ARGS+=(-tilt "$2"); shift;;
  --proof) ARGS+=(-proof "$2"); shift;; --keeps) ARGS+=(-keeps);;
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
  sleep "${STUB_AFTER:-2}"
else
  sleep "${STUB_SETTLE:-12}"
fi
if [ -n "$SHOT" ]; then xcrun simctl io "$SIM" screenshot "$SHOT" >/dev/null 2>&1 && echo "screenshot: $SHOT"; fi
# What the reader did, for the log.
applog
