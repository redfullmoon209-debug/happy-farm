extends SubViewport
# Render only the REAL garment meshes from the shipped character GLB.
# No screenshot cropping, placeholder outfit art, or text inside the image.
const FEMALE = "res://assets/characters/Female_Character_Complete.glb"
const MALE = "res://assets/characters/Male_Character_Complete.glb"

func _collect(node: Node, meshes: Array[MeshInstance3D]) -> void:
    if node is MeshInstance3D:
        meshes.append(node as MeshInstance3D)
    for child in node.get_children():
        _collect(child, meshes)

func set_equipment_item(item_id: String) -> bool:
    var gender: String = "female" if item_id.begins_with("female_") else "male"
    var source: String = FEMALE if gender == "female" else MALE
    if not ResourceLoader.exists(source):
        return false
    var pack: Resource = ResourceLoader.load(source)
    if not (pack is PackedScene):
        return false
    var scene: Node = (pack as PackedScene).instantiate()
    if not (scene is Node3D):
        scene.free()
        return false
    var parent: Node3D = scene as Node3D
    add_child(parent)
    var mesh_nodes: Array[MeshInstance3D] = []
    _collect(parent, mesh_nodes)
    var low: Vector3 = Vector3(INF, INF, INF)
    var high: Vector3 = Vector3(-INF, -INF, -INF)
    var found: int = 0
    for piece in mesh_nodes:
        var name_lower: String = str(piece.name).to_lower()
        var match_piece: bool = false
        if item_id == "female_survivor_shoes":
            match_piece = name_lower.contains("female_outfit_apocalypse_survivor_shoes")
        elif item_id == "female_martial_shoes":
            match_piece = name_lower.contains("female_outfit_martial_artist_shoes")
        piece.visible = match_piece
        if match_piece and piece.mesh != null:
            var bounds: AABB = piece.global_transform * piece.mesh.get_aabb()
            low = low.min(bounds.position)
            high = high.max(bounds.end)
            found += 1
    if found == 0:
        parent.queue_free()
        return false
    size = Vector2i(144, 144)
    transparent_bg = true
    own_world_3d = true
    render_target_update_mode = SubViewport.UPDATE_ALWAYS
    var center: Vector3 = (low + high) * 0.5
    var dimensions: Vector3 = high - low
    var frame_size: float = maxf(0.12, maxf(dimensions.x, maxf(dimensions.y, dimensions.z))) * 1.6
    var camera: Camera3D = Camera3D.new()
    camera.projection = Camera3D.PROJECTION_ORTHOGONAL
    camera.size = frame_size
    camera.position = center + Vector3(0.0, dimensions.y * 0.2 + frame_size * 0.18, frame_size * 2.5)
    add_child(camera)
    camera.look_at(center, Vector3.UP)
    camera.current = true
    var light: DirectionalLight3D = DirectionalLight3D.new()
    light.rotation_degrees = Vector3(-40.0, -35.0, 0.0)
    light.light_energy = 2.0
    add_child(light)
    return true
