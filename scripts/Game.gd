extends Node3D
# Clean Happy Farm 3D. All gameplay is new; no legacy patches.
const JOYSTICK = preload("res://scripts/Joystick.gd")
const ICON = preload("res://scripts/BadgeIcon.gd")
const SEED_ICON = preload("res://scripts/SeedIcon.gd")
const SAVE_DATA = preload("res://scripts/SaveData.gd")
const FARMER_VISUAL = preload("res://scripts/FarmerVisual.gd")
const FARM_AUDIO = preload("res://scripts/FarmAudio.gd")
const GARDEN_DECOR = preload("res://scripts/GardenDecor.gd")
# Each visual element is imported from a standalone transparent PNG.
# Text remains live Godot text for crisp rendering and future localization.
const UI_BUTTON: Texture2D = preload("res://assets/ui/happy/button_green.png")
const UI_WINDOW: Texture2D = preload("res://assets/ui/happy/window_wood.png")
const UI_HEADER: Texture2D = preload("res://assets/ui/happy/window_header.png")
const UI_SLOT: Texture2D = preload("res://assets/ui/happy/inventory_slot.png")
const UI_HUD: Texture2D = preload("res://assets/ui/happy/hud_bar.png")
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
const PLOTS_PER_LEVEL: int = 5
const MAX_FARM_LEVEL: int = 10
# Begin with the five central beds closest to the farmer's spawn.
# Unlock adjacent beds first, then move toward the opposite end of the farm.
const PLOT_UNLOCK_ORDER = [
    43, 44, 45, 46, 47, 40, 41, 42, 48, 49,
    33, 34, 35, 36, 37, 30, 31, 32, 38, 39,
    23, 24, 25, 26, 27, 20, 21, 22, 28, 29,
    13, 14, 15, 16, 17, 10, 11, 12, 18, 19,
    3, 4, 5, 6, 7, 0, 1, 2, 8, 9
]
const PEN_CAPACITY: int = 4
const MAX_PENS: int = 4
const PEN_BASE_PRICE: int = 150
const PIG_PRICE: int = 90
const PLOT_KIT_PRICE: int = 75
const TREE_VARIANTS = ["STOak2", "STPine3", "STWillow2", "STColumnar1", "STSwiggly1"]
const TREE_NAMES = ["โอ๊ก", "สน", "วิลโลว์", "ทรงสูง", "กิ่งโค้ง"]
const TREE_PRICES = [65, 75, 80, 75, 90]
const MAX_EXTRA_PLOTS: int = 120
const MAX_PLANTED_TREES: int = 80
const WORLD_SIZE: float = 400.0
const WORLD_HALF: float = 200.0
const ZONE_SIZE: float = 40.0
const ZONE_COLUMNS: int = 10
const STARTER_ZONES = [44, 45, 54, 55]
const MAX_DECORATIONS: int = 260
const DECOR_NAMES = [
    "ม้านั่งไม้", "รั้วไม้", "กระถางดอกไม้", "โคมไฟสวน",
    "น้ำพุ", "หุ่นไล่กา", "ป้ายไม้", "กองฟาง",
    "โต๊ะปิกนิก", "บ่อน้ำ", "พุ่มไม้", "ทางเดินหิน",
    "ตู้จดหมาย", "ศาลาพัก", "สวนหิน", "ตะเกียง"
]
const DECOR_PRICES = [110, 35, 45, 120, 600, 175, 80, 45, 220, 320, 35, 25, 70, 850, 95, 55]
const DECOR_RADII = [1.1, 0.7, 0.9, 0.9, 2.1, 1.0, 0.7, 1.1, 1.8, 1.6, 1.1, 0.9, 0.7, 2.8, 1.5, 0.8]
# Temporary browser playtest only. Set false AND remove the GM tool before launch.
# Client-side currency is not secure for real-money or competitive economies.
const GM_TEST_MODE: bool = true
# Close enough to inspect the farmer; wide enough for all 10 x 5 beds.
# Every zoom input uses the same limits (orthographic size is derived below).
const CAMERA_ZOOM_MIN: float = 6.0
const CAMERA_ZOOM_MAX: float = 78.0
const CAMERA_TAP_SLOP: float = 9.0
const CAMERA_PINCH_MIN_GAP: float = 10.0
var materials: Dictionary = {}
var plot_places: Array[Vector3] = []
var plant_roots: Array[Node3D] = []
var dirt_meshes: Array[MeshInstance3D] = []
var grow_stages: Array[int] = []
var plot_locks: Array[Node3D] = []
var plots: Array = []
var plot_kits: int = 0
var tree_kits: Array = [0, 0, 0, 0, 0]
var selected_tree: int = 0
var wood: int = 0
var saved_extra_plots: Array = []
var placed_trees_data: Array = []
var removed_trees: Array = []
var extra_plot_nodes: Array[Node3D] = []
var base_tree_nodes: Array[Node3D] = []
var placed_tree_nodes: Array[Node3D] = []
var unlocked_zones: Array = [44, 45, 54, 55]
var zone_covers: Array[MeshInstance3D] = []
var zone_signs: Array[Label3D] = []
var pending_zone_id: int = -1
var decor_kits: Array = [0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0]
var selected_decor: int = 0
var placed_decor_data: Array = []
var decor_nodes: Array[Node3D] = []
var placement_preview: MeshInstance3D
var landscaping_mode: bool = false
var farm_level: int = 1
var farm_xp: int = 0
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
var touch_button_fingers: Dictionary = {}
# Godot emits an emulated mouse event BEFORE its corresponding touch event.
# Keep its ownership until mouse-up, even when the finger crosses a control.
var block_touch_mouse: bool = false
# Real keyboard key-down/up state for Web exports. Use physical key codes
# so WASD remains reliable even with a non-English keyboard layout.
var keyboard_held: Dictionary = {}
var stick: Control
var stick_label: Label
var ui: Control
var status_label: Label
var farm_level_label: Label
var money_label: Label
var seed_select: OptionButton
var shop_panel: Panel
var action_buttons: Dictionary = {}
var landscape_button: Button
var landscape_shop_button: Button
var shop_plot_button: Button
var shop_tree_buttons: Array[Button] = []
var shop_decor_buttons: Array[Button] = []
var gm_button: Button
var gm_panel: Panel
var gm_title: Label
var land_confirm: ConfirmationDialog
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
var shop_header_art: TextureRect
var bag_header_art: TextureRect
var gm_header_art: TextureRect
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
    _focus_game_canvas()
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

# Use the owner's actual Stylized Trees FBX files and matching texture atlases.
# Models use old Windows texture paths, so explicitly rebind their materials here.
func _tree_material(variant: String, foliage: bool) -> StandardMaterial3D:
    var family: String = "STColumnar"
    if variant.begins_with("STOak"):
        family = "STOak"
    elif variant.begins_with("STPine"):
        family = "STPine"
    elif variant.begins_with("STSwiggly"):
        family = "STSwiggly"
    elif variant.begins_with("STWillow"):
        family = "STWillow"
    var key: String = "tree:%s:%s" % [family, "leaf" if foliage else "trunk"]
    if materials.has(key):
        return materials[key] as StandardMaterial3D
    var atlases: Dictionary = {
        "STColumnar": ["STLeafTexture1.png", "STColumnarTrunkTexture.png"],
        "STOak": ["STOakLeafTexture1.png", "STOakTrunkTexture.png"],
        "STPine": ["STPineLeafTexture.png", "STPineTrunkTexture.png"],
        "STSwiggly": ["STAltLeafTexture.png", "STSwigglyTrunkTexture.png"],
        "STWillow": ["STWillowLeafTexture.png", "STWillowTrunkTexture.png"]
    }
    var atlas_files: Array = atlases[family]
    var atlas: String = str(atlas_files[0 if foliage else 1])
    var result: StandardMaterial3D = StandardMaterial3D.new()
    result.albedo_texture = load("res://assets/trees/Textures/" + atlas) as Texture2D
    result.roughness = 0.94
    if foliage:
        result.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR
        result.alpha_scissor_threshold = 0.3
        result.cull_mode = BaseMaterial3D.CULL_DISABLED
    materials[key] = result
    return result

func _prepare_tree_model(model: Node3D, variant: String, target_height: float) -> bool:
    # Traverse the imported FBX hierarchy. Fit every variant to the farm's
    # meter-scale world while putting the lowest point on the terrain.
    var nodes: Array[Node] = [model]
    var bounds: AABB = AABB()
    var has_geometry: bool = false
    while not nodes.is_empty():
        var candidate: Node = nodes.pop_back()
        for child in candidate.get_children():
            nodes.append(child)
        if not (candidate is MeshInstance3D):
            continue
        var mesh_node: MeshInstance3D = candidate as MeshInstance3D
        if mesh_node.mesh == null:
            continue
        for surface in range(mesh_node.mesh.get_surface_count()):
            var source_material: Material = mesh_node.mesh.surface_get_material(surface)
            var material_name: String = ""
            if source_material != null:
                material_name = source_material.resource_name.to_lower()
            if material_name.is_empty():
                material_name = mesh_node.mesh.surface_get_name(surface).to_lower()
            if material_name.is_empty():
                material_name = mesh_node.name.to_lower()
            var foliage: bool = material_name.contains("leaf") or material_name.contains("leaves") or material_name.contains("needle")
            if material_name.contains("trunk") or material_name.contains("bark"):
                foliage = false
            mesh_node.set_surface_override_material(surface, _tree_material(variant, foliage))
        var mesh_bounds: AABB = mesh_node.mesh.get_aabb()
        for x in [0.0, 1.0]:
            for y in [0.0, 1.0]:
                for z in [0.0, 1.0]:
                    var corner: Vector3 = mesh_bounds.position + mesh_bounds.size * Vector3(x, y, z)
                    var local_point: Vector3 = model.to_local(mesh_node.to_global(corner))
                    if not has_geometry:
                        bounds = AABB(local_point, Vector3.ZERO)
                        has_geometry = true
                    else:
                        bounds = bounds.expand(local_point)
    if not has_geometry or bounds.size.y <= 0.001:
        return false
    var max_width: float = maxf(bounds.size.x, bounds.size.z)
    var fit: float = minf(target_height / bounds.size.y, 5.6 / maxf(max_width, 0.001))
    model.scale = Vector3.ONE * fit
    model.position.y = -bounds.position.y * fit
    return true

func tree(pos: Vector3, variant: String = "STOak2", target_height: float = 4.7, yaw: float = 0.0) -> Node3D:
    var group: Node3D = Node3D.new()
    group.name = "Tree_%s" % variant
    group.position = pos
    group.rotation_degrees = Vector3(0, yaw, 0)
    add_child(group)
    var resource: PackedScene = load("res://assets/trees/Models/%s.fbx" % variant) as PackedScene
    if resource != null:
        var instance: Node = resource.instantiate()
        if instance is Node3D:
            var model: Node3D = instance as Node3D
            group.add_child(model)
            if _prepare_tree_model(model, variant, target_height):
                group.add_to_group("farm_imported_trees")
                return group
            group.remove_child(model)
            model.queue_free()
    # Fall back to the old lightweight tree if an FBX is unavailable.
    stalk(group, Vector3(0,1.15,0), 2.25, 0.20, Color("#86654b"))
    ball(group, Vector3(0,2.65,0), Vector3(2.2,1.75,2.05), Color("#528f61"))
    ball(group, Vector3(-0.6,2.4,0.1), Vector3(1.5,1.4,1.4), Color("#72b16f"))
    ball(group, Vector3(0.65,2.6,0), Vector3(1.3,1.4,1.3), Color("#81bb76"))
    return group

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

    # 400x400 playable surface. 40x40 zones hide until bought with farm coins.
    cube(self, Vector3(0,-0.24,0), Vector3(WORLD_SIZE,0.45,WORLD_SIZE), Color("#85ba77"))
    _build_land_zones()
    cube(self, Vector3(-14.5,0,0), Vector3(2.2,0.04,29.0), Color("#d2c397"))
    cube(self, Vector3(0,0,11.8), Vector3(58.0,0.04,2.1), Color("#d2c397"))
    cube(self, Vector3(13.1,0,0), Vector3(1.7,0.04,21.0), Color("#d2c397"))

    var house: Node3D = Node3D.new()
    house.name = "FarmHouse"
    house.position = Vector3(-19.0,0,-8.4)
    add_child(house)
    cube(house, Vector3(0,1.5,0), Vector3(4.5,3,3.9), Color("#efdebb"))
    # Both slopes meet at a raised ridge; the eaves overhang the 3m walls.
    var roof_pitch: float = 0.59
    var roof_half_span: float = 2.55
    var roof_thickness: float = 0.32
    var roof_eave_height: float = 3.12
    var roof_center_height: float = roof_eave_height + roof_half_span * 0.5 * tan(roof_pitch)
    var roof_dimensions: Vector3 = Vector3(roof_half_span / cos(roof_pitch), roof_thickness, 4.5)
    var roof_l: MeshInstance3D = cube(house,Vector3(-roof_half_span * 0.5,roof_center_height,0),roof_dimensions,Color("#a8584d"))
    roof_l.name = "RoofLeft"
    roof_l.rotation.z = roof_pitch
    var roof_r: MeshInstance3D = cube(house,Vector3(roof_half_span * 0.5,roof_center_height,0),roof_dimensions,Color("#a8584d"))
    roof_r.name = "RoofRight"
    roof_r.rotation.z = -roof_pitch
    # Close the triangular attic ends up to the underside of the roof.
    var gable_height: float = roof_eave_height + roof_half_span * tan(roof_pitch) - roof_thickness * 0.5 / cos(roof_pitch) - 3.0
    var gable_mesh: PrismMesh = PrismMesh.new()
    gable_mesh.size = Vector3(4.5,gable_height,3.9)
    var gable: MeshInstance3D = MeshInstance3D.new()
    gable.name = "Gable"
    gable.mesh = gable_mesh
    gable.position = Vector3(0,3.0 + gable_height * 0.5,0)
    gable.material_override = make_material(Color("#efdebb"))
    house.add_child(gable)
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
            # Visible but unavailable plots show the required farm level.
            var plot_lock: Node3D = Node3D.new()
            plot_lock.name = "LevelLock"
            plot_lock.position.y = 0.27
            plot.add_child(plot_lock)
            cube(plot_lock, Vector3.ZERO, Vector3(1.78, 0.045, 1.78), Color("#55615c"))
            cube(plot_lock, Vector3(0, 0.21, 0), Vector3(0.38, 0.27, 0.23), Color("#e5c783"))
            for side in [-1.0, 1.0]:
                cube(plot_lock, Vector3(side * 0.13, 0.40, 0), Vector3(0.09, 0.18, 0.09), Color("#e5c783"))
            cube(plot_lock, Vector3(0, 0.49, 0), Vector3(0.35, 0.08, 0.09), Color("#e5c783"))
            var lock_label: Label3D = Label3D.new()
            lock_label.name = "RequiredLevel"
            lock_label.text = "Lv.%d" % required_farm_level(row * FARM_COLUMNS + col)
            lock_label.font = THAI_BOLD
            lock_label.font_size = 50
            lock_label.pixel_size = 0.008
            lock_label.outline_size = 7
            lock_label.modulate = Color("#fff1d0")
            lock_label.rotation_degrees.x = -90.0
            lock_label.position = Vector3(0, 0.07, 0.49)
            plot_lock.add_child(lock_label)
            plot_locks.append(plot_lock)
    update_plot_locks()

    # All owned pens/pigs are regenerated here and after purchases/imports.
    rebuild_livestock()
    # A border of owner-supplied trees leaves the 50 plots, paths and pens open.
    # Each row is [position, FBX variant, height in world units, yaw in degrees].
    for planting in [
        [Vector3(-29,0,4), "STOak2", 4.9, 22.0],
        [Vector3(-29,0,13), "STWillow2", 5.0, 85.0],
        [Vector3(-25,0,-15), "STPine3", 5.4, 170.0],
        [Vector3(-18,0,15), "STSwiggly1", 4.8, 36.0],
        [Vector3(-7,0,-15), "STColumnar1", 4.9, 140.0],
        [Vector3(0,0,-15), "STOak1", 5.0, 55.0],
        [Vector3(9,0,-15), "STPine2", 5.3, 11.0],
        [Vector3(27,0,-15), "STWillow1", 5.2, 102.0],
        [Vector3(29,0,15), "STColumnar2", 4.9, 65.0],
        [Vector3(-29,0,-10), "STOak3", 4.8, 204.0],
        [Vector3(-13,0,16), "STWillow3", 4.9, 46.0],
        [Vector3(2,0,17), "STPine4", 5.2, 267.0],
        [Vector3(17,0,17), "STSwiggly2", 4.6, 156.0],
        [Vector3(29,0,-3), "STPine1", 5.2, 23.0],
        [Vector3(28,0,7), "STOak4", 4.9, 290.0]
    ]:
        base_tree_nodes.append(tree(planting[0], str(planting[1]), float(planting[2]), float(planting[3])))
    _rebuild_placed_world()
    _build_placement_preview()



# Land ownership is a separate progression from the first 50 level-gated beds.
# The starting four 40x40 parcels preserve the existing farm in the center.
func zone_for_position(pos: Vector3) -> int:
    if not is_finite(pos.x) or not is_finite(pos.z):
        return -1
    if pos.x < -WORLD_HALF or pos.x >= WORLD_HALF or pos.z < -WORLD_HALF or pos.z >= WORLD_HALF:
        return -1
    var col: int = floori((pos.x + WORLD_HALF) / ZONE_SIZE)
    var row: int = floori((pos.z + WORLD_HALF) / ZONE_SIZE)
    return row * ZONE_COLUMNS + col

func is_land_owned(pos: Vector3) -> bool:
    var id: int = zone_for_position(pos)
    return id >= 0 and unlocked_zones.has(id)

func zone_can_be_bought(id: int) -> bool:
    if id < 0 or id >= ZONE_COLUMNS * ZONE_COLUMNS or unlocked_zones.has(id):
        return false
    var col: int = id % ZONE_COLUMNS
    var row: int = id / ZONE_COLUMNS
    if col > 0 and unlocked_zones.has(id - 1):
        return true
    if col < ZONE_COLUMNS - 1 and unlocked_zones.has(id + 1):
        return true
    if row > 0 and unlocked_zones.has(id - ZONE_COLUMNS):
        return true
    if row < ZONE_COLUMNS - 1 and unlocked_zones.has(id + ZONE_COLUMNS):
        return true
    return false

func zone_price(id: int) -> int:
    if id < 0 or id >= ZONE_COLUMNS * ZONE_COLUMNS:
        return 0
    # The price rises gradually with farm expansion; the player earns coins
    # from harvests and livestock before unlocking the next parcel.
    return 300 + maxi(0, unlocked_zones.size() - STARTER_ZONES.size()) * 125

func _build_land_zones() -> void:
    var root: Node3D = Node3D.new()
    root.name = "LandExpansionGrid"
    add_child(root)
    for id in range(ZONE_COLUMNS * ZONE_COLUMNS):
        var col: int = id % ZONE_COLUMNS
        var row: int = id / ZONE_COLUMNS
        var x: float = -WORLD_HALF + (float(col) + 0.5) * ZONE_SIZE
        var z: float = -WORLD_HALF + (float(row) + 0.5) * ZONE_SIZE
        var shade: Color = Color("#577966") if (col + row) % 2 == 0 else Color("#61806b")
        var cover: MeshInstance3D = cube(root, Vector3(x,0.04,z), Vector3(ZONE_SIZE-0.22,0.06,ZONE_SIZE-0.22), shade)
        cover.name = "LockedZone_%02d" % id
        zone_covers.append(cover)
        var sign: Label3D = Label3D.new()
        sign.name = "ZonePrice_%02d" % id
        sign.font = THAI_BOLD
        sign.font_size = 70
        sign.pixel_size = 0.025
        sign.outline_size = 10
        sign.modulate = Color("#fff3d1")
        sign.rotation_degrees.x = -90
        sign.position = Vector3(x,0.20,z)
        root.add_child(sign)
        zone_signs.append(sign)
    _refresh_land_zones()

func _refresh_land_zones() -> void:
    for i in range(zone_covers.size()):
        var open: bool = unlocked_zones.has(i)
        zone_covers[i].visible = not open
        var frontier: bool = not open and zone_can_be_bought(i)
        zone_signs[i].visible = frontier
        if frontier:
            zone_signs[i].text = "ที่ดิน %d เหรียญ" % zone_price(i)

func buy_land_zone(id: int) -> bool:
    if id < 0 or id >= ZONE_COLUMNS * ZONE_COLUMNS:
        message = "ตำแหน่งอยู่นอกแมพ"
    elif unlocked_zones.has(id):
        message = "พื้นที่นี้เป็นของฟาร์มแล้ว"
    elif not zone_can_be_bought(id):
        message = "ต้องซื้อโซนที่ติดกับที่ดินของตัวเองก่อน"
    elif coins < zone_price(id):
        message = "เหรียญไม่พอซื้อที่ดิน ต้องใช้ %d เหรียญ" % zone_price(id)
    else:
        var price: int = zone_price(id)
        coins -= price
        unlocked_zones.append(id)
        _refresh_land_zones()
        message = "ปลดล็อกที่ดิน 40×40 สำเร็จ! พื้นที่ %d/100" % unlocked_zones.size()
        if farm_audio != null:
            farm_audio.play_effect("buy")
        save_game()
        refresh_labels()
        return true
    refresh_labels()
    return false

func _request_land_purchase(pos: Vector3) -> void:
    var id: int = zone_for_position(pos)
    if id < 0:
        message = "แตะภายในแผนที่ 400×400 เท่านั้น"
    elif unlocked_zones.has(id):
        message = "ที่ดินนี้เปิดใช้งานแล้ว"
    elif not zone_can_be_bought(id):
        message = "ต้องปลดล็อกโซนที่อยู่ติดกันก่อน"
    elif coins < zone_price(id):
        message = "พื้นที่นี้ราคา %d เหรียญ (มี %d)" % [zone_price(id), coins]
    else:
        pending_zone_id = id
        land_confirm.dialog_text = "ซื้อพื้นที่ใหม่ 40×40 หน่วย ราคา %d เหรียญ?\\nเหลือเงิน %d เหรียญ" % [zone_price(id), coins]
        land_confirm.popup_centered(Vector2i(450, 205))
        return
    refresh_labels()

func _confirm_land_purchase() -> void:
    if pending_zone_id >= 0:
        buy_land_zone(pending_zone_id)
    pending_zone_id = -1

# Freely placed crop beds are separate from the original 50 level-gated beds.
# Saved world coordinates are never snapped onto the original plot grid.
func _add_extra_plot(pos: Vector3, state: Dictionary = {}) -> void:
    var root: Node3D = Node3D.new()
    root.name = "FreePlot_%d" % extra_plot_nodes.size()
    root.position = Vector3(pos.x, 0.0, pos.z)
    add_child(root)
    extra_plot_nodes.append(root)
    plot_places.append(root.position)
    var soil: MeshInstance3D = cube(root, Vector3(0,0.12,0), Vector3(1.93,0.22,1.92), SOIL)
    dirt_meshes.append(soil)
    for edge in [-1.0,1.0]:
        cube(root, Vector3(edge,0.17,0), Vector3(0.12,0.19,2.04), Color("#c8aa74"))
        cube(root, Vector3(0,0.17,edge), Vector3(2.04,0.19,0.12), Color("#c8aa74"))
    for furrow in [-0.55,0.0,0.55]:
        cube(root, Vector3(furrow,0.242,0), Vector3(0.11,0.032,1.45), Color("#926b4b"))
    var holder: Node3D = Node3D.new()
    holder.position.y = 0.28
    root.add_child(holder)
    plant_roots.append(holder)
    grow_stages.append(-1)
    plots.append(state.duplicate(true))

func _rebuild_placed_world() -> void:
    # Called on start and after confirmed save restore. Clear old scene nodes
    # before replaying placements so restored items never duplicate.
    for item in extra_plot_nodes:
        if is_instance_valid(item):
            item.queue_free()
    extra_plot_nodes.clear()
    while plot_places.size() > FARM_COLUMNS * FARM_ROWS:
        plot_places.pop_back()
        plant_roots.pop_back()
        dirt_meshes.pop_back()
        grow_stages.pop_back()
    if plots.size() > FARM_COLUMNS * FARM_ROWS:
        plots.resize(FARM_COLUMNS * FARM_ROWS)
    for entry in saved_extra_plots:
        var cell: Dictionary = entry.duplicate(true)
        var pos: Vector3 = Vector3(float(cell["x"]), 0.0, float(cell["z"]))
        cell.erase("x")
        cell.erase("z")
        _add_extra_plot(pos, cell)
    for placed in placed_tree_nodes:
        if is_instance_valid(placed):
            placed.queue_free()
    placed_tree_nodes.clear()
    for idx in range(base_tree_nodes.size()):
        base_tree_nodes[idx].visible = not removed_trees.has(idx)
    for entry in placed_trees_data:
        var pos: Vector3 = Vector3(float(entry["x"]), 0.0, float(entry["z"]))
        placed_tree_nodes.append(tree(pos, str(entry["variant"]), 4.8, float(entry["rotation"])))
    for old_decor in decor_nodes:
        if is_instance_valid(old_decor):
            old_decor.queue_free()
    decor_nodes.clear()
    for entry in placed_decor_data:
        var pos: Vector3 = Vector3(float(entry["x"]), 0.0, float(entry["z"]))
        decor_nodes.append(GARDEN_DECOR.make(self, pos, int(entry["type"]), float(entry["rotation"])))
    for i in range(grow_stages.size()):
        grow_stages[i] = -1
    refresh_plants()

func _build_placement_preview() -> void:
    placement_preview = MeshInstance3D.new()
    placement_preview.name = "FreePlacementPreview"
    var shape: BoxMesh = BoxMesh.new()
    shape.size = Vector3(1.95, 0.05, 1.95)
    placement_preview.mesh = shape
    var material: StandardMaterial3D = StandardMaterial3D.new()
    material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
    material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
    material.albedo_color = Color(0.2, 0.85, 0.35, 0.45)
    placement_preview.material_override = material
    add_child(placement_preview)
    placement_preview.visible = false

func _can_place_on_grass(pos: Vector3, kind: String) -> bool:
    var radius: float = 1.08 if kind == "plot" else (float(DECOR_RADII[selected_decor]) if kind == "decor" else 1.60)
    if not is_finite(pos.x) or not is_finite(pos.z):
        return false
    if absf(pos.x) > WORLD_HALF - radius or absf(pos.z) > WORLD_HALF - radius:
        return false
    # A purchased object must fit wholly inside owned zones, not straddle a
    # locked parcel even when its center happens to be on player land.
    for dx in [-radius, radius]:
        for dz in [-radius, radius]:
            if not is_land_owned(Vector3(pos.x+dx, 0.0, pos.z+dz)):
                return false
    # No placement on the farm house, its paths, or current/future pig pens.
    if absf(pos.x + 19.0) < 2.35 + radius and absf(pos.z + 8.4) < 2.1 + radius:
        return false
    if absf(pos.x + 14.5) < 1.1 + radius and absf(pos.z) < 14.5 + radius:
        return false
    if absf(pos.z - 11.8) < 1.1 + radius and absf(pos.x) < 29.0 + radius:
        return false
    if absf(pos.x - 13.1) < 0.85 + radius and absf(pos.z) < 10.5 + radius:
        return false
    for pen_pos in pen_locations:
        if absf(pos.x - pen_pos.x) < 3.4 + radius and absf(pos.z - pen_pos.z) < 3.4 + radius:
            return false
    for existing in plot_places:
        if absf(pos.x - existing.x) < 1.06 + radius and absf(pos.z - existing.z) < 1.06 + radius:
            return false
    for node in base_tree_nodes:
        if node.visible and Vector2(pos.x - node.position.x, pos.z - node.position.z).length() < 1.35 + radius:
            return false
    for node in placed_tree_nodes:
        if is_instance_valid(node) and Vector2(pos.x - node.position.x, pos.z - node.position.z).length() < 1.35 + radius:
            return false
    for j in range(decor_nodes.size()):
        var decor_node: Node3D = decor_nodes[j]
        if not is_instance_valid(decor_node):
            continue
        var existing_type: int = int(placed_decor_data[j]["type"])
        var other_radius: float = float(DECOR_RADII[existing_type])
        if Vector2(pos.x - decor_node.position.x, pos.z - decor_node.position.z).length() < radius + other_radius:
            return false
    return true

func _ground_at(pixel: Vector2) -> Vector3:
    var origin: Vector3 = camera.project_ray_origin(pixel)
    var ray: Vector3 = camera.project_ray_normal(pixel)
    if absf(ray.y) < 0.001:
        return Vector3(9999.0, 0.0, 9999.0)
    var t: float = -origin.y / ray.y
    if t <= 0.0:
        return Vector3(9999.0, 0.0, 9999.0)
    var hit: Vector3 = origin + ray * t
    return Vector3(hit.x, 0.0, hit.z)

func _update_placement_preview(pixel: Vector2) -> void:
    if placement_preview == null:
        return
    placement_preview.visible = false
    if not landscaping_mode or not ["place_plot", "plant_tree", "place_decor", "buy_land"].has(tool_mode):
        return
    if shop_panel.visible or bag_panel.visible or (gm_panel != null and gm_panel.visible) or point_on_ui(pixel):
        return
    var place: Vector3 = _ground_at(pixel)
    var can_use: bool = false
    var radius: float = 1.0
    if tool_mode == "buy_land":
        var id: int = zone_for_position(place)
        if id < 0 or unlocked_zones.has(id):
            return
        var col: int = id % ZONE_COLUMNS
        var row: int = id / ZONE_COLUMNS
        place.x = -WORLD_HALF + (float(col)+0.5)*ZONE_SIZE
        place.z = -WORLD_HALF + (float(row)+0.5)*ZONE_SIZE
        radius = (ZONE_SIZE - 0.4) / 1.95
        can_use = zone_can_be_bought(id) and coins >= zone_price(id)
    else:
        var kind: String = "plot" if tool_mode == "place_plot" else ("decor" if tool_mode == "place_decor" else "tree")
        radius = 1.0 if kind == "plot" else (float(DECOR_RADII[selected_decor]) if kind == "decor" else 1.55)
        can_use = _can_place_on_grass(place, kind)
    placement_preview.position = place + Vector3(0,0.08,0)
    placement_preview.scale = Vector3(radius, 1.0, radius)
    var material: StandardMaterial3D = placement_preview.material_override as StandardMaterial3D
    material.albedo_color = Color(0.18, 0.84, 0.35, 0.40) if can_use else Color(0.96, 0.23, 0.17, 0.43)
    placement_preview.visible = true

func _place_new_plot(pos: Vector3) -> bool:
    if plot_kits <= 0:
        message = "ไม่มีชุดแปลงผัก ซื้อเพิ่มจากร้านค้าก่อน"
    elif extra_plot_nodes.size() >= MAX_EXTRA_PLOTS:
        message = "พื้นที่ปลูกเพิ่มถึงขีดจำกัดของเกมแล้ว"
    elif not _can_place_on_grass(pos, "plot"):
        message = "ตรงนี้วางแปลงไม่ได้ เลือกพื้นหญ้าว่างที่ไม่ทับสิ่งของ"
    else:
        _add_extra_plot(pos)
        plot_kits -= 1
        refresh_plants()
        message = "วางแปลงใหม่แล้ว! เลือกโหมดปลูกผักเพื่อใช้งาน"
        if farm_audio != null:
            farm_audio.play_effect("till")
        save_game()
        refresh_labels()
        return true
    refresh_labels()
    return false

func _plant_purchased_tree(pos: Vector3) -> bool:
    if int(tree_kits[selected_tree]) <= 0:
        message = "ต้นกล้า%sหมด ซื้อเพิ่มที่ร้านค้า" % TREE_NAMES[selected_tree]
    elif placed_tree_nodes.size() >= MAX_PLANTED_TREES:
        message = "จำนวนต้นไม้ที่ปลูกเต็มแล้ว"
    elif not _can_place_on_grass(pos, "tree"):
        message = "ตรงนี้ปลูกต้นไม้ไม่ได้ ต้องเป็นพื้นหญ้าที่ว่าง"
    else:
        var variant: String = str(TREE_VARIANTS[selected_tree])
        var yaw: float = float((placed_tree_nodes.size() * 67) % 360)
        placed_tree_nodes.append(tree(pos, variant, 4.8, yaw))
        placed_trees_data.append({
            "x": pos.x, "z": pos.z, "variant": variant, "rotation": yaw
        })
        tree_kits[selected_tree] = int(tree_kits[selected_tree]) - 1
        message = "ปลูกต้น%sแล้ว! เลือกพื้นที่ว่างเพื่อปลูกเพิ่ม" % TREE_NAMES[selected_tree]
        if farm_audio != null:
            farm_audio.play_effect("plant")
        save_game()
        refresh_labels()
        return true
    refresh_labels()
    return false


func _place_decoration(pos: Vector3) -> bool:
    if int(decor_kits[selected_decor]) <= 0:
        message = "ไม่มี%sในกระเป๋า ซื้อที่ร้านค้าก่อน" % DECOR_NAMES[selected_decor]
    elif placed_decor_data.size() >= MAX_DECORATIONS:
        message = "วางของตกแต่งครบจำนวนสูงสุดแล้ว"
    elif not _can_place_on_grass(pos, "decor"):
        message = "เลือกพื้นที่ปลดล็อกแล้วที่ว่าง ไม่ทับแปลง ต้นไม้ หรือสิ่งปลูกสร้าง"
    else:
        var facing: float = float((placed_decor_data.size()*53) % 360)
        decor_nodes.append(GARDEN_DECOR.make(self, pos, selected_decor, facing))
        placed_decor_data.append({
            "x": pos.x, "z": pos.z, "type": selected_decor, "rotation": facing
        })
        decor_kits[selected_decor] = int(decor_kits[selected_decor]) - 1
        message = "วาง%sแล้ว (เหลือ %d)" % [DECOR_NAMES[selected_decor], int(decor_kits[selected_decor])]
        if farm_audio != null:
            farm_audio.play_effect("plant")
        save_game()
        refresh_labels()
        return true
    refresh_labels()
    return false

func _chop_tree_at(pixel: Vector2) -> bool:
    var target_distance: float = 42.0
    var base_index: int = -1
    var planted_index: int = -1
    # Tree FBX scenes do not have physics colliders. Test the crown and trunk
    # in screen space so mouse/touch taps can select the visible model.
    for i in range(base_tree_nodes.size() + placed_tree_nodes.size()):
        var is_original: bool = i < base_tree_nodes.size()
        var index: int = i if is_original else i - base_tree_nodes.size()
        var node: Node3D = base_tree_nodes[index] if is_original else placed_tree_nodes[index]
        if not node.visible:
            continue
        for elevation in [1.0, 2.5, 3.8]:
            var world_pos: Vector3 = node.global_position + Vector3(0,elevation,0)
            if camera.is_position_behind(world_pos):
                continue
            var distance: float = pixel.distance_to(camera.unproject_position(world_pos))
            if distance < target_distance:
                target_distance = distance
                base_index = index if is_original else -1
                planted_index = index if not is_original else -1
    if base_index >= 0:
        base_tree_nodes[base_index].visible = false
        removed_trees.append(base_index)
    elif planted_index >= 0:
        var node: Node3D = placed_tree_nodes[planted_index]
        placed_tree_nodes.remove_at(planted_index)
        placed_trees_data.remove_at(planted_index)
        node.queue_free()
    else:
        message = "แตะที่ต้นไม้ที่ต้องการตัด"
        refresh_labels()
        return false
    wood += 1
    message = "ตัดต้นไม้สำเร็จ ได้ไม้ +1 (รวม %d)" % wood
    if farm_audio != null:
        farm_audio.play_effect("till")
    save_game()
    refresh_labels()
    return true

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

func required_farm_level(index: int) -> int:
    var place: int = PLOT_UNLOCK_ORDER.find(index)
    if place < 0:
        return MAX_FARM_LEVEL
    return mini(MAX_FARM_LEVEL, 1 + int(place / PLOTS_PER_LEVEL))

func is_plot_unlocked(index: int) -> bool:
    if index < 0 or index >= plots.size():
        return false
    # Player-purchased beds never inherit any lock from the original 50.
    if index >= FARM_COLUMNS * FARM_ROWS:
        return true
    if required_farm_level(index) <= farm_level:
        return true
    # Grandfather existing planted/tilled beds from saves made before levels
    # were introduced. An unused locked bed still cannot be tilled.
    return bool(plots[index].get("tilled", false)) or plots[index].has("crop")

func unlocked_plot_count() -> int:
    var total: int = 0
    for i in range(mini(plots.size(), FARM_COLUMNS * FARM_ROWS)):
        if is_plot_unlocked(i):
            total += 1
    return total

func xp_to_next_level() -> int:
    if farm_level >= MAX_FARM_LEVEL:
        return 0
    return 75 + 55 * (farm_level - 1)

func update_plot_locks() -> void:
    for i in range(plot_locks.size()):
        plot_locks[i].visible = not is_plot_unlocked(i)

func gain_farm_xp(amount: int) -> bool:
    if amount <= 0 or farm_level >= MAX_FARM_LEVEL:
        return false
    var old_level: int = farm_level
    farm_xp += amount
    while farm_level < MAX_FARM_LEVEL and farm_xp >= xp_to_next_level():
        farm_xp -= xp_to_next_level()
        farm_level += 1
    if farm_level >= MAX_FARM_LEVEL:
        farm_xp = 0
    if farm_level != old_level:
        update_plot_locks()
    return farm_level != old_level

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
    if not is_plot_unlocked(index):
        message = "แปลงนี้ต้องใช้ฟาร์ม Lv.%d (ปัจจุบัน Lv.%d)" % [required_farm_level(index), farm_level]
        refresh_labels()
        return
    var c: Dictionary = plots[index]
    if tool_mode == "till" and bool(c.get("tilled", false)):
        message = "พรวนดินแปลงนี้แล้ว"
        refresh_labels()
        return
    if tool_mode == "plant" and (c.has("crop") or int(seeds[selected_seed]) == 0):
        message = "แปลงเต็มหรือเมล็ดหมด"
        refresh_labels()
        return
    if tool_mode == "water" and not c.has("crop"):
        message = "ต้องปลูกผักก่อน"
        refresh_labels()
        return
    if tool_mode == "water" and bool(c.get("wet", false)):
        message = "แปลงนี้รดน้ำแล้ว รอผักเติบโต"
        refresh_labels()
        return
    if tool_mode == "harvest" and stage(index) < 5:
        message = "ผักยังไม่โตเต็มที่"
        refresh_labels()
        return
    work_plot = index
    if tool_mode == "plant" and farm_audio != null:
        farm_audio.announce("plant")
    actor_goal = plot_places[index] + Vector3(0,0,1.20)
    message = "ชาวสวนกำลังเดินไปแปลง"
    refresh_labels()

func finish_work() -> void:
    if work_plot < 0:
        return
    var i: int = work_plot
    var gained_xp: int = 0
    if tool_mode == "till":
        if not bool(plots[i].get("tilled", false)):
            gained_xp = 2
        plots[i]["tilled"] = true
        message = "พรวนดินเรียบร้อย"
    elif tool_mode == "plant":
        plots[i] = {"crop":selected_seed,"tilled":true,"wet":false,"water_time":0.0}
        seeds[selected_seed] = int(seeds[selected_seed])-1
        gained_xp = 8
        message = "ปลูกสำเร็จ กดรดน้ำแล้วแตะแปลงเดิม"
    elif tool_mode == "water":
        if not bool(plots[i].get("wet", false)):
            gained_xp = 4
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
        gained_xp = 25
        message = "เก็บเกี่ยวสำเร็จ ได้เหรียญเพิ่ม"
    if farm_audio != null:
        farm_audio.play_effect(tool_mode)
        if tool_mode == "plant":
            farm_audio.announce("water", true)
        elif tool_mode == "harvest":
            farm_audio.announce("harvest", true)
    work_plot = -1
    if gain_farm_xp(gained_xp):
        message = "ฟาร์ม Lv.%d! ปลดล็อกแปลงผักเพิ่ม 5 แปลง" % farm_level
    hoe.visible = false
    can.visible = false
    refresh_plants()
    refresh_labels()
    save_game()

func _focus_game_canvas() -> void:
    if OS.has_feature("web"):
        # Browser canvas must be focused before it receives keyboard events.
        JavaScriptBridge.eval("(()=>{let c=document.querySelector('canvas'); if(c){c.tabIndex=0; c.focus(); c.addEventListener('pointerdown',()=>c.focus());}})();", true)

func _keyboard_active(code: Key) -> bool:
    return bool(keyboard_held.get(code, false)) or Input.is_key_pressed(code) or Input.is_physical_key_pressed(code)

func keyboard_vector() -> Vector2:
    var x: float = float(_keyboard_active(KEY_D) or _keyboard_active(KEY_RIGHT)) - float(_keyboard_active(KEY_A) or _keyboard_active(KEY_LEFT))
    var y: float = float(_keyboard_active(KEY_S) or _keyboard_active(KEY_DOWN)) - float(_keyboard_active(KEY_W) or _keyboard_active(KEY_UP))
    return Vector2(x, y).limit_length(1.0)

func _process(delta: float) -> void:
    var previous_position: Vector3 = farmer.position
    elapsed += delta
    animate_pigs()
    prompt_timer += delta
    if prompt_timer >= 8.0:
        prompt_timer = 0.0
        _check_voice_context()
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
        var input_dir: Vector2 = keyboard_vector()
        if _camera_overlay_at(Vector2.ZERO):
            # A modal popup should not let the character walk in the background.
            input_dir = Vector2.ZERO
        if stick != null and stick.visible and stick.direction.length() > 0.055:
            input_dir = stick.direction
        running = _keyboard_active(KEY_SHIFT) or run_toggle
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
    if farmer.position.distance_to(previous_position) > 0.01:
        footstep_timer -= delta
        if footstep_timer <= 0.0 and farm_audio != null:
            farm_audio.play_effect("step")
            footstep_timer = 0.29 if running else 0.46
    else:
        footstep_timer = minf(footstep_timer, 0.15)
    # Follow after every movement source, at every zoom distance.
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
    var desired: Vector3 = farmer.position + direction*speed*delta
    desired.x = clampf(desired.x, -WORLD_HALF+0.6, WORLD_HALF-0.6)
    desired.z = clampf(desired.z, -WORLD_HALF+0.6, WORLD_HALF-0.6)
    if is_land_owned(desired):
        farmer.position.x = desired.x
        farmer.position.z = desired.z
    else:
        # Slide along the purchased area's border instead of walking into
        # unowned land. Crossing the edge becomes possible after purchase.
        var slide_x: Vector3 = Vector3(desired.x, 0, farmer.position.z)
        var slide_z: Vector3 = Vector3(farmer.position.x, 0, desired.z)
        if is_land_owned(slide_x):
            farmer.position.x = desired.x
        if is_land_owned(slide_z):
            farmer.position.z = desired.z
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
        if farm_audio != null:
            farm_audio.play_effect("jump")

func zoom_in() -> void:
    set_camera_zoom(camera_distance * 0.72)

func zoom_out() -> void:
    set_camera_zoom(camera_distance * 1.35)

func set_camera_zoom(target_distance: float) -> void:
    # Orthographic projection changes size too, so this must change both.
    if not is_finite(target_distance):
        return
    camera_distance = clampf(target_distance, CAMERA_ZOOM_MIN, CAMERA_ZOOM_MAX)
    update_camera()

func _camera_overlay_at(pos: Vector2) -> bool:
    return (shop_panel != null and shop_panel.visible
        or restore_confirm != null and restore_confirm.visible
        or land_confirm != null and land_confirm.visible
        or gm_panel != null and gm_panel.visible
        or bag_panel != null and bag_panel.visible and bag_panel.get_global_rect().has_point(pos))

func _camera_action_at(pos: Vector2) -> Button:
    if _camera_overlay_at(pos):
        return null
    for button: Button in [run_button, jump_button, zoom_in_button, zoom_out_button]:
        if button != null and button.is_visible_in_tree() and not button.disabled and button.get_global_rect().has_point(pos):
            return button
    return null

func _joystick_at(pos: Vector2) -> bool:
    return stick != null and stick.is_visible_in_tree() and not _camera_overlay_at(pos) and stick.get_global_rect().has_point(pos)

func _control_touch(event: InputEventScreenTouch) -> bool:
    # Ownership is decided at touch-down, never by the finger's drag position.
    if event.pressed and not event.canceled:
        if _joystick_at(event.position):
            stick._input(event)
            return true
        var button: Button = _camera_action_at(event.position)
        if button != null:
            if not touch_button_fingers.values().has(button):
                touch_button_fingers[event.index] = button
                button.modulate = Color(0.8, 0.8, 0.8)
            return true
    elif stick != null and event.index == stick.finger_id:
        stick._input(event)
        return true
    elif touch_button_fingers.has(event.index):
        var button: Button = touch_button_fingers[event.index]
        touch_button_fingers.erase(event.index)
        button.modulate = Color.WHITE
        if not event.canceled and _camera_action_at(event.position) == button:
            button.pressed.emit()
        return true
    return false

func _control_drag(event: InputEventScreenDrag) -> bool:
    if stick != null and event.index == stick.finger_id:
        stick._input(event)
        return true
    if touch_button_fingers.has(event.index):
        var button: Button = touch_button_fingers[event.index]
        button.modulate = Color(0.8, 0.8, 0.8) if _camera_action_at(event.position) == button else Color.WHITE
        return true
    return false

func _reset_camera_input() -> void:
    camera_touches.clear()
    touch_cam = -1
    pinch_last_gap = 0.0
    pinch_was_active = false
    cam_dragged = false
    drag_camera = false
    block_touch_mouse = true
    for button: Button in touch_button_fingers.values():
        button.modulate = Color.WHITE
    touch_button_fingers.clear()
    if stick != null:
        stick.reset_input()

func _notification(what: int) -> void:
    if what == NOTIFICATION_WM_WINDOW_FOCUS_OUT or what == NOTIFICATION_APPLICATION_FOCUS_OUT or what == NOTIFICATION_APPLICATION_PAUSED:
        _reset_camera_input()
        keyboard_held.clear()

func _camera_touch_gap() -> float:
    if camera_touches.size() < 2:
        return 0.0
    var positions: Array = camera_touches.values()
    var left: Vector2 = positions[0]
    var right: Vector2 = positions[1]
    return left.distance_to(right)

func _camera_touch(event: InputEventScreenTouch) -> void:
    if event.pressed and not event.canceled:
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
        var tap_plot: bool = (not event.canceled and not pinch_was_active and not cam_dragged
            and camera_touches.size() == 1 and not point_on_ui(event.position)
            and event.position.distance_to(touch_down) <= CAMERA_TAP_SLOP)
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
        if pinch_last_gap > CAMERA_PINCH_MIN_GAP and gap > CAMERA_PINCH_MIN_GAP:
            set_camera_zoom(camera_distance * pinch_last_gap / gap)
        pinch_last_gap = gap
        pinch_was_active = true
        cam_dragged = true
        return
    if event.index != touch_cam:
        return
    var delta_screen: Vector2 = event.position - touch_last
    touch_last = event.position
    if event.position.distance_to(touch_down) > CAMERA_TAP_SLOP:
        cam_dragged = true
    if cam_dragged:
        camera_yaw -= delta_screen.x * 0.006
        camera_pitch = clampf(camera_pitch + delta_screen.y * 0.005, -1.33, -0.28)
        update_camera()

func _input(event: InputEvent) -> void:
    if event is InputEventKey:
        var physical: Key = event.physical_keycode
        var logical: Key = event.keycode
        for code in [physical, logical]:
            if code in [KEY_W, KEY_A, KEY_S, KEY_D, KEY_UP, KEY_LEFT, KEY_DOWN, KEY_RIGHT, KEY_SHIFT]:
                if event.pressed:
                    keyboard_held[code] = true
                else:
                    keyboard_held.erase(code)
    if farm_audio != null and not farm_audio.unlocked:
        var is_first_gesture: bool = (
            (event is InputEventKey and event.pressed)
            or (event is InputEventScreenTouch and event.pressed)
            or (event is InputEventMouseButton and event.pressed)
        )
        if is_first_gesture:
            farm_audio.activate()
            refresh_sound_button()
    if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_SPACE:
        jump()
    if event is InputEventMouse and event.device == InputEvent.DEVICE_ID_EMULATION:
        # Native shop/inventory GUI still receives its emulated mouse. World,
        # joystick and action touches are handled exactly once as raw touches.
        if event is InputEventMouseButton and event.pressed:
            block_touch_mouse = not point_on_ui(event.position) or _joystick_at(event.position) or _camera_action_at(event.position) != null
        if block_touch_mouse:
            get_viewport().set_input_as_handled()
        return
    if event is InputEventScreenTouch:
        if _control_touch(event):
            get_viewport().set_input_as_handled()
            return
        var owned: bool = camera_touches.has(event.index)
        _camera_touch(event)
        if owned or camera_touches.has(event.index):
            get_viewport().set_input_as_handled()
    elif event is InputEventScreenDrag:
        if _control_drag(event):
            get_viewport().set_input_as_handled()
        elif camera_touches.has(event.index):
            _camera_drag(event)
            get_viewport().set_input_as_handled()
    elif event is InputEventMouseButton:
        if event.button_index == MOUSE_BUTTON_LEFT and (stick.mouse_drag or event.pressed and _joystick_at(event.position)):
            stick._input(event)
            return
        if event.button_index == MOUSE_BUTTON_RIGHT:
            drag_camera = event.pressed
        elif event.pressed and event.button_index == MOUSE_BUTTON_WHEEL_UP:
            set_camera_zoom(camera_distance * 0.87)
        elif event.pressed and event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
            set_camera_zoom(camera_distance * 1.15)
        elif event.pressed and event.button_index == MOUSE_BUTTON_LEFT and not point_on_ui(event.position) and camera_touches.is_empty():
            click_plot(event.position)
    elif event is InputEventMouseMotion:
        if stick.mouse_drag:
            stick._input(event)
        elif drag_camera:
            camera_yaw -= event.relative.x * 0.007
            camera_pitch = clampf(camera_pitch + event.relative.y * 0.005, -1.33, -0.28)
            update_camera()
        else:
            _update_placement_preview(event.position)

func click_plot(pixel: Vector2) -> void:
    if shop_panel.visible or (gm_panel != null and gm_panel.visible) or (land_confirm != null and land_confirm.visible):
        return
    if landscaping_mode:
        if bag_panel.visible:
            return
        if tool_mode == "place_plot":
            _place_new_plot(_ground_at(pixel))
        elif tool_mode == "plant_tree":
            _plant_purchased_tree(_ground_at(pixel))
        elif tool_mode == "chop_tree":
            _chop_tree_at(pixel)
        elif tool_mode == "place_decor":
            _place_decoration(_ground_at(pixel))
        elif tool_mode == "buy_land":
            _request_land_purchase(_ground_at(pixel))
        _update_placement_preview(pixel)
        return
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
    # Orbit around the farmer at every zoom, with a steady ground-height
    # focus so jumping and the walking bob do not shake the camera.
    camera_focus = CENTER
    if farmer != null:
        camera_focus = Vector3(farmer.position.x, 1.0, farmer.position.z)
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
    label.add_theme_font_size_override("font_size", maxi(font_size, 16))
    label.add_theme_color_override("font_color", color)
    # Thai glyphs stay crisp against either the light inventory or dark PNG HUD.
    var light_text: bool = color.get_luminance() > 0.57
    label.add_theme_color_override("font_outline_color",
        Color(0.09, 0.15, 0.10, 0.96) if light_text else Color(0.98, 0.99, 0.94, 0.94))
    label.add_theme_constant_override("outline_size", 2 if light_text else 1)
    label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
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
    b.add_theme_font_size_override("font_size", 17)
    b.add_theme_color_override("font_color", Color.WHITE)
    b.alignment = HORIZONTAL_ALIGNMENT_CENTER
    b.clip_text = true
    # Nine-slice the original standalone button PNG; no screenshot cropping.
    # This keeps the glossy edges intact at desktop and mobile dimensions.
    var style: StyleBoxTexture = StyleBoxTexture.new()
    style.texture = UI_BUTTON
    # Keep the rendered 640x213 PNG as art, while reducing nine-slice
    # margins so mobile buttons and +/- camera controls stay 34-52px tall.
    style.texture_margin_left = 8.0
    style.texture_margin_right = 8.0
    style.texture_margin_top = 4.0
    style.texture_margin_bottom = 4.0
    style.content_margin_left = 0.0
    style.content_margin_right = 0.0
    style.content_margin_top = 0.0
    style.content_margin_bottom = 0.0
    style.modulate_color = Color.WHITE
    b.add_theme_stylebox_override("normal", style)
    var hover: StyleBoxTexture = style.duplicate()
    hover.modulate_color = Color(1.13, 1.13, 1.07, 1.0)
    b.add_theme_stylebox_override("hover", hover)
    var down: StyleBoxTexture = style.duplicate()
    down.modulate_color = Color("#b4ceaa")
    b.add_theme_stylebox_override("pressed", down)
    b.add_theme_stylebox_override("disabled", down)
    b.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
    b.add_theme_color_override("font_color", Color("#fffce4"))
    b.add_theme_color_override("font_hover_color", Color.WHITE)
    b.add_theme_color_override("font_pressed_color", Color("#fff8d1"))
    b.add_theme_color_override("font_disabled_color", Color("#d1d2bc"))
    b.add_theme_color_override("font_outline_color", Color(0.03, 0.13, 0.07, 0.98))
    b.add_theme_constant_override("outline_size", 3)
    b.add_theme_constant_override("h_separation", 6)
    b.pressed.connect(callback)
    return b

func _skin_window(p: Panel) -> void:
    var frame: StyleBoxTexture = StyleBoxTexture.new()
    frame.texture = UI_WINDOW
    frame.texture_margin_left = 28.0
    frame.texture_margin_right = 28.0
    frame.texture_margin_top = 24.0
    frame.texture_margin_bottom = 28.0
    p.add_theme_stylebox_override("panel", frame)

func _skin_hud(p: Panel) -> void:
    var frame: StyleBoxTexture = StyleBoxTexture.new()
    frame.texture = UI_HUD
    frame.texture_margin_left = 24.0
    frame.texture_margin_right = 24.0
    frame.texture_margin_top = 18.0
    frame.texture_margin_bottom = 18.0
    p.add_theme_stylebox_override("panel", frame)

func _header_layer(parent: Control) -> TextureRect:
    var art: TextureRect = TextureRect.new()
    art.texture = UI_HEADER
    art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
    art.stretch_mode = TextureRect.STRETCH_SCALE
    art.mouse_filter = Control.MOUSE_FILTER_IGNORE
    parent.add_child(art)
    return art

func _set_icon(button: Button, name: String) -> void:
    if button == null:
        return
    var asset: String = "res://assets/ui/happy/icon_%s.png" % name
    if ResourceLoader.exists(asset):
        button.icon = load(asset) as Texture2D
        button.icon_alignment = HORIZONTAL_ALIGNMENT_LEFT
        button.expand_icon = true
        button.add_theme_constant_override("icon_max_width", 24)
        button.set_meta("happy_icon_texture", button.icon)

# Dynamically size actual Thai glyphs to the *rendered* button width.
# Keep the original texture in metadata so icons can return after resize.
func _fit_button_caption(button: Button) -> void:
    if button == null or button.text.is_empty():
        return
    var width: float = maxf(button.size.x, button.custom_minimum_size.x)
    var height: float = maxf(button.size.y, button.custom_minimum_size.y)
    if width < 45.0 or height < 22.0:
        return
    var preferred: int = 20 if height >= 48.0 else (18 if height >= 34.0 else 16)
    var min_size: int = 12 if width < 115.0 else 13
    var original_icon: Texture2D = null
    if button.has_meta("happy_icon_texture"):
        original_icon = button.get_meta("happy_icon_texture") as Texture2D
    var icon_width: int = mini(24, maxi(16, int(height * 0.43)))
    var free_space: float = width - 24.0
    var first_line: String = button.text.replace("\n", " ")
    var preferred_text_width: float = THAI_BOLD.get_string_size(first_line,
        HORIZONTAL_ALIGNMENT_LEFT, -1.0, preferred).x
    # Prioritize complete readable words over decoration on small controls.
    var show_icon: bool = original_icon != null and width >= 140.0 and (
        preferred_text_width + float(icon_width) + 12.0 <= free_space)
    button.icon = original_icon if show_icon else null
    if show_icon:
        free_space -= float(icon_width) + 8.0
    button.add_theme_constant_override("icon_max_width", icon_width)
    var font_size: int = preferred
    while font_size > min_size:
        if THAI_BOLD.get_string_size(first_line,
            HORIZONTAL_ALIGNMENT_LEFT, -1.0, font_size).x <= free_space:
            break
        font_size -= 1
    button.add_theme_font_size_override("font_size", font_size)

func _fit_title_caption(label: Label, preferred: int, minimum: int = 15) -> void:
    if label == null or label.text.is_empty() or label.size.x < 35.0:
        return
    var font: Font = label.get_theme_font("font")
    var max_width: float = label.size.x - 6.0
    var font_size: int = preferred
    while font_size > minimum:
        if font.get_string_size(label.text, HORIZONTAL_ALIGNMENT_LEFT,
            -1.0, font_size).x <= max_width:
            break
        font_size -= 1
    label.add_theme_font_size_override("font_size", font_size)

func _fit_descendant_buttons(node: Node) -> void:
    for child in node.get_children():
        if child is Button:
            _fit_button_caption(child as Button)
        _fit_descendant_buttons(child)

func _fit_all_ui_text() -> void:
    if ui == null:
        return
    _fit_descendant_buttons(ui)
    _fit_title_caption(shop_heading, 21, 15)
    _fit_title_caption(bag_heading, 23, 17)
    _fit_title_caption(gm_title, 19, 15)
    _fit_title_caption(title_label, 20, 16)
    _fit_title_caption(money_label, 17, 14)
    _fit_title_caption(shop_livestock_label, 16, 14)

func panel(color: Color) -> Panel:
    # Panel (not PanelContainer) never enlarges itself to fit its children.
    var p: Panel = Panel.new()
    var style: StyleBoxFlat = StyleBoxFlat.new()
    style.bg_color = color
    style.set_corner_radius_all(18)
    style.set_content_margin_all(0)
    style.shadow_color = Color(0.07, 0.16, 0.12, 0.32)
    style.shadow_size = 10
    style.shadow_offset = Vector2(0, 5)
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
    bag_button = btn("กระเป๋า", show_bag, Color("#426d55"))
    ui_top.add_child(bag_button)
    # The bag button now uses its own imported transparent PNG icon layer.
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
    _skin_hud(ui_bottom)
    ui.add_child(ui_bottom)
    status_label = text_label("", 16, Color("#ffffff"))
    status_label.add_theme_font_override("font", THAI_BOLD)
    status_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    status_label.clip_text = false
    status_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
    ui_bottom.add_child(status_label)
    farm_level_label = text_label("", 16, Color("#ffedb2"))
    farm_level_label.add_theme_font_override("font", THAI_BOLD)
    ui_bottom.add_child(farm_level_label)
    active_seed_label = text_label("", 17, Color("#ffffff"))
    active_seed_label.add_theme_font_override("font", THAI_BOLD)
    ui_bottom.add_child(active_seed_label)
    change_seed_button = btn("เลือกเมล็ด", show_bag, Color("#6a946f"))
    ui_bottom.add_child(change_seed_button)
    landscape_shop_button = btn("เปิดร้านค้า", show_shop, Color("#987849"))
    ui_bottom.add_child(landscape_shop_button)
    landscape_button = btn("จัดสวน", toggle_landscaping, Color("#638d72"))
    ui_bottom.add_child(landscape_button)
    for pair in [["till","พรวนดิน"],["plant","ปลูกผัก"],["water","รดน้ำ"],["harvest","เก็บเกี่ยว"],
        ["place_plot","แปลง"],["plant_tree","ต้นไม้"],["chop_tree","ตัดไม้"],
        ["place_decor","ของแต่ง"],["buy_land","ซื้อที่ดิน"]]:
        var key: String = str(pair[0])
        var button: Button = btn(str(pair[1]), pick_tool.bind(key), Color("#468566") if key != "water" else Color("#4d95ac"))
        ui_bottom.add_child(button)
        action_buttons[key] = button

    # Always-visible browser joystick: mouse drag on PC or finger drag on phone.
    stick = JOYSTICK.new()
    ui.add_child(stick)
    # Game routes owned fingers and real mouse events to this control so
    # sibling _input ordering cannot steal a camera/UI finger.
    stick.set_process_input(false)
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
    _skin_window(shop_panel)
    ui.add_child(shop_panel)
    shop_panel.visible = false
    shop_header_art = _header_layer(shop_panel)
    shop_heading = text_label("ร้านฟาร์ม • ของตกแต่ง • สัตว์เลี้ยง", 21, Color("#fff2c6"))
    shop_heading.add_theme_font_override("font", THAI_BOLD)
    shop_panel.add_child(shop_heading)
    shop_close = btn("ปิด", show_shop, Color("#73817a"))
    shop_panel.add_child(shop_close)
    shop_livestock_label = text_label("", 17, Color("#fff0c2"))
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
    shop_plot_button = btn("ชุดแปลงปลูก 75 เหรียญ", buy_plot_kit, Color("#5d9d75"))
    shop_plot_button.custom_minimum_size = Vector2(145, 40)
    shop_plot_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    shop_grid.add_child(shop_plot_button)
    for i in range(TREE_VARIANTS.size()):
        var tree_buy: Button = btn("ต้น%s %d เหรียญ" % [TREE_NAMES[i], TREE_PRICES[i]], buy_tree_kit.bind(i), Color("#568768"))
        tree_buy.custom_minimum_size = Vector2(145, 40)
        tree_buy.size_flags_horizontal = Control.SIZE_EXPAND_FILL
        shop_grid.add_child(tree_buy)
        shop_tree_buttons.append(tree_buy)
    for i in range(DECOR_NAMES.size()):
        var decor_buy: Button = btn("%s %d เหรียญ" % [DECOR_NAMES[i], DECOR_PRICES[i]], buy_decor_kit.bind(i), Color("#7e9070"))
        decor_buy.custom_minimum_size = Vector2(145, 40)
        decor_buy.size_flags_horizontal = Control.SIZE_EXPAND_FILL
        shop_grid.add_child(decor_buy)
        shop_decor_buttons.append(decor_buy)
    shop_feed = btn("ซื้ออาหารหมู +5 (35 เหรียญ)", buy_feed, Color("#ad7c53"))
    shop_panel.add_child(shop_feed)
    shop_pen_button = btn("ขยายคอกหมู", buy_pen, Color("#7c985d"))
    shop_panel.add_child(shop_pen_button)
    shop_pig_button = btn("ซื้อลูกหมู", buy_pig, Color("#bb7c91"))
    shop_panel.add_child(shop_pig_button)

    # Dedicated seed inventory in the left-side area shown in the reference.
    # The panel is a fixed-size Panel, not a PanelContainer; it cannot grow.
    bag_panel = panel(Color("#ecf1e6fb"))
    _skin_window(bag_panel)
    ui.add_child(bag_panel)
    bag_panel.visible = false
    bag_header_art = _header_layer(bag_panel)
    bag_header = ColorRect.new()
    bag_header.color = Color.TRANSPARENT
    bag_header.mouse_filter = Control.MOUSE_FILTER_IGNORE
    bag_panel.add_child(bag_header)
    bag_heading = text_label("กระเป๋าเมล็ดพันธุ์", 23, Color("#ffffff"))
    bag_heading.add_theme_font_override("font", THAI_BOLD)
    bag_panel.add_child(bag_heading)
    bag_close = btn("ปิด", show_bag, Color("#d4a16b"))
    bag_panel.add_child(bag_close)
    bag_summary = text_label("", 17, Color("#ffffff"))
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
    bag_footer = text_label("แตะซองเมล็ดเพื่อเลือกไปปลูก", 16, Color("#ffffff"))
    bag_panel.add_child(bag_footer)
    bag_save_status = text_label("เซฟเก็บอยู่ในเบราว์เซอร์เครื่องนี้", 16, Color("#ffe4a6"))
    bag_panel.add_child(bag_save_status)
    bag_export_button = btn("ดาวน์โหลดเซฟ", export_save_backup, Color("#397e62"))
    bag_panel.add_child(bag_export_button)
    bag_import_button = btn("นำเข้าเซฟ", request_import_backup, Color("#ab8054"))
    bag_panel.add_child(bag_import_button)

    # Optional GM testing controls are disabled entirely before release.
    gm_button = btn("GM TEST", toggle_gm_panel, Color("#98624a"))
    gm_button.visible = GM_TEST_MODE
    ui.add_child(gm_button)
    gm_panel = panel(Color("#eff4e9f9"))
    _skin_window(gm_panel)
    gm_panel.visible = false
    ui.add_child(gm_panel)
    gm_header_art = _header_layer(gm_panel)
    gm_title = text_label("GM ทดสอบ — เติมเหรียญจำลอง", 19, Color("#fff2c6"))
    gm_title.add_theme_font_override("font", THAI_BOLD)
    gm_panel.add_child(gm_title)
    var gm_close: Button = btn("ปิด", toggle_gm_panel, Color("#7c8880"))
    gm_close.name = "GMClose"
    gm_panel.add_child(gm_close)
    for entry in [[1000, "+1,000 เหรียญ"],[10000, "+10,000 เหรียญ"],[100000, "+100,000 เหรียญ"]]:
        var amount: int = int(entry[0])
        var add_coins: Button = btn(str(entry[1]), gm_grant_coins.bind(amount), Color("#4f9b70"))
        add_coins.name = "Add%d" % amount
        gm_panel.add_child(add_coins)

    land_confirm = ConfirmationDialog.new()
    land_confirm.title = "ยืนยันซื้อที่ดิน"
    land_confirm.dialog_text = "ซื้อโซนขนาด 40×40 ด้วยเหรียญในเกม"
    land_confirm.ok_button_text = "ซื้อพื้นที่"
    land_confirm.cancel_button_text = "ยกเลิก"
    land_confirm.confirmed.connect(_confirm_land_purchase)
    ui.add_child(land_confirm)

    restore_confirm = ConfirmationDialog.new()
    restore_confirm.title = "ยืนยันนำเข้าเซฟ"
    restore_confirm.dialog_text = "ข้อมูลปัจจุบันในเบราว์เซอร์จะถูกแทนที่"
    restore_confirm.ok_button_text = "นำเข้าเซฟ"
    restore_confirm.cancel_button_text = "ยกเลิก"
    restore_confirm.confirmed.connect(_confirm_import_backup)
    ui.add_child(restore_confirm)
    shop_panel.visibility_changed.connect(_reset_camera_input)
    bag_panel.visibility_changed.connect(_reset_camera_input)
    restore_confirm.visibility_changed.connect(_reset_camera_input)
    land_confirm.visibility_changed.connect(_reset_camera_input)
    gm_panel.visibility_changed.connect(_reset_camera_input)

    # PNG glyphs stay separate from PNG button bases and live labels.
    for entry in [
        [shop_button, "shop"], [bag_button, "bag"], [landscape_button, "tools"],
        [landscape_shop_button, "shop"], [change_seed_button, "farm"],
        [gm_button, "gm"], [feed_button, "farm"], [run_button, "run"],
        [jump_button, "jump"], [audio_button, "sound"],
        [shop_plot_button, "plot"], [shop_feed, "farm"], [shop_pen_button, "farm"],
        [shop_pig_button, "farm"], [bag_close, "close"], [shop_close, "close"],
        [bag_export_button, "bag"], [bag_import_button, "bag"]
    ]:
        _set_icon(entry[0] as Button, str(entry[1]))
    for key in action_buttons.keys():
        var art_name: String = {
            "till":"tools", "plant":"plant", "water":"water", "harvest":"harvest",
            "place_plot":"plot", "plant_tree":"tree", "chop_tree":"axe",
            "place_decor":"decorate", "buy_land":"land"
        }.get(str(key), "farm")
        _set_icon(action_buttons[key] as Button, art_name)
    for button in shop_tree_buttons:
        _set_icon(button, "tree")
    for button in shop_decor_buttons:
        _set_icon(button, "decorate")

    update_sizes()
    pick_tool("plant")
    refresh_sound_button()

func update_sizes() -> void:
    if ui_top == null:
        return
    # Rotation/resizing changes viewport coordinates: cancel old gestures.
    _reset_camera_input()
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
    var toolbar_y: float = h-208.0
    if touch_controls:
        # In landscape, reserve both side rails for joystick and buttons.
        # In portrait, place the farming toolbar above the bottom controls.
        if w >= 700.0:
            toolbar_width = minf(570.0, w-340.0)
        else:
            toolbar_width = w-18.0
            toolbar_y = h-365.0
    var toolbar_x: float = (w-toolbar_width)*0.5
    set_box(ui_bottom, toolbar_x, toolbar_y, toolbar_width, 198.0)
    set_box(status_label, 15, 7, toolbar_width-30.0, 42.0)
    set_box(farm_level_label, 15, 51, toolbar_width-164.0, 27.0)
    set_box(landscape_button, toolbar_width-147.0, 48.0, 131.0, 34.0)
    set_box(active_seed_label, 15, 80, toolbar_width-170.0, 30.0)
    set_box(change_seed_button, toolbar_width-150.0, 80.0, 134.0, 34.0)
    set_box(landscape_shop_button, toolbar_width-150.0, 80.0, 134.0, 34.0)
    var gap: float = 6.0
    var tool_button_w: float = (toolbar_width-24.0-3.0*gap)*0.25
    var keys: Array[String] = ["till", "plant", "water", "harvest"]
    for i in range(4):
        set_box(action_buttons[keys[i]], 12.0+float(i)*(tool_button_w+gap), 129.0, tool_button_w, 50.0)
    var garden_keys: Array[String] = ["place_plot", "plant_tree", "chop_tree", "place_decor", "buy_land"]
    # Two generous rows prevent Thai labels from being squeezed into five
    # narrow buttons when decorating on a mobile or a desktop.
    var landscape_w: float = (toolbar_width-24.0-2.0*gap)/3.0
    for i in range(garden_keys.size()):
        var garden_button: Button = action_buttons[garden_keys[i]]
        var col: int = i if i < 3 else i-3
        var row: int = 0 if i < 3 else 1
        var offset: float = 0.0 if row == 0 else (landscape_w+gap)*0.5
        set_box(garden_button, 12.0+offset+float(col)*(landscape_w+gap),
            115.0+float(row)*37.0, landscape_w, 34.0)

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
    var shop_h: float = minf(h-24.0, 560.0)
    set_box(shop_panel, (w-shop_w)*0.5, (h-shop_h)*0.5, shop_w, shop_h)
    set_box(shop_header_art, 7, 3, shop_w-14, 57)
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
    if GM_TEST_MODE:
        set_box(gm_button, w-125.0, badge_y+41.0, 113.0, 34.0)
    var gm_width: float = minf(w-24.0, 365.0)
    var gm_height: float = minf(h-24.0, 258.0)
    set_box(gm_panel, (w-gm_width)*0.5, (h-gm_height)*0.5, gm_width, gm_height)
    set_box(gm_header_art, 7, 3, gm_width-14.0, 54.0)
    set_box(gm_title, 14.0, 12.0, gm_width-108.0, 34.0)
    set_box(gm_panel.get_node("GMClose"), gm_width-83.0, 9.0, 73.0, 37.0)
    set_box(gm_panel.get_node("Add1000"), 13.0, 60.0, gm_width-26.0, 50.0)
    set_box(gm_panel.get_node("Add10000"), 13.0, 119.0, gm_width-26.0, 50.0)
    set_box(gm_panel.get_node("Add100000"), 13.0, 178.0, gm_width-26.0, 50.0)
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
    set_box(bag_header_art, 7, 2, bag_width-14.0, 62)
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
    _fit_all_ui_text()
    update_camera()
func point_on_ui(pos: Vector2) -> bool:
    if _camera_overlay_at(pos):
        return true
    for panel_node in [ui_top,ui_bottom,save_chip,stick_label,voice_caption]:
        if panel_node != null and panel_node.is_visible_in_tree() and panel_node.get_global_rect().has_point(pos):
            return true
    if GM_TEST_MODE and gm_button != null and gm_button.visible and gm_button.get_global_rect().has_point(pos):
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
    voice_caption_tween.tween_callback(_hide_voice_caption)

func _hide_voice_caption() -> void:
    voice_caption.visible = false

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
        if not is_plot_unlocked(i):
            continue
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
    if farm_level >= MAX_FARM_LEVEL:
        farm_level_label.text = "ฟาร์ม Lv.10 MAX" if get_viewport().get_visible_rect().size.x < 700.0 else "Lv.10 MAX | ที่ดิน %d/100" % unlocked_zones.size()
    elif get_viewport().get_visible_rect().size.x < 700.0:
        farm_level_label.text = "Lv.%d %d/%d | ที่ดิน %d" % [farm_level, farm_xp, xp_to_next_level(), unlocked_zones.size()]
    else:
        farm_level_label.text = "Lv.%d EXP %d/%d | แปลง %d/50 | ที่ดิน %d/100" % [
            farm_level, farm_xp, xp_to_next_level(), unlocked_plot_count(), unlocked_zones.size()
        ]
    if not landscaping_mode:
        active_seed_label.text = "เมล็ด: %s ×%d" % [CROPS[selected_seed]["name"], int(seeds[selected_seed])]
    elif tool_mode == "place_plot":
        active_seed_label.text = "ชุดแปลง: %d" % plot_kits
    elif tool_mode == "plant_tree":
        active_seed_label.text = "ต้น%s ×%d" % [TREE_NAMES[selected_tree], int(tree_kits[selected_tree])]
    elif tool_mode == "place_decor":
        active_seed_label.text = "%s ×%d" % [DECOR_NAMES[selected_decor], int(decor_kits[selected_decor])]
    elif tool_mode == "buy_land":
        active_seed_label.text = "ที่ดิน %d/100 โซน" % unlocked_zones.size()
    else:
        active_seed_label.text = "ไม้ %d" % wood
    if landscape_button != null:
        landscape_button.text = "กลับทำฟาร์ม" if landscaping_mode else "จัดสวน"
        change_seed_button.visible = not landscaping_mode
        landscape_shop_button.visible = landscaping_mode
    _refresh_save_indicator()
    refresh_bag_cards()
    for key in action_buttons.keys():
        var is_garden: bool = ["place_plot", "plant_tree", "chop_tree", "place_decor", "buy_land"].has(str(key))
        action_buttons[key].visible = is_garden == landscaping_mode
        action_buttons[key].modulate = Color.WHITE if key == tool_mode else Color("#d7e0d2")
    _fit_all_ui_text()

func refresh_bag_cards() -> void:
    if bag_summary == null:
        return
    var total: int = 0
    for i in range(seeds.size()):
        total += int(seeds[i])
    bag_summary.text = "เมล็ดพันธุ์ %d ชนิด | รวม %d ซอง" % [CROPS.size(), total]
    var tree_total: int = 0
    for stock in tree_kits:
        tree_total += int(stock)
    var decor_total: int = 0
    for stock in decor_kits:
        decor_total += int(stock)
    bag_footer.text = "แปลง %d | ต้น %d | ของแต่ง %d | ไม้ %d" % [plot_kits, tree_total, decor_total, wood]
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

func toggle_landscaping() -> void:
    if work_plot >= 0 or work_time > 0.0:
        message = "รอทำแปลงปัจจุบันให้เสร็จก่อน"
        refresh_labels()
        return
    landscaping_mode = not landscaping_mode
    tool_mode = "place_plot" if landscaping_mode else "plant"
    message = "เลือกวางแปลงบนพื้นหญ้าว่าง ไม่ต้องใช้เลเวล" if landscaping_mode else "แตะแปลงผักเพื่อทำฟาร์ม"
    if placement_preview != null:
        placement_preview.visible = false
    refresh_labels()

func pick_tool(key: String) -> void:
    if work_plot >= 0 or work_time > 0.0:
        message = "รอชาวสวนทำแปลงปัจจุบันให้เสร็จก่อน"
        refresh_labels()
        return
    if key == "plant_tree" and tool_mode == "plant_tree" and landscaping_mode:
        selected_tree = (selected_tree + 1) % TREE_VARIANTS.size()
    if key == "place_decor" and tool_mode == "place_decor" and landscaping_mode:
        for offset in range(1, DECOR_NAMES.size()+1):
            var next: int = (selected_decor + offset) % DECOR_NAMES.size()
            if int(decor_kits[next]) > 0:
                selected_decor = next
                break
    tool_mode = key
    landscaping_mode = ["place_plot", "plant_tree", "chop_tree", "place_decor", "buy_land"].has(key)
    if key == "place_plot":
        message = "แตะพื้นหญ้าที่ว่างเพื่อวางแปลง (มี %d ชุด)" % plot_kits
    elif key == "plant_tree":
        message = "เลือกต้น%s (%d ต้น) แล้วแตะพื้นที่ว่าง | กดปุ่มซ้ำเพื่อเปลี่ยนชนิด" % [TREE_NAMES[selected_tree], int(tree_kits[selected_tree])]
    elif key == "chop_tree":
        message = "แตะต้นไม้ที่ต้องการตัดเพื่อเคลียร์พื้นที่"
    elif key == "place_decor":
        message = "เลือก%s ×%d จากร้านค้า แล้วแตะพื้นว่าง (กดปุ่มซ้ำเพื่อเปลี่ยนชนิด)" % [DECOR_NAMES[selected_decor], int(decor_kits[selected_decor])]
    elif key == "buy_land":
        message = "แตะโซนสีเข้มที่ติดที่ดินเพื่อดูราคาซื้อพื้นที่ 40×40"
    else:
        message = "เลือกแปลงผักที่ต้องการ"
    if placement_preview != null:
        placement_preview.visible = false
    refresh_labels()

func select_seed(index: int) -> void:
    if work_plot >= 0 or work_time > 0.0:
        message = "รอชาวสวนทำแปลงปัจจุบันให้เสร็จก่อน"
        refresh_labels()
        return
    selected_seed = index
    tool_mode = "plant"
    landscaping_mode = false
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

func buy_plot_kit() -> void:
    if coins < PLOT_KIT_PRICE:
        message = "เหรียญไม่พอซื้อชุดแปลงผัก"
    elif plot_kits >= 100000:
        message = "เก็บชุดแปลงมากเกินไปแล้ว"
    else:
        coins -= PLOT_KIT_PRICE
        plot_kits += 1
        landscaping_mode = true
        tool_mode = "place_plot"
        shop_panel.visible = false
        message = "ซื้อชุดแปลงแล้ว แตะพื้นหญ้าว่างเพื่อวางได้เลย"
        if farm_audio != null:
            farm_audio.play_effect("buy")
        save_game()
    refresh_labels()

func buy_tree_kit(index: int) -> void:
    if index < 0 or index >= TREE_VARIANTS.size():
        return
    if coins < int(TREE_PRICES[index]):
        message = "เหรียญไม่พอซื้อต้นกล้า"
    elif int(tree_kits[index]) >= 100000:
        message = "เก็บต้นกล้ามากเกินไปแล้ว"
    else:
        coins -= int(TREE_PRICES[index])
        tree_kits[index] = int(tree_kits[index]) + 1
        selected_tree = index
        landscaping_mode = true
        tool_mode = "plant_tree"
        shop_panel.visible = false
        message = "ซื้อต้น%sแล้ว แตะพื้นหญ้าที่ว่างเพื่อปลูก" % TREE_NAMES[index]
        if farm_audio != null:
            farm_audio.play_effect("buy")
        save_game()
    refresh_labels()

func buy_decor_kit(index: int) -> void:
    if index < 0 or index >= DECOR_NAMES.size():
        return
    if coins < int(DECOR_PRICES[index]):
        message = "เหรียญไม่พอซื้อ%s" % DECOR_NAMES[index]
    elif int(decor_kits[index]) >= 100000:
        message = "เก็บของตกแต่งเกินจำนวนสูงสุดแล้ว"
    else:
        coins -= int(DECOR_PRICES[index])
        decor_kits[index] = int(decor_kits[index]) + 1
        selected_decor = index
        landscaping_mode = true
        tool_mode = "place_decor"
        shop_panel.visible = false
        message = "ซื้อ%sแล้ว! แตะที่ดินที่ปลดล็อกเพื่อวาง" % DECOR_NAMES[index]
        if farm_audio != null:
            farm_audio.play_effect("buy")
        save_game()
    refresh_labels()

func toggle_gm_panel() -> void:
    if not GM_TEST_MODE:
        if gm_panel != null:
            gm_panel.visible = false
        return
    gm_panel.visible = not gm_panel.visible
    if gm_panel.visible:
        shop_panel.visible = false
        bag_panel.visible = false

func gm_grant_coins(amount: int) -> void:
    # Never call this in a public economy. A browser-only GM switch is
    # suitable for testing, not for secure production currency.
    if not GM_TEST_MODE or amount <= 0:
        return
    coins = mini(1000000000, coins + amount)
    message = "GM TEST เติมเหรียญทดลอง %d (ยอดรวม %d)" % [amount, coins]
    save_game()
    refresh_labels()

func buy_seed(index: int) -> void:
    var price: int = int(CROPS[index]["price"])
    if coins >= price:
        coins -= price
        seeds[index] = int(seeds[index])+1
        message = "ซื้อเมล็ดพันธุ์สำเร็จ"
        if farm_audio != null:
            farm_audio.play_effect("buy")
        save_game()
    else:
        message = "เงินไม่พอ"
    refresh_labels()

func buy_feed() -> void:
    if coins >= 35:
        coins -= 35
        feed += 5
        message = "ซื้ออาหารหมูสำเร็จ"
        if farm_audio != null:
            farm_audio.play_effect("buy")
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
        if farm_audio != null:
            farm_audio.play_effect("buy")
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
        if farm_audio != null:
            farm_audio.play_effect("pig")
        save_game()
    refresh_labels()

func give_feed() -> void:
    if feed <= 0:
        message = "อาหารหมูหมดแล้ว"
    else:
        feed -= 1
        message = "ให้อาหารหมูแล้ว"
        if farm_audio != null:
            farm_audio.play_effect("pig")
        save_game()
    refresh_labels()

func snapshot() -> Dictionary:
    var free_cells: Array = []
    for i in range(FARM_ROWS * FARM_COLUMNS, plots.size()):
        var cell: Dictionary = plots[i].duplicate(true)
        cell["x"] = plot_places[i].x
        cell["z"] = plot_places[i].z
        free_cells.append(cell)
    return {
        "coins": coins,
        "feed": feed,
        "pigs": pigs,
        "pens": pens,
        "farm_level": farm_level,
        "farm_xp": farm_xp,
        "plot_kits": plot_kits,
        "tree_kits": tree_kits.duplicate(),
        "wood": wood,
        "extra_plots": free_cells,
        "placed_trees": placed_trees_data.duplicate(true),
        "removed_trees": removed_trees.duplicate(),
        "unlocked_zones": unlocked_zones.duplicate(),
        "decor_kits": decor_kits.duplicate(),
        "placed_decor": placed_decor_data.duplicate(true),
        "seeds": seeds.duplicate(),
        "plots": plots.slice(0, FARM_ROWS * FARM_COLUMNS).duplicate(true)
    }

func _apply_snapshot(state: Dictionary) -> void:
    coins = int(state["coins"])
    feed = int(state["feed"])
    pigs = int(state["pigs"])
    pens = int(state["pens"])
    farm_level = int(state.get("farm_level", 1))
    farm_xp = int(state.get("farm_xp", 0))
    plot_kits = int(state.get("plot_kits", 0))
    tree_kits = state.get("tree_kits", [0, 0, 0, 0, 0]).duplicate()
    wood = int(state.get("wood", 0))
    saved_extra_plots = state.get("extra_plots", []).duplicate(true)
    placed_trees_data = state.get("placed_trees", []).duplicate(true)
    removed_trees = state.get("removed_trees", []).duplicate()
    unlocked_zones = state.get("unlocked_zones", STARTER_ZONES.duplicate()).duplicate()
    decor_kits = state.get("decor_kits", [0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0]).duplicate()
    placed_decor_data = state.get("placed_decor", []).duplicate(true)
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
    _refresh_land_zones()
    update_plot_locks()
    rebuild_livestock()
    _rebuild_placed_world()
    if placement_preview != null:
        placement_preview.visible = false
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
