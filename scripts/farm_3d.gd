extends "res://scripts/farm_3d_base.gd"
# HAPPY FARM 3D - complete controller with lighting, WASD, Shift and Space.
# The existing world, plots, pigs and shops live in farm_3d_base.gd.
# Replace this entire file whenever you want to update controls.

const WALK_SPEED: float = 4.2
const RUN_SPEED: float = 7.4
const JUMP_SPEED: float = 6.5
const GRAVITY: float = 19.0
const MIN_X: float = -17.5
const MAX_X: float = 17.5
const MIN_Z: float = -13.4
const MAX_Z: float = 13.4

var jump_height: float = 0.0
var vertical_speed: float = 0.0
var moving_freely: bool = false
var moving_fast: bool = false

func _ready() -> void:
    super._ready()
    status_text = "WASD เดิน | Shift วิ่ง | Space กระโดด | เลือกเครื่องมือแล้วคลิกแปลงเพื่อทำฟาร์ม"
    update_ui()

func _process(delta: float) -> void:
    update_jump(delta)
    handle_free_roam(delta)
    super._process(delta)

func update_jump(delta: float) -> void:
    if jump_height > 0.0 or vertical_speed > 0.0:
        vertical_speed -= GRAVITY * delta
        jump_height += vertical_speed * delta
        if jump_height <= 0.0:
            jump_height = 0.0
            vertical_speed = 0.0

func handle_free_roam(delta: float) -> void:
    moving_freely = false
    if farmer == null or actor_running or action_step != "":
        return
    if market_panel != null and market_panel.visible:
        return
    if Input.is_key_pressed(KEY_SPACE) and jump_height <= 0.0 and vertical_speed <= 0.0:
        vertical_speed = JUMP_SPEED
    var input_x: float = float(Input.is_key_pressed(KEY_D)) - float(Input.is_key_pressed(KEY_A))
    var input_z: float = float(Input.is_key_pressed(KEY_S)) - float(Input.is_key_pressed(KEY_W))
    var input_direction: Vector2 = Vector2(input_x, input_z)
    if input_direction.length_squared() < 0.01:
        return
    input_direction = input_direction.normalized()
    var forward: Vector3 = -camera.global_transform.basis.z
    forward.y = 0.0
    forward = forward.normalized()
    var right: Vector3 = camera.global_transform.basis.x
    right.y = 0.0
    right = right.normalized()
    var direction: Vector3 = (right * input_direction.x - forward * input_direction.y).normalized()
    moving_fast = Input.is_key_pressed(KEY_SHIFT)
    var speed: float = RUN_SPEED if moving_fast else WALK_SPEED
    farmer.position += direction * speed * delta
    farmer.position.x = clampf(farmer.position.x, MIN_X, MAX_X)
    farmer.position.z = clampf(farmer.position.z, MIN_Z, MAX_Z)
    farmer.rotation.y = atan2(-direction.x, -direction.z)
    moving_freely = true

func animate_farmer(delta: float) -> void:
    if actor_running or action_step != "":
        super.animate_farmer(delta)
        return
    if farmer == null:
        return
    hoe_tool.visible = false
    water_tool.visible = false
    farmer.rotation.z = lerpf(farmer.rotation.z, 0.0, minf(1.0, delta * 10.0))
    if moving_freely:
        var rate: float = 15.0 if moving_fast else 10.0
        var stride: float = sin(time_passed * rate)
        var amount: float = 0.75 if moving_fast else 0.48
        left_leg.rotation.x = stride * amount
        right_leg.rotation.x = -stride * amount
        left_arm.rotation.x = -stride * amount * 0.7
        right_arm.rotation.x = stride * amount * 0.7
        farmer.position.y = jump_height + (absf(stride) * 0.045 if jump_height <= 0.0 else 0.0)
    else:
        var blend: float = minf(1.0, delta * 11.0)
        left_leg.rotation.x = lerpf(left_leg.rotation.x, 0.0, blend)
        right_leg.rotation.x = lerpf(right_leg.rotation.x, 0.0, blend)
        left_arm.rotation.x = lerpf(left_arm.rotation.x, 0.0, blend)
        right_arm.rotation.x = lerpf(right_arm.rotation.x, 0.0, blend)
        farmer.position.y = jump_height

func build_world() -> void:
    super.build_world()
    for child in get_children():
        if child is WorldEnvironment:
            var atmosphere: Environment = child.environment
            # Mild, warm daylight (the previous environment was overexposed).
            atmosphere.background_mode = Environment.BG_COLOR
            atmosphere.background_color = Color("#afdbe7")
            atmosphere.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
            atmosphere.ambient_light_color = Color("#b5c7c2")
            atmosphere.ambient_light_energy = 0.48
            atmosphere.tonemap_mode = Environment.TONE_MAPPER_FILMIC
        elif child is DirectionalLight3D:
            child.light_color = Color("#ffe2b8")
            child.light_energy = 0.75
            child.shadow_enabled = true
    # Ground and paths with a calmer, natural green-and-earth palette.
    for child in get_children():
        if child is MeshInstance3D and child.mesh is BoxMesh:
            var sz: Vector3 = child.mesh.size
            if sz.x > 35.0 and sz.z > 25.0:
                child.material_override = mat(Color("#83b86b"))
            elif sz.x > 29.0 and sz.z < 3.0:
                child.material_override = mat(Color("#bea97e"))
            elif sz.z > 17.0 and sz.x < 3.0:
                child.material_override = mat(Color("#bea97e"))
