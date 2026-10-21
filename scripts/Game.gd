extends Node3D
# Clean Happy Farm 3D. All gameplay is new; no legacy patches.
const JOYSTICK = preload("res://scripts/Joystick.gd")
const ICON = preload("res://scripts/BadgeIcon.gd")
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
const CENTER = Vector3(0,0,0)
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
var selected_seed: int = 0
var tool_mode: String = "plant"
var farmer: Node3D
var arm_l: Node3D
var arm_r: Node3D
var leg_l: Node3D
var leg_r: Node3D
var hoe: Node3D
var can: Node3D
var camera: Camera3D
var camera_yaw: float = 0.65
var camera_pitch: float = -0.79
var camera_distance: float = 29.0
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
var stick: Control
var ui: Control
var status_label: Label
var money_label: Label
var seed_select: OptionButton
var shop_panel: PanelContainer
var action_buttons: Dictionary = {}
var run_button: Button
var jump_button: Button
var ui_top: PanelContainer
var ui_bottom: PanelContainer
var touch_controls: bool = false
var message: String = "เลือกเครื่องมือ แล้วแตะแปลงผัก"

func _ready() -> void:
    # Sarabun fully supports Thai, digits, Latin and punctuation.
    ThemeDB.fallback_font = THAI
    load_save()
    build_scene()
    build_farmer()
    build_ui()
    refresh_plants()
    refresh_labels()
    update_camera()
    get_viewport().size_changed.connect(update_sizes)

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
    cube(self, Vector3(0,-0.24,0), Vector3(37,0.45,28), Color("#85ba77"))
    cube(self, Vector3(-10,0,0), Vector3(2,0.04,22), Color("#d2c397"))
    cube(self, Vector3(0,0,7.9), Vector3(30,0.04,1.9), Color("#d2c397"))
    var house: Node3D = Node3D.new()
    house.position = Vector3(-12,0,-6.8)
    add_child(house)
    cube(house, Vector3(0,1.5,0), Vector3(4.5,3,3.9), Color("#efdebb"))
    var roof_l: MeshInstance3D = cube(house,Vector3(-1.10,3.26,0),Vector3(3.05,0.32,4.5),Color("#a8584d"))
    roof_l.rotation.z = -0.59
    var roof_r: MeshInstance3D = cube(house,Vector3(1.10,3.26,0),Vector3(3.05,0.32,4.5),Color("#a8584d"))
    roof_r.rotation.z = 0.59
    cube(house, Vector3(0,1.05,2), Vector3(1.10,2.1,0.1), Color("#936e50"))
    cube(house, Vector3(-1.4,2,2.02), Vector3(0.75,0.9,0.1), Color("#7db4c3"))
    cube(house, Vector3(1.4,2,2.02), Vector3(0.75,0.9,0.1), Color("#7db4c3"))
    for row in range(4):
        for col in range(6):
            var i: int = row * 6 + col
            var pos: Vector3 = Vector3((float(col)-2.5)*2.28, 0, (float(row)-1.5)*2.26)
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
            var plants: Node3D = Node3D.new()
            plants.position.y = 0.28
            plot.add_child(plants)
            plant_roots.append(plants)
            grow_stages.append(-1)
    # Farm pen. Simple pig mesh; easy to swap for FBX later.
    cube(self, Vector3(12,0.01,0),Vector3(6.8,0.07,6.8),Color("#bcbb7e"))
    for n in range(5):
        for side in [-1.0,1.0]:
            var v: float = -3.1 + float(n)*1.55
            cube(self,Vector3(12+v,0.70,side*3.25),Vector3(0.16,1.4,0.16),Color("#947253"))
            cube(self,Vector3(12+side*3.25,0.70,v),Vector3(0.16,1.4,0.16),Color("#947253"))
    for side in [-1.0,1.0]:
        for h in [0.40,1.0]:
            cube(self,Vector3(12,h,side*3.25),Vector3(6.5,0.11,0.11),Color("#be9362"))
            cube(self,Vector3(12+side*3.25,h,0),Vector3(0.11,0.11,6.5),Color("#be9362"))
    for k in range(mini(pigs,8)):
        var pig: Node3D = Node3D.new()
        pig.position = Vector3(12+(float(k%3)-1)*1.4,0.0,(float(k/3)-1)*1.4)
        add_child(pig)
        ball(pig,Vector3(0,0.56,0),Vector3(1.2,0.75,1),Color("#edacb8"))
        ball(pig,Vector3(0,0.75,-0.52),Vector3(0.74,0.7,0.67),Color("#f0b0bd"))
        ball(pig,Vector3(0,0.69,-0.84),Vector3(0.42,0.30,0.18),Color("#d98c9d"))
        for side in [-1.0,1.0]:
            ball(pig,Vector3(side*0.2,0.91,-0.82),Vector3(0.09,0.09,0.08),Color("#474047"))
            ball(pig,Vector3(side*0.30,1.13,-0.5),Vector3(0.22,0.30,0.15),Color("#ef9cae"))
            for side_z in [-0.32,0.32]:
                ball(pig,Vector3(side*0.38,0.20,side_z),Vector3(0.25,0.4,0.25),Color("#f0adbb"))
    for p in [Vector3(-16,0,4),Vector3(-16,0,11),Vector3(-6,0,-11),
        Vector3(-1,0,-11),Vector3(5,0,-11),Vector3(16,0,-10),Vector3(16,0,10)]:
        tree(p)

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
    elapsed += delta
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

func move_actor(direction: Vector3, speed: float, delta: float) -> void:
    farmer.position += direction*speed*delta
    farmer.position.x = clampf(farmer.position.x,-17,17)
    farmer.position.z = clampf(farmer.position.z,-12.5,12.5)
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

func _input(event: InputEvent) -> void:
    if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_SPACE:
        jump()
    if event is InputEventScreenTouch:
        if event.pressed and touch_cam < 0 and not point_on_ui(event.position):
            touch_cam = event.index
            touch_down = event.position
            touch_last = event.position
            cam_dragged = false
        elif not event.pressed and event.index == touch_cam:
            if not cam_dragged:
                click_plot(event.position)
            touch_cam = -1
    elif event is InputEventScreenDrag and event.index == touch_cam:
        var motion: Vector2 = event.position-touch_last
        touch_last = event.position
        if event.position.distance_to(touch_down) > 9: cam_dragged = true
        if cam_dragged:
            camera_yaw -= motion.x*0.006
            camera_pitch = clampf(camera_pitch+motion.y*0.005,-1.33,-0.33)
            update_camera()
    elif event is InputEventMouseButton:
        if event.button_index == MOUSE_BUTTON_RIGHT:
            drag_camera = event.pressed
        elif event.pressed and event.button_index == MOUSE_BUTTON_WHEEL_UP:
            camera_distance = maxf(15,camera_distance-1.5)
            update_camera()
        elif event.pressed and event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
            camera_distance = minf(45,camera_distance+1.5)
            update_camera()
        elif event.pressed and event.button_index == MOUSE_BUTTON_LEFT and not point_on_ui(event.position):
            click_plot(event.position)
    elif event is InputEventMouseMotion and drag_camera:
        camera_yaw -= event.relative.x*0.007
        camera_pitch = clampf(camera_pitch+event.relative.y*0.005,-1.33,-0.33)
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
    if camera == null: return
    var aspect: float = get_viewport().get_visible_rect().size.x/maxf(1,get_viewport().get_visible_rect().size.y)
    camera.position = CENTER+Vector3(sin(camera_yaw)*cos(camera_pitch),-sin(camera_pitch),
        cos(camera_yaw)*cos(camera_pitch))*camera_distance
    camera.look_at(CENTER)
    camera.size = 19 if aspect > 1.3 else (26 if aspect > 0.82 else 34)

func text_label(txt: String, font_size: int, color: Color = Color("#284c3a")) -> Label:
    var label: Label = Label.new()
    label.text = txt
    label.add_theme_font_override("font",THAI)
    label.add_theme_font_size_override("font_size",font_size)
    label.add_theme_color_override("font_color",color)
    label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    return label

func btn(txt: String, callback: Callable, background: Color=Color("#417c59")) -> Button:
    var b: Button = Button.new()
    b.text = txt
    b.focus_mode = Control.FOCUS_NONE
    b.custom_minimum_size = Vector2(88,44)
    b.add_theme_font_override("font",THAI)
    b.add_theme_font_size_override("font_size",18)
    b.add_theme_color_override("font_color",Color.WHITE)
    var style: StyleBoxFlat = StyleBoxFlat.new()
    style.bg_color = background
    style.set_corner_radius_all(13)
    style.set_content_margin_all(6)
    b.add_theme_stylebox_override("normal",style)
    b.add_theme_stylebox_override("hover",style)
    b.add_theme_stylebox_override("pressed",style)
    b.pressed.connect(callback)
    return b

func panel(color: Color) -> PanelContainer:
    var p: PanelContainer = PanelContainer.new()
    var style: StyleBoxFlat = StyleBoxFlat.new()
    style.bg_color = color
    style.set_corner_radius_all(16)
    style.set_content_margin_all(9)
    p.add_theme_stylebox_override("panel",style)
    return p

func build_ui() -> void:
    touch_controls = DisplayServer.is_touchscreen_available() or OS.has_feature("web_android") or OS.has_feature("web_ios")
    var layer: CanvasLayer = CanvasLayer.new()
    layer.layer = 4
    add_child(layer)
    ui = Control.new()
    ui.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    ui.mouse_filter = Control.MOUSE_FILTER_IGNORE
    layer.add_child(ui)
    ui_top = panel(Color("#e8f2e6f0"))
    ui_top.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT)
    ui_top.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
    ui.add_child(ui_top)
    var row: HBoxContainer = HBoxContainer.new()
    row.add_theme_constant_override("separation",6)
    ui_top.add_child(row)
    var title: Label = text_label("ฟาร์มสุขใจ",21)
    title.add_theme_font_override("font",THAI_BOLD)
    row.add_child(title)
    money_label = text_label("",16)
    row.add_child(money_label)
    row.add_child(btn("ร้านค้า",show_shop,Color("#ae7c4f")))
    row.add_child(btn("ให้อาหาร",give_feed,Color("#ae7683")))
    ui_bottom = panel(Color("#e8f2e6ed"))
    ui_bottom.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_LEFT)
    ui_bottom.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
    ui.add_child(ui_bottom)
    var controls: VBoxContainer = VBoxContainer.new()
    controls.add_theme_constant_override("separation",5)
    ui_bottom.add_child(controls)
    status_label = text_label("",15)
    controls.add_child(status_label)
    var seed_row: HBoxContainer = HBoxContainer.new()
    seed_row.add_child(text_label("เมล็ด",16))
    controls.add_child(seed_row)
    seed_select = OptionButton.new()
    seed_select.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    seed_select.add_theme_font_override("font",THAI)
    seed_select.add_theme_font_size_override("font_size",16)
    seed_select.add_theme_font_override("font_selected", THAI)
    seed_select.get_popup().add_theme_font_override("font",THAI)
    seed_select.get_popup().add_theme_font_size_override("font_size",16)
    for i in range(CROPS.size()):
        seed_select.add_item(str(CROPS[i]["name"]),i)
    seed_select.item_selected.connect(select_seed)
    seed_row.add_child(seed_select)
    var actions: GridContainer = GridContainer.new()
    actions.columns = 4
    actions.add_theme_constant_override("h_separation",5)
    controls.add_child(actions)
    for pair in [["till","พรวนดิน"],["plant","ปลูกผัก"],["water","รดน้ำ"],["harvest","เก็บเกี่ยว"]]:
        var k: String = str(pair[0])
        var button: Button = btn(str(pair[1]),pick_tool.bind(k),Color("#488765") if k!="water" else Color("#4d96af"))
        button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
        actions.add_child(button)
        action_buttons[k] = button
    stick = JOYSTICK.new()
    ui.add_child(stick)
    stick.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_LEFT)
    stick.visible = touch_controls
    run_button = btn("วิ่ง",toggle_run,Color("#518d77"))
    ui.add_child(run_button)
    run_button.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT)
    run_button.visible = touch_controls
    jump_button = btn("กระโดด",jump,Color("#cc9457"))
    ui.add_child(jump_button)
    jump_button.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT)
    jump_button.visible = touch_controls
    shop_panel = panel(Color("#f1f6ebfa"))
    shop_panel.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT)
    shop_panel.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
    shop_panel.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
    ui.add_child(shop_panel)
    shop_panel.visible = false
    var shop_body: VBoxContainer = VBoxContainer.new()
    shop_panel.add_child(shop_body)
    var shop_header: HBoxContainer = HBoxContainer.new()
    shop_body.add_child(shop_header)
    var shop_title: Label = text_label("ร้านค้าเมล็ดพันธุ์",24)
    shop_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    shop_header.add_child(shop_title)
    shop_header.add_child(btn("ปิด",show_shop,Color("#787f7a")))
    var shop_scroll: ScrollContainer = ScrollContainer.new()
    shop_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
    shop_body.add_child(shop_scroll)
    var shop_grid: GridContainer = GridContainer.new()
    shop_grid.columns = 2
    shop_grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    shop_scroll.add_child(shop_grid)
    for i in range(CROPS.size()):
        shop_grid.add_child(btn("%s  %d" % [CROPS[i]["name"],CROPS[i]["price"]],buy_seed.bind(i)))
    shop_body.add_child(btn("ซื้ออาหารหมู 5 ชุด ราคา 35 เหรียญ",buy_feed))
    update_sizes()
    pick_tool("plant")

func update_sizes() -> void:
    if ui_top == null:
        return
    var s: Vector2 = get_viewport().get_visible_rect().size
    var narrow: bool = s.x < 760.0

    # Compact floating panels: no stretched anchors, no covering the world.
    ui_top.anchor_left = 0.0
    ui_top.anchor_right = 0.0
    ui_top.anchor_top = 0.0
    ui_top.anchor_bottom = 0.0
    ui_top.offset_left = 12.0
    ui_top.offset_top = 12.0
    ui_top.offset_right = minf(s.x - 12.0, 590.0)
    ui_top.offset_bottom = 74.0

    ui_bottom.anchor_left = 0.0
    ui_bottom.anchor_right = 0.0
    ui_bottom.anchor_top = 1.0
    ui_bottom.anchor_bottom = 1.0
    ui_bottom.offset_left = 12.0 if not touch_controls else 174.0
    ui_bottom.offset_right = minf(s.x - (12.0 if not touch_controls else 144.0), 650.0)
    ui_bottom.offset_top = -147.0
    ui_bottom.offset_bottom = -12.0
    if narrow:
        ui_bottom.offset_left = 8.0
        ui_bottom.offset_right = s.x - 8.0
        ui_bottom.offset_top = -332.0 if touch_controls else -165.0
        ui_bottom.offset_bottom = -172.0 if touch_controls else -8.0
        ui_top.offset_right = s.x - 12.0

    stick.anchor_left = 0.0
    stick.anchor_right = 0.0
    stick.anchor_top = 1.0
    stick.anchor_bottom = 1.0
    stick.offset_left = 18.0
    stick.offset_right = 162.0
    stick.offset_top = -158.0
    stick.offset_bottom = -14.0

    run_button.anchor_left = 1.0
    run_button.anchor_right = 1.0
    run_button.anchor_top = 1.0
    run_button.anchor_bottom = 1.0
    run_button.offset_left = -135.0
    run_button.offset_right = -14.0
    run_button.offset_top = -152.0
    run_button.offset_bottom = -88.0

    jump_button.anchor_left = 1.0
    jump_button.anchor_right = 1.0
    jump_button.anchor_top = 1.0
    jump_button.anchor_bottom = 1.0
    jump_button.offset_left = -135.0
    jump_button.offset_right = -14.0
    jump_button.offset_top = -80.0
    jump_button.offset_bottom = -14.0

    shop_panel.anchor_left = 0.5
    shop_panel.anchor_right = 0.5
    shop_panel.anchor_top = 0.5
    shop_panel.anchor_bottom = 0.5
    shop_panel.offset_left = -minf(310.0, s.x * 0.46)
    shop_panel.offset_right = minf(310.0, s.x * 0.46)
    shop_panel.offset_top = -minf(230.0, s.y * 0.43)
    shop_panel.offset_bottom = minf(230.0, s.y * 0.43)
    update_camera()

func point_on_ui(pos: Vector2) -> bool:
    if shop_panel.visible: return true
    for panel_node in [ui_top,ui_bottom]:
        if panel_node != null and panel_node.get_global_rect().has_point(pos):
            return true
    if touch_controls:
        for control in [stick,run_button,jump_button]:
            if control.visible and control.get_global_rect().has_point(pos): return true
    return false

func refresh_labels() -> void:
    if money_label == null: return
    money_label.text = "เงิน %d | หมู %d | อาหาร %d" % [coins,pigs,feed]
    status_label.text = message
    for i in range(CROPS.size()):
        seed_select.set_item_text(i,"%s (%d)" % [CROPS[i]["name"],int(seeds[i])])
    for key in action_buttons.keys():
        action_buttons[key].modulate = Color.WHITE if key == tool_mode else Color("#bbcbbd")

func pick_tool(key: String) -> void:
    tool_mode = key
    message = "เลือกแปลงผักที่ต้องการ"
    refresh_labels()

func select_seed(index: int) -> void:
    selected_seed = index
    refresh_labels()

func toggle_run() -> void:
    run_toggle = not run_toggle
    run_button.modulate = Color.WHITE if run_toggle else Color("#aeb9a8")

func show_shop() -> void:
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

func give_feed() -> void:
    if feed <= 0:
        message = "อาหารหมูหมดแล้ว"
    else:
        feed -= 1
        message = "ให้อาหารหมูแล้ว"
        save_game()
    refresh_labels()

func load_save() -> void:
    for i in range(24):
        plots.append({})
    if not FileAccess.file_exists(SAVE): return
    var file: FileAccess = FileAccess.open(SAVE,FileAccess.READ)
    if file == null: return
    var data: Variant = JSON.parse_string(file.get_as_text())
    if not (data is Dictionary): return
    coins = int(data.get("coins",250))
    feed = int(data.get("feed",4))
    pigs = int(data.get("pigs",1))
    var saved_seeds: Variant = data.get("seeds",[])
    var saved_plots: Variant = data.get("plots",[])
    if saved_seeds is Array:
        for i in range(mini(seeds.size(),saved_seeds.size())):
            seeds[i] = maxi(0,int(saved_seeds[i]))
    if saved_plots is Array:
        for i in range(mini(plots.size(),saved_plots.size())):
            if saved_plots[i] is Dictionary:
                plots[i] = saved_plots[i]

func save_game() -> void:
    var f: FileAccess = FileAccess.open(SAVE,FileAccess.WRITE)
    if f != null:
        f.store_string(JSON.stringify({"coins":coins,"feed":feed,"pigs":pigs,"seeds":seeds,"plots":plots}))
