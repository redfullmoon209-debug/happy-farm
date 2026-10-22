#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
mkdir -p assets/audio
if [ ! -s assets/audio/farm_theme.wav ]; then
  echo "Composing original farm background theme and action Foley."
  python3 tools/build_audio.py
fi
fetch_voice() {
  local name="$1"
  local url="$2"
  if [ -s "assets/audio/$name.mp3" ]; then
    echo "Bundled voice exists: $name"
    return
  fi
  echo "Bundling Thai spoken voice: $name"
  local temp
  temp="$(mktemp --suffix=.wav)"
  curl --fail --location --silent --show-error --retry 3 --connect-timeout 15 --max-time 120 "$url" --output "$temp"
  test -s "$temp"
  file "$temp" || true
  python3 - "$temp" <<'PY'
import sys, os
path = sys.argv[1]
with open(path,"rb") as f:
    print("VOICE SOURCE HEADER:", repr(f.read(80)), "TOTAL BYTES:", os.path.getsize(path))
PY
  # HeyGen uses an MP3 bitstream even when the delivery URL ends in .wav.
  # Godot 4.4 imports MP3 directly and can play it on both Chrome and Safari.
  python3 - "$temp" "assets/audio/$name.mp3" <<'PY'
import sys, shutil
incoming, target = sys.argv[1:3]
with open(incoming, "rb") as source:
    header = source.read(4)
if not (header.startswith(b"ID3") or (header[0] == 255 and header[1] in (251, 243, 242))):
    raise ValueError("Expected MP3 speech; unexpected magic " + repr(header))
shutil.copyfile(incoming, target)
print("BUNDLED RECORDED MP3:", target)
PY
  test -s "assets/audio/$name.mp3"
  rm -f "$temp"
}
fetch_voice "voice_plant" "https://resource2.heygen.ai/text_to_speech/fb8b39b53629435a9d41f00ebcf18b29/1776ddbd05374fa480e92f0297bbc67e/id=04b9337c-138d-42b0-9d0d-4abc40b66822.wav"
fetch_voice "voice_water" "https://resource2.heygen.ai/text_to_speech/fb8b39b53629435a9d41f00ebcf18b29/1776ddbd05374fa480e92f0297bbc67e/id=6f24c915-a704-407b-a388-7e684eb1dc57.wav"
fetch_voice "voice_harvest" "https://resource2.heygen.ai/text_to_speech/fb8b39b53629435a9d41f00ebcf18b29/1776ddbd05374fa480e92f0297bbc67e/id=a7202da7-f967-45bf-87f6-efdbadca27c4.wav"
for track in farm_theme fx_till fx_plant fx_water fx_harvest fx_coin fx_pig fx_jump fx_step; do
  test -s "assets/audio/$track.wav"
done
for track in voice_plant voice_water voice_harvest; do
  test -s "assets/audio/$track.mp3"
done
echo "HAPPY FARM AUDIO ASSETS READY: theme, 8 Foley clips, 3 prerecorded Thai voices"
