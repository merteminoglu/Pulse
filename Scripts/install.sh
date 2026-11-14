#!/bin/zsh
# Builds, replaces /Applications/Pulse.app and relaunches it.
# No Apple Events, so no Automation prompt.
set -euo pipefail
cd "${0:A:h}/.."

Scripts/build.sh

if pgrep -x Pulse >/dev/null; then
    pkill -x Pulse
    for _ in {1..50}; do
        pgrep -x Pulse >/dev/null || break
        sleep 0.1
    done
    if pgrep -x Pulse >/dev/null; then
        echo "error: Pulse did not quit" >&2
        exit 1
    fi
fi

rm -rf /Applications/Pulse.app
ditto build/Build/Products/Release/Pulse.app /Applications/Pulse.app
open /Applications/Pulse.app
echo "installed and launched /Applications/Pulse.app"
