# GM Construction assets — FBX.zip

The user-provided `FBX.zip` contains **68 real binary FBX model files**.

- GM menu code: `scripts/GMProps.gd`, `scripts/Game.gd`.
- Categories: trees (20), bushes/grass (13), flowers/mushrooms (11), rocks (14), stone paths (10).
- Source paths: `assets/gm_models/<original_basename>.fbx`.
- No replacements or stock/procedural meshes are used for missing FBX models. An item without its exact imported asset is disabled in the GM chooser.
- Placement state saves to `gm_placed_props` with the original file name, X/Z, yaw and scale. Keep the original model filenames.

## Import once

1. Unzip `FarmFlex_GM_68_FBX_Import.zip` supplied with the assistant's delivery.
2. Upload the **`assets/gm_models/` folder contents** to this repository (main branch), preserving all 68 filenames and their paths. The zip is arranged to match the repo root.
3. The existing GitHub Actions pipeline imports FBX through Godot and exports the website on push.
4. Test on `https://redfullmoon209-debug.github.io/happy-farm/?gmtest=1`.
5. In the game choose **GM TEST → ปลูกสร้าง → category → model**. Click the terrain to place. Open GM again to choose move, rotate or delete.

## Security / limitations

`?gmtest=1` is a **temporary, insecure single-player testing switch**. It does not authenticate the studio owner. Remove it and replace with server-verified GM privileges before public multiplayer launch. World edits are kept in this browser's game save, **not synchronized to other players**. FBX materials may require further import adjustment if they reference external textures absent from the original ZIP.
