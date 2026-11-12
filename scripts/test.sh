#!/bin/bash
# Runs the test suite. With Command Line Tools only (no Xcode), the Swift
# Testing framework is not on the default search path, so add it.
set -euo pipefail
cd "$(dirname "$0")/.."
DEV="$(xcode-select -p)"
ARGS=()
if [[ "$DEV" == *CommandLineTools* ]]; then
  F="$DEV/Library/Developer/Frameworks"
  L="$DEV/Library/Developer/usr/lib"
  ARGS=(-Xswiftc -F -Xswiftc "$F" -Xlinker -F -Xlinker "$F" -Xlinker -rpath -Xlinker "$F" -Xlinker -rpath -Xlinker "$L")
fi
swift test "${ARGS[@]}" "$@" 2>&1 | grep -v "libSwiftScan"
exit "${PIPESTATUS[0]}"
