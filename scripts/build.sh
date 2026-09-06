#!/usr/bin/env bash
# Build Stub for the iOS Simulator. Regenerates the Xcode project from project.yml first.
# xcodebuild's destination discovery is occasionally flaky right after a project regenerate; retry three times.
set -euo pipefail
cd "$(dirname "$0")/.."
export DEVELOPER_DIR="${DEVELOPER_DIR:-/Applications/Xcode.app/Contents/Developer}"
xcodegen generate --quiet
for attempt in 1 2 3; do
  if xcodebuild -project Stub.xcodeproj -scheme Stub -destination 'generic/platform=iOS Simulator' \
       -derivedDataPath build build 2>&1 | tee build/last-build.log | grep -E "error:|BUILD (SUCCEEDED|FAILED)"; then
    grep -q "BUILD SUCCEEDED" build/last-build.log && exit 0
  fi
  echo "build attempt $attempt failed; retrying" >&2
  sleep 5
done
exit 1
