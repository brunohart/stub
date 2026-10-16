#!/usr/bin/env bash
# Install and launch the last build on the simulator, then screenshot it.
# Usage: scripts/run.sh [--seed] [--reset] [--drive] [--season] [--import] [--edition] [--turned] [--tilt x,y]
#                       [--proof spec] [--keeps] [--open title] [--press] [--overprint screen] [--stamp name] [--ink name] [--scrub x]
#                       [--separated s] [--bench name] [--flood p] [--pulled] [--wet w] [--signed] [--record path.mov]
#                       [--viewings n] [--age years] [--clip out.mp4] [--clip-card] [--inbox file] [--preview]
#                       [--face ticket|edition] [--cabinet] [--drawer name] [--carry] [--type size] [--look metal|swiftui] [--wait-for regex] [--shot path.png]
# --drive: after the seed, press, open, hold and close on a timer (see DebugDrive) so the run can be filmed.
# --season: open the season sheet once the seed has settled.
# --import: open the import sheet once the seed has settled (Day 6).
# --edition: open the newest stub once the seed has settled, so its edition is printed and can be screenshotted
#   (Day 21, ADR-015); --turned shows its back; --tilt x,y holds the light there (the simulator has no gyroscope).
#   The edition is chosen and printed on first sight: wait for "Edition '" and give the press STUB_AFTER=4 seconds.
# --proof "disc=14,bars=3": pull a proof over each edition the press shows that has none (Day 23, ADR-016). Parts by
#   their last word or whole id; movement=, inks= and stock= choose from the genome. --keeps: with --edition, open
#   "What the press keeps" in the detail. --open "Title": with --edition, open that stub instead of the newest.
# --press: with --edition, carry the card on into the press room (Day 24). --overprint stub|discs|dots|bands|letter: pull
#   a pass through that screen across the card; --stamp date|admit|seat|viewing|postmark: press that stamp; --ink
#   primary|secondary|ink: in which ink (ADR-046). --drive with --press overprints the stub and stamps the date on a
#   clock. --record path.mov: film STUB_RECORD seconds (default 20) from launch.
# --separated 0.8: in the press room, lift the card's layers that far apart (Day 25); with --drive, pinch them apart,
#   turn them in the light, and press them together.
# --bench movement|inks|stock|pull|stamp: open that object on the bench (Day 26, ADR-046); with the fan, --scrub x rests a finger
#   x points along it. --flood 0.4: hold the next palette's flood that far across the card.
# --pulled: in the press room, pull the proof on the press (Day 27); --wet 0.6 holds the ink that wet. --turned with
#   --press turns the card over on the bed. --signed: sign with the fixture signature at launch.
# --viewings 3: the opened stub is that viewing of its release, punched n − 1 times through the strip (Day 28).
#   --age 6: it has been in the drawer that many years, for its patina.
# --clip out.mp4: with --edition, draw the moving share (Day 30), wait for it, and copy it out of the app's container.
#   Vertical, 1080 by 1920, with the watermark under the card (BEDIP-221); --clip-card draws the card-sized clip instead.
# --inbox file: put a .pkpass, .pdf or image in the share extension's inbox at launch, as a share would (BEDIP-218); the
#   app opens the import sheet on it. A relative path is from the repo.
# --preview: the App Store preview's story on a clock (BEDIP-221); with --inbox, the stub that arrives. scripts/preview.sh
#   films it and cuts it to Apple's sizes.
# --face ticket|edition: the drawer shows that face (ADR-026). --cabinet: once the seed has settled, make two drawers and
#   file stubs in them. --drawer "With Mum": open that drawer. --carry: hold a stub up, so the cabinet's rail shows.
# --keep: press Keep a stub once the drawer settles (ADR-025). --camera file: the viewfinder looks at that photograph (the
#   simulator has no camera). --shutter: take it once the marks lock on the ticket.
# --type: set the simulator's Dynamic Type size for the run (medium, extra-extra-large, accessibility-extra-large …)
#   and put it back to medium afterwards.
# --wait-for: instead of sleeping STUB_SETTLE seconds, poll the app's log for a line matching the regex
#   (up to STUB_WAIT_TIMEOUT seconds, default 480) and screenshot two seconds after it appears. The seed
#   reads eight stubs through the model at up to 40 s each; a fixed settle photographs an empty drawer.
set -euo pipefail
cd "$(dirname "$0")/.."
export DEVELOPER_DIR="${DEVELOPER_DIR:-/Applications/Xcode.app/Contents/Developer}"
ARGS=(); SHOT=""; WAIT=""; TYPE=""; RECORD=""; CLIP=""
while [ $# -gt 0 ]; do case "$1" in
  --seed) ARGS+=(-seed);; --reset) ARGS+=(-reset);; --drive) ARGS+=(-drive);; --season) ARGS+=(-season);;
  --import) ARGS+=(-import);; --type) TYPE="$2"; shift;;
  --edition) ARGS+=(-edition);; --turned) ARGS+=(-turned);; --tilt) ARGS+=(-tilt "$2"); shift;;
  --proof) ARGS+=(-proof "$2"); shift;; --keeps) ARGS+=(-keeps);; --open) ARGS+=(-open "$2"); shift;;
  --press) ARGS+=(-press);; --overprint) ARGS+=(-overprint "$2"); shift;; --stamp) ARGS+=(-stamp "$2"); shift;;
  --ink) ARGS+=(-ink "$2"); shift;;
  --scrub) ARGS+=(-scrub "$2"); shift;; --record) RECORD="$2"; shift;; --separated) ARGS+=(-separated "$2"); shift;;
  --bench) ARGS+=(-bench "$2"); shift;; --flood) ARGS+=(-flood "$2"); shift;;
  --pulled) ARGS+=(-pulled);; --wet) ARGS+=(-wet "$2"); shift;; --signed) ARGS+=(-signed);;
  --viewings) ARGS+=(-viewings "$2"); shift;; --age) ARGS+=(-age "$2"); shift;;
  --clip) ARGS+=(-clip); CLIP="$2"; WAIT="${WAIT:-Clip: written}"; shift;;
  --clip-card) ARGS+=(-clipformat card);;
  --inbox) ARGS+=(-inbox "$(cd "$(dirname "$2")" && pwd)/$(basename "$2")"); shift;;
  --preview) ARGS+=(-preview);;
  --face) ARGS+=(-face "$2"); shift;; --cabinet) ARGS+=(-cabinet);; --drawer) ARGS+=(-drawer "$2"); shift;;
  --carry) ARGS+=(-carry);; --keep) ARGS+=(-keep);; --shutter) ARGS+=(-shutter);;
  --camera) ARGS+=(-camera "$(cd "$(dirname "$2")" && pwd)/$(basename "$2")"); shift;;
  --look) ARGS+=(-look "$2"); shift;; --wait-for) WAIT="$2"; shift;;
  --shot) SHOT="$2"; shift;; *) echo "unknown $1" >&2; exit 2;; esac; shift; done
SIM="$(scripts/sim.sh)"
APP="${STUB_DERIVED_DATA:-$HOME/Library/Developer/Xcode/DerivedData/Stub-scripts}/Build/Products/Debug-iphonesimulator/Stub.app"
xcrun simctl terminate "$SIM" com.designedbybruno.stub 2>/dev/null || true
if [ -n "$TYPE" ]; then xcrun simctl ui "$SIM" content_size "$TYPE"; trap 'xcrun simctl ui "$SIM" content_size medium' EXIT; fi
xcrun simctl install "$SIM" "$APP"
START="$(date '+%Y-%m-%d %H:%M:%S')"
xcrun simctl launch "$SIM" com.designedbybruno.stub ${ARGS[@]+"${ARGS[@]}"} >/dev/null
if [ -n "$RECORD" ]; then
  xcrun simctl io "$SIM" recordVideo --codec=hevc --force "$RECORD" >/dev/null 2>&1 &
  REC=$!
  sleep "${STUB_RECORD:-20}"
  kill -INT "$REC" 2>/dev/null || true
  wait "$REC" 2>/dev/null || true
  echo "recording: $RECORD"
fi
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
if [ -n "$CLIP" ]; then
  MADE="$(ls -t "$(xcrun simctl get_app_container "$SIM" com.designedbybruno.stub data)"/tmp/*-edition*.mp4 2>/dev/null | head -1)"
  if [ -n "$MADE" ] && cp "$MADE" "$CLIP"; then echo "clip: $CLIP"; else echo "no clip was written" >&2; fi
fi
# What the reader did, for the log.
applog
