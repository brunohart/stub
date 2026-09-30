#!/usr/bin/env bash
# The deep eval (StubTests/DeepEvalTests.swift): every fixture read `runs` times by each reader, the season sentence and
# every release's edition asked `runs` times, written to docs/evals-deep.md. It asks the on-device model a few hundred
# times, so it is not part of scripts/test.sh: expect twenty minutes to an hour in the simulator at three runs.
# Usage: scripts/eval.sh [runs]   (default 3)
set -euo pipefail
cd "$(dirname "$0")/.."
export DEVELOPER_DIR="${DEVELOPER_DIR:-/Applications/Xcode.app/Contents/Developer}"
RUNS="${1:-3}"
SIM="$(scripts/sim.sh)"
DD="${STUB_DERIVED_DATA:-$HOME/Library/Developer/Xcode/DerivedData/Stub-scripts}"   # see build.sh
xcodegen generate --quiet
mkdir -p build
# xcodebuild hands TEST_RUNNER_-prefixed variables to the tests with the prefix taken off.
TEST_RUNNER_STUB_EVAL_RUNS="$RUNS" xcodebuild -project Stub.xcodeproj -scheme Stub -destination "id=$SIM" \
     -derivedDataPath "$DD" -only-testing:StubTests/DeepEvalTests test 2>&1 \
     | tee build/last-eval.log | grep --line-buffered -E "deep eval:|✔|✘|error:|TEST (SUCCEEDED|FAILED)" || true
grep -q "TEST SUCCEEDED" build/last-eval.log && grep -q "theDeepEvalWritesItsTables() passed" build/last-eval.log
