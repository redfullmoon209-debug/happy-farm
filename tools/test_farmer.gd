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
    if farm.zoom_in_button == null or farm.zoom_out_button == null:
        problems.append("camera plus/minus buttons missing")
    if not farm.touch_controls or not farm.stick.is_visible_in_tree():
        problems.append("joystick must be visible automatically on PC web")
    if not farm.run_button.is_visible_in_tree() or not farm.jump_button.is_visible_in_tree():
        problems.append("run and jump buttons must be visible automatically")
    if farm.stick_label == null or not farm.stick_label.is_visible_in_tree():
        problems.append("joystick heading is missing")
    if not farm.zoom_in_button.is_visible_in_tree() or not farm.zoom_out_button.is_visible_in_tree():
        problems.append("zoom controls must be visible on mobile and PC")

    var screen: Rect2 = Rect2(Vector2.ZERO, farm.get_viewport().get_visible_rect().size)
    if not screen.encloses(farm.stick.get_global_rect()):
        problems.append("joystick extends beyond game viewport")
    if not screen.encloses(farm.run_button.get_global_rect()) or not screen.encloses(farm.jump_button.get_global_rect()):
        problems.append("run or jump button extends outside game")
    if not screen.encloses(farm.zoom_in_button.get_global_rect()) or not screen.encloses(farm.zoom_out_button.get_global_rect()):
        problems.append("zoom controls extend outside viewport")
    print("ZOOM CONTROL RECTS: window=", farm.get_viewport().get_visible_rect().size,
        " run=", farm.run_button.get_global_rect(),
        " plus=", farm.zoom_in_button.get_global_rect(),
        " minus=", farm.zoom_out_button.get_global_rect())
    if farm.run_button.get_global_rect().intersects(farm.zoom_in_button.get_global_rect()):
        problems.append("zoom-in button overlaps Run")
    if farm.run_button.get_global_rect().intersects(farm.zoom_out_button.get_global_rect()):
        problems.append("zoom-out button overlaps Run")

    # The real mobile zoom controls must change the orthographic camera.
    var default_size: float = farm.camera.size
    farm.zoom_in_button.pressed.emit()
    var zoom_in_size: float = farm.camera.size
    if zoom_in_size >= default_size:
        problems.append("zoom-in button did not enlarge the character")
    farm.zoom_out_button.pressed.emit()
    if farm.camera.size <= zoom_in_size:
        problems.append("zoom-out button did not restore a wider view")
    # Pinch two fingers on empty 3D terrain, away from all UI.
    var vp: Vector2 = farm.get_viewport().get_visible_rect().size
    var left: InputEventScreenTouch = InputEventScreenTouch.new()
    left.index = 3
    left.position = Vector2(vp.x * 0.54, vp.y * 0.35)
    left.pressed = true
    var right: InputEventScreenTouch = InputEventScreenTouch.new()
    right.index = 4
    right.position = Vector2(vp.x * 0.72, vp.y * 0.35)
    right.pressed = true
    farm._input(left)
    farm._input(right)
    var before_pinch: float = farm.camera_distance
    var spreading: InputEventScreenDrag = InputEventScreenDrag.new()
    spreading.index = 4
    spreading.position = right.position + Vector2(98.0, 0.0)
    farm._input(spreading)
    if farm.camera_distance >= before_pinch:
        problems.append("two-finger spreading did not zoom toward farmer")
    left.pressed = false
    right.pressed = false
    farm._input(right)
    farm._input(left)
    if not farm.camera_touches.is_empty():
        problems.append("camera touch slots not released after pinch")

    # Test a real mouse drag on the on-screen joystick (Chrome desktop).
    # ScreenTouch is supported by the same Joystick script on Android/iPhone.
    var center: Vector2 = farm.stick.get_global_rect().get_center()
    var press: InputEventMouseButton = InputEventMouseButton.new()
    press.button_index = MOUSE_BUTTON_LEFT
    press.pressed = true
    press.position = center
    farm.stick._input(press)
    var motion: InputEventMouseMotion = InputEventMouseMotion.new()
    motion.position = center + Vector2(53, -27)
    farm.stick._input(motion)
    if farm.stick.direction.x < 0.5 or farm.stick.direction.y > -0.25:
        problems.append("mouse drag does not update analog joystick direction")

    # Emulate a held analog stick: it must translate the farm actor freely.
    var before: Vector3 = farm.farmer.position
    farm._process(0.15)
    var release: InputEventMouseButton = InputEventMouseButton.new()
    release.button_index = MOUSE_BUTTON_LEFT
    release.pressed = false
    release.position = motion.position
    farm.stick._input(release)
    if farm.stick.direction.length() > 0.01:
        problems.append("joystick did not return to center after releasing")
    var travelled: float = Vector2(
        farm.farmer.position.x - before.x,
        farm.farmer.position.z - before.z
    ).length()
    if travelled < 0.07:
        problems.append("joystick movement did not move player")

    var jump_before: float = farm.jump_velocity
    farm.jump_button.pressed.emit()
    if farm.jump_velocity <= jump_before:
        problems.append("jump button did not trigger")
    var initial_running: bool = farm.run_toggle
    farm.run_button.pressed.emit()
    if farm.run_toggle == initial_running:
        problems.append("run button did not toggle sprint")
    farm.run_button.pressed.emit()
    if ResourceLoader.exists("res://assets/characters/Female_Character_Complete.glb"):
        if farm.farmer_visual == null or not farm.farmer_visual.is_model_ready():
            problems.append("real Codex GLB character failed to load into the farm")
        elif farm.farmer_visual.display_height < 0.87 or farm.farmer_visual.display_height > 0.93:
            problems.append("real Codex GLB model is not at the 0.90-height garden scale")
        elif farm.farmer_visual.mesh_count < 2:
            problems.append("hair or body mesh missing from real Codex model")
        elif farm.farmer_visual.anim_player == null:
            problems.append("real Codex GLB has no retargeted AnimationPlayer")
        else:
            for required_state in ["Idle", "Walk", "Run", "Jump", "Water", "Dig"]:
                if not farm.farmer_visual.anim_player.has_animation("Farm/" + required_state):
                    problems.append("missing modular animation: " + required_state)
            farm.farmer_visual.set_state("Water")
            if farm.farmer_visual.current_state != "Water":
                problems.append("Water work state did not activate")
            farm.farmer_visual.set_state("Dig")
            if farm.farmer_visual.current_state != "Dig":
                problems.append("Dig work state did not activate")
            farm.farmer_visual.set_state("Idle")
            # Regression for the 'character lying flat' bug. A valid 3D
            # animation must leave the Head ABOVE the feet for every action.
            var sk: Skeleton3D = farm.farmer_visual.skeleton
            var head_id: int = -1
            var foot_id: int = -1
            if sk != null:
                for idx in range(sk.get_bone_count()):
                    var label: String = String(sk.get_bone_name(idx)).to_lower()
                    if label.ends_with("head") and not label.ends_with("headtop_end"):
                        head_id = idx
                    if label.ends_with("leftfoot"):
                        foot_id = idx
            if sk == null or head_id < 0 or foot_id < 0:
                problems.append("could not verify modular character upright bones")
            else:
                for pose_name in ["Idle", "Walk", "Run", "Jump", "Water", "Dig"]:
                    farm.farmer_visual.set_state(pose_name)
                    farm.farmer_visual.anim_player.advance(0.18)
                    # get_bone_global_pose() is relative to Skeleton3D,
                    # not Y-up world space. GLB armatures have a rotated
                    # import root, so raw .y measures the wrong axis.
                    var head_world: Vector3 = sk.to_global(sk.get_bone_global_pose(head_id).origin)
                    var foot_world: Vector3 = sk.to_global(sk.get_bone_global_pose(foot_id).origin)
                    var height_gap: float = head_world.y-foot_world.y
                    print("UPRIGHT TEST: ", pose_name, " world head-above-foot=", height_gap, " skel-basis=", sk.global_basis)
                    if height_gap <= 0.12:
                        problems.append("model lying or upside down in " + pose_name)
                farm.farmer_visual.set_state("Idle")
                farm.farmer_visual.anim_player.advance(0.2)
                # The previous emergency fix passed while playing zero-track
                # clips (T-pose). Assert the arms actually lower in Idle.
                var left_shoulder: int = -1
                var left_hand: int = -1
                for b in range(sk.get_bone_count()):
                    var n: String = String(sk.get_bone_name(b)).to_lower()
                    if n.ends_with("leftarm") and not n.ends_with("forearm"):
                        left_shoulder = b
                    if n.ends_with("lefthand"):
                        left_hand = b
                if left_shoulder >= 0 and left_hand >= 0:
                    var shoulder_y: float = sk.to_global(sk.get_bone_global_pose(left_shoulder).origin).y
                    var hand_y: float = sk.to_global(sk.get_bone_global_pose(left_hand).origin).y
                    print("ARM RELAX TEST: shoulder=", shoulder_y, " hand=", hand_y, " drop=", shoulder_y-hand_y)
                    if hand_y >= shoulder_y - 0.05:
                        problems.append("Idle animation still T-pose: hand not lowered")
                else:
                    problems.append("cannot locate left arm/hand for T-pose regression")
    elif ResourceLoader.exists("res://assets/characters/femalefarmer.fbx"):
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
            # The original FBX faces +Z and a Godot actor moves along -Z.
            # Check actual world-space visual heading after a sideways walk.
            var desired: Vector3 = Vector3(0.8, 0.0, -0.6)
            farm.move_actor(desired, 2.0, 0.12)
            var visual_axis: Vector3 = farm.farmer_visual.imported_character.global_basis * Vector3.BACK
            visual_axis.y = 0.0
            if visual_axis.normalized().dot(desired) < 0.97:
                problems.append("Mixamo character visually faces away from travel direction")
            for state in ["Idle", "Walk", "Run", "Jump"]:
                if not farm.farmer_visual.anim_player.has_animation("Farm/" + state):
                    problems.append("missing Mixamo motion " + state)
    # Male and female must BOTH leave T-pose and remain upright.
    if ResourceLoader.exists("res://assets/characters/Male_Character_Complete.glb"):
        var male_script: GDScript = load("res://scripts/ModularVisual.gd") as GDScript
        var male_avatar: Node3D = male_script.new() as Node3D
        farm.farmer.add_child(male_avatar)
        if not male_avatar.initialize("male") or not male_avatar.is_model_ready():
            problems.append("male GLB rig failed to initialize")
        elif male_avatar.anim_player == null:
            problems.append("male rig missing animation player")
        else:
            var ms: Skeleton3D = male_avatar.skeleton
            var male_ids: Dictionary = {}
            for id in range(ms.get_bone_count()):
                var bone_name: String = String(ms.get_bone_name(id)).to_lower()
                for target in ["head", "leftfoot", "leftarm", "lefthand"]:
                    if bone_name.ends_with(target):
                        male_ids[target] = id
            if male_ids.size() < 4:
                problems.append("male GLB missing essential upright test bones")
            else:
                for anim_state in ["Idle", "Walk", "Run", "Jump", "Water", "Dig"]:
                    male_avatar.set_state(anim_state)
                    male_avatar.anim_player.advance(0.19)
                    var hy: float = ms.to_global(ms.get_bone_global_pose(int(male_ids["head"])).origin).y
                    var fy: float = ms.to_global(ms.get_bone_global_pose(int(male_ids["leftfoot"])).origin).y
                    print("MALE UPRIGHT TEST: ", anim_state, " head-above-foot=", hy - fy)
                    if hy - fy <= 0.12:
                        problems.append("male model tips over in " + anim_state)
                male_avatar.set_state("Idle")
                male_avatar.anim_player.advance(0.19)
                var shoulder_y: float = ms.to_global(ms.get_bone_global_pose(int(male_ids["leftarm"])).origin).y
                var hand_y: float = ms.to_global(ms.get_bone_global_pose(int(male_ids["lefthand"])).origin).y
                print("MALE ARM RELAX TEST: drop=", shoulder_y - hand_y)
                if shoulder_y - hand_y < 0.05:
                    problems.append("male Idle pose still T-pose")
        male_avatar.queue_free()

    # 200-slot MMO backpack: left 3D player, right item grid at equal width.
    var previous_gender: String = farm.avatar_gender
    farm.bag_button.pressed.emit()
    if not farm.bag_panel.visible or not farm.character_panel.visible or not farm.bag_scroll.visible:
        problems.append("single split backpack must show model and inventory together")
    if farm.inventory_slots.size() != 200:
        problems.append("MMORPG backpack does not have exactly 200 slots")
    # Source artwork must be imported into the PLAYABLE backpack, not
    # merely stored in a ZIP or added as files with no scene references.
    if farm.bag_metal_edge_overlay == null or farm.bag_metal_edge_overlay.texture != farm.USER_INV_BORDER:
        problems.append("real user-supplied inventory border image not installed")
    if farm.bag_character_backdrop == null or farm.bag_character_backdrop.texture != farm.USER_INV_PREVIEW:
        problems.append("real user-supplied character backdrop not installed")
    if farm.bag_stats_backdrop == null or farm.bag_stats_backdrop.texture != farm.USER_INV_STATS:
        problems.append("real user-supplied character stats panel not installed")
    if farm.inventory_slots.size() > 0:
        var slot_style: StyleBoxTexture = farm.inventory_slots[0].get_theme_stylebox("normal") as StyleBoxTexture
        if slot_style == null or slot_style.texture != farm.USER_INV_SLOT:
            problems.append("200 item slots are not using separated artwork")
    if absf(farm.character_panel.size.x - (farm.bag_panel.size.x-30.0)*0.5) > 2.0:
        problems.append("left model panel does not occupy 50 percent")
    if absf(farm.bag_scroll.size.x - farm.character_panel.size.x) > 14.0:
        problems.append("right item pane does not occupy 50 percent")
    if farm.character_preview_viewport == null or farm.character_preview_avatar == null:
        problems.append("left panel missing real 3D character preview")
    else:
        var original_rotation: float = farm.character_preview_avatar.rotation.y
        farm.rotate_character_preview(65.0)
        if absf(farm.character_preview_avatar.rotation.y - original_rotation) < 0.15:
            problems.append("dragging character preview does not rotate the model")
        if absf(farm.farmer.rotation.y - farm.character_preview_avatar.rotation.y) < 0.001:
            print("PREVIEW NOTE: world avatar may coincidentally face same rotation")
    if farm.character_equipment_buttons.size() != 5:
        problems.append("missing horizontal 5-slot equipment bar")
    else:
        var glove_button: Button = farm.character_equipment_buttons["gloves"]
        if glove_button.icon != farm.USER_EQUIP_GLOVE or not glove_button.text.contains("ถุงมือ"):
            problems.append("glove slot missing one-hand icon or runtime caption")
        farm.toggle_inventory_language()
        if not glove_button.text.contains("Glove") or not farm.bag_heading.text.contains("Inventory"):
            problems.append("inventory language change requires text labels, not PNG artwork")
        farm.toggle_inventory_language()
        if not glove_button.text.contains("ถุงมือ"):
            problems.append("Thai equipment label did not restore")
        var previous: Array[Rect2] = []
        var tall: bool = farm.character_panel.size.y >= 440 and farm.character_panel.size.x >= 340
        for i in farm.CLOTHING_SLOTS.size():
            var gear: Button = farm.character_equipment_buttons[farm.CLOTHING_SLOTS[i]]
            var bounds := gear.get_rect()
            var model: Rect2 = farm.character_preview_frame.get_rect()
            if not Rect2(Vector2.ZERO, farm.character_panel.size).encloses(bounds) or model.intersects(bounds):
                problems.append("gear outside wardrobe or overlapping the model")
            for other in previous:
                if bounds.intersects(other):
                    problems.append("gear slots overlap")
            if tall:
                if (i < 3 and bounds.end.x > model.position.x) or (i >= 3 and bounds.position.x < model.end.x):
                    problems.append("gear on wrong preview rail")
                if i in [1,2,4] and bounds.position.y <= previous[i-1].position.y:
                    problems.append("gear rail ordering")
            elif i > 0 and (bounds.position.x <= previous[i-1].position.x or absf(bounds.position.y-previous[i-1].position.y)>2.0):
                problems.append("compact gear row ordering")
            previous.append(bounds)
        if farm.character_info_label == null or not farm.character_info_label.text.contains("EXP"):
            problems.append("character stats missing beneath equipment slots")
    # The MMORPG inventory must not equip from a left-side slot.
    farm.on_equipment_slot_pressed("top")
    if farm.inventory_detail_panel.visible:
        problems.append("left equipment slot incorrectly opened item choice")
    farm.equip_clothing(farm.avatar_gender + "_martial_top")
    if farm.clothing_equipped.has("top"):
        problems.append("unowned shirt equipped without a purchase")
    if farm.inventory_detail_panel == null or farm.inventory_equip_button == null:
        problems.append("missing separate item details and equip confirmation")
    # Both rigs have new 3D bone-attached wardrobe parts. Purchasing a shirt
    # and gloves never modifies the other equipped slot.
    farm.coins = maxi(farm.coins, 600)
    var bought_shirt: String = farm.avatar_gender + "_villager_top"
    var bought_gloves: String = farm.avatar_gender + "_martial_gloves"
    var cost_before: int = farm.coins
    farm.buy_clothing(bought_shirt)
    if int(farm.clothing_owned.get(bought_shirt, 0)) != 1 or farm.coins != cost_before - farm.WARDROBE.shop_price(bought_shirt):
        problems.append("farm coins did not purchase a modular shirt")
    farm.buy_clothing(bought_gloves)
    farm.refresh_bag_cards()
    var shirt_index: int = -1
    for i in range(farm.inventory_entries.size()):
        if str(farm.inventory_entries[i].get("item_id", "")) == bought_shirt:
            shirt_index = i
            break
    if shirt_index < 0:
        problems.append("purchased shirt missing from right inventory grid")
    else:
        farm.inventory_slot_pressed(shirt_index)
        if farm.clothing_equipped.has("top"):
            problems.append("item tap changed clothes before confirmation")
        if farm.inventory_equip_button.text != "สวมใส่":
            problems.append("item details missing separate equip action")
        farm._equip_selected_inventory_item()
        if str(farm.clothing_equipped.get("top", "")) != bought_shirt:
            problems.append("confirm equip did not wear modular shirt")
        var glove_index: int = -1
        for i in range(farm.inventory_entries.size()):
            if str(farm.inventory_entries[i].get("item_id", "")) == bought_gloves:
                glove_index = i
                break
        if glove_index >= 0:
            farm.inventory_slot_pressed(glove_index)
            farm._equip_selected_inventory_item()
            if str(farm.clothing_equipped.get("top", "")) != bought_shirt or str(farm.clothing_equipped.get("gloves", "")) != bought_gloves:
                problems.append("different modular slots do not mix independently")
        farm.unequip_clothing("gloves")
        farm.unequip_clothing("top")
    if farm.gender_item_button.disabled == false:
        problems.append("gender card usable with zero inventory")
    farm.consume_gender_change_ticket()
    if farm.avatar_gender != previous_gender:
        problems.append("gender changed without consuming a purchased card")
    if previous_gender == "female" and farm.farmer_visual != null:
        # Purchased wardrobe: gameplay must not grant a wearable item for free.
        if int(farm.clothing_owned.get("female_survivor_shoes", 0)) != 0:
            problems.append("shoe item was free before purchase")
        farm.coins = maxi(farm.coins, 300)
        var coins_before_wardrobe: int = farm.coins
        farm.buy_clothing("female_survivor_shoes")
        if int(farm.clothing_owned.get("female_survivor_shoes", 0)) != 1:
            problems.append("shoe shop purchase did not add item to backpack")
        if farm.coins != coins_before_wardrobe - farm.WARDROBE.shop_price("female_survivor_shoes"):
            problems.append("shoe shop did not deduct earned coins")
        # Tap to inspect the item; only the separate action button can equip it.
        farm.refresh_bag_cards()
        var shoe_index: int = -1
        for i in range(farm.inventory_entries.size()):
            if str(farm.inventory_entries[i].get("item_id", "")) == "female_survivor_shoes":
                shoe_index = i
                break
        if shoe_index < 0:
            problems.append("purchased shoe item missing from right-hand backpack")
        else:
            farm.inventory_slot_pressed(shoe_index)
            if not farm.inventory_detail_panel.visible or farm.inventory_equip_button.text != "สวมใส่":
                problems.append("shoe tap did not show details and separate equip button")
            if farm.clothing_equipped.has("shoes"):
                problems.append("shoe tap equipped item without pressing equip")
            farm._equip_selected_inventory_item()
            if str(farm.clothing_equipped.get("shoes", "")) != "female_survivor_shoes":
                problems.append("explicit equip action failed to dress avatar")
            if farm.inventory_equip_button.text != "ถอด":
                problems.append("details did not update to unequip after dressing")
            farm._equip_selected_inventory_item()
            if farm.clothing_equipped.has("shoes"):
                problems.append("explicit unequip action failed to undress avatar")
        # Rendering uses real meshes; never show a generic fake image.
        var shoe_thumbnail: Texture2D = farm._real_equipment_thumbnail("female_survivor_shoes")
        if shoe_thumbnail == null:
            problems.append("real survivor shoe mesh thumbnail did not load")
        if farm._real_equipment_thumbnail("female_villager_top") == null:
            problems.append("modular shirt thumbnail does not use real gear geometry")
        farm.equip_clothing("female_survivor_shoes")
        farm.refresh_character_preview()
        if farm.character_preview_avatar == null or not is_instance_valid(farm.character_preview_avatar):
            problems.append("preview avatar missing after equipment change")
        if str(farm.clothing_equipped.get("shoes", "")) != "female_survivor_shoes":
            problems.append("shoe item failed to equip into independent slot")
        else:
            var visual_skeleton: Skeleton3D = farm.farmer_visual.skeleton
            var worn_pieces: int = 0
            if visual_skeleton != null:
                for child in visual_skeleton.get_children():
                    if child.name.begins_with("FarmFlexWardrobe_female_survivor_shoes"):
                        worn_pieces += 1
            if worn_pieces != 2:
                problems.append("wearing shoes did not attach both modular 3D shoe meshes")
        farm.unequip_clothing("shoes")
        if farm.clothing_equipped.has("shoes"):
            problems.append("unequip did not empty shoe slot")
    var money_before_cards: int = farm.coins
    if money_before_cards >= farm.GENDER_CHANGE_CARD_PRICE:
        farm.buy_gender_change_ticket()
        if farm.gender_change_tickets != 1 or farm.coins != money_before_cards - farm.GENDER_CHANGE_CARD_PRICE:
            problems.append("shop did not sell the gender item correctly")
        farm.consume_gender_change_ticket()
        if farm.avatar_gender == previous_gender or farm.gender_change_tickets != 0:
            problems.append("gender card was not consumed when changing gender")
        var after_change: Dictionary = farm.snapshot()
        if str(after_change.get("avatar_gender", "")) != farm.avatar_gender:
            problems.append("consumed gender choice not persisted in farm snapshot")
        if after_change.get("clothing_owned", {}).size() < 2:
            problems.append("changing gender deleted owned clothing")
    farm.bag_button.pressed.emit()
    if farm.bag_panel.visible:
        problems.append("backpack close did not hide inventory")
    farm.farm_audio.music.stop()
    await create_timer(0.15).timeout
    farm.queue_free()
    await process_frame
    await process_frame
    if problems.is_empty():
        print("FARMER TESTS PASS: joystick walking, jumping, FBX fallback, gender item and modular wardrobe")
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
