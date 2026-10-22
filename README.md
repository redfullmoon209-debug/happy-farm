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

