#!/bin/bash
# Builds Margin and installs it in /Applications. Replaces only /Applications/Margin.app.
set -euo pipefail
cd "$(dirname "$0")/.."
scripts/build-app.sh
osascript -e 'tell application id "app.margin.Margin" to quit' 2>/dev/null || true
pkill -f "Margin.app/Contents/MacOS/Margin" 2>/dev/null || true
sleep 1
rm -rf "/Applications/Margin.app"
cp -R build/Margin.app "/Applications/Margin.app"
open "/Applications/Margin.app"
echo "Installed /Applications/Margin.app"
