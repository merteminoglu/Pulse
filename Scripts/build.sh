#!/bin/zsh
# Release build into build/Build/Products/Release/Pulse.app (universal).
# Fails if the binary is coverage-instrumented (__llvm_prf sections).
set -euo pipefail
cd "${0:A:h}/.."

APP=build/Build/Products/Release/Pulse.app
LOG=build/build.log
mkdir -p build

if ! xcodebuild -project Pulse.xcodeproj -scheme Pulse -configuration Release \
    -derivedDataPath build -destination 'generic/platform=macOS' \
    CLANG_COVERAGE_MAPPING=NO build >"$LOG" 2>&1; then
    grep -E "error:|warning:|\*\* BUILD" "$LOG" || tail -n 30 "$LOG"
    exit 1
fi
grep -E "\.swift:[0-9]+:[0-9]+: warning:|\*\* BUILD" "$LOG" | sort -u

BIN="$APP/Contents/MacOS/Pulse"
PRF=$(otool -l "$BIN" | grep -c 'sectname __llvm_prf' || true)
if [[ "$PRF" != 0 ]]; then
    echo "error: $BIN is coverage-instrumented ($PRF __llvm_prf sections)" >&2
    exit 1
fi

VERSION=$(/usr/libexec/PlistBuddy -c 'Print CFBundleShortVersionString' "$APP/Contents/Info.plist")
BUILD=$(/usr/libexec/PlistBuddy -c 'Print CFBundleVersion' "$APP/Contents/Info.plist")
echo "app:     $APP"
echo "archs:   $(lipo -archs "$BIN")"
echo "version: $VERSION ($BUILD)"
