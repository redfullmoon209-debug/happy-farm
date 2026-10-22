extends Node3D
# Loads a real Mixamo-skinned FBX and merges matching animation tracks onto its
# one Skeleton3D. No retarget is needed because all uploaded clips have the
# same geometry and mixamorig bones. Missing assets use the existing farmer.

const BASE_PATH: String = "res://assets/characters/femalefarmer.fbx"
const ALBEDO_PATH: String = "res://assets/characters/female_color.png"
const CLIPS: Dictionary = {
    "Idle": "res://assets/characters/Idle.fbx",
    "Walk": "res://assets/characters/Walk.fbx",
    "Run": "res://assets/characters/Run.fbx",
    "Jump": "res://assets/characters/Jump.fbx"
}

var ready_to_animate: bool = false
var anim_player: AnimationPlayer
var skeleton: Skeleton3D
var current_state: String = ""
var imported_character: Node3D
var visual_scale: float = 1.0
var display_height: float = 0.0
var mesh_count: int = 0
const TARGET_HEIGHT: float = 1.90
# Mixamo source meshes face local +Z; the farm controller uses -Z as forward.
# Rotate only the imported visual (not the movement controller or the rig).
var visual_rotation_y: float = PI

func initialize() -> bool:
    if not ResourceLoader.exists(BASE_PATH):
        return false
    for filename in CLIPS.values():
        if not ResourceLoader.exists(str(filename)):
            push_warning("Missing FBX motion asset: " + str(filename))
            return false

    var scene_resource: Resource = ResourceLoader.load(BASE_PATH)
    if not (scene_resource is PackedScene):
        push_warning("The rigged farmer was not imported as a scene.")
        return false
    var created: Node = (scene_resource as PackedScene).instantiate()
    if not (created is Node3D):
        created.free()
        return false

    imported_character = created
    imported_character.name = "FemaleFarmerMixamo"
    # FBX conversion can shrink geometry 100x. Measure the imported mesh,
    # not the original FBX units, before hiding the procedural character.
    imported_character.scale = Vector3.ONE
    imported_character.rotation.y = visual_rotation_y
    add_child(imported_character)

    if not _fit_imported_mesh(imported_character):
        push_warning("Rigged FBX has no usable mesh bounds; use placeholder.")
        imported_character.queue_free()
        imported_character = null
        return false

    skeleton = _first_skeleton(imported_character)
    if skeleton == null:
        push_warning("No Skeleton3D in femalefarmer.fbx")
        imported_character.queue_free()
        imported_character = null
        return false

    _apply_albedo(imported_character)

    anim_player = AnimationPlayer.new()
    anim_player.name = "FarmAnimationPlayer"
    add_child(anim_player)
    anim_player.root_node = NodePath("..")

    var library: AnimationLibrary = AnimationLibrary.new()
    var states_loaded: int = 0
    for motion in ["Idle", "Walk", "Run", "Jump"]:
        if _load_clip(library, motion, str(CLIPS[motion])):
            states_loaded += 1

    if states_loaded != 4:
        push_warning("Mixamo character animations incomplete; using placeholder.")
        imported_character.queue_free()
        imported_character = null
        anim_player.queue_free()
        anim_player = null
        return false

    var result: Error = anim_player.add_animation_library("Farm", library)
    if result != OK:
        push_warning("Could not register the Mixamo animation library.")
        imported_character.queue_free()
        imported_character = null
        anim_player.queue_free()
        anim_player = null
        return false
    ready_to_animate = true
    set_state("Idle")
    return true

func _collect_meshes(node: Node, found: Array[MeshInstance3D]) -> void:
    if node is MeshInstance3D:
        var surface: MeshInstance3D = node as MeshInstance3D
        if surface.mesh != null and surface.mesh.get_surface_count() > 0:
            found.append(surface)
    for child in node.get_children():
        _collect_meshes(child, found)

func _fit_imported_mesh(avatar: Node3D) -> bool:
    var meshes: Array[MeshInstance3D] = []
    _collect_meshes(avatar, meshes)
    mesh_count = meshes.size()
    if mesh_count == 0:
        return false

    var low: Vector3 = Vector3(INF, INF, INF)
    var high: Vector3 = Vector3(-INF, -INF, -INF)
    var inverse_root: Transform3D = avatar.global_transform.affine_inverse()
    for obj in meshes:
        var bounds: AABB = (inverse_root * obj.global_transform) * obj.get_aabb()
        low = low.min(bounds.position)
        high = high.max(bounds.end)
    var imported_height: float = high.y - low.y
    if not is_finite(imported_height) or imported_height < 0.00001:
        return false

    # This FBX imports around 0.0118 units high in Godot, although its
    # source mesh is about 1.18 m. The previous scale 1.65 left it invisible.
    visual_scale = TARGET_HEIGHT / imported_height
    if visual_scale < 0.01 or visual_scale > 10000.0:
        return false
    avatar.scale = Vector3.ONE * visual_scale
    avatar.position = -Vector3(
        (low.x + high.x) * 0.5, low.y, (low.z + high.z) * 0.5
    ) * visual_scale
    display_height = imported_height * visual_scale
    print("FARMER VISUAL: meshes=", mesh_count,
        " raw_height=", imported_height,
        " fitted_height=", display_height,
        " scale=", visual_scale)
    return display_height >= 1.5 and display_height <= 2.4

func has_visible_avatar() -> bool:
    return mesh_count > 0 and display_height >= 1.5 and display_height <= 2.4

func _first_skeleton(node: Node) -> Skeleton3D:
    if node is Skeleton3D:
        return node
    for child in node.get_children():
        var found: Skeleton3D = _first_skeleton(child)
        if found != null:
            return found
    return null

func _first_player(node: Node) -> AnimationPlayer:
    if node is AnimationPlayer:
        return node
    for child in node.get_children():
        var found: AnimationPlayer = _first_player(child)
        if found != null:
            return found
    return null

func _apply_albedo(root: Node) -> void:
    if not ResourceLoader.exists(ALBEDO_PATH):
        return
    var texture_res: Resource = ResourceLoader.load(ALBEDO_PATH)
    if not (texture_res is Texture2D):
        return
    var material: StandardMaterial3D = StandardMaterial3D.new()
    material.albedo_texture = texture_res as Texture2D
    material.roughness = 0.90
    material.metallic = 0.0
    material.cull_mode = BaseMaterial3D.CULL_DISABLED
    _paint_meshes(root, material)

func _paint_meshes(node: Node, surface: Material) -> void:
    if node is MeshInstance3D:
        (node as MeshInstance3D).material_override = surface
    for child in node.get_children():
        _paint_meshes(child, surface)

func _matching_bone(path: NodePath) -> String:
    if skeleton == null or path.get_subname_count() == 0:
        return ""
    var whole: String = String(path)
    var last_token: String = whole.substr(whole.rfind(":") + 1).to_lower()
    if last_token.is_empty():
        return ""
    for i in range(skeleton.get_bone_count()):
        var bone_name: String = String(skeleton.get_bone_name(i))
        if whole.ends_with(":" + bone_name):
            return bone_name
        var bone_tail: String = bone_name.substr(bone_name.rfind(":") + 1).to_lower()
        if last_token == bone_tail:
            return bone_name
    return ""

func _load_clip(library: AnimationLibrary, state: String, fbx_path: String) -> bool:
    var scene_resource: Resource = ResourceLoader.load(fbx_path)
    if not (scene_resource is PackedScene):
        return false
    var instance: Node = (scene_resource as PackedScene).instantiate()
    var source_player: AnimationPlayer = _first_player(instance)
    if source_player == null or source_player.get_animation_list().size() == 0:
        instance.free()
        push_warning("No animations found inside " + fbx_path)
        return false

    # Godot's importer may add RESET before the actual Mixamo clip.
    # Choose a real motion with the greatest track count, not a reset pose.
    var animation: Animation = null
    var most_tracks: int = -1
    for anim_name in source_player.get_animation_list():
        if String(anim_name).to_upper().contains("RESET"):
            continue
        var candidate: Animation = source_player.get_animation(anim_name)
        if candidate != null and candidate.get_track_count() > most_tracks:
            animation = candidate
            most_tracks = candidate.get_track_count()
    if animation == null:
        instance.free()
        push_warning("No playback clip in " + fbx_path)
        return false
    var copy: Animation = animation.duplicate(true) as Animation
    var skeleton_path: String = String(get_path_to(skeleton))
    var animated_bone_tracks: int = 0

    for track in range(copy.get_track_count() - 1, -1, -1):
        var path: NodePath = copy.track_get_path(track)
        var bone_name: String = _matching_bone(path)
        if bone_name.is_empty():
            copy.remove_track(track)
            continue
        copy.track_set_path(track, NodePath(skeleton_path + ":" + bone_name))
        animated_bone_tracks += 1

    # This would otherwise leave the model permanently in bind pose.
    if animated_bone_tracks == 0:
        instance.free()
        push_warning("No matching Mixamo bone animation tracks in " + fbx_path)
        return false

    # Character translation is driven by our keyboard/joystick controller.
    # Skip hips position to avoid combining double root motion.
    if state == "Walk" or state == "Run":
        for track in range(copy.get_track_count() - 1, -1, -1):
            if copy.track_get_type(track) == Animation.TYPE_POSITION_3D:
                var bone_path: String = String(copy.track_get_path(track))
                if bone_path.ends_with(":Hips") or bone_path.ends_with(":mixamorig:Hips"):
                    copy.remove_track(track)

    copy.loop_mode = Animation.LOOP_NONE if state == "Jump" else Animation.LOOP_LINEAR
    var result: Error = library.add_animation(state, copy)
    instance.free()
    return result == OK

func set_state(state: String) -> void:
    if not ready_to_animate or anim_player == null:
        return
    if current_state == state and anim_player.is_playing():
        return
    if state not in CLIPS:
        state = "Idle"
    current_state = state
    var anim_name: String = "Farm/" + state
    if anim_player.has_animation(anim_name):
        anim_player.play(anim_name, 0.0 if state == "Jump" else 0.15, 1.0)

func is_model_ready() -> bool:
    return ready_to_animate
