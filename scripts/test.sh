#!/usr/bin/env bash
# Run the unit tests on a booted iOS 26 simulator (boots one if none is up).
set -euo pipefail
cd "$(dirname "$0")/.."
export DEVELOPER_DIR="${DEVELOPER_DIR:-/Applications/Xcode.app/Contents/Developer}"
SIM="$(scripts/sim.sh)"
DD="${STUB_DERIVED_DATA:-$HOME/Library/Developer/Xcode/DerivedData/Stub-scripts}"   # see build.sh: iCloud must not see the .app
mkdir -p "$DD"
for attempt in 1 2 3; do
  # xcodebuild exits non-zero on a failed test as well as on a run that never started, so the pipeline's status
  # cannot tell the two apart (Day 3: a failing test was retried three times). The log can.
  xcodebuild -project Stub.xcodeproj -scheme Stub -destination "id=$SIM" -derivedDataPath "$DD" test 2>&1 \
       | tee build/last-test.log | grep -E "✔|✘|error:|TEST (SUCCEEDED|FAILED)" | grep -v CoreData || true
  grep -q "TEST SUCCEEDED" build/last-test.log && exit 0
  grep -q "TEST FAILED" build/last-test.log && exit 1
  echo "test attempt $attempt did not run; retrying" >&2
  sleep 5
done
exit 1
