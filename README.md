# Happy Farm - Clean 3D Rebuild

A new Godot 4.4.1 project written from scratch on 22 October 2026.

## What you can play
- Procedurally modeled, warm low-poly farm with farmer, trees, house, 24 raised garden beds and pigs.
- Tap/click a garden plot: the farmer walks to the plot and tills, plants, waters, or harvests.
- Plants visibly grow over time and show splash effects.
- WASD to move, Shift to run, Space to jump.
- Right-mouse drag to orbit the camera, mouse wheel to zoom.
- Mobile: drag the left joystick to move, buttons to run and jump. Swipe empty ground to orbit camera; pinch empty ground to zoom.
- Shop to buy seeds and feed. Progress saved in your browser.

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
