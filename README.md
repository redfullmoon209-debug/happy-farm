# Happy Farm - Clean 3D Rebuild

A new Godot 4.4.1 project written from scratch on 22 October 2026.

## What you can play
- Procedurally modeled, warm low-poly farm with farmer, trees, house, 50 raised garden beds (10 columns × 5 rows) plus expandable pig pens and pigs.
- Tap/click a garden plot: the farmer walks to the plot and tills, plants, waters, or harvests.
- Plants visibly grow over time and show splash effects.
- WASD to move, Shift to run, Space to jump.
- Free-roam 360-degree left joystick on phones with independent Run and Jump buttons.
- When the character asset ZIP is installed, the procedural avatar is replaced by the rigged female Mixamo model; uploaded Idle, Walking, Fast Run and Jumping Up clips animate the model.
- Right-mouse drag to orbit the camera, mouse wheel to zoom.
- Mobile: drag the left joystick to move, buttons to run and jump. Swipe empty ground to orbit camera; pinch empty ground to zoom.
- Shop to buy seeds and pig feed, expand pig pens (up to four pens) and buy new pigs (up to four per pen, 16 total).
- The starter pen holds four pigs; buying more pens immediately adds a fenced 3D pen, and buying pigs adds visible animated pigs.
- The first additional pen costs 150 coins; later pens cost more. Each pig costs 90 coins.
- Your existing 24-plot save automatically expands to 50 without losing planted crops, seeds, money or pigs.
- Autosaves, browser save status, downloadable JSON backup and confirmation before restoring backups.

## Camera and multitouch

- Spread two fingers on the world to zoom in; bring them together to zoom out.
  The orthographic camera and its position update together. Zoom is bounded to
  6–78 world units: close views follow the farmer, while the far view fits all
  50 beds at the default orbit on PC, landscape phones and portrait phones.
- Drag one world finger to orbit. A short single tap works a plot only on
  release; a drag, pinch or canceled gesture never becomes a plot tap.
- Each finger keeps the control it started on until release. Hold the joystick
  to walk while another finger orbits, or use two other fingers to pinch.
  Run, Jump and +/− accept their own fingers, including secondary touches.
- Touches starting on UI stay out of camera gestures. Shop/restore dialogs,
  inventory visibility changes, focus loss and screen resizing cancel active
  gestures so late releases cannot trigger farm work or leave the stick held.
- PC mouse wheel, right-button orbit, mouse joystick and +/− remain available.

Run the regression suite with Godot **4.4.1**, after importing the project:

```bash
godot --headless --path . --editor --quit
godot --headless --path . --script res://tools/test_camera.gd
```

The suite uses the real Input/Viewport pipeline with touch-to-mouse emulation
enabled. It checks finger ownership, pinch direction/limits, UI/plot separation,
interruptions, PC controls and projected bounds of all 50 beds. GitHub Actions
runs it before Web Export.

**iPhone device checks still required:** in Safari, try both orientations,
joystick + pinch + Run/Jump, lifting either pinch finger, and switching away
from Safari while fingers are down. Confirm the game zooms without page zoom
or accidental planting, and that the +/− fallback works. Automated/headless
tests and a successful Web Export do not establish real iPhone behavior.

## Preview on GitHub Codespaces
Open this repository in Codespaces and run:

```bash
bash tools/run_port.sh
```

Open the **Ports** tab > **8080** > **Open in Browser**.

## Notes
This is a clean, separate project. No previous game scripts or FBX models are used. The current 3D farmer is a lightweight placeholder; you can replace it with your Mixamo FBX later. A generic open-source Thai font asset is included for readability.

## Files
- `scripts/Game.gd`: entire gameplay, level and camera.
- `scripts/Joystick.gd`: multi-touch analog joystick.
- `scripts/BadgeIcon.gd`: vector icons.
- `scenes/Main.tscn`: clean scene.

## Install the supplied Mixamo farmer (one time)

The supplied avatar and animation files are binary, so they are distributed
as a standalone downloadable ZIP to the owner. No avatar source files are
required for the fallback model and CI to work.

1. Download `HappyFarm_Mixamo_Farmer.zip` from the ChatGPT conversation.
2. Open the Happy Farm GitHub Codespaces workspace; in the VS Code file
   explorer, upload that ZIP to the root of the repository.
3. In Codespaces Terminal execute:

```bash
git pull --ff-only origin main
bash tools/install_farmer.sh
```

The installer unpacks the 5 skinned Mixamo FBX scenes and optimized color,
normal, roughness and metallic maps to `assets/characters/`, commits
and pushes them to the GitHub repository. After GitHub Actions publishes,
the avatar loads with idle, walk, run and jump motions. The same avatar is
controlled by WASD/Shift/Space on PCs and the multitouch joystick/Run/Jump
on mobile browsers. Tap plots to walk to farming tasks.

## Animations and visuals

- `scripts/FarmerVisual.gd`: imports one Mixamo skeleton and copies
  animation tracks from matched FBX clips to its skeleton.
- The color texture is extracted from the user's second, non-rigged
  `femalefarmer(1).fbx` and optimized for mobile.
- The original Mixamo rig has 41 model nodes and 34 skin clusters.
- In case assets are missing or fail to import, the game keeps the existing
  procedural farmer instead of crashing.
- The joystick does not consume right-hand touches; a second finger can
  interact with the camera and independent buttons.


## Original music, interactive sound and Thai farmer voice

Happy Farm uses a custom synthesized 8-bar background theme composed in
`tools/build_audio.py` (no copyrighted third-party tune) and eight matching
Foley effects for hoeing, planting, watering, harvesting, purchasing, pig oinks,
jumping and walking. The same soundtrack automatically loops in Chrome and
mobile browsers. The `FarmAudio.gd` controller fades the music during speech.

Recorded female Thai voice lines, generated for this project and stored locally
in `assets/audio/voice_*.mp3`, are:

- Idle near empty, plantable beds: "โอ๊ย ฉันอยากปลูกผักจังเลย"
- Immediately after planting or beside a planted but dry bed: "รดน้ำหน่อยจ้า"
- When crops are ripe nearby or just harvested: "เก็บเกี่ยวได้แล้วจ้า เอาไปขายจ้า"

Speech has per-event cooldowns to avoid repetitive announcements and clear
on-screen subtitles. A dedicated **เปิดเสียง / เสียง: เปิด / เสียง: ปิด**
button appears beside the save status, and audio preferences persist separately
from farm save data in `user://happy_farm_audio.cfg`.

**Browser note:** Chrome, Safari and many mobile platforms prevent background
sound from starting without a user interaction. Tap the game, joystick,
sound button or a farm tool to start the music. Muting stops music, voice and
effects together, without affecting game saves or player progress.

Before Godot export, `tools/prepare_audio.sh` ensures all authored assets
are available. The first GitHub Actions build bundles the MP3 Thai recordings
and synthesizes the original theme and Foley. The build also attempts to store
the audio files permanently in GitHub, so future builds need no external audio
service. Run `bash tools/prepare_audio.sh` locally when building the game
from source for the first time.
