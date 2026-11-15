#!/bin/zsh
# Runs the unit tests. Extra xcodebuild arguments pass through, e.g.
#   Scripts/test.sh -only-testing:PulseTests/FmtTests
# The test host launches Pulse.app, so extra items flash in the menu bar.
set -euo pipefail
cd "${0:A:h}/.."

mkdir -p build
LOG=build/test.log
set +e
xcodebuild test -project Pulse.xcodeproj -scheme Pulse -derivedDataPath build/tests \
    -destination 'platform=macOS,arch=arm64' "$@" >"$LOG" 2>&1
STATUS=$?
set -e

grep -E "\.swift:[0-9]+(:[0-9]+)?: error:|\*\* TEST" "$LOG" | sort -u
echo "passed: $(grep -cE 'Test [Cc]ase .* passed' "$LOG" || true)  failed: $(grep -cE 'Test [Cc]ase .* failed' "$LOG" || true)  (log: $LOG)"
exit $STATUS
