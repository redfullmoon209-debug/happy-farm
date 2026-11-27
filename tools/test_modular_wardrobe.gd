extends SceneTree
const Visual = preload("res://scripts/ModularVisual.gd")
const Catalog = preload("res://scripts/WardrobeCatalog.gd")
var problems: Array[String] = []

func _initialize() -> void:
    check.call_deferred()

func check() -> void:
    for sex: String in ["female","male"]:
        var v := Visual.new()
        root.add_child(v)
        if not v.initialize(sex, {"hair":"03"}):
            problems.append(sex + " initialization")
            v.free()
            continue
        var prefix := sex.capitalize()
        for set_id: String in ["villager","martial","survivor"]:
            var worn := {}
            for id: String in Catalog.available_item_ids():
                if id.begins_with(sex + "_" + set_id + "_") and not (Catalog.full_set(id) and id.ends_with("bottom")):
                    worn = Catalog.wear(worn, id, id.get_slice("_",2))
            v.apply_equipment(worn)
            for id: String in worn.values():
                var expected: MeshInstance3D = v.parts.get(Catalog.mesh_name(id))
                if expected == null or not expected.visible:
                    problems.append(id + " missing")
            var masked := 0
            for i in v.original_surfaces.size():
                if v.master_body.get_surface_override_material(i) == v.hidden_skin:
                    masked += 1
            if sex == "male" and masked == 0: problems.append(sex+" "+set_id+" body mask")
            print("EQUIPMENT ",sex," ",set_id," surfaces hidden ",masked,"/",v.original_surfaces.size())
        if sex == "female":
            for style in ["black_red", "pink"]:
                var items := {}
                for slot in Catalog.SLOTS:
                    var id := Catalog.item_id(sex, style, slot)
                    items = Catalog.wear(items, id, slot)
                v.apply_equipment(items)
                for slot in Catalog.SLOTS:
                    if not v.parts[Catalog.mesh_name(items[slot])].visible:
                        problems.append("Missing "+items[slot])
                for slot in Catalog.SLOTS:
                    items = Catalog.wear(items, "", slot)
                    v.apply_equipment(items)
                    if slot != "headwear" and not v.parts["Starter_"+slot].visible:
                        problems.append("Missing starter "+slot)
            var mixed := {"top":"female_black_red_top", "bottom":"female_pink_bottom", "shoes":"female_black_red_shoes", "headwear":"female_pink_headwear"}
            v.apply_equipment(mixed)
            for name in ["Black_Red_top","Pink_bottom","Starter_gloves","Black_Red_shoes","Pink_headwear"]:
                if not v.parts[name].visible: problems.append(name)
            if not v.master_body.visible or not v.find_child("Female_Hair_03", true, false).visible:
                problems.append("Missing head or selected hair")
        var full := sex+"_martial_top"
        var worn := Catalog.wear({"top":sex+"_survivor_top","bottom":sex+"_survivor_bottom"},full,"top")
        if worn.get("top") != full or worn.get("bottom") != full or not Catalog.wear(worn,"","bottom").is_empty():
            problems.append("full set occupancy")
        if Catalog.restore_equipped(worn,{full:1},sex) != worn:
            problems.append("full set restore")
        v.apply_equipment({})
        for action: String in ["Idle","Walk","Run","Jump","Dig","Water"]:
            v.set_state(action)
            var clip := v.anim_player.get_animation("Farm/"+action)
            v.anim_player.advance(0.3)
            v.anim_player.seek(clip.length*0.2,true)
            var hand := v.skeleton.find_bone("mixamorig_RightHand")
            if hand<0:problems.append("missing hand");continue
            var start := v.skeleton.get_bone_global_pose(hand).origin
            v.anim_player.seek(clip.length*0.6,true)
            var travel := start.distance_to(v.skeleton.get_bone_global_pose(hand).origin)
            if travel<0.00001:problems.append(sex+" static "+action)
            print("ACTION ",sex," ",action," hand travel ",travel)
        v.free()
    print("MODULAR CHECK ",problems)
    quit(0 if problems.is_empty() else 1)
