extends Node3D
# Clean Happy Farm 3D. All gameplay is new; no legacy patches.
const JOYSTICK = preload("res://scripts/Joystick.gd")
const ICON = preload("res://scripts/BadgeIcon.gd")
const SEED_ICON = preload("res://scripts/SeedIcon.gd")
const SAVE_DATA = preload("res://scripts/SaveData.gd")
const FARMER_VISUAL = preload("res://scripts/FarmerVisual.gd")
const FARM_AUDIO = preload("res://scripts/FarmAudio.gd")
const THAI = preload("res://assets/Sarabun-Regular.ttf")
const THAI_BOLD = preload("res://assets/Sarabun-SemiBold.ttf")
const SAVE = "user://happy_farm_clean.json"
const CROPS = [
    {"name":"แครอต","price":8,"reward":19,"time":16.0,"tint":"#e9823d"},
    {"name":"ผักกาด","price":10,"reward":24,"time":20.0,"tint":"#b0d16f"},
    {"name":"มะเขือเทศ","price":14,"reward":32,"time":26.0,"tint":"#d95143"},
    {"name":"ข้าวโพด","price":18,"reward":42,"time":32.0,"tint":"#e8c451"},
    {"name":"ฟักทอง","price":24,"reward":58,"time":42.0,"tint":"#d28b3d"},
    {"name":"สตรอว์เบอร์รี","price":22,"reward":52,"time":38.0,"tint":"#d84f65"}
]
const SOIL = Color("#75523f")
const WET = Color("#493a34")
const GREEN = Color("#529964")
const CENTER = Vector3(3.5,0,0)
const FARM_COLUMNS: int = 10
const FARM_ROWS: int = 5
const PEN_CAPACITY: int = 4
const MAX_PENS: int = 4
const PEN_BASE_PRICE: int = 150
const PIG_PRICE: int = 90
var materials: Dictionary = {}
var plot_places: Array[Vector3] = []
var plant_roots: Array[Node3D] = []
var dirt_meshes: Array[MeshInstance3D] = []
var grow_stages: Array[int] = []
var plots: Array = []
var coins: int = 250
var seeds: Array = [4, 2, 2, 0, 0, 0]
var feed: int = 4
var pigs: int = 1
var pens: int = 1
var pen_nodes: Array[Node3D] = []
var pig_nodes: Array[Node3D] = []
var pig_roam_positions: Array[Vector3] = []
var pen_locations: Array[Vector3] = [
    Vector3(16.8, 0, -4.4), Vector3(16.8, 0, 4.2),
    Vector3(24.0, 0, -4.4), Vector3(24.0, 0, 4.2)
]
var selected_seed: int = 0
var tool_mode: String = "plant"
var farmer: Node3D
var farmer_visual: Variant = null
var arm_l: Node3D
var arm_r: Node3D
var leg_l: Node3D
var leg_r: Node3D
var hoe: Node3D
var can: Node3D
var camera: Camera3D
var camera_yaw: float = 0.65
var camera_pitch: float = -0.79
var camera_distance: float = 39.0
var camera_focus: Vector3 = Vector3.ZERO
var actor_goal: Vector3 = Vector3.ZERO
var work_plot: int = -1
var work_time: float = 0.0
var jumping: float = 0.0
var jump_velocity: float = 0.0
var running: bool = false
var run_toggle: bool = false
var tick: float = 0.0
var elapsed: float = 0.0
var drag_camera: bool = false
var touch_cam: int = -1
var touch_down: Vector2
var touch_last: Vector2
var cam_dragged: bool = false
# Only touches on empty world count toward a pinch; joystick/buttons use their own fingers.
var camera_touches: Dictionary = {}
var pinch_last_gap: float = 0.0
var pinch_was_active: bool = false
var stick: Control
var stick_label: Label
var ui: Control
var status_label: Label
var money_label: Label
var seed_select: OptionButton
var shop_panel: Panel
var action_buttons: Dictionary = {}
var run_button: Button
var jump_button: Button
var zoom_in_button: Button
var zoom_out_button: Button
var ui_top: Panel
var ui_bottom: Panel
var touch_controls: bool = false
var title_label: Label
var shop_button: Button
var feed_button: Button
var seed_caption: Label
var shop_heading: Label
var shop_close: Button
var shop_feed: Button
var shop_scroll: ScrollContainer
var shop_grid: GridContainer
var shop_livestock_label: Label
var shop_pen_button: Button
var shop_pig_button: Button
var bag_button: Button
var change_seed_button: Button
var active_seed_label: Label
var bag_panel: Panel
var bag_header: ColorRect
var bag_heading: Label
var bag_close: Button
var bag_summary: Label
var bag_scroll: ScrollContainer
var bag_grid: GridContainer
var bag_footer: Label
var bag_save_status: Label
var bag_export_button: Button
var bag_import_button: Button
var farm_audio: Node
var audio_button: Button
var voice_caption: Panel
var voice_caption_label: Label
var voice_caption_tween: Tween
var prompt_timer: float = 0.0
var footstep_timer: float = 0.0
var save_chip: Panel
var save_icon: Control
var save_status_label: Label
var save_status_text: String = "ยังไม่บันทึก"
var save_status_ok: bool = false
var restore_confirm: ConfirmationDialog
var pending_restore: Dictionary = {}
var browser_import_callback: JavaScriptObject
var bag_cards: Array[Button] = []
var bag_counts: Array[Label] = []
var message: String = "เลือกเครื่องมือ แล้วแตะแปลงผัก"

func _ready() -> void:
    # Sarabun fully supports Thai, digits, Latin and punctuation.
    ThemeDB.fallback_font = THAI
    load_save()
    build_scene()
    build_farmer()
    farm_audio = FARM_AUDIO.new()
    farm_audio.name = "FarmAudio"
    add_child(farm_audio)
    farm_audio.subtitle.connect(_show_voice_caption)
    build_ui()
    refresh_plants()
    refresh_labels()
    update_camera()
    get_viewport().size_changed.connect(update_sizes)
    if OS.has_feature("web"):
        browser_import_callback = JavaScriptBridge.create_callback(_on_browser_import)
        var web_window: JavaScriptObject = JavaScriptBridge.get_interface("window")
        if web_window != null:
            web_window.happyFarmReceiveSave = browser_import_callback
    _refresh_save_indicator()

func make_material(color: Color) -> StandardMaterial3D:
    var key: String = color.to_html()
    if not materials.has(key):
        var m: StandardMaterial3D = StandardMaterial3D.new()
        m.albedo_color = color
        m.roughness = 0.95
        materials[key] = m
    return materials[key]

func cube(root: Node3D, pos: Vector3, dimensions: Vector3, color: Color) -> MeshInstance3D:
    var obj: MeshInstance3D = MeshInstance3D.new()
    var mesh: BoxMesh = BoxMesh.new()
    mesh.size = dimensions
    obj.mesh = mesh
    obj.material_override = make_material(color)
    obj.position = pos
    root.add_child(obj)
    return obj

func ball(root: Node3D, pos: Vector3, dimensions: Vector3, color: Color) -> MeshInstance3D:
    var obj: MeshInstance3D = MeshInstance3D.new()
    var mesh: SphereMesh = SphereMesh.new()
    mesh.radius = 0.5
    mesh.height = 1.0
    mesh.radial_segments = 12
    mesh.rings = 6
    obj.mesh = mesh
    obj.position = pos
    obj.scale = dimensions
    obj.material_override = make_material(color)
    root.add_child(obj)
    return obj

func stalk(root: Node3D, pos: Vector3, height: float, radius: float, color: Color) -> MeshInstance3D:
    var mesh: CylinderMesh = CylinderMesh.new()
    mesh.height = height
    mesh.top_radius = radius
    mesh.bottom_radius = radius
    mesh.radial_segments = 10
    var obj: MeshInstance3D = MeshInstance3D.new()
    obj.mesh = mesh
    obj.material_override = make_material(color)
    obj.position = pos
    root.add_child(obj)
    return obj

func tree(pos: Vector3) -> void:
    var group: Node3D = Node3D.new()
    add_child(group)
    group.position = pos
    stalk(group, Vector3(0,1.15,0), 2.25, 0.20, Color("#86654b"))
    ball(group, Vector3(0,2.65,0), Vector3(2.2,1.75,2.05), Color("#528f61"))
    ball(group, Vector3(-0.6,2.4,0.1), Vector3(1.5,1.4,1.4), Color("#72b16f"))
    ball(group, Vector3(0.65,2.6,0), Vector3(1.3,1.4,1.3), Color("#81bb76"))

func build_scene() -> void:
    var world: WorldEnvironment = WorldEnvironment.new()
    world.environment = Environment.new()
    world.environment.background_mode = Environment.BG_COLOR
    world.environment.background_color = Color("#b4dce8")
    world.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
    world.environment.ambient_light_color = Color("#c2d5cb")
    world.environment.ambient_light_energy = 0.55
    add_child(world)
    var sun: DirectionalLight3D = DirectionalLight3D.new()
    sun.rotation_degrees = Vector3(-55,-32,-10)
    sun.light_color = Color("#fff0d2")
    sun.light_energy = 0.9
    sun.shadow_enabled = true
    add_child(sun)
    camera = Camera3D.new()
    camera.projection = Camera3D.PROJECTION_ORTHOGONAL
    camera.current = true
    add_child(camera)

    # Expanded grounds: 50 real clickable plots, paths and a livestock district.
    cube(self, Vector3(0,-0.24,0), Vector3(64.0,0.45,40.0), Color("#85ba77"))
    cube(self, Vector3(-14.5,0,0), Vector3(2.2,0.04,29.0), Color("#d2c397"))
    cube(self, Vector3(0,0,11.8), Vector3(58.0,0.04,2.1), Color("#d2c397"))
    cube(self, Vector3(13.1,0,0), Vector3(1.7,0.04,21.0), Color("#d2c397"))

    var house: Node3D = Node3D.new()
    house.position = Vector3(-19.0,0,-8.4)
    add_child(house)
    cube(house, Vector3(0,1.5,0), Vector3(4.5,3,3.9), Color("#efdebb"))
    var roof_l: MeshInstance3D = cube(house,Vector3(-1.10,3.26,0),Vector3(3.05,0.32,4.5),Color("#a8584d"))
    roof_l.rotation.z = -0.59
    var roof_r: MeshInstance3D = cube(house,Vector3(1.10,3.26,0),Vector3(3.05,0.32,4.5),Color("#a8584d"))
    roof_r.rotation.z = 0.59
    cube(house, Vector3(0,1.05,2), Vector3(1.10,2.1,0.1), Color("#936e50"))
    cube(house, Vector3(-1.4,2,2.02), Vector3(0.75,0.9,0.1), Color("#7db4c3"))
    cube(house, Vector3(1.4,2,2.02), Vector3(0.75,0.9,0.1), Color("#7db4c3"))

    for row in range(FARM_ROWS):
        for col in range(FARM_COLUMNS):
            var pos: Vector3 = Vector3((float(col)-4.5)*2.28, 0, (float(row)-1.5)*2.26)
            plot_places.append(pos)
            var plot: Node3D = Node3D.new()
            plot.position = pos
            add_child(plot)
            var soil: MeshInstance3D = cube(plot,Vector3(0,0.12,0),Vector3(1.93,0.22,1.92),SOIL)
            dirt_meshes.append(soil)
            for edge in [-1.0,1.0]:
                cube(plot,Vector3(edge,0.17,0),Vector3(0.12,0.19,2.04),Color("#c8aa74"))
                cube(plot,Vector3(0,0.17,edge),Vector3(2.04,0.19,0.12),Color("#c8aa74"))
            for furrow in [-0.55,0.0,0.55]:
                cube(plot,Vector3(furrow,0.242,0),Vector3(0.11,0.032,1.45),Color("#926b4b"))
            var plant_holder: Node3D = Node3D.new()
            plant_holder.position.y = 0.28
            plot.add_child(plant_holder)
            plant_roots.append(plant_holder)
            grow_stages.append(-1)

    # All owned pens/pigs are regenerated here and after purchases/imports.
    rebuild_livestock()
    for p in [Vector3(-29,0,4),Vector3(-29,0,13),Vector3(-25,0,-15),
        Vector3(-18,0,15),Vector3(-7,0,-15),Vector3(0,0,-15),
        Vector3(9,0,-15),Vector3(27,0,-15),Vector3(29,0,15)]:
        tree(p)

func pen_price() -> int:
    return PEN_BASE_PRICE + maxi(0, pens-1)*110

func rebuild_livestock() -> void:
    for old_pen in pen_nodes:
        if is_instance_valid(old_pen):
            old_pen.queue_free()
    pen_nodes.clear()
    pig_nodes.clear()
    pig_roam_positions.clear()
    for pen_idx in range(pens):
        create_pen(pen_idx)
    for pig_idx in range(pigs):
        create_pig(pig_idx)

func create_pen(index: int) -> void:
    var root: Node3D = Node3D.new()
    root.position = pen_locations[index]
    add_child(root)
    pen_nodes.append(root)
    cube(root,Vector3(0,0.02,0),Vector3(6.65,0.06,6.65),Color("#c7c18c"))
    # Decorative tidy fence with a wider gate on the near side.
    for side in [-1.0,1.0]:
        for k in range(5):
            var offset: float = -3.1+float(k)*1.55
            cube(root,Vector3(offset,0.67,side*3.15),Vector3(0.16,1.34,0.16),Color("#936e50"))
            cube(root,Vector3(side*3.15,0.67,offset),Vector3(0.16,1.34,0.16),Color("#936e50"))
        for height in [0.40,0.95]:
            cube(root,Vector3(0,height,side*3.15),Vector3(6.35,0.12,0.12),Color("#b88a5d"))
            cube(root,Vector3(side*3.15,height,0),Vector3(0.12,0.12,6.35),Color("#b88a5d"))
    cube(root,Vector3(0,0.28,-2.4),Vector3(1.55,0.53,0.7),Color("#a3744b"))
    cube(root,Vector3(0,0.56,-2.4),Vector3(1.30,0.10,0.50),Color("#79a561"))
    # Straw pile adds a visible distinction from the crop plots.
    ball(root,Vector3(2.0,0.16,2.1),Vector3(0.85,0.27,0.8),Color("#e5cb77"))

func create_pig(index: int) -> void:
    var pen_index: int = index / PEN_CAPACITY
    var slot: int = index % PEN_CAPACITY
    if pen_index >= pen_nodes.size():
        return
    var root: Node3D = Node3D.new()
    var pen_x: float = -1.05 if slot % 2 == 0 else 1.05
    var pen_z: float = -0.65 if slot < 2 else 1.3
    var origin: Vector3 = Vector3(pen_x, 0.0, pen_z)
    root.position = origin
    pen_nodes[pen_index].add_child(root)
    pig_nodes.append(root)
    pig_roam_positions.append(origin)
    var pink: Color = Color("#efa7b7") if index % 3 != 1 else Color("#e5a0ae")
    ball(root,Vector3(0,0.56,0),Vector3(1.2,0.75,1),pink)
    ball(root,Vector3(0,0.75,-0.52),Vector3(0.74,0.7,0.67),Color("#f0b0bd"))
    ball(root,Vector3(0,0.69,-0.84),Vector3(0.42,0.30,0.18),Color("#d98c9d"))
    for side in [-1.0,1.0]:
        ball(root,Vector3(side*0.2,0.91,-0.82),Vector3(0.09,0.09,0.08),Color("#474047"))
        ball(root,Vector3(side*0.30,1.13,-0.5),Vector3(0.22,0.30,0.15),Color("#ef9cae"))
        for side_z in [-0.32,0.32]:
            ball(root,Vector3(side*0.38,0.20,side_z),Vector3(0.25,0.4,0.25),pink)
    ball(root,Vector3(-0.12,0.68,-0.93),Vector3(0.065,0.065,0.04),Color("#995f72"))
    ball(root,Vector3(0.12,0.68,-0.93),Vector3(0.065,0.065,0.04),Color("#995f72"))

func animate_pigs() -> void:
    for i in range(pig_nodes.size()):
        var pig: Node3D = pig_nodes[i]
        var home: Vector3 = pig_roam_positions[i]
        var speed: float = 0.7+float(i%3)*0.12
        var phase: float = elapsed*speed+float(i)*1.3
        pig.position = home+Vector3(sin(phase)*0.26,absf(sin(phase*2.0))*0.027,cos(phase*0.8)*0.24)
        pig.rotation.y = sin(phase*0.6)*0.29

func build_farmer() -> void:
    farmer = Node3D.new()
    farmer.position = Vector3(-1,0,7.8)
    add_child(farmer)
    ball(farmer,Vector3(0,1.48,0),Vector3(0.70,0.91,0.52),Color("#4d9ca5"))
    ball(farmer,Vector3(0,2.11,0),Vector3(0.54,0.61,0.53),Color("#edba91"))
    stalk(farmer,Vector3(0,2.42,0),0.13,0.52,Color("#d4ab67"))
    stalk(farmer,Vector3(0,2.53,0),0.22,0.30,Color("#ae824c"))
    for side in [-1.0,1.0]:
        ball(farmer,Vector3(side*0.17,2.11,-0.257),Vector3(0.055,0.06,0.06),Color("#403d38"))
    arm_l = Node3D.new()
    arm_l.position = Vector3(-0.48,1.79,0)
    farmer.add_child(arm_l)
    arm_r = Node3D.new()
    arm_r.position = Vector3(0.48,1.79,0)
    farmer.add_child(arm_r)
    cube(arm_l,Vector3(0,-0.35,0),Vector3(0.24,0.73,0.26),Color("#e5b38f"))
    cube(arm_r,Vector3(0,-0.35,0),Vector3(0.24,0.73,0.26),Color("#e5b38f"))
    leg_l = Node3D.new()
    leg_l.position = Vector3(-0.19,1.06,0)
    farmer.add_child(leg_l)
    leg_r = Node3D.new()
    leg_r.position = Vector3(0.19,1.06,0)
    farmer.add_child(leg_r)
    cube(leg_l,Vector3(0,-0.46,0),Vector3(0.26,0.85,0.30),Color("#5e7696"))
    cube(leg_r,Vector3(0,-0.46,0),Vector3(0.26,0.85,0.30),Color("#5e7696"))
    hoe = Node3D.new()
    arm_r.add_child(hoe)
    stalk(hoe,Vector3(0,-0.80,-0.16),1.32,0.05,Color("#af9264"))
    cube(hoe,Vector3(0,-1.39,-0.16),Vector3(0.47,0.08,0.24),Color("#a4a9a2"))
    can = Node3D.new()
    arm_r.add_child(can)
    stalk(can,Vector3(0,-0.85,-0.2),0.48,0.23,Color("#79b7c5"))
    var nozzle: MeshInstance3D = stalk(can,Vector3(-0.27,-0.85,-0.2),0.4,0.06,Color("#79b7c5"))
    nozzle.rotation.z = 1.05
    hoe.visible = false
    can.visible = false

    # Swap the placeholder for the player's real skinned Mixamo farmer.
    # The old model remains a safe fallback until the FBX bundle is imported.
    var mixamo: Node3D = FARMER_VISUAL.new()
    mixamo.name = "MixamoFemale"
    farmer.add_child(mixamo)
    if mixamo.initialize() and mixamo.has_visible_avatar():
        farmer_visual = mixamo
        for part in farmer.get_children():
            if part != farmer_visual:
                part.visible = false
    else:
        # Do not hide the backup actor unless a real, correctly sized
        # skinned mesh can actually be displayed.
        mixamo.queue_free()
        farmer_visual = null

func stage(index: int) -> int:
    var cell: Dictionary = plots[index]
    if not cell.has("crop"):
        return 0
    if not bool(cell.get("wet",false)):
        return 1
    var id: int = clampi(int(cell["crop"]),0,CROPS.size()-1)
    var age: float = Time.get_unix_time_from_system() - float(cell.get("water_time",0))
    var frac: float = clampf(age/float(CROPS[id]["time"]),0.0,1.0)
    if frac < 0.20: return 2
    if frac < 0.50: return 3
    if frac < 0.85: return 4
    return 5

func refresh_plants() -> void:
    for i in range(plots.size()):
        var st: int = stage(i)
        if grow_stages[i] == st:
            continue
        grow_stages[i] = st
        dirt_meshes[i].material_override = make_material(WET if bool(plots[i].get("wet",false)) else SOIL)
        var root: Node3D = plant_roots[i]
        for child in root.get_children():
            root.remove_child(child)
            child.queue_free()
        if st == 0:
            continue
        var id: int = clampi(int(plots[i].get("crop",0)),0,CROPS.size()-1)
        var amount: float = 0.26 if st == 1 else (0.46 if st == 2 else (0.7 if st == 3 else 1.0))
        var leaf: Color = Color("#579f5d")
        var fruit: Color = Color(str(CROPS[id]["tint"]))
        for k in range(3):
            var x: float = (float(k)-1.0)*0.45
            stalk(root,Vector3(x,0.38*amount,0),0.7*amount,0.045,Color("#327d48"))
            ball(root,Vector3(x-0.12*amount,0.5*amount,0.0),Vector3(0.32,0.16,0.48)*amount,leaf)
            ball(root,Vector3(x+0.12*amount,0.61*amount,0.0),Vector3(0.32,0.16,0.42)*amount,leaf.lightened(0.16))
            if st >= 4:
                ball(root,Vector3(x,0.56*amount,0.02),Vector3(0.44,0.42,0.43)*amount,fruit)
        root.scale = Vector3(1,0.07,1)
        create_tween().tween_property(root,"scale",Vector3.ONE,0.4).set_trans(Tween.TRANS_BACK)

func work_on(index: int) -> void:
    if index < 0 or index >= plots.size() or work_plot >= 0 or work_time > 0:
        return
    var c: Dictionary = plots[index]
    if tool_mode == "plant" and (c.has("crop") or int(seeds[selected_seed]) == 0):
        message = "แปลงเต็มหรือเมล็ดหมด"
        refresh_labels()
        return
    if tool_mode == "water" and not c.has("crop"):
        message = "ต้องปลูกผักก่อน"
        refresh_labels()
        return
    if tool_mode == "harvest" and stage(index) < 5:
        message = "ผักยังไม่โตเต็มที่"
        refresh_labels()
        return
    work_plot = index
    actor_goal = plot_places[index] + Vector3(0,0,1.20)
    message = "ชาวสวนกำลังเดินไปแปลง"
    refresh_labels()

func finish_work() -> void:
    if work_plot < 0:
        return
    var i: int = work_plot
    if tool_mode == "till":
        plots[i]["tilled"] = true
        message = "พรวนดินเรียบร้อย"
    elif tool_mode == "plant":
        plots[i] = {"crop":selected_seed,"tilled":true,"wet":false,"water_time":0.0}
        seeds[selected_seed] = int(seeds[selected_seed])-1
        message = "ปลูกสำเร็จ กดรดน้ำแล้วแตะแปลงเดิม"
    elif tool_mode == "water":
        plots[i]["wet"] = true
        if float(plots[i].get("water_time",0.0)) == 0.0:
            plots[i]["water_time"] = Time.get_unix_time_from_system()
        for j in range(11):
            var p: Vector3 = plot_places[i]
            var drop: MeshInstance3D = ball(self,p+Vector3((float(j%4)-1.5)*0.33,1.5+float(j%3)*0.20,(float(j/4)-1)*0.35),
                Vector3.ONE*0.12,Color("#79cbec"))
            var tween: Tween = create_tween()
            tween.tween_property(drop,"position:y",0.22,0.45+float(j%3)*0.08)
            tween.tween_callback(drop.queue_free)
        message = "รดน้ำแล้ว ผักจะค่อย ๆ โต"
    elif tool_mode == "harvest":
        var crop_id: int = int(plots[i].get("crop",0))
        coins += int(CROPS[crop_id]["reward"])
        plots[i] = {"tilled":true}
        message = "เก็บเกี่ยวสำเร็จ ได้เหรียญเพิ่ม"
    work_plot = -1
    hoe.visible = false
    can.visible = false
    refresh_plants()
    refresh_labels()
    save_game()

func _process(delta: float) -> void:
    var previous_position: Vector3 = farmer.position
    elapsed += delta
    animate_pigs()
    tick += delta
    if tick >= 0.55:
        tick = 0
        refresh_plants()
    if jumping > 0.0 or jump_velocity > 0.0:
        jump_velocity -= 17.5*delta
        jumping = maxf(0.0,jumping+jump_velocity*delta)
        if jumping <= 0: jump_velocity = 0.0
    if work_plot >= 0 and work_time <= 0.0:
        var gap: Vector3 = actor_goal - farmer.position
        gap.y = 0
        if gap.length() > 0.10:
            move_actor(gap.normalized(),4.3,delta)
        else:
            work_time = 0.95 if tool_mode != "water" else 1.30
            hoe.visible = tool_mode == "till"
            can.visible = tool_mode == "water"
    elif work_time > 0.0:
        work_time -= delta
        arm_r.rotation.x = -0.75+sin(elapsed*11)*0.42
        arm_l.rotation.x = 0.28
        farmer.position.y = absf(sin(elapsed*5))*0.035
        if work_time <= 0:
            finish_work()
    else:
        var input_dir: Vector2 = Vector2(float(Input.is_key_pressed(KEY_D))-float(Input.is_key_pressed(KEY_A)),
            float(Input.is_key_pressed(KEY_S))-float(Input.is_key_pressed(KEY_W)))
        if stick != null and stick.visible and stick.direction.length() > 0.055:
            input_dir = stick.direction
        running = Input.is_key_pressed(KEY_SHIFT) or run_toggle
        if input_dir.length() > 0.08:
            var side: Vector3 = camera.global_basis.x
            side.y = 0
            var front: Vector3 = -camera.global_basis.z
            front.y = 0
            var travel: Vector3 = (side.normalized()*input_dir.x-front.normalized()*input_dir.y).normalized()
            move_actor(travel,(7.5 if running else 4.25)*minf(1,input_dir.length()),delta)
        else:
            leg_l.rotation.x = lerpf(leg_l.rotation.x,0.0,delta*10)
            leg_r.rotation.x = lerpf(leg_r.rotation.x,0.0,delta*10)
            arm_l.rotation.x = lerpf(arm_l.rotation.x,0.0,delta*10)
            arm_r.rotation.x = lerpf(arm_r.rotation.x,0.0,delta*10)
            farmer.position.y = jumping
        hoe.visible = false
        can.visible = false
    # On a close-up view, keep the real farmer centered while they walk.
    if camera_distance < 30.0:
        update_camera()
    # Keep the skeleton animation aligned to actual movement, not just inputs:
    # keyboard, touchscreen stick and automatic farm work share this state.
    if farmer_visual != null and farmer_visual.is_model_ready():
        var displacement: Vector2 = Vector2(
            farmer.position.x-previous_position.x,
            farmer.position.z-previous_position.z
        )
        var pose_name: String = "Idle"
        if jumping > 0.015 or jump_velocity > 0.0:
            pose_name = "Jump"
        elif displacement.length() > 0.001:
            pose_name = "Run" if (running and work_plot < 0) else "Walk"
        farmer_visual.set_state(pose_name)

func move_actor(direction: Vector3, speed: float, delta: float) -> void:
    farmer.position += direction*speed*delta
    farmer.position.x = clampf(farmer.position.x,-30.0,30.0)
    farmer.position.z = clampf(farmer.position.z,-17.0,17.0)
    farmer.position.y = jumping+absf(sin(elapsed*12))*0.035
    farmer.rotation.y = atan2(-direction.x,-direction.z)
    var wave: float = sin(elapsed*(16 if running else 10))
    leg_l.rotation.x = wave*0.60
    leg_r.rotation.x = -wave*0.60
    arm_l.rotation.x = -wave*0.36
    arm_r.rotation.x = wave*0.36

func jump() -> void:
    if work_plot >= 0 or work_time > 0 or shop_panel.visible: return
    if jumping <= 0 and jump_velocity <= 0:
        jump_velocity = 6.2

func zoom_in() -> void:
    set_camera_zoom(camera_distance * 0.72)

func zoom_out() -> void:
    set_camera_zoom(camera_distance * 1.35)

func set_camera_zoom(target_distance: float) -> void:
    # Orthographic projection changes size too, so this must change both.
    camera_distance = clampf(target_distance, 5.0, 85.0)
    update_camera()

func _camera_touch_gap() -> float:
    if camera_touches.size() < 2:
        return 0.0
    var positions: Array = camera_touches.values()
    var left: Vector2 = positions[0]
    var right: Vector2 = positions[1]
    return left.distance_to(right)

func _camera_touch(event: InputEventScreenTouch) -> void:
    if event.pressed:
        # Fingers on the joystick, zoom controls and other UI cannot start a
        # camera gesture; other fingers can still operate those controls.
        if point_on_ui(event.position) or camera_touches.size() >= 2:
            return
        camera_touches[event.index] = event.position
        if camera_touches.size() == 1:
            touch_cam = event.index
            touch_down = event.position
            touch_last = event.position
            cam_dragged = false
            pinch_was_active = false
        else:
            pinch_last_gap = _camera_touch_gap()
            pinch_was_active = true
            cam_dragged = true
            touch_cam = -1
    elif camera_touches.has(event.index):
        var tap_plot: bool = not pinch_was_active and not cam_dragged and camera_touches.size() == 1
        camera_touches.erase(event.index)
        if tap_plot:
            click_plot(event.position)
        if camera_touches.size() == 1:
            # A remaining finger can pan again, but cannot accidentally plant.
            touch_cam = int(camera_touches.keys()[0])
            touch_down = camera_touches[touch_cam]
            touch_last = touch_down
            cam_dragged = true
            pinch_last_gap = 0.0
        else:
            touch_cam = -1
            pinch_last_gap = 0.0
            if camera_touches.is_empty():
                pinch_was_active = false
                cam_dragged = false

func _camera_drag(event: InputEventScreenDrag) -> void:
    if not camera_touches.has(event.index):
        return
    camera_touches[event.index] = event.position
    if camera_touches.size() >= 2:
        var gap: float = _camera_touch_gap()
        if pinch_last_gap > 10.0 and gap > 10.0:
            set_camera_zoom(camera_distance * pinch_last_gap / gap)
        pinch_last_gap = gap
        pinch_was_active = true
        cam_dragged = true
        return
    if event.index != touch_cam:
        return
    var delta_screen: Vector2 = event.position - touch_last
    touch_last = event.position
    if event.position.distance_to(touch_down) > 9.0:
        cam_dragged = true
    if cam_dragged:
        camera_yaw -= delta_screen.x * 0.006
        camera_pitch = clampf(camera_pitch + delta_screen.y * 0.005, -1.33, -0.28)
        update_camera()

func _input(event: InputEvent) -> void:
    if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_SPACE:
        jump()
    if event is InputEventScreenTouch:
        _camera_touch(event)
    elif event is InputEventScreenDrag:
        _camera_drag(event)
    elif event is InputEventMouseButton:
        if event.button_index == MOUSE_BUTTON_RIGHT:
            drag_camera = event.pressed
        elif event.pressed and event.button_index == MOUSE_BUTTON_WHEEL_UP:
            set_camera_zoom(camera_distance * 0.87)
        elif event.pressed and event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
            set_camera_zoom(camera_distance * 1.15)
        elif event.pressed and event.button_index == MOUSE_BUTTON_LEFT and not point_on_ui(event.position) and camera_touches.is_empty():
            click_plot(event.position)
    elif event is InputEventMouseMotion and drag_camera:
        camera_yaw -= event.relative.x * 0.007
        camera_pitch = clampf(camera_pitch + event.relative.y * 0.005, -1.33, -0.28)
        update_camera()

func click_plot(pixel: Vector2) -> void:
    if shop_panel.visible: return
    var origin: Vector3 = camera.project_ray_origin(pixel)
    var ray: Vector3 = camera.project_ray_normal(pixel)
    if absf(ray.y) < 0.001: return
    var t: float = (0.22-origin.y)/ray.y
    if t <= 0: return
    var p: Vector3 = origin+ray*t
    var best: int = -1
    var distance: float = 1.08
    for i in range(plot_places.size()):
        var d: float = Vector2(plot_places[i].x-p.x,plot_places[i].z-p.z).length()
        if d < distance:
            distance = d
            best = i
    if best >= 0: work_on(best)

func update_camera() -> void:
    if camera == null:
        return
    var screen: Vector2 = get_viewport().get_visible_rect().size
    var aspect: float = screen.x / maxf(1.0, screen.y)
    # A far view shows the whole farm; close zoom focuses on the actual
    # skinned character instead of an empty spot in the middle of the map.
    var focus_mix: float = 1.0 - smoothstep(14.0, 31.0, camera_distance)
    var subject: Vector3 = CENTER
    if farmer != null:
        subject = Vector3(farmer.position.x, 1.0, farmer.position.z)
    camera_focus = CENTER.lerp(subject, focus_mix)
    var offset: Vector3 = Vector3(
        sin(camera_yaw) * cos(camera_pitch),
        -sin(camera_pitch),
        cos(camera_yaw) * cos(camera_pitch)
    )
    camera.position = camera_focus + offset * camera_distance
    camera.look_at(camera_focus)
    var factor: float = 0.82 if aspect > 1.3 else (1.07 if aspect > 0.82 else 1.40)
    var close_factor: float = lerpf(0.75, 1.0, smoothstep(12.0, 30.0, camera_distance))
    camera.size = clampf(camera_distance * factor * close_factor, 3.6, 120.0)

func text_label(txt: String, font_size: int, color: Color = Color("#284c3a")) -> Label:
    var label: Label = Label.new()
    label.text = txt
    label.add_theme_font_override("font", THAI)
    label.add_theme_font_size_override("font_size", font_size)
    label.add_theme_color_override("font_color", color)
    label.autowrap_mode = TextServer.AUTOWRAP_OFF
    label.clip_text = true
    label.mouse_filter = Control.MOUSE_FILTER_IGNORE
    return label

func btn(txt: String, callback: Callable, background: Color = Color("#417c59")) -> Button:
    var b: Button = Button.new()
    b.text = txt
    b.focus_mode = Control.FOCUS_NONE
    b.custom_minimum_size = Vector2.ZERO
    b.add_theme_font_override("font", THAI_BOLD)
    b.add_theme_font_size_override("font_size", 16)
    b.add_theme_color_override("font_color", Color.WHITE)
    b.clip_text = true
    var style: StyleBoxFlat = StyleBoxFlat.new()
    style.bg_color = background
    style.set_corner_radius_all(10)
    style.set_content_margin_all(3)
    b.add_theme_stylebox_override("normal", style)
    var hover: StyleBoxFlat = style.duplicate()
    hover.bg_color = background.lightened(0.12)
    b.add_theme_stylebox_override("hover", hover)
    var down: StyleBoxFlat = style.duplicate()
    down.bg_color = background.darkened(0.13)
    b.add_theme_stylebox_override("pressed", down)
    b.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
    b.pressed.connect(callback)
    return b

func panel(color: Color) -> Panel:
    # Panel (not PanelContainer) never enlarges itself to fit its children.
    var p: Panel = Panel.new()
    var style: StyleBoxFlat = StyleBoxFlat.new()
    style.bg_color = color
    style.set_corner_radius_all(13)
    style.set_content_margin_all(0)
    style.border_width_left = 1
    style.border_width_top = 1
    style.border_width_right = 1
    style.border_width_bottom = 1
    style.border_color = Color(1.0, 1.0, 1.0, 0.36)
    p.add_theme_stylebox_override("panel", style)
    p.mouse_filter = Control.MOUSE_FILTER_IGNORE
    return p

func set_box(node: Control, x: float, y: float, w: float, h: float) -> void:
    node.set_anchors_preset(Control.PRESET_TOP_LEFT)
    node.position = Vector2(x, y)
    node.size = Vector2(w, h)

func build_ui() -> void:
    # Players asked for the on-screen controls even when using Chrome on a PC.
    # Godot Web can also report touchscreen availability inconsistently.
    # Keep the analog joystick and buttons visible on every device.
    touch_controls = true
    var layer: CanvasLayer = CanvasLayer.new()
    layer.layer = 4
    add_child(layer)

    ui = Control.new()
    ui.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    ui.mouse_filter = Control.MOUSE_FILTER_IGNORE
    layer.add_child(ui)

    # Compact information card: fixed dimensions, never stretched by labels.
    ui_top = panel(Color("#edf5e5ed"))
    ui.add_child(ui_top)
    title_label = text_label("ฟาร์มสุขใจ", 20, Color("#315941"))
    title_label.add_theme_font_override("font", THAI_BOLD)
    ui_top.add_child(title_label)
    var coin_icon: Control = ICON.new()
    coin_icon.kind = "coin"
    ui_top.add_child(coin_icon)
    coin_icon.name = "CoinIcon"
    money_label = text_label("", 16, Color("#375c49"))
    ui_top.add_child(money_label)
    bag_button = btn("   กระเป๋า", show_bag, Color("#426d55"))
    ui_top.add_child(bag_button)
    var bag_icon: Control = ICON.new()
    bag_icon.kind = "bag"
    bag_button.add_child(bag_icon)
    set_box(bag_icon, 5, 6, 24, 24)
    shop_button = btn("ร้านค้า", show_shop, Color("#ad7c53"))
    ui_top.add_child(shop_button)
    feed_button = btn("ให้อาหาร", give_feed, Color("#b87b89"))
    ui_top.add_child(feed_button)

    # Optional sound control: one tap starts music on phones; another mutes.
    audio_button = btn("เปิดเสียง", toggle_sound, Color("#5e817c"))
    ui.add_child(audio_button)
    voice_caption = panel(Color("#2d5546eb"))
    voice_caption.visible = false
    ui.add_child(voice_caption)
    voice_caption_label = text_label("", 19, Color.WHITE)
    voice_caption_label.add_theme_font_override("font", THAI_BOLD)
    voice_caption_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    voice_caption_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
    voice_caption.add_child(voice_caption_label)

    # Unobtrusive save indicator with a vector icon, not an emoji.
    save_chip = panel(Color("#edf5e7f2"))
    ui.add_child(save_chip)
    save_icon = ICON.new()
    save_icon.kind = "save"
    save_chip.add_child(save_icon)
    save_status_label = text_label("", 15, Color("#357652"))
    save_chip.add_child(save_status_label)

    # Floating toolbar: only 118px tall instead of covering the farm.
    ui_bottom = panel(Color("#edf5e5f2"))
    ui.add_child(ui_bottom)
    status_label = text_label("", 15, Color("#3f654b"))
    ui_bottom.add_child(status_label)
    active_seed_label = text_label("", 16, Color("#365c44"))
    active_seed_label.add_theme_font_override("font", THAI_BOLD)
    ui_bottom.add_child(active_seed_label)
    change_seed_button = btn("เลือกเมล็ด", show_bag, Color("#6a946f"))
    ui_bottom.add_child(change_seed_button)
    for pair in [["till","พรวนดิน"],["plant","ปลูกผัก"],["water","รดน้ำ"],["harvest","เก็บเกี่ยว"]]:
        var key: String = str(pair[0])
        var button: Button = btn(str(pair[1]), pick_tool.bind(key), Color("#468566") if key != "water" else Color("#4d95ac"))
        ui_bottom.add_child(button)
        action_buttons[key] = button

    # Always-visible browser joystick: mouse drag on PC or finger drag on phone.
    stick = JOYSTICK.new()
    ui.add_child(stick)
    stick.visible = true
    stick_label = text_label("เดินอิสระ", 17, Color("#23533c"))
    stick_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    stick_label.add_theme_font_override("font", THAI_BOLD)
    ui.add_child(stick_label)
    run_button = btn("วิ่ง", toggle_run, Color("#538b77"))
    ui.add_child(run_button)
    run_button.visible = true
    jump_button = btn("กระโดด", jump, Color("#ce9254"))
    ui.add_child(jump_button)
    jump_button.visible = true
    # Dedicated zoom buttons work on iPhone even if the browser does not
    # deliver two-finger gestures to the Godot canvas.
    zoom_out_button = btn("−", zoom_out, Color("#587e91"))
    zoom_out_button.add_theme_font_size_override("font_size", 28)
    zoom_out_button.tooltip_text = "ซูมออก ดูฟาร์มทั้งหมด"
    ui.add_child(zoom_out_button)
    zoom_in_button = btn("+", zoom_in, Color("#4f9682"))
    zoom_in_button.add_theme_font_size_override("font_size", 28)
    zoom_in_button.tooltip_text = "ซูมเข้า ดูตัวละครใกล้ ๆ"
    ui.add_child(zoom_in_button)

    # Shop is an explicitly sized popup; scrolling happens inside its bounds.
    shop_panel = panel(Color("#f4f8effa"))
    ui.add_child(shop_panel)
    shop_panel.visible = false
    shop_heading = text_label("ร้านค้าฟาร์มและสัตว์เลี้ยง", 21, Color("#345841"))
    shop_heading.add_theme_font_override("font", THAI_BOLD)
    shop_panel.add_child(shop_heading)
    shop_close = btn("ปิด", show_shop, Color("#73817a"))
    shop_panel.add_child(shop_close)
    shop_livestock_label = text_label("", 15, Color("#426e55"))
    shop_panel.add_child(shop_livestock_label)
    shop_scroll = ScrollContainer.new()
    shop_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
    shop_panel.add_child(shop_scroll)
    shop_grid = GridContainer.new()
    shop_grid.columns = 2
    shop_grid.add_theme_constant_override("h_separation", 7)
    shop_grid.add_theme_constant_override("v_separation", 7)
    shop_grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    shop_scroll.add_child(shop_grid)
    for i in range(CROPS.size()):
        var buy: Button = btn("%s  %d เหรียญ" % [CROPS[i]["name"], CROPS[i]["price"]], buy_seed.bind(i))
        buy.custom_minimum_size = Vector2(145, 39)
        buy.size_flags_horizontal = Control.SIZE_EXPAND_FILL
        shop_grid.add_child(buy)
    shop_feed = btn("ซื้ออาหารหมู +5 (35 เหรียญ)", buy_feed, Color("#ad7c53"))
    shop_panel.add_child(shop_feed)
    shop_pen_button = btn("ขยายคอกหมู", buy_pen, Color("#7c985d"))
    shop_panel.add_child(shop_pen_button)
    shop_pig_button = btn("ซื้อลูกหมู", buy_pig, Color("#bb7c91"))
    shop_panel.add_child(shop_pig_button)

    # Dedicated seed inventory in the left-side area shown in the reference.
    # The panel is a fixed-size Panel, not a PanelContainer; it cannot grow.
    bag_panel = panel(Color("#ecf1e6fb"))
    ui.add_child(bag_panel)
    bag_panel.visible = false
    bag_header = ColorRect.new()
    bag_header.color = Color("#335b47")
    bag_header.mouse_filter = Control.MOUSE_FILTER_IGNORE
    bag_panel.add_child(bag_header)
    bag_heading = text_label("กระเป๋าเมล็ดพันธุ์", 23, Color("#ffffff"))
    bag_heading.add_theme_font_override("font", THAI_BOLD)
    bag_panel.add_child(bag_heading)
    bag_close = btn("ปิด", show_bag, Color("#d4a16b"))
    bag_panel.add_child(bag_close)
    bag_summary = text_label("", 16, Color("#45624c"))
    bag_panel.add_child(bag_summary)
    bag_scroll = ScrollContainer.new()
    bag_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
    bag_scroll.clip_contents = true
    bag_panel.add_child(bag_scroll)
    bag_grid = GridContainer.new()
    bag_grid.columns = 3
    bag_grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    bag_grid.add_theme_constant_override("h_separation", 8)
    bag_grid.add_theme_constant_override("v_separation", 10)
    bag_scroll.add_child(bag_grid)
    for i in range(CROPS.size()):
        var card: Button = btn("", select_seed.bind(i), Color("#fff9ec"))
        card.custom_minimum_size = Vector2(96, 122)
        card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
        bag_grid.add_child(card)
        bag_cards.append(card)
        var contents: VBoxContainer = VBoxContainer.new()
        contents.mouse_filter = Control.MOUSE_FILTER_IGNORE
        contents.add_theme_constant_override("separation", 0)
        card.add_child(contents)
        contents.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
        contents.offset_left = 3
        contents.offset_right = -3
        contents.offset_top = 5
        contents.offset_bottom = -3
        var crop_image: Control = SEED_ICON.new()
        crop_image.crop_id = i
        crop_image.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
        contents.add_child(crop_image)
        var crop_name: Label = text_label(str(CROPS[i]["name"]), 16, Color("#314b3a"))
        crop_name.add_theme_font_override("font", THAI_BOLD)
        crop_name.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
        crop_name.size_flags_horizontal = Control.SIZE_EXPAND_FILL
        contents.add_child(crop_name)
        var count: Label = text_label("", 14, Color("#608066"))
        count.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
        count.size_flags_horizontal = Control.SIZE_EXPAND_FILL
        contents.add_child(count)
        bag_counts.append(count)
    bag_footer = text_label("แตะซองเมล็ดเพื่อเลือกไปปลูก", 15, Color("#5c715c"))
    bag_panel.add_child(bag_footer)
    bag_save_status = text_label("เซฟเก็บอยู่ในเบราว์เซอร์เครื่องนี้", 14, Color("#487456"))
    bag_panel.add_child(bag_save_status)
    bag_export_button = btn("ดาวน์โหลดเซฟ", export_save_backup, Color("#397e62"))
    bag_panel.add_child(bag_export_button)
    bag_import_button = btn("นำเข้าเซฟ", request_import_backup, Color("#ab8054"))
    bag_panel.add_child(bag_import_button)

    restore_confirm = ConfirmationDialog.new()
    restore_confirm.title = "ยืนยันนำเข้าเซฟ"
    restore_confirm.dialog_text = "ข้อมูลปัจจุบันในเบราว์เซอร์จะถูกแทนที่"
    restore_confirm.ok_button_text = "นำเข้าเซฟ"
    restore_confirm.cancel_button_text = "ยกเลิก"
    restore_confirm.confirmed.connect(_confirm_import_backup)
    ui.add_child(restore_confirm)

    update_sizes()
    pick_tool("plant")
    refresh_sound_button()

func update_sizes() -> void:
    if ui_top == null:
        return
    var view: Vector2 = get_viewport().get_visible_rect().size
    var w: float = view.x
    var h: float = view.y
    var narrow: bool = w < 960.0
    var header_width: float = minf(w-16.0, 930.0)
    var header_height: float = 94.0 if narrow else 56.0
    set_box(ui_top, 8.0, 8.0, header_width, header_height)

    if narrow:
        set_box(title_label, 12, 5, 118, 30)
        set_box(ui_top.get_node("CoinIcon"), 132, 8, 24, 24)
        set_box(money_label, 158, 7, maxf(80.0, header_width-169.0), 27)
        var button_w: float = (header_width-32.0)/3.0
        set_box(bag_button, 9, 44, button_w, 39)
        set_box(shop_button, 16+button_w, 44, button_w, 39)
        set_box(feed_button, 23+2.0*button_w, 44, button_w, 39)
    else:
        set_box(title_label, 12, 12, 115, 30)
        set_box(ui_top.get_node("CoinIcon"), 131, 15, 24, 24)
        set_box(money_label, 158, 13, 348, 30)
        set_box(bag_button, 517, 8, 115, 40)
        set_box(shop_button, 640, 8, 113, 40)
        set_box(feed_button, 761, 8, 150, 40)

    # Small tool tray keeps the working 3D farm visible.
    var toolbar_width: float = minf(650.0, maxf(300.0, w-20.0))
    var toolbar_y: float = h-127.0
    if touch_controls:
        # In landscape, reserve both side rails for joystick and buttons.
        # In portrait, place the farming toolbar above the bottom controls.
        if w >= 700.0:
            toolbar_width = minf(570.0, w-340.0)
        else:
            toolbar_width = w-18.0
            toolbar_y = h-291.0
    var toolbar_x: float = (w-toolbar_width)*0.5
    set_box(ui_bottom, toolbar_x, toolbar_y, toolbar_width, 116.0)
    set_box(status_label, 12, 7, toolbar_width-24.0, 25.0)
    set_box(active_seed_label, 13, 37, toolbar_width-166.0, 30.0)
    set_box(change_seed_button, toolbar_width-148.0, 33, 135.0, 35.0)
    var gap: float = 6.0
    var tool_button_w: float = (toolbar_width-24.0-3.0*gap)*0.25
    var keys: Array[String] = ["till", "plant", "water", "harvest"]
    for i in range(4):
        set_box(action_buttons[keys[i]], 12.0+float(i)*(tool_button_w+gap), 75.0, tool_button_w, 34.0)

    set_box(stick, 18, h-158, 144, 144)
    set_box(stick_label, 26, h-184, 128, 27)
    set_box(run_button, w-139, h-151, 123, 62)
    set_box(jump_button, w-139, h-82, 123, 64)
    # Keep zoom entirely above the Run/Jump rail, with room for fonts.
    var zoom_buttons_y: float = h-264.0 if w >= 700.0 else h-408.0
    set_box(zoom_out_button, w-142, zoom_buttons_y, 62, 52)
    set_box(zoom_in_button, w-73, zoom_buttons_y, 62, 52)
    stick.queue_redraw()

    var shop_w: float = minf(w-24.0, 490.0)
    var shop_h: float = minf(h-24.0, 490.0)
    set_box(shop_panel, (w-shop_w)*0.5, (h-shop_h)*0.5, shop_w, shop_h)
    set_box(shop_heading, 15, 10, shop_w-105, 33)
    set_box(shop_close, shop_w-85, 8, 73, 37)
    set_box(shop_livestock_label, 15, 48, shop_w-30, 28)
    set_box(shop_scroll, 14, 79, shop_w-28, maxf(57.0, shop_h-260.0))
    set_box(shop_feed, 14, shop_h-169, shop_w-28, 45)
    set_box(shop_pen_button, 14, shop_h-116, shop_w-28, 45)
    set_box(shop_pig_button, 14, shop_h-63, shop_w-28, 45)
    shop_grid.columns = 1 if w < 440.0 else 2

    # On narrow screens the badge sits below the header.
    var badge_y: float = 8.0 if w > 960.0 else header_height+15.0
    set_box(save_chip, w-171.0, badge_y, 160.0, 35.0)
    set_box(save_icon, 7.0, 4.0, 26.0, 26.0)
    set_box(save_status_label, 37.0, 7.0, 117.0, 25.0)
    var sound_x: float = w-290.0 if w >= 430.0 else 10.0
    set_box(audio_button, sound_x, badge_y, 108.0, 35.0)
    var caption_width: float = minf(w-22.0, 540.0)
    var caption_y: float = 70.0 if not narrow else header_height+56.0
    set_box(voice_caption, (w-caption_width)*0.5, caption_y, caption_width, 53.0)
    set_box(voice_caption_label, 9, 7, caption_width-18.0, 37.0)

    # Inventory lives on the left. Never stretch it to the full game screen.
    var bag_top: float = 118.0 if narrow else 75.0
    var bag_width: float = minf(440.0, w*0.43) if w >= 900.0 else minf(385.0, w-20.0)
    var bag_x: float = 13.0 if w >= 900.0 else 9.0
    var bag_bottom_margin: float = 155.0
    if touch_controls and w < 900.0:
        bag_bottom_margin = 303.0
    var bag_height: float = maxf(278.0, minf(h-bag_top-12.0, h-bag_top-bag_bottom_margin))
    set_box(bag_panel, bag_x, bag_top, bag_width, bag_height)
    set_box(bag_header, 0, 0, bag_width, 60)
    set_box(bag_heading, 16, 12, bag_width-104, 35)
    set_box(bag_close, bag_width-76, 11, 63, 37)
    set_box(bag_summary, 15, 68, bag_width-30, 27)
    set_box(bag_scroll, 12, 103, bag_width-24, maxf(55.0, bag_height-220.0))
    set_box(bag_footer, 14, bag_height-111.0, bag_width-28, 23)
    set_box(bag_save_status, 14, bag_height-85.0, bag_width-28, 24)
    var backup_button_width: float = (bag_width-36.0)*0.5
    set_box(bag_export_button, 12, bag_height-54.0, backup_button_width, 41)
    set_box(bag_import_button, 24.0+backup_button_width, bag_height-54.0, backup_button_width, 41)
    bag_grid.columns = 3 if bag_width >= 345.0 else 2
    for card in bag_cards:
        card.custom_minimum_size = Vector2(95.0, 119.0)
    update_camera()
func point_on_ui(pos: Vector2) -> bool:
    if shop_panel.visible:
        return true
    if bag_panel != null and bag_panel.visible and bag_panel.get_global_rect().has_point(pos):
        return true
    for panel_node in [ui_top,ui_bottom]:
        if panel_node != null and panel_node.get_global_rect().has_point(pos):
            return true
    if touch_controls:
        for control in [stick,run_button,jump_button,zoom_in_button,zoom_out_button,audio_button]:
            if control.visible and control.get_global_rect().has_point(pos): return true
    return false

func toggle_sound() -> void:
    if farm_audio == null:
        return
    if not farm_audio.unlocked:
        farm_audio.activate()
    else:
        farm_audio.set_enabled(not farm_audio.enabled)
    refresh_sound_button()

func refresh_sound_button() -> void:
    if audio_button == null or farm_audio == null:
        return
    if not farm_audio.enabled:
        audio_button.text = "เสียง: ปิด"
    elif not farm_audio.unlocked:
        audio_button.text = "เปิดเสียง"
    else:
        audio_button.text = "เสียง: เปิด"

func _show_voice_caption(line: String) -> void:
    if voice_caption == null:
        return
    voice_caption.visible = true
    voice_caption.modulate.a = 1.0
    voice_caption_label.text = line
    if voice_caption_tween != null and voice_caption_tween.is_running():
        voice_caption_tween.kill()
    voice_caption_tween = create_tween()
    voice_caption_tween.tween_interval(2.8)
    voice_caption_tween.tween_property(voice_caption, "modulate:a", 0.0, 0.65)
    voice_caption_tween.tween_callback(func() -> void: voice_caption.visible = false)

func _check_voice_context() -> void:
    if farm_audio == null or not farm_audio.unlocked or not farm_audio.enabled:
        return
    if work_plot >= 0 or work_time > 0.0 or bag_panel.visible or shop_panel.visible:
        return
    var ready: bool = false
    var dry: bool = false
    var empty: bool = false
    var enough_seeds: bool = false
    for stock in seeds:
        enough_seeds = enough_seeds or int(stock) > 0
    for i in range(plots.size()):
        var pos: Vector3 = plot_places[i]
        if Vector2(pos.x-farmer.position.x, pos.z-farmer.position.z).length() > 3.3:
            continue
        if stage(i) >= 5:
            ready = true
            break
        if plots[i].has("crop") and not bool(plots[i].get("wet",false)):
            dry = true
        elif not plots[i].has("crop"):
            empty = true
    # Prioritize ripe crops, then thirsty crops, then empty fields.
    if ready:
        farm_audio.announce("harvest")
    elif dry:
        farm_audio.announce("water")
    elif empty and enough_seeds:
        farm_audio.announce("plant")

func refresh_labels() -> void:
    if money_label == null:
        return
    if get_viewport().get_visible_rect().size.x < 960.0:
        money_label.text = "เงิน %d | คอก %d | หมู %d/%d" % [coins, pens, pigs, pens*PEN_CAPACITY]
    else:
        money_label.text = "เงิน %d | คอก %d/%d | หมู %d/%d | อาหาร %d" % [coins, pens, MAX_PENS, pigs, pens*PEN_CAPACITY, feed]
    money_label.add_theme_font_size_override("font_size", 14)
    if shop_livestock_label != null:
        shop_livestock_label.text = "คอก %d/%d  |  หมู %d/%d ตัว" % [pens, MAX_PENS, pigs, pens*PEN_CAPACITY]
        shop_pen_button.text = "ขยายคอกหมู +1 (ราคา %d เหรียญ)" % pen_price() if pens < MAX_PENS else "คอกเต็มแล้ว (%d คอก)" % MAX_PENS
        shop_pig_button.text = "ซื้อลูกหมู +1 (%d เหรียญ)" % PIG_PRICE if pigs < pens*PEN_CAPACITY else "คอกเต็ม! ซื้อคอกเพิ่มก่อน"
        shop_pen_button.disabled = pens >= MAX_PENS
        shop_pig_button.disabled = pigs >= pens*PEN_CAPACITY
    status_label.text = message
    active_seed_label.text = "เมล็ดที่เลือก: %s ×%d" % [CROPS[selected_seed]["name"], int(seeds[selected_seed])]
    _refresh_save_indicator()
    refresh_bag_cards()
    for key in action_buttons.keys():
        action_buttons[key].modulate = Color.WHITE if key == tool_mode else Color("#bbcbbd")

func refresh_bag_cards() -> void:
    if bag_summary == null:
        return
    var total: int = 0
    for i in range(seeds.size()):
        total += int(seeds[i])
    bag_summary.text = "เมล็ดพันธุ์ %d ชนิด  |  รวม %d ซอง" % [CROPS.size(), total]
    for i in range(bag_cards.size()):
        var count: int = int(seeds[i])
        var selected: bool = selected_seed == i
        bag_counts[i].text = "มี %d ซอง" % count if count > 0 else "หมดแล้ว"
        bag_counts[i].add_theme_color_override("font_color", Color("#28774e") if count > 0 else Color("#a98c7a"))
        var style: StyleBoxFlat = StyleBoxFlat.new()
        style.bg_color = Color("#e0f0d8") if selected else (Color("#fffdf4") if count > 0 else Color("#edece4"))
        style.border_color = Color("#399465") if selected else Color("#d8ddcf")
        style.set_border_width_all(3 if selected else 1)
        style.set_corner_radius_all(13)
        style.set_content_margin_all(3)
        bag_cards[i].add_theme_stylebox_override("normal", style)
        var hover: StyleBoxFlat = style.duplicate()
        hover.bg_color = style.bg_color.lightened(0.07)
        bag_cards[i].add_theme_stylebox_override("hover", hover)
        bag_cards[i].add_theme_stylebox_override("pressed", style)
        bag_cards[i].modulate = Color.WHITE if count > 0 or selected else Color("#dddddd")

func pick_tool(key: String) -> void:
    tool_mode = key
    message = "เลือกแปลงผักที่ต้องการ"
    refresh_labels()

func select_seed(index: int) -> void:
    selected_seed = index
    tool_mode = "plant"
    bag_panel.visible = false
    if int(seeds[index]) > 0:
        message = "เลือก%sแล้ว แตะแปลงเพื่อปลูก" % CROPS[index]["name"]
    else:
        message = "%sหมดแล้ว ซื้อเพิ่มได้ในร้านค้า" % CROPS[index]["name"]
    refresh_labels()

func toggle_run() -> void:
    run_toggle = not run_toggle
    run_button.modulate = Color.WHITE if run_toggle else Color("#aeb9a8")

func show_bag() -> void:
    if shop_panel.visible:
        shop_panel.visible = false
    bag_panel.visible = not bag_panel.visible
    refresh_bag_cards()

func show_shop() -> void:
    if bag_panel != null:
        bag_panel.visible = false
    shop_panel.visible = not shop_panel.visible

func buy_seed(index: int) -> void:
    var price: int = int(CROPS[index]["price"])
    if coins >= price:
        coins -= price
        seeds[index] = int(seeds[index])+1
        message = "ซื้อเมล็ดพันธุ์สำเร็จ"
        save_game()
    else:
        message = "เงินไม่พอ"
    refresh_labels()

func buy_feed() -> void:
    if coins >= 35:
        coins -= 35
        feed += 5
        message = "ซื้ออาหารหมูสำเร็จ"
        save_game()
    else:
        message = "เงินไม่พอ"
    refresh_labels()

func buy_pen() -> void:
    if pens >= MAX_PENS:
        message = "ขยายคอกครบ %d คอกแล้ว" % MAX_PENS
    elif coins < pen_price():
        message = "เหรียญไม่พอสำหรับขยายคอก"
    else:
        var cost: int = pen_price()
        coins -= cost
        pens += 1
        rebuild_livestock()
        message = "ขยายคอกหมูสำเร็จ! มีพื้นที่เลี้ยงได้ %d ตัว" % (pens*PEN_CAPACITY)
        save_game()
    refresh_labels()

func buy_pig() -> void:
    if pigs >= pens*PEN_CAPACITY:
        message = "คอกเต็มแล้ว! ขยายคอกเพิ่มก่อนซื้อหมู"
    elif coins < PIG_PRICE:
        message = "เหรียญไม่พอสำหรับซื้อลูกหมู"
    else:
        coins -= PIG_PRICE
        pigs += 1
        rebuild_livestock()
        message = "มีลูกหมูตัวใหม่แล้ว! ตอนนี้เลี้ยง %d ตัว" % pigs
        save_game()
    refresh_labels()

func give_feed() -> void:
    if feed <= 0:
        message = "อาหารหมูหมดแล้ว"
    else:
        feed -= 1
        message = "ให้อาหารหมูแล้ว"
        save_game()
    refresh_labels()

func snapshot() -> Dictionary:
    return {
        "coins": coins,
        "feed": feed,
        "pigs": pigs,
        "pens": pens,
        "seeds": seeds.duplicate(),
        "plots": plots.duplicate(true)
    }

func _apply_snapshot(state: Dictionary) -> void:
    coins = int(state["coins"])
    feed = int(state["feed"])
    pigs = int(state["pigs"])
    pens = int(state["pens"])
    seeds = state["seeds"].duplicate()
    plots = state["plots"].duplicate(true)

func _set_save_indicator(label_text: String, is_good: bool) -> void:
    save_status_text = label_text
    save_status_ok = is_good
    _refresh_save_indicator()

func _refresh_save_indicator() -> void:
    if save_status_label == null:
        return
    save_status_label.text = save_status_text
    save_status_label.add_theme_color_override("font_color", Color("#317454") if save_status_ok else Color("#a46b3e"))
    if bag_save_status != null:
        bag_save_status.text = save_status_text + " (เฉพาะเครื่องนี้)"

func load_save() -> void:
    plots.clear()
    for i in range(FARM_ROWS*FARM_COLUMNS):
        plots.append({})
    var data: Dictionary = SAVE_DATA.load_from(SAVE)
    if not data.is_empty():
        _apply_snapshot(data)
        _set_save_indicator("โหลดเซฟแล้ว", true)
        return
    if FileAccess.file_exists(SAVE):
        var old_data: Dictionary = SAVE_DATA.load_from(SAVE_DATA.PREVIOUS)
        if not old_data.is_empty():
            _apply_snapshot(old_data)
            _set_save_indicator("กู้เซฟเก่าแล้ว", true)
            return
        _set_save_indicator("เซฟอ่านไม่ได้", false)
    else:
        _set_save_indicator("ยังไม่มีเซฟ", false)

func save_game() -> bool:
    var okay: bool = SAVE_DATA.save_to(SAVE, snapshot())
    if okay:
        if OS.has_feature("web") and not OS.is_userfs_persistent():
            _set_save_indicator("เซฟชั่วคราว", false)
        else:
            _set_save_indicator("บันทึกแล้ว", true)
    else:
        _set_save_indicator("เซฟไม่สำเร็จ", false)
    return okay

func export_save_backup() -> void:
    var package_data: Dictionary = SAVE_DATA.package(snapshot())
    var data_text: String = JSON.stringify(package_data, "  ")
    var filename: String = "HappyFarm_Save_%d.json" % int(Time.get_unix_time_from_system())
    if OS.has_feature("web"):
        # Called synchronously from the inventory backup button.
        JavaScriptBridge.download_buffer(data_text.to_utf8_buffer(), filename, "application/json")
        message = "ตรวจสอบไฟล์เซฟในรายการดาวน์โหลดของเบราว์เซอร์"
    else:
        var native_path: String = "user://" + filename
        var file: FileAccess = FileAccess.open(native_path, FileAccess.WRITE)
        if file != null:
            file.store_string(data_text)
            file.close()
            message = "สำรองเซฟไว้ที่ " + native_path
        else:
            message = "ไม่สามารถสร้างไฟล์สำรองได้"
    refresh_labels()

func request_import_backup() -> void:
    if work_plot >= 0 or work_time > 0.0:
        message = "รอชาวสวนทำงานเสร็จก่อนนำเข้าเซฟ"
        refresh_labels()
        return
    if not OS.has_feature("web"):
        message = "การนำเข้าเซฟรองรับ Chrome และ Safari เวอร์ชันเว็บ"
        refresh_labels()
        return
    # Fixed JavaScript source; selected file content is never evaluated as code.
    JavaScriptBridge.eval("""
(function () {
  var picker = document.createElement('input');
  picker.type = 'file';
  picker.accept = '.json,application/json';
  picker.style.display = 'none';
  document.body.appendChild(picker);
  picker.onchange = function () {
    var file = picker.files && picker.files[0];
    if (!file) { picker.remove(); return; }
    if (file.size > 524288) {
      window.happyFarmReceiveSave('__HF_TOO_LARGE__');
      picker.remove();
      return;
    }
    var reader = new FileReader();
    reader.onload = function () {
      window.happyFarmReceiveSave(String(reader.result || ''));
      picker.remove();
    };
    reader.onerror = function () {
      window.happyFarmReceiveSave('__HF_READ_ERROR__');
      picker.remove();
    };
    reader.readAsText(file, 'UTF-8');
  };
  picker.click();
})();
""", true)

func _on_browser_import(args: Array) -> void:
    if args.is_empty():
        return
    var input_text: String = str(args[0])
    if input_text == "__HF_TOO_LARGE__":
        message = "ไฟล์ใหญ่เกิน 512 KB"
        refresh_labels()
        return
    if input_text == "__HF_READ_ERROR__":
        message = "อ่านไฟล์เซฟไม่สำเร็จ"
        refresh_labels()
        return
    if input_text.to_utf8_buffer().size() > SAVE_DATA.MAX_BYTES:
        message = "ไฟล์เซฟมีขนาดใหญ่เกินไป"
        refresh_labels()
        return
    var state: Dictionary = SAVE_DATA.normalize(JSON.parse_string(input_text))
    if state.is_empty():
        message = "ไฟล์ไม่ถูกต้องหรือไม่ใช่เซฟ Happy Farm"
        refresh_labels()
        return
    pending_restore = state
    var total: int = 0
    for value in state["seeds"]:
        total += int(value)
    restore_confirm.dialog_text = "ข้อมูลปัจจุบันในเครื่องนี้จะถูกแทนที่\n\nไฟล์ใหม่: %d เหรียญ / %d ซองเมล็ด\n\nแนะนำให้ดาวน์โหลดเซฟเดิมก่อน" % [state["coins"], total]
    restore_confirm.popup_centered(Vector2i(440, 215))

func _confirm_import_backup() -> void:
    if pending_restore.is_empty():
        return
    if work_plot >= 0 or work_time > 0.0:
        message = "รอชาวสวนทำงานเสร็จก่อนนำเข้าเซฟ"
        refresh_labels()
        return
    var to_restore: Dictionary = pending_restore.duplicate(true)
    pending_restore.clear()
    _apply_snapshot(to_restore)
    rebuild_livestock()
    for i in range(grow_stages.size()):
        grow_stages[i] = -1
    refresh_plants()
    bag_panel.visible = false
    shop_panel.visible = false
    if save_game():
        message = "นำเข้าเซฟสำเร็จ! ตรวจสอบเงิน แปลง และกระเป๋าได้เลย"
    else:
        message = "นำเข้าข้อมูลแล้ว แต่เขียนเซฟในเครื่องไม่สำเร็จ"
    refresh_labels()
