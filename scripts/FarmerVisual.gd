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
var visual_scale: float = 1.65
var visual_rotation_y: float = 0.0

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
    imported_character.scale = Vector3.ONE * visual_scale
    imported_character.rotation.y = visual_rotation_y
    add_child(imported_character)

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
    material.albedo_texture = texture_res
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

    var animation: Animation = source_player.get_animation(source_player.get_animation_list()[0])
    if animation == null:
        instance.free()
        return false
    var copy: Animation = animation.duplicate(true)
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
