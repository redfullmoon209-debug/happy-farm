#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
mkdir -p .preview-bin build/web
if [ ! -x .preview-bin/Godot_v4.4.1-stable_linux.x86_64 ]; then
  curl -fL --retry 3 https://github.com/godotengine/godot/releases/download/4.4.1-stable/Godot_v4.4.1-stable_linux.x86_64.zip -o .preview-bin/editor.zip
  unzip -qo .preview-bin/editor.zip -d .preview-bin
  chmod +x .preview-bin/Godot_v4.4.1-stable_linux.x86_64
fi
if [ ! -f "$HOME/.local/share/godot/export_templates/4.4.1.stable/web_release.zip" ]; then
  curl -fL --retry 3 https://github.com/godotengine/godot/releases/download/4.4.1-stable/Godot_v4.4.1-stable_export_templates.tpz -o .preview-bin/templates.tpz
  mkdir -p "$HOME/.local/share/godot/export_templates/4.4.1.stable"
  unzip -qo .preview-bin/templates.tpz -d .preview-bin
  cp -a .preview-bin/templates/. "$HOME/.local/share/godot/export_templates/4.4.1.stable/"
fi
.preview-bin/Godot_v4.4.1-stable_linux.x86_64 --headless --path . --editor --quit 2>&1 | tee .preview-bin/import.log
if grep -E 'SCRIPT ERROR:|Parse Error:|Compile Error:|Failed to load script' .preview-bin/import.log; then exit 1; fi
.preview-bin/Godot_v4.4.1-stable_linux.x86_64 --headless --path . --export-release Web build/web/index.html 2>&1 | tee .preview-bin/export.log
if grep -E 'SCRIPT ERROR:|Parse Error:|Compile Error:|Failed to load script' .preview-bin/export.log; then exit 1; fi
test -s build/web/index.html
echo 'Happy Farm clean is running on port 8080'
python3 -m http.server 8080 --bind 0.0.0.0 --directory build/web
