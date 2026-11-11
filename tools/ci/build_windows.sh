#!/bin/sh
# Builds the Windows game (build/CarrerasLocas.exe) from scratch, the way the
# release workflow does: downloads Godot and its export templates, imports
# the project and exports it. Usage: tools/ci/build_windows.sh [work dir]
set -e
GODOT_VERSION="${GODOT_VERSION:-4.7.2-stable}"
WORK="${1:-/tmp/godot-ci}"
cd "$(dirname "$0")/../.."
mkdir -p "$WORK" build
BASE="https://github.com/godotengine/godot/releases/download/$GODOT_VERSION"

if [ ! -x "$WORK/godot" ]; then
	curl -fsSL -o "$WORK/godot.zip" "$BASE/Godot_v${GODOT_VERSION}_linux.x86_64.zip"
	unzip -q -o "$WORK/godot.zip" -d "$WORK"
	mv "$WORK/Godot_v${GODOT_VERSION}_linux.x86_64" "$WORK/godot"
	rm "$WORK/godot.zip"
fi

# Only the Windows templates, where Godot looks for them (4.7.2-stable -> 4.7.2.stable)
TEMPLATES="$HOME/.local/share/godot/export_templates/$(echo "$GODOT_VERSION" | sed 's/-/./')"
if [ ! -f "$TEMPLATES/windows_release_x86_64.exe" ]; then
	curl -fsSL -o "$WORK/templates.tpz" "$BASE/Godot_v${GODOT_VERSION}_export_templates.tpz"
	mkdir -p "$TEMPLATES"
	unzip -q -o -j "$WORK/templates.tpz" "templates/windows_*_x86_64.exe" "templates/version.txt" -d "$TEMPLATES"
	rm "$WORK/templates.tpz"
fi

"$WORK/godot" --headless --path . --import > "$WORK/import.log" 2>&1 || true
rm -f build/CarrerasLocas.exe
"$WORK/godot" --headless --path . --export-release "Windows Desktop" build/CarrerasLocas.exe
# Godot can fail to export and still exit with 0
[ -s build/CarrerasLocas.exe ] || { echo "The export didn't produce build/CarrerasLocas.exe"; exit 1; }
ls -la build/CarrerasLocas.exe
