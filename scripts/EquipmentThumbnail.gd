extends SubViewport
# The very same piece meshes used on the 3D character, rendered as item icons.
const GARMENTS = preload("res://scripts/FarmFlexGarments.gd")

func set_equipment_item(item_id: String) -> bool:
    if not GARMENTS.valid_id(item_id):
        return false
    size = Vector2i(144, 144)
    transparent_bg = true
    own_world_3d = true
    var garment: Node3D = GARMENTS.make_icon_model(item_id)
    garment.name = "RealMesh_" + item_id
    add_child(garment)
    var camera: Camera3D = Camera3D.new()
    camera.projection = Camera3D.PROJECTION_ORTHOGONAL
    camera.size = 0.62
    camera.position = Vector3(0.5, 0.26, 1.0)
    add_child(camera)
    camera.look_at(Vector3(0.0, 0.03, 0.0), Vector3.UP)
    camera.current = true
    var light: DirectionalLight3D = DirectionalLight3D.new()
    light.rotation_degrees = Vector3(-35.0, -30.0, 0.0)
    light.light_energy = 2.3
    add_child(light)
    render_target_update_mode = SubViewport.UPDATE_ONCE
    return true
