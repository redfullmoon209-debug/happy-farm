extends Node
# Original Mixamo FBX animations provided in Male_Talking.zip (8 files).
# Their rotations must be retargeted through REST-POSE WORLD ROTATIONS rather
# than copied by bone name: the target GLBs have a different skeleton basis.
const ACTIONS: Array[String] = ["Idle", "Walk", "Run", "Talk", "Jump", "Water", "Dig"]
const PROVIDED: Array[String] = ["Idle", "Walk", "Run", "Talk"]
const SAMPLE_FPS: float = 60.0
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
        var probes := _sole_probes()
        if probes.is_empty():
            return false
        for state in PROVIDED:
            var path := "res://assets/animations/%s/%s.fbx" % [gender, state]
            if not ResourceLoader.exists(path) or not _retarget_original(library, state, path, probes):
                push_error("FarmFlex could not bind " + path)
                return false
            source_files[state] = path
            print("ORIGINAL MIXAMO PLAYBACK: ", gender, " ", state, " <- ", path)
        if not _retarget_original(library, "Jump", "res://assets/characters/Jump.fbx", probes):
            return false
        for state in ["Water", "Dig"]:
            var action := library.get_animation("Idle").duplicate() as Animation
            for track in action.get_track_count():
                if action.track_get_type(track) != Animation.TYPE_ROTATION_3D:
                    continue
                var name_text := str(action.track_get_path(track)).to_lower()
                var angle := 0.0
                if name_text.ends_with("rightarm"):
                    angle = -0.9 if state == "Dig" else -0.52
                elif name_text.ends_with("rightforearm"):
                    angle = 0.55 if state == "Dig" else 0.95
                elif name_text.ends_with("spine1"):
                    angle = 0.36 if state == "Dig" else 0.12
                if angle != 0:
                    for k in action.track_get_key_count(track):
                        var phase := action.track_get_key_time(track,k) / action.length
                        var pose: Quaternion = action.track_get_key_value(track,k)
                        action.track_set_key_value(track,k, pose * Quaternion(Vector3.RIGHT,angle*(0.5-0.5*cos(TAU*phase))))
            library.add_animation(state, action)
        libraries_by_gender[gender] = library
        paths_by_gender[gender] = source_files.duplicate()
    if player.add_animation_library("Farm", library) != OK:
        return false
    for state in ACTIONS:
        available[state] = player.has_animation("Farm/" + state)
    change_state("Idle")
    player.advance(0.0)
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
    if up.length_squared() < 1e-12 or side.length_squared() < 1e-12:
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

# Select the extremes of each sole from the actual skinned body. Using
# heel and toe vertices also supports tilted feet during push-off.
func _sole_probes() -> Dictionary:
    var probes := {}
    var lowest := {}
    var directions: Array[Vector3] = [Vector3.UP]
    for tilt in [0.5, 1.1, 1.48]:
        for direction in 8:
            var angle := TAU * direction / 8.0
            directions.append(Vector3(sin(tilt)*cos(angle), cos(tilt), sin(tilt)*sin(angle)))
    for node in host.find_children("Starter_shoes" if host.get("model_gender") == "female" else "*Master_Body*", "MeshInstance3D", true, false):
        var mesh := node as MeshInstance3D
        var skin := mesh.skin
        for surface in mesh.mesh.get_surface_count():
            var arrays := mesh.mesh.surface_get_arrays(surface)
            var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
            var bones: PackedInt32Array = arrays[Mesh.ARRAY_BONES]
            var weights: PackedFloat32Array = arrays[Mesh.ARRAY_WEIGHTS]
            var stride := bones.size() / vertices.size()
            for i in vertices.size():
                var strongest := i * stride
                for k in range(1,stride):
                    if weights[i*stride+k] > weights[strongest]:
                        strongest = i*stride+k
                var bind := bones[strongest]
                var id := skeleton.find_bone(skin.get_bind_name(bind))
                if id < 0:
                    id = skin.get_bind_bone(bind)
                var name_lower := str(skeleton.get_bone_name(id)).to_lower()
                if not ("foot" in name_lower or "toe" in name_lower):
                    continue
                var local_point := skin.get_bind_pose(bind) * vertices[i]
                var rest := host.to_local(skeleton.to_global(skeleton.get_bone_global_rest(id) * local_point))
                if not probes.has(id):
                    var samples := PackedVector3Array()
                    samples.resize(directions.size())
                    probes[id] = samples
                    var distances := PackedFloat32Array()
                    distances.resize(directions.size())
                    distances.fill(INF)
                    lowest[id] = distances
                for j in directions.size():
                    var height := rest.dot(directions[j])
                    if height < lowest[id][j]:
                        lowest[id][j] = height
                        probes[id][j] = local_point
    return probes

func _retarget_original(library: AnimationLibrary, state: String, filename: String, supports: Dictionary) -> bool:
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
    skeleton.reset_bone_poses()
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
    for target_idx in target_map.keys():
        var idx: int = int(target_idx)
        var bone_name: String = String(skeleton.get_bone_name(idx))
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
    var hips := _bone_with_suffix(skeleton, "hips")
    var position_track := animation.add_track(Animation.TYPE_POSITION_3D)
    animation.track_set_path(position_track, NodePath(String(host.get_path_to(skeleton)) + ":" + str(skeleton.get_bone_name(hips))))
    var hip_rest := skeleton.get_bone_rest(hips)
    var hip_parent := skeleton.get_bone_parent(hips)
    var parent_axes := skeleton.global_basis
    if hip_parent >= 0:
        parent_axes *= skeleton.get_bone_global_rest(hip_parent).basis
    var count: int = maxi(2, ceili(duration * SAMPLE_FPS) + 1)
    for frame in range(count):
        var t: float = minf(duration, float(frame) * duration / float(count - 1))
        donor_player.seek(t, true)
        for target_idx in tracks.keys():
            var idx: int = int(target_idx)
            var src_idx: int = int(target_map[idx])
            var source_pose: Quaternion = donor.get_bone_pose_rotation(src_idx)
            var mapping: Quaternion = conversion[idx]
            var src_rest := donor.get_bone_rest(src_idx).basis.get_rotation_quaternion()
            var tgt_rest := skeleton.get_bone_rest(idx).basis.get_rotation_quaternion()
            var target_rotation := (tgt_rest * mapping * src_rest.inverse() * source_pose * mapping.inverse()).normalized()
            skeleton.set_bone_pose_rotation(idx, target_rotation)
            animation.rotation_track_insert_key(int(tracks[idx]), t, target_rotation)
        var lowest := INF
        for id: int in supports:
            var posed := host.global_transform.affine_inverse() * skeleton.global_transform * skeleton.get_bone_global_pose(id)
            for point: Vector3 in supports[id]:
                lowest = minf(lowest, (posed * point).y)
        var lift := parent_axes.inverse() * (host.global_basis * Vector3.DOWN * lowest)
        animation.position_track_insert_key(position_track, t, hip_rest.origin + lift)
    skeleton.reset_bone_poses()
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
