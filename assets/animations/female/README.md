# FarmFlex — separated male/female animations

Put Mixamo **without skin** motion FBX files in this gender folder with exact names:

- Idle.fbx
- Walk.fbx
- Run.fbx
- Jump.fbx
- Water.fbx (watering plants)
- Dig.fbx (tilling/digging soil)

**Important:** select the original gender's rigged GLB (or a matching Mixamo character) when obtaining animations. Mixamo tracks must be compatible with the existing `mixamorig:` Skeleton3D and imported by Godot 4.4.1. The engine automatically selects files in this folder first. Until these are provided it reuses the existing shared Idle/Walk/Run/Jump Mixamo FBX and plays built-in Water/Dig keyframes. Animation files downloaded on a player's personal computer are not accessible to this repository until uploaded.
