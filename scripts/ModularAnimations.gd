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
const PRESERVE_ORIGINAL_BIND_POSE: bool = true

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

func _add_rotation(clip: Animation, sk_path: String, tail: String, axis: Vector3, times: Array, angles: Array) -> void:
    var bone: String = ""
    var bone_index: int = -1
    for i in range(skeleton.get_bone_count()):
        var name: String = String(skeleton.get_bone_name(i))
        # Godot GLB imports may spell Mixamo bones as "mixamorigRightArm",
        # "mixamorig_RightArm" or "mixamorig:RightArm".
        if name.to_lower().ends_with(tail.to_lower()):
            bone = name
            bone_index = i
            break
    if bone_index < 0:
        return
    var track: int = clip.add_track(Animation.TYPE_ROTATION_3D)
    clip.track_set_path(track, NodePath(sk_path + ":" + bone))
    var base_rotation: Quaternion = original_rotations.get(bone_index, Quaternion.IDENTITY)
    for j in range(mini(times.size(), angles.size())):
        clip.rotation_track_insert_key(track, float(times[j]), base_rotation * Quaternion(axis, deg_to_rad(float(angles[j]))))

func _add_generated_clip(library: AnimationLibrary, state: String, sk_path: String) -> bool:
    var anim: Animation = Animation.new()
    anim.length = 1.2
    anim.loop_mode = Animation.LOOP_NONE if state == "Jump" else Animation.LOOP_LINEAR
    # Root/Hips are deliberately never keyed: the GLB's upright rest axes
    # and the farm controller own world translation and orientation.
    var sex_tone: float = 0.82 if gender == "female" else 1.0
    var t: Array = [0.0, 0.3, 0.6, 0.9, 1.2]
    if state == "Water":
        _add_rotation(anim, sk_path, "Spine", Vector3.RIGHT, t, [0.0, 5.0, 9.0, 5.0, 0.0])
        _add_rotation(anim, sk_path, "RightArm", Vector3.RIGHT, t, [-25.0, -44.0*sex_tone, -58.0*sex_tone, -44.0*sex_tone, -25.0])
        _add_rotation(anim, sk_path, "RightForeArm", Vector3.RIGHT, t, [18.0, 31.0, 45.0, 31.0, 18.0])
        _add_rotation(anim, sk_path, "RightHand", Vector3.FORWARD, t, [0.0, -22.0, -42.0, -22.0, 0.0])
        _add_rotation(anim, sk_path, "LeftArm", Vector3.RIGHT, t, [0.0, -12.0, -17.0, -12.0, 0.0])
    elif state == "Dig":
        _add_rotation(anim, sk_path, "Spine", Vector3.RIGHT, t, [0.0, 4.0, 8.0, 4.0, 0.0])
        _add_rotation(anim, sk_path, "RightArm", Vector3.RIGHT, t, [-55.0, -30.0, 24.0, -30.0, -55.0])
        _add_rotation(anim, sk_path, "RightForeArm", Vector3.RIGHT, t, [38.0, 42.0, 62.0, 42.0, 38.0])
        _add_rotation(anim, sk_path, "LeftArm", Vector3.RIGHT, t, [-30.0, -15.0, 12.0, -15.0, -30.0])
        _add_rotation(anim, sk_path, "LeftForeArm", Vector3.RIGHT, t, [15.0, 30.0, 45.0, 30.0, 15.0])
    elif state == "Idle":
        _add_rotation(anim, sk_path, "RightArm", Vector3.FORWARD, t, [35.0, 37.0, 38.0, 37.0, 35.0])
        _add_rotation(anim, sk_path, "LeftArm", Vector3.FORWARD, t, [-35.0, -37.0, -38.0, -37.0, -35.0])
        _add_rotation(anim, sk_path, "Spine", Vector3.RIGHT, t, [0.0, 1.0, 2.0, 1.0, 0.0])
    elif state in ["Walk", "Run"]:
        var amount: float = 12.0 if state == "Walk" else 18.0
        _add_rotation(anim, sk_path, "LeftUpLeg", Vector3.RIGHT, t, [-amount, 0.0, amount, 0.0, -amount])
        _add_rotation(anim, sk_path, "RightUpLeg", Vector3.RIGHT, t, [amount, 0.0, -amount, 0.0, amount])
        _add_rotation(anim, sk_path, "LeftArm", Vector3.RIGHT, t, [amount*0.6, 0.0, -amount*0.6, 0.0, amount*0.6])
        _add_rotation(anim, sk_path, "RightArm", Vector3.RIGHT, t, [-amount*0.6, 0.0, amount*0.6, 0.0, -amount*0.6])
    elif state == "Jump":
        _add_rotation(anim, sk_path, "LeftUpLeg", Vector3.RIGHT, t, [0.0, 8.0, 12.0, 8.0, 0.0])
        _add_rotation(anim, sk_path, "RightUpLeg", Vector3.RIGHT, t, [0.0, -7.0, -11.0, -7.0, 0.0])
        _add_rotation(anim, sk_path, "LeftArm", Vector3.RIGHT, t, [0.0, -30.0, -48.0, -30.0, 0.0])
        _add_rotation(anim, sk_path, "RightArm", Vector3.RIGHT, t, [0.0, -30.0, -48.0, -30.0, 0.0])
    # Tracks must cover the whole skeleton, otherwise Godot leaves rotations
    # from the preceding Walk/Run/Jump state on bones missing from Water/Dig.
    # Every animation is now self-contained and returns to upright rest pose.
    for i in range(skeleton.get_bone_count()):
        var full_path: NodePath = NodePath(sk_path + ":" + String(skeleton.get_bone_name(i)))
        if anim.find_track(full_path, Animation.TYPE_ROTATION_3D) >= 0:
            continue
        var neutral_track: int = anim.add_track(Animation.TYPE_ROTATION_3D)
        anim.track_set_path(neutral_track, full_path)
        var initial_rotation: Quaternion = original_rotations.get(i, Quaternion.IDENTITY)
        anim.rotation_track_insert_key(neutral_track, 0.0, initial_rotation)
        anim.rotation_track_insert_key(neutral_track, anim.length, initial_rotation)
    if anim.get_track_count() == 0:
        return false
    return library.add_animation(state, anim) == OK

func change_state(state: String) -> void:
    if not available.get(state, false):
        state = "Idle"
    if player == null or not player.has_animation("Farm/" + state):
        return
    if current_state == state and player.is_playing():
        return
    current_state = state
    player.play("Farm/" + state, 0.16 if state != "Jump" else 0.05)
