extends SceneTree

func _initialize() -> void:
    run.call_deferred()

func run() -> void:
    var failures: Array[String] = []
    for sex in ["female", "male"]:
        var avatar := preload("res://scripts/ModularVisual.gd").new()
        root.add_child(avatar)
        if not avatar.initialize(sex):
            printerr("Cannot load ", sex)
            quit(1)
            return
        var sk := avatar.skeleton
        var body: MeshInstance3D
        for mesh in avatar.find_children("*", "MeshInstance3D", true, false):
            if "Master_Body" in str(mesh.name) or mesh.name == "Starter_shoes":
                body = mesh
        var skin := body.skin
        var bindings: Array[int] = []
        for i in skin.get_bind_count():
            bindings.append(sk.find_bone(skin.get_bind_name(i)))
        var verts := PackedVector3Array()
        var bones := PackedInt32Array()
        var weights := PackedFloat32Array()
        for surface in body.mesh.get_surface_count():
            var arrays := body.mesh.surface_get_arrays(surface)
            verts.append_array(arrays[Mesh.ARRAY_VERTEX])
            bones.append_array(arrays[Mesh.ARRAY_BONES])
            weights.append_array(arrays[Mesh.ARRAY_WEIGHTS])
        var influences := bones.size() / verts.size()
        var feet: Array[int] = []
        for i in verts.size():
            var bind := bones[i*influences]
            var rest := sk.to_global(sk.get_bone_global_rest(bindings[bind]) * skin.get_bind_pose(bind) * verts[i])
            if rest.y < 0.026:
                feet.append(i)
        for state in ["Idle","Walk","Run","Talk"]:
            avatar.set_state(state)
            var clip := avatar.anim_player.get_animation("Farm/"+state)
            var worst := 0.0
            var min_gap := INF
            var first_hand := Vector3.ZERO
            var motion := 0.0
            for frame in 31:
                avatar.anim_player.advance(0.2 if frame == 0 else 0.0)
                avatar.anim_player.seek(clip.length*frame/31.0,true)
                var transforms: Array[Transform3D] = []
                for i in bindings.size():
                    transforms.append(sk.global_transform * sk.get_bone_global_pose(bindings[i]) * skin.get_bind_pose(i))
                var floor_y := INF
                for i in feet:
                    var y := 0.0
                    for w in influences:
                        var j := i*influences+w
                        y += (transforms[bones[j]] * verts[i]).y * weights[j]
                    floor_y = minf(floor_y,y)
                worst = maxf(worst,absf(floor_y))
                var head := sk.to_global(sk.get_bone_global_pose(sk.find_bone("mixamorig_Head")).origin)
                min_gap = minf(min_gap,head.y-floor_y)
                var hand := sk.to_global(sk.get_bone_global_pose(sk.find_bone("mixamorig_LeftHand")).origin)
                if frame == 0:
                    first_hand = hand
                motion = maxf(motion,hand.distance_to(first_hand))
            print("POSE ",sex," ",state," floor error=",worst," head height=",min_gap," hand travel=",motion)
            if worst > .004 or min_gap < .15 or motion < .0002:
                failures.append(sex+" "+state)
        avatar.free()
    if not failures.is_empty():
        printerr("POSE FAIL ",failures)
    else:
        print("SKINNED POSE TEST PASS")
    quit(0 if failures.is_empty() else 1)
