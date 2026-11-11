#!/bin/sh
# Bot races on every level at once (each game on its own port).
# Usage: tools/tests/run_bots.sh <godot binary> [level numbers, default all]
# Prints one RESULT line per level; the whole logs stay in $OUT (default /tmp/bots_race)
GODOT="$1"; shift
[ -x "$GODOT" ] || { echo "usage: $0 <godot binary> [level numbers]"; exit 1; }
cd "$(dirname "$0")/../.." || exit 1
OUT="${OUT:-/tmp/bots_race}"; mkdir -p "$OUT"
LEVELS="${*:-$(ls scenes/level_*.tscn | sed 's/.*level_\([0-9]*\)\.tscn/\1/' | sort -n)}"
for n in $LEVELS; do
	timeout 300 "$GODOT" --headless --path . -s tools/tests/bots_race.gd -- $((n - 1)) --port=$((8400 + n)) > "$OUT/level_$n.txt" 2>&1 &
done
wait
for n in $LEVELS; do
	grep "^RESULT" "$OUT/level_$n.txt" || echo "RESULT level $n: no result (see $OUT/level_$n.txt)"
	grep -c "SCRIPT ERROR" "$OUT/level_$n.txt" | grep -v "^0$" | sed "s/^/  script errors: /"
done
