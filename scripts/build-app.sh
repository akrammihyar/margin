#!/bin/bash
# Builds build/Margin.app from the Swift package. Xcode is not necessary.
set -euo pipefail
cd "$(dirname "$0")/.."

swift build -c release 2>&1 | grep -v "libSwiftScan" || true
BIN="$(swift build -c release --show-bin-path 2>/dev/null | tail -1)"

APP="build/Margin.app"
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Helpers" "$APP/Contents/Resources"

# The file system ignores case: the app binary "Margin" and the command "margin"
# must be in different folders.
cp "$BIN/MarginApp" "$APP/Contents/MacOS/Margin"
cp "$BIN/margin" "$APP/Contents/Helpers/margin"
cp Resources/Info.plist "$APP/Contents/Info.plist"

if [ ! -f build/AppIcon.icns ]; then
  swift scripts/make-icon.swift build/AppIcon.iconset 2>&1 | grep -v "libSwiftScan" || true
  iconutil -c icns build/AppIcon.iconset -o build/AppIcon.icns
fi
cp build/AppIcon.icns "$APP/Contents/Resources/AppIcon.icns"

codesign --force -s - "$APP/Contents/Helpers/margin"
codesign --force -s - "$APP"
echo "Built $APP"
