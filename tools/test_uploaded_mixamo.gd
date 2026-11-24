extends SceneTree
# Validates the exact eight FBX files uploaded in Male_Talking.zip. Do not
# substitute procedural samples or other Mixamo files for these source clips.
const CLIPS: Array[String] = [
    "male/Idle.fbx", "male/Walk.fbx", "male/Run.fbx", "male/Talk.fbx",
    "female/Idle.fbx", "female/Walk.fbx", "female/Run.fbx", "female/Talk.fbx"
]

func _initialize() -> void:
    call_deferred("_validate")

func _find(n: Node, cls: String) -> Node:
    if n.is_class(cls):
        return n
    for ch in n.get_children():
        var result: Node = _find(ch, cls)
        if result != null:
            return result
    return null

func _validate() -> void:
    var bad: int = 0
    for rel_path in CLIPS:
        var path: String = "res://assets/animations/" + rel_path
        var packed: Resource = load(path)
        if not (packed is PackedScene):
            printerr("ORIGINAL MIXAMO MISSING: ", path)
            bad += 1
            continue
        var scene: Node = (packed as PackedScene).instantiate()
        var anim_player: AnimationPlayer = _find(scene, "AnimationPlayer") as AnimationPlayer
        var rig: Skeleton3D = _find(scene, "Skeleton3D") as Skeleton3D
        if anim_player == null or rig == null:
            printerr("ORIGINAL MIXAMO INVALID: ", path, " player=", anim_player, " rig=", rig)
            bad += 1
        else:
            var names: PackedStringArray = anim_player.get_animation_list()
            var anim_length: float = -1.0
            for anim_name in names:
                if not str(anim_name).to_upper().contains("RESET"):
                    var clip: Animation = anim_player.get_animation(anim_name)
                    if clip != null and clip.get_track_count() > 5:
                        anim_length = maxf(anim_length, clip.length)
            if anim_length <= 0.0:
                printerr("ORIGINAL MIXAMO EMPTY: ", path, " animations=", names)
                bad += 1
            else:
                print("ORIGINAL MIXAMO VALID: ", rel_path, " bones=", rig.get_bone_count(), " clip_length=", anim_length, " animations=", names)
                print("ORIGINAL MIXAMO SOURCE RIG: ", rel_path, " local_basis=", rig.basis)
        scene.free()
    if bad > 0:
        printerr("ORIGINAL MIXAMO IMPORTS FAILED: ", bad)
        quit(1)
    else:
        print("ORIGINAL MIXAMO IMPORTS PASS: 8 user-supplied FBX clips are readable")
        quit(0)
