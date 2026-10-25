#!/usr/bin/env bash
# Runs the test suite with Swift Testing from the Command Line Tools.
# SwiftPM does not find Testing.framework without Xcode, so we pass its paths explicitly.
set -euo pipefail
cd "$(dirname "$0")/.."

DEV="$(xcode-select -p)"
if [[ -d "$DEV/Library/Developer/Frameworks" ]]; then
  FW="$DEV/Library/Developer/Frameworks"
  LIB="$DEV/Library/Developer/usr/lib"
else
  FW="$DEV/Platforms/MacOSX.platform/Developer/Library/Frameworks"
  LIB="$DEV/Platforms/MacOSX.platform/Developer/usr/lib"
fi

exec swift test \
  -Xswiftc -F -Xswiftc "$FW" \
  -Xlinker -F -Xlinker "$FW" \
  -Xlinker -rpath -Xlinker "$FW" \
  -Xlinker -rpath -Xlinker "$LIB" \
  "$@"
