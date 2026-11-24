extends Node
# Original Mixamo FBX animations provided in Male_Talking.zip (8 files).
# Their rotations must be retargeted through REST-POSE WORLD ROTATIONS rather
# than copied by bone name: the target GLBs have a different skeleton basis.
const ACTIONS: Array[String] = ["Idle", "Walk", "Run", "Talk", "Jump", "Water", "Dig"]
const PROVIDED: Array[String] = ["Idle", "Walk", "Run", "Talk"]
const SAMPLE_FPS: float = 18.0
static var libraries_by_gender: Dictionary = {}
static var paths_by_gender: Dictionary = {}

var player: AnimationPlayer
var skeleton: Skeleton3D
var host: Node3D
var gender: String = "female"
var available: Dictionary = {}
var source_files: Dictionary = {}
var current_state: String = ""

func initialize(target_host: Node3D, target_skeleton: Skeleton3D, selected_gender: String) -> bool:
    if target_skeleton == null:
        return false
    host = target_host
    skeleton = target_skeleton
    gender = "male" if selected_gender == "male" else "female"
    player = AnimationPlayer.new()
    player.name = "FarmFlex_%s_AnimationPlayer" % gender
    host.add_child(player)
    player.root_node = NodePath("..")
    var library: AnimationLibrary = null
    if libraries_by_gender.has(gender):
        library = libraries_by_gender[gender] as AnimationLibrary
        source_files = (paths_by_gender.get(gender, {}) as Dictionary).duplicate()
    else:
        library = AnimationLibrary.new()
        for state in ACTIONS:
            var imported: bool = false
            if state in PROVIDED:
                var path: String = "res://assets/animations/%s/%s.fbx" % [gender, state]
                if ResourceLoader.exists(path):
                    imported = _retarget_original(library, state, path)
                    if imported:
                        source_files[state] = path
                        print("ORIGINAL MIXAMO PLAYBACK: ", gender, " ", state, " <- ", path)
                if not imported:
                    push_error("FarmFlex missing user-supplied %s %s Mixamo animation" % [gender, state])
                    return false
            else:
                # There were NO Jump, Water, Dig clips in the user's upload.
                # Keep the game state functional, but do not invent substitute
                # gestures and do not pass off procedural motion as the source.
                var hold: Animation = Animation.new()
                hold.length = 0.5
                hold.loop_mode = Animation.LOOP_NONE if state == "Jump" else Animation.LOOP_LINEAR
                if library.add_animation(state, hold) != OK:
                    return false
        libraries_by_gender[gender] = library
        paths_by_gender[gender] = source_files.duplicate()
    if player.add_animation_library("Farm", library) != OK:
        return false
    for state in ACTIONS:
        available[state] = player.has_animation("Farm/" + state)
    change_state("Idle")
    return true

func _find_node_by_class(n: Node, expected_class: String) -> Node:
    if n.is_class(expected_class):
        return n
    for child in n.get_children():
        var found: Node = _find_node_by_class(child, expected_class)
        if found != null:
            return found
    return null

func _normalized_bone_name(value: String) -> String:
    var text_value: String = value.to_lower()
    text_value = text_value.replace("mixamorig", "").replace(":", "").replace("_", "").replace(" ", "")
    return text_value

func _bone_with_suffix(rig: Skeleton3D, suffix: String) -> int:
    for i in range(rig.get_bone_count()):
        if _normalized_bone_name(String(rig.get_bone_name(i))) == suffix.to_lower():
            return i
    return -1

func _landmark_frame(rig: Skeleton3D) -> Basis:
    var head: int = _bone_with_suffix(rig, "head")
    var hip: int = _bone_with_suffix(rig, "hips")
    var left: int = _bone_with_suffix(rig, "leftarm")
    var right: int = _bone_with_suffix(rig, "rightarm")
    if head < 0 or hip < 0 or left < 0 or right < 0:
        return Basis.IDENTITY
    var up: Vector3 = rig.to_global(rig.get_bone_global_rest(head).origin) - rig.to_global(rig.get_bone_global_rest(hip).origin)
    var side: Vector3 = rig.to_global(rig.get_bone_global_rest(right).origin) - rig.to_global(rig.get_bone_global_rest(left).origin)
    if up.length() < 0.01 or side.length() < 0.01:
        return Basis.IDENTITY
    up = up.normalized()
    side = (side - up * side.dot(up)).normalized()
    var forward: Vector3 = side.cross(up).normalized()
    side = up.cross(forward).normalized()
    return Basis(side, up, forward).orthonormalized()

func _chosen_clip(src_player: AnimationPlayer) -> String:
    var best_name: String = ""
    var max_tracks: int = 0
    for name in src_player.get_animation_list():
        if String(name).to_upper().contains("RESET"):
            continue
        var candidate: Animation = src_player.get_animation(name)
        if candidate != null and candidate.get_track_count() > max_tracks:
            max_tracks = candidate.get_track_count()
            best_name = str(name)
    return best_name if max_tracks > 5 else ""

func _retarget_original(library: AnimationLibrary, state: String, filename: String) -> bool:
    var resource: Resource = ResourceLoader.load(filename)
    if not (resource is PackedScene):
        return false
    var instance: Node = (resource as PackedScene).instantiate()
    if not (instance is Node3D):
        instance.free()
        return false
    host.add_child(instance)
    (instance as Node3D).visible = false
    var donor_player: AnimationPlayer = _find_node_by_class(instance, "AnimationPlayer") as AnimationPlayer
    var donor: Skeleton3D = _find_node_by_class(instance, "Skeleton3D") as Skeleton3D
    if donor_player == null or donor == null:
        instance.queue_free()
        return false
    var clip_name: String = _chosen_clip(donor_player)
    if clip_name.is_empty():
        instance.queue_free()
        return false
    var source_clip: Animation = donor_player.get_animation(clip_name)
    var duration: float = source_clip.length
    if duration <= 0.0 or duration > 60.0:
        instance.queue_free()
        return false
    var donor_map: Dictionary = {}
    for s_idx in range(donor.get_bone_count()):
        donor_map[_normalized_bone_name(String(donor.get_bone_name(s_idx)))] = s_idx
    var target_map: Dictionary = {}
    for t_idx in range(skeleton.get_bone_count()):
        var clean: String = _normalized_bone_name(String(skeleton.get_bone_name(t_idx)))
        if donor_map.has(clean):
            target_map[t_idx] = donor_map[clean]
    if target_map.size() < 15:
        push_error("FarmFlex retarget: too few matching skeleton bones: " + str(target_map.size()))
        instance.queue_free()
        return false
    donor_player.play(clip_name)
    donor_player.seek(0.0, true)
    var donor_basis: Basis = donor.global_basis.orthonormalized()
    var target_basis: Basis = skeleton.global_basis.orthonormalized()
    var alignment: Basis = _landmark_frame(skeleton) * _landmark_frame(donor).inverse()
    alignment = alignment.orthonormalized()
    var animation: Animation = Animation.new()
    animation.length = duration
    animation.loop_mode = Animation.LOOP_LINEAR
    var tracks: Dictionary = {}
    var conversion: Dictionary = {}
    # Original FBX movement only: drive appendages, never the imported Codex
    # GLB's Hips/Spine/Neck/Head or root. FBX global skeleton rotations
    # produce 90-degree offsets on this model, even with a name match.
    for target_idx in target_map.keys():
        var idx: int = int(target_idx)
        var bone_name: String = String(skeleton.get_bone_name(idx))
        var canonical: String = _normalized_bone_name(bone_name)
        if not (canonical.begins_with("left") or canonical.begins_with("right")):
            continue
        var src_idx: int = int(target_map[idx])
        var tr: int = animation.add_track(Animation.TYPE_ROTATION_3D)
        animation.track_set_path(tr, NodePath(String(host.get_path_to(skeleton)) + ":" + bone_name))
        tracks[idx] = tr
        # Converts a source BONE-LOCAL pose delta into the target bone's local
        # orientation, retaining the actual original source keyframe motion.
        var src_rest_world: Basis = donor_basis * donor.get_bone_global_rest(src_idx).basis.orthonormalized()
        var tgt_rest_world: Basis = target_basis * skeleton.get_bone_global_rest(idx).basis.orthonormalized()
        var change_of_basis: Basis = tgt_rest_world.inverse() * alignment * src_rest_world
        conversion[idx] = change_of_basis.orthonormalized().get_rotation_quaternion()
    var count: int = maxi(2, ceili(duration * SAMPLE_FPS) + 1)
    for frame in range(count):
        var t: float = minf(duration, float(frame) * duration / float(count - 1))
        donor_player.seek(t, true)
        for target_idx in tracks.keys():
            var idx: int = int(target_idx)
            var src_idx: int = int(target_map[idx])
            var source_pose: Quaternion = donor.get_bone_pose_rotation(src_idx)
            var mapping: Quaternion = conversion[idx]
            var target_rotation: Quaternion = (mapping * source_pose * mapping.inverse()).normalized()
            animation.rotation_track_insert_key(int(tracks[idx]), t, target_rotation)
    instance.queue_free()
    if animation.get_track_count() < 10:
        return false
    return library.add_animation(state, animation) == OK

func change_state(state: String) -> void:
    if not available.get(state, false):
        state = "Idle"
    if player == null or not player.has_animation("Farm/" + state):
        return
    if current_state == state and player.is_playing():
        return
    current_state = state
    player.play("Farm/" + state, 0.18 if state != "Jump" else 0.05)
