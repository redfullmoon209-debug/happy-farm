extends Node
# FarmFlex: isolated Mixamo animation controller for each gender's GLB rig.
# Prefers assets/animations/{female,male}/NAME.fbx, then the existing shared
# Mixamo clips. Water/Dig have real generated keyframe fallbacks.
const ACTIONS = ["Idle", "Walk", "Run", "Jump", "Water", "Dig"]
# Source FBX rotations are expressed in a different rig's rest space. Direct
# bone-name remapping tips our Codex GLB's Hips over by 90 degrees (lying down).
# Keep those imports OFF until a proper rest-pose retarget and upright test exist.
# Generated rotations use our actual GLB skeleton and preserve its Y-up root.
const USE_DIRECT_MIXAMO_RETARGET: bool = false
# Emergency upright-safe playback: No bone rotation is applied to the imported
# Codex GLB until a valid rest-pose retarget is verified. This prevents lying
# flat and is reversible without modifying source meshes or character saves.
const PRESERVE_ORIGINAL_BIND_POSE: bool = false

var player: AnimationPlayer
var skeleton: Skeleton3D
var host: Node3D
var gender: String = "female"
var available: Dictionary = {}
var current_state: String = ""
var original_rotations: Dictionary = {}

func initialize(target_host: Node3D, target_skeleton: Skeleton3D, selected_gender: String) -> bool:
    if target_skeleton == null:
        push_warning("FarmFlex motion: no Skeleton3D on selected character")
        return false
    host = target_host
    skeleton = target_skeleton
    # Capture the CORRECT GLB bind-pose rotations before any animation plays.
    # The initial pose is not identity: setting all bones to Quaternion.IDENTITY
    # flips the character onto its back.
    original_rotations.clear()
    for index in range(skeleton.get_bone_count()):
        original_rotations[index] = skeleton.get_bone_pose_rotation(index)
    gender = "male" if selected_gender == "male" else "female"
    player = AnimationPlayer.new()
    player.name = "FarmFlex_%s_AnimationPlayer" % gender
    host.add_child(player)
    player.root_node = NodePath("..")
    var library: AnimationLibrary = AnimationLibrary.new()
    var skeleton_path: String = String(host.get_path_to(skeleton))
    for state in ACTIONS:
        if PRESERVE_ORIGINAL_BIND_POSE:
            # Keep these state names active for the farm tool UI, but an empty
            # animation never changes skeleton axes, keeping the base pose upright.
            var safe_clip: Animation = Animation.new()
            safe_clip.length = 1.0
            safe_clip.loop_mode = Animation.LOOP_NONE if state == "Jump" else Animation.LOOP_LINEAR
            available[state] = library.add_animation(state, safe_clip) == OK
            print("FARMFLEX MOTION: ", gender, " ", state, " (upright safety pose; awaiting correct retarget)")
            continue
        var source: String = _clip_for(state)
        var loaded: bool = false
        if USE_DIRECT_MIXAMO_RETARGET and not source.is_empty():
            loaded = _import_mixamo(library, state, source, skeleton_path)
        elif not source.is_empty():
            # Do not apply an unrelated FBX Hips rotation onto this GLB.
            # It can rotate the entire skinned mesh onto the ground.
            if gender == "female" and state == "Idle":
                print("FARMFLEX MOTION: source FBX retarget disabled for upright GLB safety")
        if not loaded:
            loaded = _add_generated_clip(library, state, skeleton_path)
            if loaded:
                print("FARMFLEX MOTION: ", gender, " ", state, " (built-in keyframes)")
        else:
            print("FARMFLEX MOTION: ", gender, " ", state, " => ", source)
        available[state] = loaded
    if player.add_animation_library("Farm", library) != OK:
        return false
    change_state("Idle")
    return true

func _clip_for(state: String) -> String:
    var own_folder: String = "res://assets/animations/%s/" % gender
    for extension in [".fbx", ".glb"]:
        var own_path: String = own_folder + state + extension
        if ResourceLoader.exists(own_path):
            return own_path
    # Existing compatible Mixamo clips in this repository; they share the
    # mixamorig skeleton and are only fallbacks until gender-specific files arrive.
    if state in ["Idle", "Walk", "Run", "Jump"]:
        var shared: String = "res://assets/characters/" + state + ".fbx"
        if ResourceLoader.exists(shared):
            return shared
    return ""

func _find_player(node: Node) -> AnimationPlayer:
    if node is AnimationPlayer:
        return node as AnimationPlayer
    for child in node.get_children():
        var player_found: AnimationPlayer = _find_player(child)
        if player_found != null:
            return player_found
    return null

func _bone_matching(path: NodePath) -> String:
    var value: String = String(path)
    var pos: int = value.rfind(":")
    if pos < 0:
        return ""
    var last: String = value.substr(pos + 1).to_lower()
    for index in range(skeleton.get_bone_count()):
        var name: String = String(skeleton.get_bone_name(index))
        if name.to_lower() == last or name.to_lower().ends_with(":" + last):
            return name
    return ""

func _import_mixamo(library: AnimationLibrary, state: String, filename: String, sk_path: String) -> bool:
    var resource: Resource = ResourceLoader.load(filename)
    if not (resource is PackedScene):
        return false
    var instance: Node = (resource as PackedScene).instantiate()
    if instance == null:
        return false
    var source_player: AnimationPlayer = _find_player(instance)
    if source_player == null:
        instance.free()
        return false
    var chosen: Animation = null
    var best_tracks: int = 0
    for name in source_player.get_animation_list():
        if String(name).to_upper().contains("RESET"):
            continue
        var candidate: Animation = source_player.get_animation(name)
        if candidate != null and candidate.get_track_count() > best_tracks:
            best_tracks = candidate.get_track_count()
            chosen = candidate
    if chosen == null:
        instance.free()
        return false
    var converted: Animation = chosen.duplicate(true) as Animation
    var valid: int = 0
    for i in range(converted.get_track_count() - 1, -1, -1):
        var bone_name: String = _bone_matching(converted.track_get_path(i))
        var track_type: int = converted.track_get_type(i)
        if bone_name.is_empty() or track_type not in [Animation.TYPE_ROTATION_3D, Animation.TYPE_POSITION_3D, Animation.TYPE_SCALE_3D]:
            converted.remove_track(i)
            continue
        # The farm movement controller owns height and world translation.
        # Mixamo Hips position tracks would make tiny characters float.
        if track_type == Animation.TYPE_POSITION_3D and bone_name.ends_with("Hips"):
            converted.remove_track(i)
            continue
        converted.track_set_path(i, NodePath(sk_path + ":" + bone_name))
        valid += 1
    instance.free()
    if valid < 5:
        return false
    converted.loop_mode = Animation.LOOP_NONE if state == "Jump" else Animation.LOOP_LINEAR
    return library.add_animation(state, converted) == OK

# An upright procedural fallback for the actual Codex skeleton. We NEVER
# animate Hips, Spine, Head or Armature and never use FBX rotations on a
# foreign GLB rest pose. All six states key the same limited appendage set.
func _joint(suffix: String) -> int:
    for i in range(skeleton.get_bone_count()):
        if String(skeleton.get_bone_name(i)).to_lower().ends_with(suffix.to_lower()):
            return i
    return -1

func _bone_axis(index: int, world_axis: Vector3) -> Vector3:
    if index < 0:
        return Vector3.RIGHT
    # Local-bone axis yielding a desired movement in Y-up world coordinates.
    var joint_basis: Basis = (skeleton.global_basis * skeleton.get_bone_global_pose(index).basis).orthonormalized()
    return (joint_basis.inverse() * world_axis).normalized()

func _arm_drop_axis(arm_index: int, elbow_index: int) -> Vector3:
    if arm_index < 0 or elbow_index < 0:
        return Vector3.FORWARD
    var origin: Vector3 = skeleton.to_global(skeleton.get_bone_global_pose(arm_index).origin)
    var tip: Vector3 = skeleton.to_global(skeleton.get_bone_global_pose(elbow_index).origin)
    var direction: Vector3 = tip - origin
    direction.y = 0.0
    if direction.length() < 0.0001:
        return Vector3.FORWARD
    # The axis is derived from the arm's actual direction, so a positive
    # rotation ALWAYS moves either outstretched hand toward the ground.
    return direction.normalized().cross(Vector3.DOWN).normalized()

func _add_upright_clip(library: AnimationLibrary, state: String, _sk_path: String) -> bool:
    var clip: Animation = Animation.new()
    var duration: float = 1.5
    if state == "Walk":
        duration = 0.85
    elif state == "Run":
        duration = 0.58
    elif state == "Jump":
        duration = 0.9
    elif state in ["Water", "Dig"]:
        duration = 1.25
    clip.length = duration
    clip.loop_mode = Animation.LOOP_NONE if state == "Jump" else Animation.LOOP_LINEAR
    var lt: int = _joint("LeftArm")
    var rt: int = _joint("RightArm")
    var joints: Dictionary = {
        "LeftArm": lt, "RightArm": rt,
        "LeftForeArm": _joint("LeftForeArm"),
        "RightForeArm": _joint("RightForeArm"),
        "LeftUpLeg": _joint("LeftUpLeg"),
        "RightUpLeg": _joint("RightUpLeg"),
        "LeftLeg": _joint("LeftLeg"),
        "RightLeg": _joint("RightLeg")
    }
    var left_drop: Vector3 = _arm_drop_axis(lt, joints["LeftForeArm"])
    var right_drop: Vector3 = _arm_drop_axis(rt, joints["RightForeArm"])
    for joint_name in joints:
        var index: int = int(joints[joint_name])
        if index < 0:
            continue
        var track: int = clip.add_track(Animation.TYPE_ROTATION_3D)
        clip.track_set_path(track, NodePath(String(host.get_path_to(skeleton)) + ":" + String(skeleton.get_bone_name(index))))
        var base: Quaternion = original_rotations.get(index, Quaternion.IDENTITY)
        for f in range(9):
            var tt: float = duration * float(f) / 8.0
            var wave: float = sin(TAU * float(f) / 8.0)
            var drop: float = 58.0 if gender == "male" else 52.0
            var swing: float = 0.0
            var bend: float = 0.0
            if joint_name.ends_with("Arm") and not joint_name.ends_with("ForeArm"):
                if state == "Idle":
                    swing = 1.3 * wave
                elif state == "Walk":
                    swing = (8.0 if joint_name == "LeftArm" else -8.0) * wave
                elif state == "Run":
                    drop = 64.0
                    swing = (16.0 if joint_name == "LeftArm" else -16.0) * wave
                elif state == "Jump":
                    drop = 43.0 - 6.0 * sin(PI * float(f) / 8.0)
                    swing = -12.0
                elif state == "Water":
                    drop = 48.0 if joint_name == "RightArm" else 67.0
                    swing = (-15.0 - 10.0 * wave) if joint_name == "RightArm" else 0.0
                elif state == "Dig":
                    drop = 43.0 if joint_name == "RightArm" else 50.0
                    swing = -19.0 * wave
                var drop_axis: Vector3 = left_drop if joint_name == "LeftArm" else right_drop
                var drop_local: Vector3 = _bone_axis(index, drop_axis)
                var swing_local: Vector3 = _bone_axis(index, Vector3.RIGHT)
                var result: Quaternion = base * Quaternion(drop_local, deg_to_rad(drop)) * Quaternion(swing_local, deg_to_rad(swing))
                clip.rotation_track_insert_key(track, tt, result.normalized())
                continue
            if joint_name.ends_with("ForeArm"):
                if state == "Water":
                    bend = (20.0 + 7.0 * wave) if joint_name == "RightForeArm" else 7.0
                elif state == "Dig":
                    bend = 25.0 + 8.0 * wave
                else:
                    bend = 8.0 if state in ["Idle", "Walk", "Run"] else 14.0
            elif joint_name.ends_with("UpLeg"):
                var alternate: float = 1.0 if joint_name == "LeftUpLeg" else -1.0
                if state == "Walk":
                    bend = alternate * 9.0 * wave
                elif state == "Run":
                    bend = alternate * 17.0 * wave
                elif state == "Jump":
                    bend = alternate * 7.0 * sin(PI * float(f) / 8.0)
                elif state == "Dig":
                    bend = alternate * 3.0
            elif joint_name.ends_with("Leg"):
                if state == "Run":
                    bend = 10.0 * maxf(0.0, wave)
                elif state == "Walk":
                    bend = 5.0 * maxf(0.0, wave)
            var local_axis: Vector3 = _bone_axis(index, Vector3.RIGHT)
            clip.rotation_track_insert_key(track, tt, (base * Quaternion(local_axis, deg_to_rad(bend))).normalized())
    if clip.get_track_count() < 4:
        push_warning("FarmFlex upright clip: missing expected arm/leg bones")
        return false
    return library.add_animation(state, clip) == OK

func _add_generated_clip(library: AnimationLibrary, state: String, sk_path: String) -> bool:
    return _add_upright_clip(library, state, sk_path)

func change_state(state: String) -> void:
    if not available.get(state, false):
        state = "Idle"
    if player == null or not player.has_animation("Farm/" + state):
        return
    if current_state == state and player.is_playing():
        return
    current_state = state
    player.play("Farm/" + state, 0.16 if state != "Jump" else 0.05)
