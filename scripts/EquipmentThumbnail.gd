extends SubViewport
# The very same piece meshes used on the 3D character, rendered as item icons.
const WARDROBE = preload("res://scripts/WardrobeCatalog.gd")
const VISUAL = preload("res://scripts/ModularVisual.gd")
static var meshes := {}

static func item_mesh(id: String) -> Mesh:
    var gender := id.get_slice("_", 0)
    if not meshes.has(gender):
        var packed: PackedScene = load(VISUAL.MALE_PATH if gender == "male" else VISUAL.FEMALE_PATH)
        if packed == null:
            return null
        var root := packed.instantiate()
        var lookup := {}
        for node in root.find_children("*", "MeshInstance3D", true, false):
            lookup[str(node.name)] = (node as MeshInstance3D).mesh
        meshes[gender] = lookup
        root.free()
    return meshes[gender].get(WARDROBE.mesh_name(id))


func set_equipment_item(item_id: String) -> bool:
    var geometry := item_mesh(item_id)
    if geometry == null:
        return false
    size = Vector2i(144, 144)
    transparent_bg = true
    own_world_3d = true
    var garment := MeshInstance3D.new()
    garment.mesh = geometry
    garment.position = -geometry.get_aabb().get_center()
    garment.name = "RealMesh_" + item_id
    add_child(garment)
    var camera: Camera3D = Camera3D.new()
    camera.projection = Camera3D.PROJECTION_ORTHOGONAL
    camera.size = maxf(0.05, geometry.get_aabb().size.length() * 1.08)
    camera.position = Vector3(0.5, 0.26, 1.0)
    add_child(camera)
    camera.look_at(Vector3.ZERO, Vector3.UP)
    camera.current = true
    var light: DirectionalLight3D = DirectionalLight3D.new()
    light.rotation_degrees = Vector3(-35.0, -30.0, 0.0)
    light.light_energy = 2.3
    add_child(light)
    render_target_update_mode = SubViewport.UPDATE_ONCE
    return true
