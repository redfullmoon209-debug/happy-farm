extends "res://scripts/farm_3d_base.gd"
# HAPPY FARM - COMPLETE 3D MOBILE + PC CONTROLLER (Godot 4.4.1).
# Replace this WHOLE file; do not edit farm_3d_base.gd.
# Mobile: left thumbstick, RUN toggle, JUMP; tap plots to work.
# PC: WASD, Shift, Space and mouse wheel. The world/save/shop stay intact.

const WALK_SPEED: float = 4.2
const RUN_SPEED: float = 7.4
const JUMP_SPEED: float = 6.5
const GRAVITY: float = 19.0
const MIN_X: float = -17.4
const MAX_X: float = 17.4
const MIN_Z: float = -13.3
const MAX_Z: float = 13.3

# These icons are drawn as graphics: no unsupported emoji glyphs.
class FarmIcon:
    extends Control

    var kind: String = "coin"

    func _ready() -> void:
        mouse_filter = Control.MOUSE_FILTER_IGNORE
        custom_minimum_size = Vector2(28, 28)

    func _draw() -> void:
        var center: Vector2 = size * 0.5
        match kind:
            "coin":
                draw_circle(center, 12.0, Color("#ffcc62"))
                draw_arc(center, 9.1, 0.0, TAU, 24, Color("#b97b2b"), 2.0, true)
                draw_line(center + Vector2(-4.0, -3.0), center + Vector2(4.0, -3.0), Color("#a46a20"), 2.5, true)
                draw_line(center + Vector2(-4.0, 2.0), center + Vector2(4.0, 2.0), Color("#a46a20"), 2.5, true)
            "pig":
                draw_circle(center + Vector2(-8.0, -7.0), 5.3, Color("#ffc1ce"))
                draw_circle(center + Vector2(8.0, -7.0), 5.3, Color("#ffc1ce"))
                draw_circle(center, 11.0, Color("#ffa5bb"))
                draw_circle(center + Vector2(0.0, 5.0), 5.3, Color("#db7894"))
                draw_circle(center + Vector2(-4.3, -1.3), 1.7, Color("#493c44"))
                draw_circle(center + Vector2(4.3, -1.3), 1.7, Color("#493c44"))
                draw_circle(center + Vector2(-2.0, 5.0), 1.2, Color("#9e4965"))
                draw_circle(center + Vector2(2.0, 5.0), 1.2, Color("#9e4965"))
            "feed":
                draw_colored_polygon(PackedVector2Array([center+Vector2(-11,-2),center+Vector2(11,-2),center+Vector2(8,9),center+Vector2(-8,9)]), Color("#e7b771"))
                draw_line(center + Vector2(-8, -3), center + Vector2(8, -3), Color("#88603a"), 3, true)
                draw_circle(center + Vector2(-4, -6), 3.8, Color("#7caf58"))
                draw_circle(center + Vector2(1, -8), 4.0, Color("#93cc60"))
                draw_circle(center + Vector2(6, -5), 3.5, Color("#659c4d"))
            "hoe":
                draw_line(center+Vector2(7,-11),center+Vector2(-5,11),Color("#deb27e"),4.0,true)
                draw_line(center+Vector2(-13,8),center+Vector2(2,13),Color("#b7d2d2"),4.5,true)
            "plant":
                draw_line(center+Vector2(0,10),center+Vector2(0,-4),Color("#63b76f"),3.0,true)
                draw_circle(center+Vector2(-6,-5),6,Color("#76cc79"))
                draw_circle(center+Vector2(6,-7),6,Color("#459d5f"))
                draw_circle(center+Vector2(0,10),4,Color("#a8804d"))
            "water":
                draw_colored_polygon(PackedVector2Array([center+Vector2(-9,-3),center+Vector2(6,-3),center+Vector2(5,8),center+Vector2(-8,8)]),Color("#65c0dc"))
                draw_arc(center+Vector2(-1,-2),7,PI,TAU,15,Color("#e6f8fb"),2.5,true)
                draw_line(center+Vector2(5,-2),center+Vector2(13,-7),Color("#65c0dc"),3,true)
                draw_circle(center+Vector2(12,4),2.5,Color("#92e4ff"))
            "harvest":
                draw_circle(center+Vector2(-4,4),7.0,Color("#ee9553"))
                draw_circle(center+Vector2(6,4),7.0,Color("#efbb62"))
                draw_line(center+Vector2(1,0),center+Vector2(3,-10),Color("#598b49"),3,true)
                draw_circle(center+Vector2(7,-9),4,Color("#80bf62"))
            "shop":
                draw_rect(Rect2(center-Vector2(10,4),Vector2(20,14)),Color("#e7c28c"),true)
                draw_rect(Rect2(center-Vector2(12,11),Vector2(24,7)),Color("#f4ad70"),true)
                draw_rect(Rect2(center+Vector2(-5,1),Vector2(7,13)),Color("#8b654a"),true)
            "jump":
                draw_line(center+Vector2(0,10),center+Vector2(0,-11),Color.WHITE,3.5,true)
                draw_line(center+Vector2(0,-11),center+Vector2(-7,-4),Color.WHITE,3.5,true)
                draw_line(center+Vector2(0,-11),center+Vector2(7,-4),Color.WHITE,3.5,true)
            "run":
                draw_circle(center+Vector2(4,-9),4,Color.WHITE)
                draw_line(center+Vector2(3,-3),center+Vector2(-3,4),Color.WHITE,4,true)
                draw_line(center+Vector2(-3,4),center+Vector2(7,11),Color.WHITE,3,true)
                draw_line(center+Vector2(-1,0),center+Vector2(-10,5),Color.WHITE,3,true)

# Independent multitouch joystick. Touching the other side will not steal it.
class FarmStick:
    extends Control

    var value: Vector2 = Vector2.ZERO
    var finger: int = -1
    var mouse_held: bool = false

    func _ready() -> void:
        mouse_filter = Control.MOUSE_FILTER_STOP
        custom_minimum_size = Vector2(154, 154)

    func _draw() -> void:
        var center: Vector2 = size * 0.5
        var outer: float = minf(size.x, size.y) * 0.47
        draw_circle(center, outer, Color(0.10, 0.23, 0.21, 0.28))
        draw_arc(center, outer-2.0, 0.0, TAU, 48, Color(1,1,1,0.55), 3.0, true)
        draw_circle(center, outer*0.64, Color(1,1,1,0.10))
        var thumb: Vector2 = center + value * (outer*0.58)
        draw_circle(thumb, outer*0.37, Color(0.90, 0.98, 0.87, 0.94))
        draw_circle(thumb, outer*0.28, Color("#3e9b73"))
        draw_arc(thumb, outer*0.30, 0.0, TAU, 36, Color.WHITE, 2.0, true)

    func _update_stick(screen_position: Vector2) -> void:
        var center: Vector2 = global_position + size * 0.5
        var distance: Vector2 = (screen_position-center) / (minf(size.x,size.y)*0.33)
        value = distance.limit_length(1.0)
        queue_redraw()

    func _input(event: InputEvent) -> void:
        if not visible:
            return
        if event is InputEventScreenTouch:
            if event.pressed and finger < 0 and get_global_rect().has_point(event.position):
                finger = event.index
                _update_stick(event.position)
                get_viewport().set_input_as_handled()
            elif not event.pressed and event.index == finger:
                finger = -1
                value = Vector2.ZERO
                queue_redraw()
                get_viewport().set_input_as_handled()
        elif event is InputEventScreenDrag and event.index == finger:
            _update_stick(event.position)
            get_viewport().set_input_as_handled()
        elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
            if event.pressed and get_global_rect().has_point(event.position):
                mouse_held = true
                _update_stick(event.position)
                get_viewport().set_input_as_handled()
            elif not event.pressed and mouse_held:
                mouse_held = false
                value = Vector2.ZERO
                queue_redraw()
                get_viewport().set_input_as_handled()
        elif event is InputEventMouseMotion and mouse_held:
            _update_stick(event.position)
            get_viewport().set_input_as_handled()

var jump_height: float = 0.0
var vertical_speed: float = 0.0
var moving_freely: bool = false
var moving_fast: bool = false
var mobile_run: bool = false
var show_touch_ui: bool = false
var touch_stick: FarmStick
var hud_root: Control
var hud_top: PanelContainer
var hud_bottom: PanelContainer
var hud_money: Label
var hud_pigs: Label
var hud_feed: Label
var hud_status: Label
var hud_seed: OptionButton
var hud_market: PanelContainer
var hud_buttons: Dictionary = {}
var run_button: Button
var jump_button: Button

func _ready() -> void:
    # Existing Thai font may lack ASCII/digits. Fallback fixes the square boxes.
    var fallback_fonts: Array[Font] = [ThemeDB.fallback_font]
    FONT.set_fallbacks(fallback_fonts)
    show_touch_ui = DisplayServer.is_touchscreen_available() or OS.has_feature("web_android") or OS.has_feature("web_ios")
    super._ready()
    status_text = "แตะแปลงเพื่อทำฟาร์ม | WASD เดิน | Shift วิ่ง | Space กระโดด"
    update_ui()

func _process(delta: float) -> void:
    update_jump(delta)
    handle_free_roam(delta)
    super._process(delta)

func _input(event: InputEvent) -> void:
    if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_SPACE:
        request_jump()

func request_jump() -> void:
    if actor_running or action_step != "" or (market_panel != null and market_panel.visible):
        return
    if jump_height <= 0.001 and vertical_speed <= 0.0:
        vertical_speed = JUMP_SPEED

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
    var input_x: float = float(Input.is_key_pressed(KEY_D)) - float(Input.is_key_pressed(KEY_A))
    var input_z: float = float(Input.is_key_pressed(KEY_S)) - float(Input.is_key_pressed(KEY_W))
    var direction_2d: Vector2 = Vector2(input_x, input_z)
    if touch_stick != null and touch_stick.visible and touch_stick.value.length() > 0.06:
        direction_2d = touch_stick.value
    if direction_2d.length_squared() < 0.008:
        return
    var strength: float = minf(direction_2d.length(), 1.0)
    direction_2d = direction_2d.normalized()
    var forward: Vector3 = -camera.global_transform.basis.z
    forward.y = 0.0
    forward = forward.normalized()
    var right: Vector3 = camera.global_transform.basis.x
    right.y = 0.0
    right = right.normalized()
    var direction: Vector3 = (right * direction_2d.x - forward * direction_2d.y).normalized()
    moving_fast = Input.is_key_pressed(KEY_SHIFT) or mobile_run
    var speed: float = (RUN_SPEED if moving_fast else WALK_SPEED) * strength
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
    farmer.rotation.z = lerpf(farmer.rotation.z, 0.0, minf(1.0, delta*10.0))
    var blend: float = minf(1.0, delta*11.0)
    if moving_freely:
        var stride: float = sin(time_passed * (15.0 if moving_fast else 10.0))
        var amount: float = 0.75 if moving_fast else 0.48
        left_leg.rotation.x = stride * amount
        right_leg.rotation.x = -stride * amount
        left_arm.rotation.x = -stride * amount * 0.70
        right_arm.rotation.x = stride * amount * 0.70
        farmer.position.y = jump_height + (absf(stride)*0.045 if jump_height <= 0.0 else 0.0)
    else:
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
            atmosphere.background_mode = Environment.BG_COLOR
            atmosphere.background_color = Color("#a9d6e5")
            atmosphere.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
            atmosphere.ambient_light_color = Color("#bacbc6")
            atmosphere.ambient_light_energy = 0.48
            atmosphere.tonemap_mode = Environment.TONE_MAPPER_FILMIC
        elif child is DirectionalLight3D:
            child.light_color = Color("#ffe1b8")
            child.light_energy = 0.76
            child.shadow_enabled = true
    for child in get_children():
        if child is MeshInstance3D and child.mesh is BoxMesh:
            var dimensions: Vector3 = child.mesh.size
            if dimensions.x > 35 and dimensions.z > 25:
                child.material_override = mat(Color("#83b86b"))
            elif dimensions.x > 29 and dimensions.z < 3:
                child.material_override = mat(Color("#bdaa81"))
            elif dimensions.z > 17 and dimensions.x < 3:
                child.material_override = mat(Color("#bdaa81"))

func _make_panel(color: Color) -> PanelContainer:
    var panel: PanelContainer = PanelContainer.new()
    var style: StyleBoxFlat = StyleBoxFlat.new()
    style.bg_color = color
    style.set_corner_radius_all(17)
    style.set_content_margin_all(8)
    panel.add_theme_stylebox_override("panel", style)
    return panel

func _make_label(text_value: String, font_size: int, color: Color) -> Label:
    var label: Label = Label.new()
    label.text = text_value
    label.add_theme_font_override("font", FONT)
    label.add_theme_font_size_override("font_size", font_size)
    label.add_theme_color_override("font_color", color)
    label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    return label

func _make_icon(kind: String) -> FarmIcon:
    var icon: FarmIcon = FarmIcon.new()
    icon.kind = kind
    icon.custom_minimum_size = Vector2(28, 28)
    return icon

func _make_icon_button(kind: String, label_text: String, color: Color, callback: Callable) -> Button:
    var button: Button = Button.new()
    button.text = ""
    button.focus_mode = Control.FOCUS_NONE
    button.custom_minimum_size = Vector2(70, 47)
    button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    var style: StyleBoxFlat = StyleBoxFlat.new()
    style.bg_color = color
    style.set_corner_radius_all(12)
    style.set_content_margin_all(5)
    button.add_theme_stylebox_override("normal", style)
    var pressed: StyleBoxFlat = style.duplicate()
    pressed.bg_color = color.darkened(0.15)
    button.add_theme_stylebox_override("pressed", pressed)
    button.add_theme_stylebox_override("hover", style)
    button.add_theme_stylebox_override("focus", style)
    var contents: HBoxContainer = HBoxContainer.new()
    contents.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    contents.mouse_filter = Control.MOUSE_FILTER_IGNORE
    contents.alignment = BoxContainer.ALIGNMENT_CENTER
    contents.add_theme_constant_override("separation", 4)
    button.add_child(contents)
    contents.add_child(_make_icon(kind))
    var txt: Label = _make_label(label_text, 17, Color.WHITE)
    txt.mouse_filter = Control.MOUSE_FILTER_IGNORE
    contents.add_child(txt)
    button.pressed.connect(callback)
    return button

func _stat_chip(parent: HBoxContainer, kind: String, text_value: String) -> Label:
    var chip: HBoxContainer = HBoxContainer.new()
    chip.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    chip.add_theme_constant_override("separation", 4)
    parent.add_child(chip)
    chip.add_child(_make_icon(kind))
    var label: Label = _make_label(text_value, 18, Color("#f5fff2"))
    chip.add_child(label)
    return label

func build_ui() -> void:
    # Build original save/shop UI but replace oversized visible HUD.
    super.build_ui()
    top_panel.visible = false
    bottom_panel.visible = false

    var ui_layer: CanvasLayer = CanvasLayer.new()
    ui_layer.layer = 3
    add_child(ui_layer)
    hud_root = Control.new()
    hud_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
    hud_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    ui_layer.add_child(hud_root)

    hud_top = _make_panel(Color("#244638e3"))
    hud_top.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
    hud_root.add_child(hud_top)
    var top_v: VBoxContainer = VBoxContainer.new()
    top_v.add_theme_constant_override("separation", 3)
    hud_top.add_child(top_v)
    var stats: HBoxContainer = HBoxContainer.new()
    top_v.add_child(stats)
    hud_money = _stat_chip(stats, "coin", "เงิน")
    hud_feed = _stat_chip(stats, "feed", "อาหาร")
    hud_pigs = _stat_chip(stats, "pig", "หมู")
    var commands: HBoxContainer = HBoxContainer.new()
    commands.add_theme_constant_override("separation", 7)
    top_v.add_child(commands)
    commands.add_child(_make_icon_button("shop", "ร้านค้า", Color("#b18349"), toggle_shop))
    commands.add_child(_make_icon_button("feed", "ให้อาหาร", Color("#b47487"), feed_pig))

    hud_bottom = _make_panel(Color("#e9f4e9ed"))
    hud_bottom.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
    hud_root.add_child(hud_bottom)
    var bottom_v: VBoxContainer = VBoxContainer.new()
    bottom_v.add_theme_constant_override("separation", 6)
    hud_bottom.add_child(bottom_v)
    hud_status = _make_label("", 15, Color("#385643"))
    bottom_v.add_child(hud_status)
    var seeds_row: HBoxContainer = HBoxContainer.new()
    seeds_row.add_theme_constant_override("separation", 5)
    bottom_v.add_child(seeds_row)
    seeds_row.add_child(_make_icon("plant"))
    seeds_row.add_child(_make_label("เมล็ด:", 17, Color("#2c533d")))
    hud_seed = OptionButton.new()
    hud_seed.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    hud_seed.custom_minimum_size.y = 34
    hud_seed.add_theme_font_override("font", FONT)
    hud_seed.add_theme_font_size_override("font_size", 17)
    for i in range(CROPS.size()):
        hud_seed.add_item(str(CROPS[i]["name"]), i)
    hud_seed.selected = 0
    hud_seed.item_selected.connect(select_seed)
    seeds_row.add_child(hud_seed)
    var actions: GridContainer = GridContainer.new()
    actions.columns = 4
    actions.add_theme_constant_override("h_separation", 6)
    bottom_v.add_child(actions)
    for entry in [
        ["till", "hoe", "พรวน"],
        ["plant", "plant", "ปลูก"],
        ["water", "water", "รดน้ำ"],
        ["harvest", "harvest", "เก็บ"]
    ]:
        var key: String = str(entry[0])
        var action: Button = _make_icon_button(str(entry[1]), str(entry[2]),
            Color("#468965") if key != "water" else Color("#438eb1"),
            select_mode.bind(key))
        hud_buttons[key] = action
        actions.add_child(action)

    # Multitouch controls: joystick left; independent RUN and JUMP right.
    touch_stick = FarmStick.new()
    hud_root.add_child(touch_stick)
    touch_stick.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_LEFT)
    touch_stick.visible = show_touch_ui

    run_button = _make_icon_button("run", "วิ่ง", Color("#667e63"), toggle_run)
    hud_root.add_child(run_button)
    run_button.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT)
    run_button.visible = show_touch_ui
    jump_button = _make_icon_button("jump", "กระโดด", Color("#e29b50"), request_jump)
    hud_root.add_child(jump_button)
    jump_button.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT)
    jump_button.visible = show_touch_ui

    # The original shop is still fully functional, brought above new HUD.
    market_panel.reparent(hud_root, false)
    market_panel.anchor_left = 0.5
    market_panel.anchor_right = 0.5
    market_panel.anchor_top = 0.5
    market_panel.anchor_bottom = 0.5
    hud_market = market_panel
    _resize_hud()
    get_viewport().size_changed.connect(_resize_hud)
    update_ui()

func _resize_hud() -> void:
    if hud_top == null:
        return
    var size_view: Vector2 = get_viewport().get_visible_rect().size
    var narrow: bool = size_view.x < 750.0
    hud_top.offset_left = 9.0
    hud_top.offset_right = -9.0
    hud_top.offset_top = 7.0
    hud_top.offset_bottom = 116.0
    hud_bottom.offset_left = 9.0
    hud_bottom.offset_right = -9.0
    hud_bottom.offset_bottom = -9.0 if not show_touch_ui else -198.0
    hud_bottom.offset_top = -150.0 if not show_touch_ui else -342.0
    if narrow:
        hud_bottom.offset_top -= 6.0
        hud_top.offset_bottom = 122.0
    touch_stick.offset_left = 18.0
    touch_stick.offset_right = 172.0
    touch_stick.offset_top = -183.0
    touch_stick.offset_bottom = -29.0
    run_button.offset_left = -133.0
    run_button.offset_right = -14.0
    run_button.offset_top = -180.0
    run_button.offset_bottom = -112.0
    jump_button.offset_left = -133.0
    jump_button.offset_right = -14.0
    jump_button.offset_top = -104.0
    jump_button.offset_bottom = -21.0
    if hud_market != null:
        var modal_w: float = minf(size_view.x - 24.0, 680.0)
        var modal_h: float = minf(size_view.y - 24.0, 560.0)
        hud_market.offset_left = -modal_w*0.5
        hud_market.offset_right = modal_w*0.5
        hud_market.offset_top = -modal_h*0.5
        hud_market.offset_bottom = modal_h*0.5
        var grids: Array[Node] = hud_market.find_children("*", "GridContainer", true, false)
        for item in grids:
            if item is GridContainer:
                item.columns = 2 if size_view.x < 500 else 3

func update_ui() -> void:
    super.update_ui()
    if hud_money == null:
        return
    hud_money.text = "เงิน %d" % money
    hud_feed.text = "อาหาร %d" % feed
    hud_pigs.text = "หมู %d" % pigs.size()
    hud_status.text = status_text
    for i in range(CROPS.size()):
        hud_seed.set_item_text(i, "%s (%d)" % [CROPS[i]["name"], int(seeds[i])])
    if hud_seed.selected != selected_crop:
        hud_seed.select(selected_crop)
    for mode_name in hud_buttons.keys():
        var button: Button = hud_buttons[mode_name]
        button.modulate = Color.WHITE if mode_name == selected_mode else Color("#b7c4b9")
    if run_button != null:
        run_button.modulate = Color("#ffffff") if mobile_run else Color("#b8c4b6")

func toggle_run() -> void:
    mobile_run = not mobile_run
    update_ui()

func _unhandled_input(event: InputEvent) -> void:
    # Let joystick/buttons own touch events; use other taps for plot selection.
    if market_panel != null and market_panel.visible:
        return
    if event is InputEventScreenTouch and event.pressed:
        if not _on_mobile_overlay(event.position):
            select_world_point(event.position)
            get_viewport().set_input_as_handled()
    elif event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
        if not _on_mobile_overlay(event.position):
            super._unhandled_input(event)
    elif event is InputEventMouseButton and (event.button_index == MOUSE_BUTTON_WHEEL_UP or event.button_index == MOUSE_BUTTON_WHEEL_DOWN):
        super._unhandled_input(event)

func _on_mobile_overlay(point: Vector2) -> bool:
    if hud_top != null and hud_top.get_global_rect().has_point(point):
        return true
    if hud_bottom != null and hud_bottom.get_global_rect().has_point(point):
        return true
    if touch_stick != null and touch_stick.visible and touch_stick.get_global_rect().has_point(point):
        return true
    if run_button != null and run_button.visible and run_button.get_global_rect().has_point(point):
        return true
    if jump_button != null and jump_button.visible and jump_button.get_global_rect().has_point(point):
        return true
    return false
