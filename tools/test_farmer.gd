extends SceneTree
# Tests free movement and safe missing-asset fallback.
func _initialize() -> void:
    call_deferred("_check")

func _check() -> void:
    var scene: PackedScene = load("res://scenes/Main.tscn")
    var farm: Variant = scene.instantiate()
    root.add_child(farm)
    var problems: Array[String] = []
    if farm.farmer == null:
        problems.append("no player actor")
    if farm.stick == null:
        problems.append("no joystick")
    if farm.jump_button == null or farm.run_button == null:
        problems.append("run/jump buttons missing")

    # Emulate a held analog stick: it must translate the farm actor freely.
    var before: Vector3 = farm.farmer.position
    farm.stick.visible = true
    farm.stick.set("direction", Vector2(0.5, -0.75))
    farm._process(0.15)
    farm.stick.set("direction", Vector2.ZERO)
    var travelled: float = Vector2(
        farm.farmer.position.x - before.x,
        farm.farmer.position.z - before.z
    ).length()
    if travelled < 0.07:
        problems.append("joystick movement did not move player")

    var jump_before: float = farm.jump_velocity
    farm.jump()
    if farm.jump_velocity <= jump_before:
        problems.append("jump input did not trigger")
    if ResourceLoader.exists("res://assets/characters/femalefarmer.fbx"):
        var meshes: Array[MeshInstance3D] = []
        _log_model_nodes(farm.farmer_visual, meshes)
        print("MODEL DIAGNOSTIC: mesh count=", meshes.size())
        if meshes.is_empty():
            problems.append("imported avatar has no renderable meshes")
        if farm.farmer_visual != null:
            print("MODEL DIAGNOSTIC: local visual=", farm.farmer_visual.transform)
            print("MODEL DIAGNOSTIC: parent farmer=", farm.farmer.position)
            print("MODEL DIAGNOSTIC: rig skeleton=", farm.farmer_visual.skeleton)
            print("MODEL DIAGNOSTIC: fitted height=", farm.farmer_visual.display_height,
                " auto_scale=", farm.farmer_visual.visual_scale)
            if farm.farmer_visual.display_height < 1.5 or farm.farmer_visual.display_height > 2.4:
                problems.append("imported model not scaled to human height")
        for obj in meshes:
            var aabb: AABB = obj.get_aabb()
            var transform: Transform3D = obj.global_transform
            var bound_world: AABB = transform * aabb
            print("MODEL DIAGNOSTIC: mesh path=", obj.get_path(), " visible=", obj.is_visible_in_tree(), " material=", obj.material_override, " aabb=", aabb, " world=", bound_world, " transform=", transform)
            if not obj.is_visible_in_tree():
                problems.append("avatar mesh hidden")
            if bound_world.size.y < 1.4 or bound_world.size.y > 2.6:
                problems.append("avatar mesh too small or too tall for farm")
            if absf(bound_world.position.y-farm.farmer.position.y) > 1.5:
                problems.append("avatar outside standing ground height")
        if farm.farmer_visual == null or not farm.farmer_visual.is_model_ready():
            problems.append("rigged female FBX not loaded")
        else:
            for state in ["Idle", "Walk", "Run", "Jump"]:
                if not farm.farmer_visual.anim_player.has_animation("Farm/" + state):
                    problems.append("missing Mixamo motion " + state)
    if problems.is_empty():
        print("FARMER TESTS PASS: joystick walking, jumping, FBX fallback and animation libraries")
        quit(0)
    else:
        for err in problems:
            printerr("FARMER TEST FAIL: " + err)
        quit(1)

func _log_model_nodes(n: Node, out_meshes: Array[MeshInstance3D], depth: int = 0) -> void:
    if n == null or depth > 20:
        return
    if n is MeshInstance3D:
        out_meshes.append(n)
    if depth < 8 and (n is MeshInstance3D or n is Skeleton3D or n is AnimationPlayer):
        print("MODEL DIAGNOSTIC: node=", n.get_path(), " type=", n.get_class(), " visible=", n.visible if n is Node3D else true)
    for child in n.get_children():
        _log_model_nodes(child, out_meshes, depth+1)
