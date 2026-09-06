#!/usr/bin/env bash
# Run the unit tests on a booted iOS 26 simulator (boots one if none is up).
set -euo pipefail
cd "$(dirname "$0")/.."
export DEVELOPER_DIR="${DEVELOPER_DIR:-/Applications/Xcode.app/Contents/Developer}"
SIM="$(scripts/sim.sh)"
for attempt in 1 2 3; do
  if xcodebuild -project Stub.xcodeproj -scheme Stub -destination "id=$SIM" -derivedDataPath build test 2>&1 \
       | tee build/last-test.log | grep -E "✔|✘|error:|TEST (SUCCEEDED|FAILED)" | grep -v CoreData; then
    grep -q "TEST SUCCEEDED" build/last-test.log && exit 0
    grep -q "TEST FAILED" build/last-test.log && exit 1
  fi
  echo "test attempt $attempt did not run; retrying" >&2
  sleep 5
done
exit 1
