extends Node3D
# Happy Farm 3D: fully procedural low-poly world for Chrome/PC/mobile.
# Placeholder characters can later be replaced by FBX/Mixamo scenes.
const FONT = preload("res://assets/NotoSansThai-Regular.ttf")
const SAVE = "user://happy_farm.json"
const CROPS = [
    {"name":"แครอต","cost":8,"sell":18,"seconds":15.0,"color":"#f08c34"},
    {"name":"ผักกาด","cost":10,"sell":24,"seconds":20.0,"color":"#addd60"},
    {"name":"มะเขือเทศ","cost":12,"sell":28,"seconds":25.0,"color":"#f14d43"},
    {"name":"ข้าวโพด","cost":18,"sell":43,"seconds":32.0,"color":"#f3d15e"},
    {"name":"ฟักทอง","cost":25,"sell":62,"seconds":45.0,"color":"#f39129"},
    {"name":"มันหวาน","cost":13,"sell":30,"seconds":25.0,"color":"#a17cc5"},
    {"name":"สตรอว์เบอร์รี","cost":20,"sell":54,"seconds":35.0,"color":"#e9405a"},
    {"name":"แตงโม","cost":30,"sell":76,"seconds":50.0,"color":"#3d974c"},
    {"name":"สับปะรด","cost":35,"sell":90,"seconds":55.0,"color":"#efd055"},
    {"name":"แอปเปิล","cost":40,"sell":103,"seconds":60.0,"color":"#ed4244"},
    {"name":"ส้ม","cost":38,"sell":96,"seconds":55.0,"color":"#f89b38"},
    {"name":"มะม่วง","cost":48,"sell":130,"seconds":70.0,"color":"#e7c754"}
]
const BROWN = Color("#805036")
const WET_BROWN = Color("#4b382d")
const LEAF = Color("#4f9f50")
const DARK = Color("#29442d")
const SKY = Color("#c4e9ee")
const FARM_X = 6
const FARM_Z = 4
const SPACING_X = 2.45
const SPACING_Z = 2.43

var mats: Dictionary = {}
var camera: Camera3D
var farmer: Node3D
var left_arm: Node3D
var right_arm: Node3D
var left_leg: Node3D
var right_leg: Node3D
var hoe_tool: Node3D
var water_tool: Node3D
var actor_target: Vector3 = Vector3.ZERO
var actor_running: bool = false
var action_step: String = ""
var action_time: float = 0.0
var action_index: int = -1
var selected_crop: int = 0
var selected_mode: String = "plant"
var money: int = 350
var feed: int = 4
var seeds: Array = []
var plots: Array = []
var pigs: Array = []
var plot_positions: Array = []
var plot_soils: Array = []
var plot_plants: Array = []
var plot_stages: Array = []
var pig_actors: Array = []
var tree_crowns: Array = []
var time_passed: float = 0.0
var refresh_clock: float = 0.0
var status_text: String = "กดแปลงดินเพื่อให้ชาวสวนวิ่งไปปลูกผัก"
var money_label: Label
var status_label: Label
var seed_option: OptionButton
var market_panel: PanelContainer
var market_info: Label
var top_panel: PanelContainer
var bottom_panel: PanelContainer
var mode_buttons: Dictionary = {}

func _ready() -> void:
    load_game()
    build_world()
    build_farmer()
    build_ui()
    refresh_fields()
    refresh_pig_models()
    update_ui()
    update_camera()
    get_viewport().size_changed.connect(update_camera)

func _process(delta: float) -> void:
    time_passed += delta
    refresh_clock += delta
    animate_farmer(delta)
    animate_pigs()
    for crown in tree_crowns:
        if is_instance_valid(crown):
            crown.rotation.z = sin(time_passed * 1.1 + crown.position.x) * 0.032
    if refresh_clock > 0.6:
        refresh_clock = 0.0
        refresh_fields()
        update_ui()

func load_game() -> void:
    for i in range(CROPS.size()):
        seeds.append(3 if i < 3 else 0)
    for i in range(FARM_X * FARM_Z):
        plots.append({})
    pigs.append({"hunger":75,"born":Time.get_unix_time_from_system()})
    if not FileAccess.file_exists(SAVE):
        return
    var file: FileAccess = FileAccess.open(SAVE, FileAccess.READ)
    if file == null:
        return
    var data: Variant = JSON.parse_string(file.get_as_text())
    if not (data is Dictionary):
        return
    money = int(data.get("money", 350))
    feed = int(data.get("feed", 4))
    var loaded_seeds: Variant = data.get("seeds", [])
    var loaded_plots: Variant = data.get("plots", [])
    var loaded_pigs: Variant = data.get("pigs", [])
    if loaded_seeds is Array:
        for i in range(mini(CROPS.size(), loaded_seeds.size())):
            seeds[i] = maxi(0, int(loaded_seeds[i]))
    if loaded_plots is Array:
        for i in range(mini(plots.size(), loaded_plots.size())):
            if loaded_plots[i] is Dictionary:
                plots[i] = loaded_plots[i]
    if loaded_pigs is Array and not loaded_pigs.is_empty():
        pigs = loaded_pigs

func save_game() -> void:
    var file: FileAccess = FileAccess.open(SAVE, FileAccess.WRITE)
    if file != null:
        file.store_string(JSON.stringify({
            "money":money, "feed":feed, "seeds":seeds,
            "plots":plots, "pigs":pigs
        }))

func mat(color: Color) -> StandardMaterial3D:
    var key: String = color.to_html(true)
    if not mats.has(key):
        var m: StandardMaterial3D = StandardMaterial3D.new()
        m.albedo_color = color
        m.roughness = 0.94
        mats[key] = m
    return mats[key]

func box(parent: Node3D, pos: Vector3, dims: Vector3, color: Color) -> MeshInstance3D:
    var obj: MeshInstance3D = MeshInstance3D.new()
    var m: BoxMesh = BoxMesh.new()
    m.size = dims
    obj.mesh = m
    obj.material_override = mat(color)
    obj.position = pos
    parent.add_child(obj)
    return obj

func sphere(parent: Node3D, pos: Vector3, size_xyz: Vector3, color: Color) -> MeshInstance3D:
    var obj: MeshInstance3D = MeshInstance3D.new()
    var m: SphereMesh = SphereMesh.new()
    m.radius = 0.5
    m.height = 1.0
    m.radial_segments = 12
    m.rings = 7
    obj.mesh = m
    obj.material_override = mat(color)
    obj.position = pos
    obj.scale = size_xyz
    parent.add_child(obj)
    return obj

func cylinder(parent: Node3D, pos: Vector3, height: float, radius: float, color: Color) -> MeshInstance3D:
    var obj: MeshInstance3D = MeshInstance3D.new()
    var m: CylinderMesh = CylinderMesh.new()
    m.height = height
    m.top_radius = radius
    m.bottom_radius = radius * 1.06
    m.radial_segments = 10
    obj.mesh = m
    obj.material_override = mat(color)
    obj.position = pos
    parent.add_child(obj)
    return obj

func make_tree(pos: Vector3, scale_factor: float = 1.0) -> void:
    var root: Node3D = Node3D.new()
    root.position = pos
    add_child(root)
    cylinder(root, Vector3(0, 1.2 * scale_factor, 0), 2.4 * scale_factor, 0.22 * scale_factor, Color("#866346"))
    var top: Node3D = Node3D.new()
    top.position = Vector3(0, 2.55 * scale_factor, 0)
    root.add_child(top)
    sphere(top, Vector3(0, 0.2, 0), Vector3(2.0, 1.7, 1.9) * scale_factor, Color("#438e57"))
    sphere(top, Vector3(-0.65, 0, 0.12), Vector3(1.3, 1.45, 1.35) * scale_factor, Color("#59a85c"))
    sphere(top, Vector3(0.65, 0.12, -0.06), Vector3(1.35, 1.3, 1.4) * scale_factor, Color("#69b95e"))
    for i in range(4):
        sphere(top, Vector3(sin(float(i) * 1.6) * 0.72, 0.10 + float(i % 2) * 0.27, cos(float(i) * 1.4) * 0.76),
            Vector3(0.20, 0.22, 0.20), Color("#f0b748"))
    tree_crowns.append(top)

func build_world() -> void:
    var env: WorldEnvironment = WorldEnvironment.new()
    env.environment = Environment.new()
    env.environment.background_mode = Environment.BG_COLOR
    env.environment.background_color = SKY
    env.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
    env.environment.ambient_light_color = Color("#e2f4e5")
    env.environment.ambient_light_energy = 0.83
    add_child(env)
    var sun: DirectionalLight3D = DirectionalLight3D.new()
    sun.rotation_degrees = Vector3(-55, -30, -22)
    sun.light_energy = 1.45
    sun.shadow_enabled = true
    add_child(sun)
    camera = Camera3D.new()
    camera.projection = Camera3D.PROJECTION_ORTHOGONAL
    camera.current = true
    add_child(camera)
    box(self, Vector3(0, -0.22, 0), Vector3(38.0, 0.4, 30.0), Color("#84bc6d"))
    box(self, Vector3(0, -0.01, 8.8), Vector3(31.0, 0.03, 2.35), Color("#c8ac78"))
    box(self, Vector3(-10, -0.01, -1), Vector3(2.0, 0.035, 22), Color("#cfb581"))
    box(self, Vector3(10, -0.01, 0), Vector3(2.0, 0.035, 18.0), Color("#cfb581"))
    # A barn and house define the farm environment.
    var house: Node3D = Node3D.new()
    house.position = Vector3(-12.3, 0, -6.4)
    add_child(house)
    box(house, Vector3(0, 1.6, 0), Vector3(4.6, 3.2, 4.0), Color("#f4ddad"))
    var left_roof: MeshInstance3D = box(house, Vector3(-1.15, 3.45, 0), Vector3(3.15, 0.35, 4.65), Color("#bd644f"))
    left_roof.rotation.z = -0.58
    var right_roof: MeshInstance3D = box(house, Vector3(1.15, 3.45, 0), Vector3(3.15, 0.35, 4.65), Color("#bd644f"))
    right_roof.rotation.z = 0.58
    box(house, Vector3(0, 1.08, 2.02), Vector3(1.25, 2.17, 0.15), Color("#936344"))
    box(house, Vector3(-1.45, 1.98, 2.06), Vector3(0.9, 0.95, 0.10), Color("#82c3e6"))
    box(house, Vector3(1.45, 1.98, 2.06), Vector3(0.9, 0.95, 0.10), Color("#82c3e6"))
    box(house, Vector3(-1.45, 1.98, 2.11), Vector3(0.08, 0.94, 0.08), Color("#f8edcf"))
    box(house, Vector3(1.45, 1.98, 2.11), Vector3(0.08, 0.94, 0.08), Color("#f8edcf"))
    # Raised soil plots with neat borders and furrows.
    for row in range(FARM_Z):
        for col in range(FARM_X):
            var pos: Vector3 = Vector3((float(col) - 2.5) * SPACING_X, 0, (float(row) - 1.5) * SPACING_Z)
            var plot: Node3D = Node3D.new()
            plot.position = pos
            add_child(plot)
            var soil: MeshInstance3D = box(plot, Vector3(0, 0.09, 0), Vector3(2.06, 0.22, 2.04), BROWN)
            plot_soils.append(soil)
            box(plot, Vector3(-1.06, 0.19, 0), Vector3(0.13, 0.25, 2.2), Color("#d5ad6b"))
            box(plot, Vector3(1.06, 0.19, 0), Vector3(0.13, 0.25, 2.2), Color("#d5ad6b"))
            box(plot, Vector3(0, 0.19, -1.06), Vector3(2.2, 0.25, 0.13), Color("#d5ad6b"))
            box(plot, Vector3(0, 0.19, 1.06), Vector3(2.2, 0.25, 0.13), Color("#d5ad6b"))
            for k in range(3):
                box(plot, Vector3((float(k) - 1.0) * 0.47, 0.215, 0), Vector3(0.12, 0.045, 1.6), Color("#9d6841"))
            var plant: Node3D = Node3D.new()
            plant.position = Vector3(0, 0.25, 0)
            plot.add_child(plant)
            plot_positions.append(pos)
            plot_plants.append(plant)
            plot_stages.append(-99)
    # Pig pen, feed trough and fencing.
    var pen: Node3D = Node3D.new()
    pen.position = Vector3(12.65, 0, 0.1)
    add_child(pen)
    box(pen, Vector3(0, 0.025, 0), Vector3(7.2, 0.06, 7.5), Color("#c9c277"))
    for k in range(5):
        var x: float = -3.3 + float(k) * 1.65
        box(pen, Vector3(x, 0.65, -3.55), Vector3(0.18, 1.3, 0.18), Color("#956744"))
        box(pen, Vector3(x, 0.65, 3.55), Vector3(0.18, 1.3, 0.18), Color("#956744"))
    for k in range(5):
        var z: float = -3.55 + float(k) * 1.775
        box(pen, Vector3(-3.3, 0.65, z), Vector3(0.18, 1.3, 0.18), Color("#956744"))
        box(pen, Vector3(3.3, 0.65, z), Vector3(0.18, 1.3, 0.18), Color("#956744"))
    for h in [0.38, 0.92]:
        for z in [-3.55, 3.55]:
            box(pen, Vector3(0, h, z), Vector3(6.6, 0.12, 0.12), Color("#c18a57"))
        for x in [-3.3, 3.3]:
            box(pen, Vector3(x, h, 0), Vector3(0.12, 0.12, 7.1), Color("#c18a57"))
    box(pen, Vector3(0, 0.28, -2.6), Vector3(1.8, 0.54, 0.75), Color("#8e6646"))
    box(pen, Vector3(0, 0.59, -2.6), Vector3(1.5, 0.16, 0.56), Color("#75a55c"))
    var shed: Node3D = Node3D.new()
    shed.position = Vector3(13.3, 0, -8.2)
    add_child(shed)
    box(shed, Vector3(0, 1.3, 0), Vector3(4.5, 2.6, 3.5), Color("#b87758"))
    box(shed, Vector3(0, 2.85, 0), Vector3(5.4, 0.4, 4.2), Color("#7f4b3e"))
    box(shed, Vector3(-0.35, 1.1, 1.78), Vector3(2.0, 2.1, 0.12), Color("#5f4035"))
    # Orchards, flowers, stones.
    for p in [Vector3(-15,0,5),Vector3(-15,0,11),Vector3(-10,0,12),
        Vector3(-4,0,-11),Vector3(2,0,-11),Vector3(7.6,0,-11),Vector3(17,0,9),
        Vector3(17,0,-11),Vector3(-17,0,-11)]:
        make_tree(p, 0.78 + absf(sin(p.x)) * 0.18)
    for i in range(28):
        var x: float = sin(float(i) * 13.73) * 17.0
        var z: float = cos(float(i) * 7.15) * 13.0
        if absf(x) < 8.0 and absf(z) < 6.3:
            continue
        sphere(self, Vector3(x, 0.07, z), Vector3(0.16, 0.14, 0.16),
            Color("#f5de81") if i % 2 == 0 else Color("#fff5e0"))

func build_farmer() -> void:
    farmer = Node3D.new()
    farmer.position = Vector3(-1.1, 0.0, 8.6)
    add_child(farmer)
    sphere(farmer, Vector3(0, 1.45, 0), Vector3(0.76, 0.92, 0.52), Color("#54a3b6"))
    sphere(farmer, Vector3(0, 2.09, 0), Vector3(0.58, 0.62, 0.54), Color("#f3c08f"))
    sphere(farmer, Vector3(-0.17, 2.12, -0.255), Vector3(0.07, 0.07, 0.06), DARK)
    sphere(farmer, Vector3(0.17, 2.12, -0.255), Vector3(0.07, 0.07, 0.06), DARK)
    cylinder(farmer, Vector3(0, 2.39, 0), 0.14, 0.53, Color("#e6b46c"))
    cylinder(farmer, Vector3(0, 2.51, 0), 0.26, 0.33, Color("#d8a052"))
    box(farmer, Vector3(0, 0.91, -0.16), Vector3(0.65, 0.56, 0.22), Color("#9d684a"))
    left_arm = Node3D.new()
    left_arm.position = Vector3(-0.48, 1.83, 0)
    farmer.add_child(left_arm)
    right_arm = Node3D.new()
    right_arm.position = Vector3(0.48, 1.83, 0)
    farmer.add_child(right_arm)
    box(left_arm, Vector3(0, -0.36, -0.02), Vector3(0.24, 0.71, 0.26), Color("#f3c08f"))
    box(right_arm, Vector3(0, -0.36, -0.02), Vector3(0.24, 0.71, 0.26), Color("#f3c08f"))
    left_leg = Node3D.new()
    left_leg.position = Vector3(-0.22, 1.09, 0)
    farmer.add_child(left_leg)
    right_leg = Node3D.new()
    right_leg.position = Vector3(0.22, 1.09, 0)
    farmer.add_child(right_leg)
    box(left_leg, Vector3(0, -0.44, 0), Vector3(0.28, 0.82, 0.3), Color("#576d9b"))
    box(right_leg, Vector3(0, -0.44, 0), Vector3(0.28, 0.82, 0.3), Color("#576d9b"))
    box(left_leg, Vector3(0, -0.88, -0.12), Vector3(0.32, 0.18, 0.48), Color("#634632"))
    box(right_leg, Vector3(0, -0.88, -0.12), Vector3(0.32, 0.18, 0.48), Color("#634632"))
    hoe_tool = Node3D.new()
    right_arm.add_child(hoe_tool)
    cylinder(hoe_tool, Vector3(0.03, -0.72, -0.24), 1.35, 0.065, Color("#bd935b"))
    box(hoe_tool, Vector3(0.03, -1.37, -0.24), Vector3(0.55, 0.1, 0.23), Color("#858f96"))
    water_tool = Node3D.new()
    right_arm.add_child(water_tool)
    cylinder(water_tool, Vector3(0.02, -0.87, -0.22), 0.46, 0.26, Color("#61b6c3"))
    var nozzle: MeshInstance3D = cylinder(water_tool, Vector3(-0.27, -0.91, -0.28), 0.46, 0.055, Color("#61b6c3"))
    nozzle.rotation.z = PI * 0.47
    sphere(water_tool, Vector3(-0.46, -0.87, -0.30), Vector3(0.15, 0.11, 0.15), Color("#4d8fa8"))
    hoe_tool.visible = false
    water_tool.visible = false

func make_pig(index: int) -> Node3D:
    var pig: Node3D = Node3D.new()
    pig.position = Vector3(12.65 + (float(index % 3) - 1.0) * 1.5, 0.1, (float(index / 3) - 1.0) * 1.7)
    add_child(pig)
    sphere(pig, Vector3(0, 0.61, 0), Vector3(1.25, 0.82, 1.02), Color("#f6a4b2"))
    sphere(pig, Vector3(0, 0.77, -0.53), Vector3(0.80, 0.74, 0.63), Color("#f8afbc"))
    sphere(pig, Vector3(0, 0.68, -0.84), Vector3(0.48, 0.30, 0.19), Color("#dc8099"))
    for side in [-1.0, 1.0]:
        sphere(pig, Vector3(side * 0.22, 0.94, -0.81), Vector3(0.09, 0.10, 0.08), Color("#46383c"))
        sphere(pig, Vector3(side * 0.29, 1.16, -0.49), Vector3(0.27, 0.38, 0.13), Color("#ef8ca5"))
        sphere(pig, Vector3(side * 0.40, 0.2, -0.31), Vector3(0.26, 0.48, 0.25), Color("#f6a4b2"))
        sphere(pig, Vector3(side * 0.40, 0.2, 0.38), Vector3(0.26, 0.48, 0.25), Color("#f6a4b2"))
    sphere(pig, Vector3(-0.15, 0.70, -0.953), Vector3(0.08, 0.08, 0.04), Color("#9a5268"))
    sphere(pig, Vector3(0.15, 0.70, -0.953), Vector3(0.08, 0.08, 0.04), Color("#9a5268"))
    return pig

func refresh_pig_models() -> void:
    while pig_actors.size() < mini(pigs.size(), 8):
        pig_actors.append(make_pig(pig_actors.size()))

func animate_pigs() -> void:
    for i in range(pig_actors.size()):
        var pig: Node3D = pig_actors[i]
        if not is_instance_valid(pig):
            continue
        var f: float = time_passed * (0.58 + float(i) * 0.04) + float(i) * 2.3
        pig.position = Vector3(12.65 + sin(f) * (1.45 + float(i % 2) * 0.37),
            0.10 + absf(sin(f * 3.0)) * 0.035,
            sin(f * 0.61 + float(i)) * 1.35)
        pig.rotation.y = sin(f * 0.45) * 0.75

func stage_for(idx: int) -> int:
    var cell: Dictionary = plots[idx]
    if not cell.has("seed"):
        return 0
    if not bool(cell.get("wet", false)):
        return 1
    var crop_id: int = clampi(int(cell.get("seed", 0)), 0, CROPS.size() - 1)
    var age: float = Time.get_unix_time_from_system() - float(cell.get("time", 0.0))
    var ratio: float = clampf(age / float(CROPS[crop_id]["seconds"]), 0.0, 1.0)
    if ratio < 0.20:
        return 2
    if ratio < 0.5:
        return 3
    if ratio < 0.85:
        return 4
    return 5

func is_ripe(idx: int) -> bool:
    return stage_for(idx) == 5

func refresh_fields() -> void:
    for i in range(plots.size()):
        var cell: Dictionary = plots[i]
        var s: int = stage_for(i)
        if int(plot_stages[i]) == s:
            continue
        plot_stages[i] = s
        plot_soils[i].material_override = mat(WET_BROWN if bool(cell.get("wet", false)) else BROWN)
        var holder: Node3D = plot_plants[i]
        for child in holder.get_children():
            holder.remove_child(child)
            child.queue_free()
        if s < 1 or not cell.has("seed"):
            continue
        var crop_id: int = clampi(int(cell["seed"]), 0, CROPS.size() - 1)
        draw_crop(holder, crop_id, s)
        holder.scale = Vector3(1.0, 0.05, 1.0)
        var tween: Tween = create_tween()
        tween.tween_property(holder, "scale", Vector3.ONE, 0.45).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

func draw_crop(holder: Node3D, crop_id: int, stage: int) -> void:
    var scale_f: float = 0.25 if stage == 1 else (0.42 if stage == 2 else (0.72 if stage == 3 else 1.0))
    var leaf: Color = Color("#4d9f54")
    var fruit: Color = Color(str(CROPS[crop_id]["color"]))
    var is_tree: bool = crop_id >= 9
    if is_tree and stage >= 3:
        cylinder(holder, Vector3(0, 0.58 * scale_f, 0), 1.12 * scale_f, 0.15, Color("#8e6846"))
        sphere(holder, Vector3(0, 1.25 * scale_f, 0), Vector3(1.35, 1.10, 1.35) * scale_f, leaf)
        if stage >= 4:
            for k in range(4):
                sphere(holder, Vector3(sin(float(k) * 2.1) * 0.38 * scale_f, (1.27 + float(k % 2) * 0.3) * scale_f,
                    cos(float(k) * 2.1) * 0.32 * scale_f), Vector3.ONE * 0.24 * scale_f, fruit)
        return
    for k in range(3):
        var x: float = (float(k) - 1.0) * 0.48
        cylinder(holder, Vector3(x, 0.36 * scale_f, 0), 0.67 * scale_f, 0.055, Color("#3b8a44"))
        sphere(holder, Vector3(x - 0.14 * scale_f, 0.46 * scale_f, 0.05), Vector3(0.30, 0.14, 0.43) * scale_f, leaf)
        sphere(holder, Vector3(x + 0.14 * scale_f, 0.56 * scale_f, -0.04), Vector3(0.30, 0.15, 0.37) * scale_f, leaf.lightened(0.11))
        if stage >= 4:
            if crop_id == 1:
                sphere(holder, Vector3(x, 0.50 * scale_f, 0), Vector3(0.56, 0.54, 0.59) * scale_f, Color("#a9db67"))
            elif crop_id == 0:
                var carrot: MeshInstance3D = cylinder(holder, Vector3(x, 0.24 * scale_f, 0), 0.49 * scale_f, 0.20 * scale_f, fruit)
                carrot.scale = Vector3(1,1,1)
            else:
                sphere(holder, Vector3(x, 0.55 * scale_f, 0.03), Vector3(0.44, 0.40, 0.44) * scale_f, fruit)
    if stage == 5:
        sphere(holder, Vector3(0, 0.91, 0), Vector3(0.15, 0.15, 0.15), Color("#ffe080"))

func splash_water(idx: int) -> void:
    var origin: Vector3 = plot_positions[idx]
    for i in range(12):
        var drop: MeshInstance3D = sphere(self,
            origin + Vector3((float(i % 4) - 1.5) * 0.35, 1.6 + float(i % 3) * 0.24,
                (float(i / 4) - 1.0) * 0.39), Vector3.ONE * 0.115, Color("#55bff1"))
        var tween: Tween = create_tween()
        tween.tween_property(drop, "position:y", 0.28, 0.43 + float(i % 3) * 0.09)
        tween.tween_callback(drop.queue_free)

func animate_farmer(delta: float) -> void:
    if farmer == null:
        return
    if actor_running:
        var diff: Vector3 = actor_target - farmer.position
        diff.y = 0.0
        if diff.length() > 0.10:
            var direction: Vector3 = diff.normalized()
            farmer.position += direction * minf(diff.length(), 4.8 * delta)
            farmer.rotation.y = atan2(-direction.x, -direction.z)
            var steps: float = sin(time_passed * 12.0) * 0.55
            left_leg.rotation.x = steps
            right_leg.rotation.x = -steps
            left_arm.rotation.x = -steps * 0.8
            right_arm.rotation.x = steps * 0.8
            farmer.position.y = absf(sin(time_passed * 12.0)) * 0.07
        else:
            actor_running = false
            start_work()
    elif action_step != "":
        action_time -= delta
        var swing: float = sin((2.0 - action_time) * 10.0)
        right_arm.rotation.x = -0.55 + swing * 0.45
        left_arm.rotation.x = 0.18 + swing * 0.13
        farmer.rotation.z = sin((2.0 - action_time) * 5.0) * 0.06
        farmer.position.y = absf(sin(time_passed * 4.0)) * 0.025
        if action_time <= 0.0:
            finish_work()
    else:
        left_leg.rotation.x = lerpf(left_leg.rotation.x, 0.0, 0.16)
        right_leg.rotation.x = lerpf(right_leg.rotation.x, 0.0, 0.16)
        left_arm.rotation.x = lerpf(left_arm.rotation.x, 0.0, 0.16)
        right_arm.rotation.x = lerpf(right_arm.rotation.x, 0.0, 0.16)
        farmer.rotation.z = lerpf(farmer.rotation.z, 0.0, 0.16)
        farmer.position.y = 0.0
        hoe_tool.visible = false
        water_tool.visible = false

func start_work() -> void:
    if action_index < 0:
        return
    action_step = "hoe" if selected_mode == "till" or (selected_mode == "plant" and not plots[action_index].get("tilled", false)) else selected_mode
    action_time = 0.9 if action_step == "hoe" else (1.35 if action_step == "water" else 0.8)
    hoe_tool.visible = action_step == "hoe"
    water_tool.visible = action_step == "water"
    if action_step == "hoe":
        status_text = "ชาวสวนกำลังพรวนดิน..."
    elif action_step == "plant":
        status_text = "ชาวสวนกำลังหยอดเมล็ด..."
    elif action_step == "water":
        status_text = "ชาวสวนกำลังรดน้ำ..."
    else:
        status_text = "ชาวสวนกำลังเก็บเกี่ยว..."
    update_ui()

func finish_work() -> void:
    var idx: int = action_index
    var step: String = action_step
    action_step = ""
    if idx < 0 or idx >= plots.size():
        return
    if step == "hoe":
        plots[idx]["tilled"] = true
        status_text = "พรวนดินเรียบร้อย"
        save_game()
        if selected_mode == "plant":
            action_step = "plant"
            action_time = 0.85
            hoe_tool.visible = false
            update_ui()
            return
    elif step == "plant":
        if int(seeds[selected_crop]) > 0 and not plots[idx].has("seed"):
            seeds[selected_crop] = int(seeds[selected_crop]) - 1
            plots[idx] = {"tilled":true,"seed":selected_crop,"wet":false,"time":Time.get_unix_time_from_system()}
            status_text = "ปลูก%sแล้ว กดรดน้ำและแตะแปลงเดิม" % str(CROPS[selected_crop]["name"])
        else:
            status_text = "เมล็ดไม่พอหรือแปลงนี้ปลูกไปแล้ว"
    elif step == "water":
        plots[idx]["wet"] = true
        if not bool(plots[idx].get("watered_once", false)):
            plots[idx]["time"] = Time.get_unix_time_from_system()
            plots[idx]["watered_once"] = true
        splash_water(idx)
        status_text = "รดน้ำแล้ว! ผักกำลังโตเป็นระยะ ๆ"
    elif step == "harvest":
        var crop_id: int = clampi(int(plots[idx].get("seed", 0)), 0, CROPS.size() - 1)
        money += int(CROPS[crop_id]["sell"])
        plots[idx] = {"tilled":true}
        status_text = "เก็บเกี่ยวขายได้ %d เหรียญ" % int(CROPS[crop_id]["sell"])
    save_game()
    refresh_fields()
    update_ui()

func try_plot(idx: int) -> void:
    if idx < 0 or idx >= plots.size() or actor_running or action_step != "":
        return
    var cell: Dictionary = plots[idx]
    if selected_mode == "plant":
        if cell.has("seed"):
            status_text = "แปลงนี้ปลูกแล้ว เลือกรดน้ำหรือเก็บเกี่ยว"
            update_ui()
            return
        if int(seeds[selected_crop]) <= 0:
            status_text = "เมล็ดหมด! กดร้านค้าเพื่อซื้อเมล็ดเพิ่ม"
            update_ui()
            return
    elif selected_mode == "water" and not cell.has("seed"):
        status_text = "ต้องปลูกพืชก่อนรดน้ำ"
        update_ui()
        return
    elif selected_mode == "harvest" and not is_ripe(idx):
        status_text = "ยังไม่พร้อมเก็บเกี่ยว ต้องรดน้ำแล้วรอให้โต"
        update_ui()
        return
    elif selected_mode == "till" and cell.has("seed"):
        status_text = "มีพืชอยู่แล้ว ไม่สามารถพรวนดินทับ"
        update_ui()
        return
    action_index = idx
    actor_target = plot_positions[idx] + Vector3(0.0, 0.0, 1.35)
    actor_running = true
    status_text = "ชาวสวนกำลังวิ่งไปแปลง %d" % (idx + 1)
    update_ui()

func _unhandled_input(event: InputEvent) -> void:
    if market_panel != null and market_panel.visible:
        return
    if event is InputEventMouseButton:
        if event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
            select_world_point(event.position)
        elif event.pressed and event.button_index == MOUSE_BUTTON_WHEEL_UP:
            camera.size = maxf(14.0, camera.size - 1.5)
        elif event.pressed and event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
            camera.size = minf(38.0, camera.size + 1.5)

func select_world_point(screen: Vector2) -> void:
    var ray_o: Vector3 = camera.project_ray_origin(screen)
    var ray_d: Vector3 = camera.project_ray_normal(screen)
    if absf(ray_d.y) < 0.0001:
        return
    var distance: float = (0.18 - ray_o.y) / ray_d.y
    if distance <= 0:
        return
    var point: Vector3 = ray_o + ray_d * distance
    var best: int = -1
    var nearest: float = 1.23
    for i in range(plot_positions.size()):
        var d: float = Vector2(point.x - plot_positions[i].x, point.z - plot_positions[i].z).length()
        if d < nearest:
            nearest = d
            best = i
    if best >= 0:
        try_plot(best)

func update_camera() -> void:
    if camera == null:
        return
    var viewport: Vector2 = get_viewport().get_visible_rect().size
    var ratio: float = viewport.x / maxf(1.0, viewport.y)
    camera.position = Vector3(17, 22, 25)
    camera.look_at(Vector3(0, 0, 0))
    camera.size = 20.5 if ratio >= 1.25 else (28.0 if ratio >= 0.78 else 37.0)

func make_label(text_value: String, size_val: int = 20) -> Label:
    var label: Label = Label.new()
    label.text = text_value
    label.add_theme_font_override("font", FONT)
    label.add_theme_font_size_override("font_size", size_val)
    label.add_theme_color_override("font_color", DARK)
    label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    return label

func make_button(text_value: String, callback: Callable, color: Color = Color("#4b9868")) -> Button:
    var button: Button = Button.new()
    button.text = text_value
    button.add_theme_font_override("font", FONT)
    button.add_theme_font_size_override("font_size", 18)
    button.add_theme_color_override("font_color", Color.WHITE)
    button.custom_minimum_size = Vector2(114, 50)
    button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    var normal: StyleBoxFlat = StyleBoxFlat.new()
    normal.bg_color = color
    normal.set_corner_radius_all(11)
    normal.set_content_margin_all(6)
    button.add_theme_stylebox_override("normal", normal)
    button.add_theme_stylebox_override("hover", normal)
    button.add_theme_stylebox_override("pressed", normal)
    button.pressed.connect(callback)
    return button

func make_panel() -> PanelContainer:
    var panel: PanelContainer = PanelContainer.new()
    var style: StyleBoxFlat = StyleBoxFlat.new()
    style.bg_color = Color("#eff5e3ed")
    style.set_corner_radius_all(15)
    style.set_content_margin_all(10)
    panel.add_theme_stylebox_override("panel", style)
    return panel

func build_ui() -> void:
    var layer: CanvasLayer = CanvasLayer.new()
    add_child(layer)
    var hud: Control = Control.new()
    hud.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    hud.mouse_filter = Control.MOUSE_FILTER_IGNORE
    layer.add_child(hud)
    top_panel = make_panel()
    top_panel.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
    top_panel.offset_left = 9
    top_panel.offset_top = 7
    top_panel.offset_right = -9
    top_panel.offset_bottom = 76
    hud.add_child(top_panel)
    var top_layout: HBoxContainer = HBoxContainer.new()
    top_panel.add_child(top_layout)
    money_label = make_label("HAPPY FARM 3D", 22)
    money_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    top_layout.add_child(money_label)
    top_layout.add_child(make_button("ร้านค้า", toggle_shop, Color("#b47e48")))
    top_layout.add_child(make_button("ให้อาหารหมู", feed_pig, Color("#bf8191")))
    bottom_panel = make_panel()
    bottom_panel.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
    bottom_panel.offset_left = 9
    bottom_panel.offset_right = -9
    bottom_panel.offset_top = -147
    bottom_panel.offset_bottom = -7
    hud.add_child(bottom_panel)
    var body: VBoxContainer = VBoxContainer.new()
    body.add_theme_constant_override("separation", 6)
    bottom_panel.add_child(body)
    var seed_row: HBoxContainer = HBoxContainer.new()
    body.add_child(seed_row)
    seed_row.add_child(make_label("เมล็ด:", 19))
    seed_option = OptionButton.new()
    seed_option.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    seed_option.add_theme_font_override("font", FONT)
    seed_option.add_theme_font_size_override("font_size", 18)
    for i in range(CROPS.size()):
        seed_option.add_item(str(CROPS[i]["name"]), i)
    seed_option.selected = 0
    seed_option.item_selected.connect(select_seed)
    seed_row.add_child(seed_option)
    var tools: GridContainer = GridContainer.new()
    tools.columns = 4
    tools.add_theme_constant_override("h_separation", 6)
    body.add_child(tools)
    for entry in [
        ["till","พรวนดิน"],["plant","ปลูกผัก"],["water","รดน้ำ"],["harvest","เก็บเกี่ยว"]
    ]:
        var key: String = str(entry[0])
        var b: Button = make_button(str(entry[1]), select_mode.bind(key),
            Color("#478a60") if key != "water" else Color("#4e99bf"))
        tools.add_child(b)
        mode_buttons[key] = b
    status_label = make_label(status_text, 17)
    body.add_child(status_label)
    market_panel = make_panel()
    market_panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
    market_panel.offset_left = -340
    market_panel.offset_top = -280
    market_panel.offset_right = 340
    market_panel.offset_bottom = 280
    market_panel.visible = false
    hud.add_child(market_panel)
    var market_body: VBoxContainer = VBoxContainer.new()
    market_panel.add_child(market_body)
    var header: HBoxContainer = HBoxContainer.new()
    market_body.add_child(header)
    var market_heading: Label = make_label("ร้านค้า Happy Farm", 28)
    market_heading.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    header.add_child(market_heading)
    header.add_child(make_button("ปิด", toggle_shop, Color("#777f82")))
    market_info = make_label("", 18)
    market_body.add_child(market_info)
    var scroll: ScrollContainer = ScrollContainer.new()
    scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
    market_body.add_child(scroll)
    var grid: GridContainer = GridContainer.new()
    grid.columns = 3
    grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    grid.add_theme_constant_override("h_separation", 7)
    grid.add_theme_constant_override("v_separation", 7)
    scroll.add_child(grid)
    for i in range(CROPS.size()):
        grid.add_child(make_button("%s\n%d เหรียญ" % [CROPS[i]["name"], CROPS[i]["cost"]], buy_seed.bind(i)))
    market_body.add_child(make_button("ซื้ออาหารหมู 5 ชุด (35 เหรียญ)", buy_feed))
    market_body.add_child(make_button("ซื้อลูกหมู 1 ตัว (150 เหรียญ)", buy_pig))
    select_mode("plant")

func update_ui() -> void:
    if money_label == null:
        return
    money_label.text = "HAPPY FARM 3D    %d เหรียญ   |   หมู %d   |   อาหาร %d" % [money, pigs.size(), feed]
    status_label.text = status_text
    market_info.text = "เงิน %d เหรียญ  •  เลือกเมล็ดที่ต้องการซื้อ" % money
    for i in range(CROPS.size()):
        seed_option.set_item_text(i, "%s (%d)" % [CROPS[i]["name"], int(seeds[i])])
    for k in mode_buttons.keys():
        var b: Button = mode_buttons[k]
        b.modulate = Color.WHITE if k == selected_mode else Color("#c0cdbe")

func select_mode(mode_name: String) -> void:
    if actor_running or action_step != "":
        return
    selected_mode = mode_name
    status_text = "เลือกแปลงดิน: ชาวสวนจะวิ่งไป%s" % ("พรวนดิน" if mode_name == "till" else
        ("ปลูก" if mode_name == "plant" else ("รดน้ำ" if mode_name == "water" else "เก็บเกี่ยว")))
    update_ui()

func select_seed(idx: int) -> void:
    selected_crop = idx
    update_ui()

func toggle_shop() -> void:
    market_panel.visible = not market_panel.visible
    update_ui()

func buy_seed(idx: int) -> void:
    var price: int = int(CROPS[idx]["cost"])
    if money >= price:
        money -= price
        seeds[idx] = int(seeds[idx]) + 1
        status_text = "ซื้อเมล็ด%sแล้ว" % str(CROPS[idx]["name"])
        save_game()
    else:
        status_text = "เหรียญไม่พอ"
    update_ui()

func buy_feed() -> void:
    if money >= 35:
        money -= 35
        feed += 5
        save_game()
        status_text = "ซื้ออาหารหมู 5 ชุดแล้ว"
    else:
        status_text = "เหรียญไม่พอ"
    update_ui()

func buy_pig() -> void:
    if money >= 150 and pigs.size() < 8:
        money -= 150
        pigs.append({"hunger":75,"born":Time.get_unix_time_from_system()})
        refresh_pig_models()
        save_game()
        status_text = "มีลูกหมูตัวใหม่อยู่ในคอก!"
    else:
        status_text = "เงินไม่พอ หรือคอกเต็ม (8 ตัว)"
    update_ui()

func feed_pig() -> void:
    if feed > 0 and not pigs.is_empty():
        feed -= 1
        var pig: Dictionary = pigs[0]
        pig["hunger"] = mini(100, int(pig.get("hunger",75)) + 25)
        pigs[0] = pig
        status_text = "หมูตัวแรกกินอาหารแล้ว!"
        save_game()
    else:
        status_text = "ไม่มีอาหารหมู ซื้อเพิ่มที่ร้านค้า"
    update_ui()
