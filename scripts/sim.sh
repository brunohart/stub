#!/usr/bin/env bash
# Print the UDID of a booted iPhone running iOS 27, booting the newest iPhone 18 Pro if needed.
set -euo pipefail
export DEVELOPER_DIR="${DEVELOPER_DIR:-/Applications/Xcode.app/Contents/Developer}"
booted=$(xcrun simctl list devices booted -j | python3 -c 'import json,sys; d=json.load(sys.stdin)["devices"]; print(next((x["udid"] for k,v in d.items() if "iOS-27" in k for x in v if "iPhone" in x["name"]), ""))')
if [ -n "$booted" ]; then echo "$booted"; exit 0; fi
udid=$(xcrun simctl list devices available -j | python3 -c 'import json,sys; d=json.load(sys.stdin)["devices"]; c=[(k,x["udid"]) for k,v in sorted(d.items(), reverse=True) if "iOS-27" in k for x in v if x["name"]=="iPhone 18 Pro"]; print(c[0][1] if c else "")')
[ -n "$udid" ] || { echo "no iPhone 18 Pro iOS 27 simulator" >&2; exit 1; }
xcrun simctl boot "$udid" >/dev/null 2>&1 || true
xcrun simctl bootstatus "$udid" -b >/dev/null 2>&1
echo "$udid"
