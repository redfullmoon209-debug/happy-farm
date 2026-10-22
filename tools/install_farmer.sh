#!/usr/bin/env bash
# One-command installation for the user-supplied Mixamo FBX assets.
set -euo pipefail
cd "$(dirname "$0")/.."
archive="${1:-HappyFarm_Mixamo_Farmer.zip}"
if [ ! -f "$archive" ]; then
  echo "ERROR: Missing ${archive}"
  echo "Upload HappyFarm_Mixamo_Farmer.zip into the Codespaces project folder first."
  exit 2
fi
echo "Installing rigged female farmer, four Mixamo motions and optimized textures..."
unzip -oq "$archive" 'assets/characters/*' -d .
for filename in femalefarmer.fbx Idle.fbx Walk.fbx Run.fbx Jump.fbx female_color.png; do
  if [ ! -s "assets/characters/$filename" ]; then
    echo "ERROR: Missing asset $filename"
    exit 1
  fi
done
git add assets/characters
if git diff --cached --quiet; then
  echo "Farmer assets are already installed."
else
  git commit -m "Install supplied Mixamo female farmer FBX, motions and mobile textures"
  git push origin main
fi
echo ""
echo "DONE. GitHub Actions will rebuild the Chrome/mobile web game."
echo "Play: https://redfullmoon209-debug.github.io/happy-farm/"
