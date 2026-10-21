#!/usr/bin/env bash
# Happy Farm - build the Godot 4.4.1 web game, then serve it on port 8080.
# Run in GitHub Codespaces: bash tools/run_port.sh
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

VERSION="4.4.1"
BIN_DIR="$ROOT/.preview-bin"
GODOT="$BIN_DIR/Godot_v${VERSION}-stable_linux.x86_64"
TEMPLATE_DIR="${XDG_DATA_HOME:-$HOME/.local/share}/godot/export_templates/${VERSION}.stable"

for command in curl unzip python3; do
  if ! command -v "$command" >/dev/null 2>&1; then
    echo "Missing dependency: $command"
    exit 1
  fi
done

mkdir -p "$BIN_DIR"

if [[ ! -x "$GODOT" ]]; then
  echo "[1/4] Downloading Godot ${VERSION}..."
  curl --fail --location --retry 3 --progress-bar \
    "https://github.com/godotengine/godot/releases/download/${VERSION}-stable/Godot_v${VERSION}-stable_linux.x86_64.zip" \
    --output "$BIN_DIR/godot.zip"
  unzip -qo "$BIN_DIR/godot.zip" -d "$BIN_DIR"
  chmod +x "$GODOT"
fi

if [[ ! -f "$TEMPLATE_DIR/web_release.zip" && ! -f "$TEMPLATE_DIR/web_release_nothreads.zip" ]]; then
  echo "[2/4] Downloading matching Web export templates..."
  curl --fail --location --retry 3 --progress-bar \
    "https://github.com/godotengine/godot/releases/download/${VERSION}-stable/Godot_v${VERSION}-stable_export_templates.tpz" \
    --output "$BIN_DIR/templates.tpz"
  mkdir -p "$BIN_DIR/template_unpack" "$TEMPLATE_DIR"
  unzip -qo "$BIN_DIR/templates.tpz" -d "$BIN_DIR/template_unpack"
  cp -a "$BIN_DIR/template_unpack/templates/." "$TEMPLATE_DIR/"
fi

echo "[3/4] Importing assets and exporting the Godot project to HTML5..."
"$GODOT" --headless --path "$ROOT" --editor --quit
mkdir -p "$ROOT/build/web"
"$GODOT" --headless --path "$ROOT" --export-debug "Web" "$ROOT/build/web/index.html"

if [[ ! -s "$ROOT/build/web/index.html" ]]; then
  echo "ERROR: Godot did not create build/web/index.html"
  exit 1
fi

echo "[4/4] Happy Farm is running at http://localhost:8080"
echo "In Codespaces, open the PORTS tab, find port 8080, and choose Open in Browser."
echo "To test on your phone, copy the forwarded address; a private port requires GitHub sign-in."
echo "Keep this terminal open while playing. Ctrl+C stops the test server."
exec python3 -m http.server 8080 --bind 0.0.0.0 --directory "$ROOT/build/web"
