#!/bin/bash
# Measures the resource use of the release app against the acceptance criteria.
# Uses a temporary data folder with 90 days of history and 20 tasks today.
# Usage: scripts/measure.sh [seconds of idle sampling, default 300]
set -euo pipefail
cd "$(dirname "$0")/.."
SECONDS_IDLE="${1:-300}"
APP="build/Margin.app"
[ -d "$APP" ] || scripts/build-app.sh
CLI="$APP/Contents/Helpers/margin"

export MARGIN_HOME="$(mktemp -d)"
export MARGIN_MEASURE=1
LOG="$(mktemp)"
trap 'kill "$PID" 2>/dev/null || true; rm -rf "$MARGIN_HOME" "$LOG"' EXIT

mkdir -p "$MARGIN_HOME/days"
for i in $(seq 1 90); do
  d=$(date -v-"${i}"d +%Y-%m-%d)
  printf '# %s\n\n- [x] Task one @done(10:00)\n- [x] Task two @done(11:30)\n- [~] Task three\n' "$d" > "$MARGIN_HOME/days/$d.md"
done
for i in $(seq 1 20); do "$CLI" add "Task number $i" > /dev/null; done

START=$(python3 -c 'import time; print(time.time())')
"$APP/Contents/MacOS/Margin" > "$LOG" 2>&1 &
PID=$!
while ! grep -q MARGIN_READY "$LOG"; do
  kill -0 "$PID" 2>/dev/null || { echo "The app did not start (is a different Margin running?)"; exit 1; }
  python3 -c 'import time; time.sleep(0.01)'
done
END=$(python3 -c 'import time; print(time.time())')
echo "A4 launch to ready:   $(python3 -c "print(f'{($END-$START)*1000:.0f} ms')")   (limit 500 ms)"
echo "A6 bundle size:       $(du -sh "$APP" | cut -f1)   (limit 15 MB)"

echo "Sampling idle for ${SECONDS_IDLE} s ..."
sleep 5
N=$((SECONDS_IDLE / 10 + 1))
top -l "$N" -s 10 -pid "$PID" -stats cpu,idlew | awk -v pid="$PID" '
  /^[ ]*[0-9.]+[ ]+[0-9]+/ { n++; if (n > 1) { cpu += $1; c++; if (first == "") first = $2; last = $2 } }
  END { printf "A1 idle CPU average:  %.3f %%   (limit 0.1 %%)\n", cpu / c;
        printf "A2 idle wake-ups:     %.2f per second\n", (last - first) / ((c - 1) * 10) }'
echo "A3 memory footprint:  $(footprint "$PID" 2>/dev/null | awk '/phys_footprint:/ {print $2, $3; exit}')   (limit 50 MB)"
