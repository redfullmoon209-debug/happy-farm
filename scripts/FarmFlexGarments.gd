extends RefCounted
# FarmFlex modular test garments. These are newly constructed 3D mesh pieces,
# not the absent original outfit GLBs. Every icon uses the exact same geometry.
const SLOT_ORDER = ["headwear", "top", "gloves", "bottom", "shoes"]
const SET_ORDER = ["villager", "martial", "survivor"]
const SET_COLORS = {
    "villager": Color("#997559"),
    "martial": Color("#4a5363"),
    "survivor": Color("#363d42")
}
const SET_ACCENTS = {
    "villager": Color("#d6be93"),
    "martial": Color("#a45b4c"),
    "survivor": Color("#cf8049")
}

static func valid_id(item_id: String) -> bool:
    var bits: PackedStringArray = item_id.split("_")
    return bits.size() == 3 and bits[0] in ["male", "female"] and bits[1] in SET_ORDER and bits[2] in SLOT_ORDER

static func _make_part(parent: Node3D, shape: String, dimensions: Vector3, color: Color, offset: Vector3 = Vector3.ZERO) -> MeshInstance3D:
    var part: MeshInstance3D = MeshInstance3D.new()
    var geo: PrimitiveMesh
    if shape == "round":
        var capsule: CapsuleMesh = CapsuleMesh.new()
        capsule.radius = dimensions.x
        capsule.height = maxf(dimensions.y, dimensions.x * 2.01)
        geo = capsule
    elif shape == "cone":
        var cylinder: CylinderMesh = CylinderMesh.new()
        cylinder.top_radius = dimensions.x
        cylinder.bottom_radius = dimensions.z
        cylinder.height = dimensions.y
        geo = cylinder
    else:
        var block: BoxMesh = BoxMesh.new()
        block.size = dimensions
        geo = block
    part.mesh = geo
    part.position = offset
    var mat: StandardMaterial3D = StandardMaterial3D.new()
    mat.albedo_color = color
    mat.metallic = 0.13 if color != SET_COLORS["villager"] else 0.0
    mat.roughness = 0.87
    part.material_override = mat
    parent.add_child(part)
    return part

static func add_piece(parent: Node3D, slot: String, set_id: String, gender: String) -> void:
    var base: Color = SET_COLORS.get(set_id, Color.GRAY)
    var accent: Color = SET_ACCENTS.get(set_id, Color.WHITE)
    match slot:
        "headwear":
            _make_part(parent, "cone", Vector3(0.145, 0.075, 0.16), base, Vector3(0, 0.14, 0))
            _make_part(parent, "cone", Vector3(0.18, 0.018, 0.18), accent, Vector3(0, 0.10, 0))
        "top":
            _make_part(parent, "cone", Vector3(0.154, 0.23, 0.132), base, Vector3(0, 0.07, 0))
            _make_part(parent, "box", Vector3(0.25, 0.036, 0.17), accent, Vector3(0, 0.03, 0))
            if set_id == "survivor":
                _make_part(parent, "box", Vector3(0.09, 0.095, 0.025), accent, Vector3(0.065, 0.06, 0.15))
        "gloves":
            _make_part(parent, "round", Vector3(0.058, 0.13, 0), base, Vector3(0, 0.025, 0))
            _make_part(parent, "box", Vector3(0.105, 0.025, 0.105), accent, Vector3(0, 0.09, 0))
        "bottom":
            if gender == "female":
                _make_part(parent, "cone", Vector3(0.125, 0.19, 0.20), base, Vector3(0, -0.095, 0))
                _make_part(parent, "box", Vector3(0.265, 0.035, 0.18), accent, Vector3(0, -0.02, 0))
            else:
                _make_part(parent, "box", Vector3(0.245, 0.12, 0.17), base, Vector3(0, -0.06, 0))
                _make_part(parent, "box", Vector3(0.24, 0.028, 0.18), accent, Vector3(0, 0, 0))
        "shoes":
            _make_part(parent, "box", Vector3(0.125, 0.125, 0.21), base, Vector3(0, 0.025, 0.06))
            _make_part(parent, "box", Vector3(0.13, 0.024, 0.23), accent, Vector3(0, -0.046, 0.065))

static func _attach(skeleton: Skeleton3D, bone_name: String, item_id: String, slot: String, set_id: String, gender: String) -> BoneAttachment3D:
    var attachment: BoneAttachment3D = BoneAttachment3D.new()
    attachment.name = "FarmFlexWardrobe_" + item_id + "_" + bone_name.replace(":", "_")
    attachment.bone_name = bone_name
    skeleton.add_child(attachment)
    add_piece(attachment, slot, set_id, gender)
    return attachment

static func build_worn(skeleton: Skeleton3D, equipped: Dictionary, gender: String) -> void:
    for node in skeleton.get_children():
        if node.name.begins_with("FarmFlexWardrobe_"):
            skeleton.remove_child(node)
            node.queue_free()
    for slot in SLOT_ORDER:
        var item_id: String = str(equipped.get(slot, ""))
        if not valid_id(item_id) or not item_id.begins_with(gender + "_"):
            continue
        var set_id: String = item_id.split("_")[1]
        var anchors: Array[String] = []
        match slot:
            "headwear": anchors = ["mixamorig:Head"]
            "top": anchors = ["mixamorig:Spine1"]
            "bottom": anchors = ["mixamorig:Hips"]
            "gloves": anchors = ["mixamorig:LeftHand", "mixamorig:RightHand"]
            "shoes": anchors = ["mixamorig:LeftFoot", "mixamorig:RightFoot"]
        for anchor in anchors:
            if skeleton.find_bone(anchor) >= 0:
                _attach(skeleton, anchor, item_id, slot, set_id, gender)

static func make_icon_model(item_id: String) -> Node3D:
    var root: Node3D = Node3D.new()
    if valid_id(item_id):
        var bits: PackedStringArray = item_id.split("_")
        add_piece(root, bits[2], bits[1], bits[0])
    return root
