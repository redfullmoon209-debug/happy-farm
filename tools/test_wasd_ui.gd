extends SceneTree
# Browser/desktop keyboard, PNG-layered UI and input coexistence regression.
var errors: Array[String] = []

func check(okay: bool, reason: String) -> void:
    if not okay:
        errors.append(reason)
        printerr("WASD UI FAIL: " + reason)

func key_event(game: Node, code: Key, is_down: bool) -> void:
    var event: InputEventKey = InputEventKey.new()
    event.keycode = code
    event.physical_keycode = code
    event.pressed = is_down
    game._input(event)

func _initialize() -> void:
    call_deferred("_run")

func _run() -> void:
    var scene: PackedScene = load("res://scenes/Main.tscn")
    check(scene != null, "game main scene opens")
    if scene == null:
        quit(1)
        return
    var farm: Variant = scene.instantiate()
    root.add_child(farm)
    farm.farm_audio.unlocked = true
    farm.farm_audio.enabled = false

    var base: Vector3 = Vector3(-4,0,-3)
    farm.farmer.position = base
    farm.update_camera()
    check(farm.keyboard_vector() == Vector2.ZERO, "keyboard starts released")
    key_event(farm, KEY_W, true)
    check(farm.keyboard_vector().y < 0, "W keydown registered")
    farm._process(0.14)
    check(farm.farmer.position.distance_to(base) > 0.20, "W walks the farmer through camera-oriented movement")
    key_event(farm, KEY_W, false)
    check(farm.keyboard_vector() == Vector2.ZERO, "W keyup stops input")
    var stopped: Vector3 = farm.farmer.position
    farm._process(0.10)
    var planar_stop: Vector2 = Vector2(farm.farmer.position.x-stopped.x, farm.farmer.position.z-stopped.z)
    check(planar_stop.length() < 0.01, "keyup stops horizontal movement")

    key_event(farm, KEY_A, true)
    check(farm.keyboard_vector().x < 0, "A moves left")
    key_event(farm, KEY_A, false)
    key_event(farm, KEY_S, true)
    check(farm.keyboard_vector().y > 0, "S moves backward")
    key_event(farm, KEY_S, false)
    key_event(farm, KEY_D, true)
    check(farm.keyboard_vector().x > 0, "D moves right")
    key_event(farm, KEY_D, false)
    key_event(farm, KEY_UP, true)
    check(farm.keyboard_vector().y < 0, "arrow-up alternative works")
    key_event(farm, KEY_UP, false)

    key_event(farm, KEY_W, true)
    key_event(farm, KEY_D, true)
    check(absf(farm.keyboard_vector().length() - 1.0) < 0.01, "diagonal movement normalized")
    key_event(farm, KEY_SHIFT, true)
    check(farm._keyboard_active(KEY_SHIFT), "shift sprint recognized")
    farm._process(0.11)
    check(farm.running, "shift runs while moving")
    key_event(farm, KEY_SHIFT, false)
    key_event(farm, KEY_D, false)
    key_event(farm, KEY_W, false)
    key_event(farm, KEY_W, true)
    farm.notification(Node.NOTIFICATION_WM_WINDOW_FOCUS_OUT)
    check(farm.keyboard_vector() == Vector2.ZERO and farm.keyboard_held.is_empty(), "window focus loss releases keys")

    check(farm.stick != null and farm.stick.BASE_TEXTURE != null, "joystick base uses imported PNG")
    check(farm.stick.THUMB_TEXTURE != null, "joystick thumb is independent PNG")
    # Small buttons are allowed to hide PNGs so Thai words stay readable.
    # The independent asset must remain attached for wider layouts.
    check(farm.shop_button.has_meta("happy_icon_texture") and farm.bag_button.has_meta("happy_icon_texture"),
        "shop/bag preserve their separate PNG assets")
    check(farm.action_buttons["plant"].has_meta("happy_icon_texture"),
        "farm tools preserve their separate PNG assets")
    check(farm.action_buttons["plant"].get_theme_font_size("font_size") >= 15,
        "farming button captions stay readable")
    check(farm.status_label.autowrap_mode == TextServer.AUTOWRAP_WORD_SMART,
        "status text can use two readable Thai lines")
    check(farm.shop_plot_button.text.contains("\n") and farm.shop_plot_button.custom_minimum_size.y >= 50.0,
        "shop item names and prices have their own lines")
    check(farm.shop_button.get_theme_stylebox("normal") is StyleBoxTexture, "buttons use imported PNG style texture")
    var shop_skin: StyleBoxTexture = farm.shop_button.get_theme_stylebox("normal") as StyleBoxTexture
    check(shop_skin != null and shop_skin.region_rect.position.y >= 30.0,
        "button art is shown without transparent top and bottom gaps")
    check(farm.zoom_in_button.get_theme_stylebox("normal") is StyleBoxTexture,
        "zoom buttons use dedicated square PNG")
    check((farm.zoom_in_button.get_theme_stylebox("normal") as StyleBoxTexture).texture == farm.UI_SLOT,
        "zoom buttons must not squeeze wide green art into a square")
    check(farm.money_label.get_theme_color("font_color").get_luminance() < 0.4,
        "header money text is dark enough on the pale background")
    check(farm.status_label.get_theme_font_size("font_size") >= 16,
        "farm HUD status is at least 16px")
    check(farm.shop_panel.get_theme_stylebox("panel") is StyleBoxTexture, "shop window uses imported PNG skin")
    check(farm.bag_panel.get_theme_stylebox("panel") is StyleBoxTexture, "inventory window uses imported PNG skin")
    check(farm.shop_header_art.texture != null and farm.bag_header_art.texture != null, "heading art independent layer")
    check(farm.gm_button.visible, "GM playtest button remains available")
    check(farm.shop_decor_buttons.size() == 16, "decoration shop retained")
    check(farm.WORLD_SIZE == 400.0 and farm.zone_covers.size() == 100, "map and land progression untouched")

    for file in [
        "button_green.png", "window_wood.png", "window_header.png", "inventory_slot.png",
        "hud_bar.png", "joystick_base.png", "joystick_thumb.png",
        "icon_bag.png", "icon_shop.png", "icon_plant.png", "icon_water.png",
        "icon_harvest.png", "icon_farm.png", "icon_gm.png"
    ]:
        check(ResourceLoader.exists("res://assets/ui/happy/" + file), "real PNG layer exists: " + file)
    if errors.is_empty():
        print("WASD UI TESTS PASS: W A S D, Shift, keyup, browser focus, PNG panels/icons and joystick")
        quit(0)
    else:
        printerr("%d WASD/UI failures" % errors.size())
        quit(1)
