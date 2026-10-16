#!/usr/bin/env bash
# Films the App Store preview from the app itself and cuts it to Apple's sizes (BEDIP-221).
# Usage: scripts/preview.sh [fixture]   (default fixtures/stub-1-the-brutalist.png; build first with scripts/build.sh)
#
# The story, on the app's own clock (`-preview`, DebugDrive): the drawer's cards dealt; a stub arrives and is read; it is
# kept and its edition prints; into the drawer; opened; turned in the light; held in the light. The simulator's screen is
# recorded whole, the app's log says when each beat happened, and three takes are cut from it: the deal and the stub
# arriving; the read fields, the keep, the press and the drawer; the edition in the light. The wait while
# the model reads is cut, not sped up.
#
# Writes build/preview/: stub-preview-886x1920.mp4 (every iPhone with Face ID), stub-preview-750x1334.mp4 (iPhone SE),
# H.264 High at 30 fps and about 11 Mb/s, with a silent stereo AAC track, 15 to 30 seconds (Apple's app preview
# specification, checked 2026-10-13), and frames.png, a contact sheet to look at.
set -euo pipefail
cd "$(dirname "$0")/.."
export DEVELOPER_DIR="${DEVELOPER_DIR:-/Applications/Xcode.app/Contents/Developer}"
FIXTURE="$(cd "$(dirname "${1:-fixtures/stub-1-the-brutalist.png}")" && pwd)/$(basename "${1:-fixtures/stub-1-the-brutalist.png}")"
OUT=build/preview
mkdir -p "$OUT"
SIM="$(scripts/sim.sh)"
APP="${STUB_DERIVED_DATA:-$HOME/Library/Developer/Xcode/DerivedData/Stub-scripts}/Build/Products/Debug-iphonesimulator/Stub.app"
xcrun simctl terminate "$SIM" com.designedbybruno.stub 2>/dev/null || true
xcrun simctl install "$SIM" "$APP"
xcrun simctl status_bar "$SIM" override --time "9:41" --batteryState charged --batteryLevel 100 --cellularBars 4 --wifiBars 3 >/dev/null 2>&1 || true
trap 'xcrun simctl status_bar "$SIM" clear >/dev/null 2>&1 || true' EXIT

START="$(date '+%Y-%m-%d %H:%M:%S')"
T0="$(python3 -c 'import time; print(time.time())')"
xcrun simctl io "$SIM" recordVideo --codec=h264 --force "$OUT/raw.mov" >/dev/null 2>&1 &
REC=$!
sleep 0.6
xcrun simctl launch "$SIM" com.designedbybruno.stub -preview -inbox "$FIXTURE" >/dev/null
# Wait for the last beat, then a little of the light.
deadline=$(( $(date +%s) + ${STUB_PREVIEW_TIMEOUT:-120} ))
events() {
  xcrun simctl spawn "$SIM" log show --start "$START" --info --predicate 'subsystem == "com.designedbybruno.stub" AND (category == "drive" OR category == "reach")' --style compact 2>/dev/null \
    | grep -E "preview:|Arrival from" || true
}
until events | grep -q "preview: done"; do
  if [ "$(date +%s)" -ge "$deadline" ]; then echo "the preview never finished" >&2; kill -INT $REC; exit 1; fi
  sleep 1
done
sleep "${STUB_TABLE_SECONDS:-6}"
kill -INT $REC
wait $REC 2>/dev/null || true
n=0; until ffprobe -v error "$OUT/raw.mov" >/dev/null 2>&1 || [ $n -ge 40 ]; do sleep 0.5; n=$((n+1)); done

# When each beat happened, in seconds from the start of the recording.
events > "$OUT/events.log"
python3 - "$T0" "$OUT/events.log" > "$OUT/cuts.txt" <<'EOF'
import sys, re, datetime
t0 = float(sys.argv[1])
at = {}
for line in open(sys.argv[2]):
    m = re.match(r'(\d{4}-\d\d-\d\d \d\d:\d\d:\d\d\.\d+)', line)
    if not m: continue
    t = datetime.datetime.strptime(m.group(1)[:26], '%Y-%m-%d %H:%M:%S.%f').timestamp() - t0
    for key in ['Arrival from', 'preview: keep', 'preview: into the drawer', 'preview: open', 'preview: turn it in the light', 'preview: done']:
        if key in line and key not in at: at[key] = t
arrive, keep, drawer, opened, done = at['Arrival from'], at['preview: keep'], at['preview: into the drawer'], at['preview: open'], at['preview: done']
# Take one: the deal and the stub arriving, until the reader is a few seconds in.
# Take two: the fields read, the keep, the press printing, the drawer, the stub opened.
# Take three: the edition in the light.
takes = [(max(0.3, arrive - 2.6), arrive + 3.2), (keep - 1.6, opened + 0.5), (opened + 0.5, done + 1.5)]
total = sum(b - a for a, b in takes)
if total > 29.5:   # Apple's ceiling is thirty seconds: shorten the light.
    over = total - 29.5
    a, b = takes[2]; takes[2] = (a, b - over)
print(' '.join(f'{a:.2f} {b:.2f}' for a, b in takes))
EOF
read -r A0 A1 B0 B1 C0 C1 < "$OUT/cuts.txt"
echo "takes: $A0–$A1, $B0–$B1, $C0–$C1"

cut() { # cut WIDTH HEIGHT FILTER OUTFILE
  ffmpeg -v error -y -i "$OUT/raw.mov" -f lavfi -t 40 -i "anullsrc=channel_layout=stereo:sample_rate=48000" -filter_complex "
    [0:v]fps=30,split=3[a][b][c];
    [a]trim=$A0:$A1,setpts=PTS-STARTPTS[a1];
    [b]trim=$B0:$B1,setpts=PTS-STARTPTS[b1];
    [c]trim=$C0:$C1,setpts=PTS-STARTPTS[c1];
    [a1][b1][c1]concat=n=3:v=1:a=0,$3,format=yuv420p,setsar=1[v]" \
    -map "[v]" -map 1:a -shortest -c:v libx264 -profile:v high -level 4.0 -preset slow -b:v 11M -maxrate 12M -bufsize 24M \
    -r 30 -c:a aac -b:a 256k -ac 2 -ar 48000 -movflags +faststart "$4"
}
cut 886 1920 "scale=886:-2:flags=lanczos,crop=886:1920" "$OUT/stub-preview-886x1920.mp4"
cut 750 1334 "scale=-2:1334:flags=lanczos,pad=750:1334:(ow-iw)/2:0:color=0xF0EDE6" "$OUT/stub-preview-750x1334.mp4"

for f in "$OUT"/stub-preview-*.mp4; do
  ffprobe -v error -show_entries stream=codec_name,profile,width,height,r_frame_rate,channels,sample_rate,bit_rate:format=duration -of compact "$f" | sed "s|^|$(basename "$f"): |"
done
ffmpeg -v error -y -i "$OUT/stub-preview-886x1920.mp4" -vf "fps=1/2,scale=200:-2,tile=7x2" -frames:v 1 "$OUT/frames.png"
echo "frames: $OUT/frames.png"
