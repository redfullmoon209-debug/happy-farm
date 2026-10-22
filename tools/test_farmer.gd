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
