extends Node3D
# FarmFlex: identical Codex-authored male/female GLB models, including skeleton, hair and face morphs.
# Animation binding can be added when matching Mixamo clips are provided.
const ANIMATION_CONTROLLER = preload("res://scripts/ModularAnimations.gd")
const FEMALE_PATH = "res://assets/characters/Female_Character_Complete.glb"
const MALE_PATH = "res://assets/characters/Male_Character_Complete.glb"
# The old 0.50 height was still oversized against the 1.93-wide garden beds.
# This scales ONLY the scene instance, never modifies the source GLB vertices.
const TARGET_HEIGHT = 0.25
const DEFAULT_SKIN = "#e2b49d"
var imported_character: Node3D = null
var skeleton: Skeleton3D = null
var display_height: float = 0.0
var visual_scale: float = 1.0
var mesh_count: int = 0
var current_state: String = "Idle"
var motion_controller: Node = null
var anim_player: AnimationPlayer = null
var can_prop: Node3D = null
var hoe_prop: Node3D = null

func _find_meshes(node: Node, out: Array[MeshInstance3D]) -> void:
    if node is Skeleton3D and skeleton == null:
        skeleton = node as Skeleton3D
    if node is MeshInstance3D and (node as MeshInstance3D).mesh != null:
        out.append(node as MeshInstance3D)
    for child in node.get_children():
        _find_meshes(child, out)

func initialize(gender: String, appearance: Dictionary = {}) -> bool:
    var selected_path: String = MALE_PATH if gender == "male" else FEMALE_PATH
    if not ResourceLoader.exists(selected_path):
        push_warning("Modular character model is missing: " + selected_path)
        return false
    var packed: Resource = ResourceLoader.load(selected_path)
    if not (packed is PackedScene):
        push_warning("GLB did not import as PackedScene: " + selected_path)
        return false
    var created: Node = (packed as PackedScene).instantiate()
    if not (created is Node3D):
        created.free()
        return false
    imported_character = created as Node3D
    add_child(imported_character)
    var meshes: Array[MeshInstance3D] = []
    _find_meshes(imported_character, meshes)
    if meshes.is_empty():
        imported_character.queue_free()
        imported_character = null
        return false
    var hair_id: String = str(appearance.get("hair", "01")).pad_zeros(2)
    if hair_id not in ["01", "02", "03"]:
        hair_id = "01"
    var face_index: int = clampi(int(appearance.get("face", 0)), 0, 3)
    for mesh_node in meshes:
        var mesh_name: String = str(mesh_node.name)
        if mesh_name.contains("_Hair_"):
            mesh_node.visible = mesh_name.ends_with("_Hair_" + hair_id)
        elif mesh_name.contains("_Outfit_"):
            # Default player appearance uses the starter body, no extra shoes.
            mesh_node.visible = false
        elif mesh_name.contains("BaseBody"):
            if face_index > 0 and mesh_node.mesh.get_blend_shape_count() >= face_index:
                mesh_node.set_blend_shape_value(face_index - 1, 1.0)
            _apply_skin_tone(mesh_node, str(appearance.get("skin_color", DEFAULT_SKIN)), gender)
        if mesh_name.contains("_Hair_") and mesh_node.visible:
            _tint_hair(mesh_node, str(appearance.get("hair_color", "#78513d")))
    var low: Vector3 = Vector3(INF, INF, INF)
    var high: Vector3 = Vector3(-INF, -INF, -INF)
    var inverse_root: Transform3D = imported_character.global_transform.affine_inverse()
    mesh_count = 0
    for m in meshes:
        if not m.visible:
            continue
        var bounds: AABB = (inverse_root * m.global_transform) * m.get_aabb()
        low = low.min(bounds.position)
        high = high.max(bounds.end)
        mesh_count += 1
    if mesh_count == 0:
        return false
    var raw_height: float = high.y - low.y
    if not is_finite(raw_height) or raw_height <= 0.01:
        push_warning("Unexpected GLB model height: " + str(raw_height))
        return false
    visual_scale = TARGET_HEIGHT / raw_height
    imported_character.scale = Vector3.ONE * visual_scale
    # Bounds are in the GLB's unrotated local coordinates. Rotate the origin
    # correction too, or the visible avatar will be offset from the farmer axis.
    var rest_origin: Vector3 = Vector3((low.x + high.x) * 0.5, low.y, (low.z + high.z) * 0.5)
    imported_character.rotation.y = PI
    imported_character.position = -(Basis(Vector3.UP, PI) * rest_origin) * visual_scale
    display_height = raw_height * visual_scale
    print("FARMFLEX MODULAR: gender=", gender, " visible_meshes=", mesh_count,
          " height=", display_height, " hair=", hair_id, " face=", face_index)
    if has_visible_avatar() and skeleton != null:
        motion_controller = ANIMATION_CONTROLLER.new()
        motion_controller.name = "Motion_" + gender
        add_child(motion_controller)
        if motion_controller.initialize(self, skeleton, gender):
            anim_player = motion_controller.player
            _create_hand_tools()
        else:
            motion_controller.queue_free()
            motion_controller = null
    return has_visible_avatar()

func _tint_hair(mesh_node: MeshInstance3D, hex_color: String) -> void:
    if not Color.html_is_valid(hex_color):
        return
    var tint: Color = Color(hex_color)
    for surface_index in range(mesh_node.mesh.get_surface_count()):
        var base: Material = mesh_node.get_active_material(surface_index)
        if base is StandardMaterial3D:
            var recolored: StandardMaterial3D = (base as StandardMaterial3D).duplicate() as StandardMaterial3D
            recolored.albedo_color = tint
            mesh_node.set_surface_override_material(surface_index, recolored)

# Preserve the GLB's PBR material, texture tiling, alpha and shading.
# Only recolor warm skin pixels in the embedded body atlas (dark outfit pixels untouched).
# Default/legacy saves use the ORIGINAL materials exactly: no shader or recoloring.
func _apply_skin_tone(body: MeshInstance3D, hex_color: String, gender: String) -> void:
    if not Color.html_is_valid(hex_color) or hex_color.to_lower() == DEFAULT_SKIN:
        return
    var desired: Color = Color(hex_color)
    var reference: Vector3 = Vector3(201.0, 155.0, 132.0) if gender == "male" else Vector3(207.0, 163.0, 140.0)
    var target: Vector3 = Vector3(desired.r * 255.0, desired.g * 255.0, desired.b * 255.0)
    var gains: Vector3 = Vector3(target.x / reference.x, target.y / reference.y, target.z / reference.z)
    for idx in range(body.mesh.get_surface_count()):
        var surface: Material = body.get_active_material(idx)
        if not (surface is StandardMaterial3D):
            continue
        var original: StandardMaterial3D = surface as StandardMaterial3D
        var texture: Texture2D = original.albedo_texture
        if texture == null:
            continue
        var pixels: Image = texture.get_image()
        if pixels == null or pixels.is_empty():
            continue
        if pixels.is_compressed() and pixels.decompress() != OK:
            continue
        pixels.convert(Image.FORMAT_RGBA8)
        var source_bytes: PackedByteArray = pixels.get_data()
        var changed: PackedByteArray = source_bytes.duplicate()
        for at in range(0, source_bytes.size(), 4):
            var red: float = float(source_bytes[at])
            var green: float = float(source_bytes[at + 1])
            var blue: float = float(source_bytes[at + 2])
            # Warm skin clusters in original atlas; shirt/shorts are neutral charcoal.
            var warmth: float = clampf((red - green - 12.0) / 18.0, 0.0, 1.0)
            var red_blue: float = clampf((red - blue - 28.0) / 24.0, 0.0, 1.0)
            var skin_brightness: float = clampf((red - 100.0) / 35.0, 0.0, 1.0)
            var mask: float = warmth * red_blue * skin_brightness
            if mask < 0.01:
                continue
            changed[at] = clampi(roundi(lerpf(red, red * gains.x, mask)), 0, 255)
            changed[at + 1] = clampi(roundi(lerpf(green, green * gains.y, mask)), 0, 255)
            changed[at + 2] = clampi(roundi(lerpf(blue, blue * gains.z, mask)), 0, 255)
        var result_image: Image = Image.create_from_data(pixels.get_width(), pixels.get_height(), false, Image.FORMAT_RGBA8, changed)
        var material_copy: StandardMaterial3D = original.duplicate() as StandardMaterial3D
        material_copy.albedo_texture = ImageTexture.create_from_image(result_image)
        body.set_surface_override_material(idx, material_copy)

func has_visible_avatar() -> bool:
    return imported_character != null and mesh_count > 0 and display_height >= 0.20 and display_height <= 0.30

func is_model_ready() -> bool:
    return has_visible_avatar()

# Simple tools follow the matching Mixamo hand bone, not the old hidden
# procedural character. Imported skinned gloves remain compatible.
func _tool_part(parent: Node3D, primitive: PrimitiveMesh, local_position: Vector3, tint: Color) -> MeshInstance3D:
    var mesh: MeshInstance3D = MeshInstance3D.new()
    mesh.mesh = primitive
    mesh.position = local_position
    var material: StandardMaterial3D = StandardMaterial3D.new()
    material.albedo_color = tint
    material.roughness = 0.86
    mesh.material_override = material
    parent.add_child(mesh)
    return mesh

func _create_hand_tools() -> void:
    var bone: int = -1
    for i in range(skeleton.get_bone_count()):
        if String(skeleton.get_bone_name(i)).to_lower().ends_with("righthand"):
            bone = i
            break
    if bone < 0:
        return
    var mount: BoneAttachment3D = BoneAttachment3D.new()
    mount.name = "RightHandEquipment"
    mount.bone_name = String(skeleton.get_bone_name(bone))
    skeleton.add_child(mount)
    can_prop = Node3D.new()
    can_prop.name = "WateringCan"
    can_prop.position = Vector3(0.0, 0.03, 0.02)
    mount.add_child(can_prop)
    var body: SphereMesh = SphereMesh.new()
    body.radius = 0.075
    body.height = 0.12
    _tool_part(can_prop, body, Vector3.ZERO, Color("#5ca7a2"))
    var spout: CylinderMesh = CylinderMesh.new()
    spout.top_radius = 0.012
    spout.bottom_radius = 0.021
    spout.height = 0.17
    var spout_part: MeshInstance3D = _tool_part(can_prop, spout, Vector3(0.12, 0.01, 0.0), Color("#87bab8"))
    spout_part.rotation.z = PI * 0.5
    hoe_prop = Node3D.new()
    hoe_prop.name = "DiggingHoe"
    hoe_prop.position = Vector3(0.0, -0.16, 0.03)
    mount.add_child(hoe_prop)
    var shaft: CylinderMesh = CylinderMesh.new()
    shaft.top_radius = 0.014
    shaft.bottom_radius = 0.014
    shaft.height = 0.43
    _tool_part(hoe_prop, shaft, Vector3.ZERO, Color("#936d47"))
    var blade: BoxMesh = BoxMesh.new()
    blade.size = Vector3(0.19, 0.035, 0.07)
    _tool_part(hoe_prop, blade, Vector3(0, -0.21, 0), Color("#a9afb2"))
    can_prop.visible = false
    hoe_prop.visible = false

func set_state(state: String) -> void:
    if state not in ["Idle", "Walk", "Run", "Jump", "Water", "Dig"]:
        state = "Idle"
    current_state = state
    if can_prop != null:
        can_prop.visible = state == "Water"
    if hoe_prop != null:
        hoe_prop.visible = state == "Dig"
    if motion_controller != null:
        motion_controller.change_state(state)
