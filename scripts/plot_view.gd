extends Button
# A real, animated garden plot. Replaces text-only farm cells.
# Kept in a separate script to avoid inner-class type-inference issues.

const ATLAS = preload("res://assets/tiny_farm.png")
const FONT = preload("res://assets/NotoSansThai-Regular.ttf")
const FRUIT_COLORS = [
    Color("#f68b32"), Color("#b5df75"), Color("#ec5041"),
    Color("#eec64a"), Color("#df8b2d"), Color("#a575c3"),
    Color("#e54162"), Color("#59b855"), Color("#f0c94b"),
    Color("#e74c53"), Color("#ff9f34"), Color("#edc34f")
]
const LEAF = Color("#3c9c53")
const SOIL = Color("#805038")
const SOIL_WET = Color("#553e32")
const PATH = Color("#dfcf9b")

var crop_id: int = -1
var crop_name: String = ""
var stage: int = 0
var ripe: bool = false
var wet: bool = false
var progress: float = 0.0
var water_left: float = 0.0
var plant_pulse: float = 0.0
var growth_pulse: float = 0.0
var age_seconds: float = 0.0

func _ready() -> void:
    flat = true
    focus_mode = Control.FOCUS_NONE
    text = ""
    mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
    size_flags_horizontal = Control.SIZE_EXPAND_FILL
    custom_minimum_size = Vector2(124, 130)
    var invisible_style = StyleBoxEmpty.new()
    add_theme_stylebox_override("normal", invisible_style)
    add_theme_stylebox_override("hover", invisible_style)
    add_theme_stylebox_override("pressed", invisible_style)
    add_theme_stylebox_override("focus", invisible_style)

func set_plot(cell: Dictionary, all_crops: Array) -> void:
    var previous_stage: int = stage
    crop_id = -1
    crop_name = ""
    ripe = false
    wet = false
    progress = 0.0
    stage = 0
    age_seconds = 0.0
    if not cell.is_empty():
        crop_id = clampi(int(cell.get("seed", 0)), 0, all_crops.size() - 1)
        var crop: Dictionary = all_crops[crop_id]
        crop_name = str(crop["name"])
        wet = bool(cell.get("wet", false))
        age_seconds = maxf(0.0, Time.get_unix_time_from_system() - float(cell.get("time", 0.0)))
        var grow_time: float = maxf(1.0, float(crop["seconds"]))
        if wet:
            progress = clampf(age_seconds / grow_time, 0.0, 1.0)
        else:
            progress = 0.0
        if not wet:
            stage = 1
        elif progress < 0.20:
            stage = 2
        elif progress < 0.50:
            stage = 3
        elif progress < 0.80:
            stage = 4
        else:
            stage = 5
        ripe = wet and progress >= 1.0
    if previous_stage > 0 and stage > previous_stage:
        growth_pulse = 1.0
    queue_redraw()

func animate_water() -> void:
    water_left = 1.5
    plant_pulse = 0.8
    queue_redraw()

func animate_plant() -> void:
    plant_pulse = 0.8
    queue_redraw()

func _process(delta: float) -> void:
    water_left = maxf(0.0, water_left - delta)
    plant_pulse = maxf(0.0, plant_pulse - delta * 1.6)
    growth_pulse = maxf(0.0, growth_pulse - delta * 1.4)
    # A gentle leaf sway even while the crop is growing.
    if stage > 1 or water_left > 0.0 or plant_pulse > 0.0:
        queue_redraw()

func _draw() -> void:
    var w: float = size.x
    var h: float = size.y
    var base: Rect2 = Rect2(3.0, 3.0, w - 6.0, h - 6.0)
    draw_rect(base, Color("#afd28c"))
    draw_rect(Rect2(7.0, 7.0, w - 14.0, h - 14.0), Color("#d5e7a8"))
    draw_rect(Rect2(10.0, 10.0, w - 20.0, h - 20.0), Color("#b4d58c"), false, 2.0)

    # Three raised soil rows make each plot recognizable as a garden bed.
    var soil_color: Color = SOIL_WET if wet else SOIL
    for r in range(3):
        var soil_y: float = h * 0.45 + float(r) * 18.0
        var rect: Rect2 = Rect2(15.0, soil_y, w - 30.0, 13.0)
        draw_rect(rect, Color("#533b2d"))
        draw_rect(rect.grow(-2.0), soil_color)
        draw_line(Vector2(17.0, soil_y), Vector2(w - 18.0, soil_y), PATH.darkened(0.18), 1.0)

    # Decorative Kenney Tiny Farm sprite (different tile for different crops).
    if crop_id >= 0:
        var tile_col: int = 4 + (crop_id % 4)
        var tile_row: int = 1 + (crop_id / 4)
        var src: Rect2 = Rect2(float(tile_col * 16), float(tile_row * 16), 16.0, 16.0)
        draw_texture_rect_region(ATLAS, Rect2(w - 32.0, 11.0, 21.0, 21.0), src)

    if crop_id == -1:
        _draw_empty(w, h)
    elif stage == 1:
        _draw_seed(w, h)
    else:
        _draw_crop(w, h)

    if ripe:
        draw_rect(base.grow(-2.0), Color("#ffd65c"), false, 4.0)
        draw_circle(Vector2(w - 18.0, h - 18.0), 7.0, Color("#fff09b"))
    if water_left > 0.0:
        _draw_water(w, h)
    if plant_pulse > 0.0:
        draw_rect(base.grow(-4.0), Color(1.0, 1.0, 0.8, plant_pulse * 0.48), false, 3.0)

    var title: String = "ว่าง" if crop_id < 0 else crop_name
    var subtitle: String = ""
    if crop_id >= 0:
        if ripe:
            subtitle = "เก็บเกี่ยว"
        elif not wet:
            subtitle = "รดน้ำ"
        else:
            subtitle = "%d%%" % int(progress * 100.0)
    draw_rect(Rect2(10.0, h - 37.0, w - 20.0, 32.0), Color(0.14, 0.25, 0.17, 0.84))
    draw_string(FONT, Vector2(15.0, h - 23.0), title, HORIZONTAL_ALIGNMENT_CENTER, w - 30.0, 14, Color.WHITE)
    if subtitle != "":
        draw_string(FONT, Vector2(15.0, h - 8.0), subtitle, HORIZONTAL_ALIGNMENT_CENTER, w - 30.0, 12, Color("#dceeb6"))

func _draw_empty(w: float, h: float) -> void:
    draw_circle(Vector2(w * 0.34, h * 0.56), 2.0, Color("#a6794a"))
    draw_circle(Vector2(w * 0.57, h * 0.66), 2.0, Color("#b58b58"))
    draw_circle(Vector2(w * 0.73, h * 0.53), 2.0, Color("#bd986b"))

func _draw_seed(w: float, h: float) -> void:
    for i in range(3):
        var x: float = w * (0.35 + float(i) * 0.16)
        var y: float = h * (0.47 + float(i % 2) * 0.09)
        draw_circle(Vector2(x, y), 3.5, Color("#ead383"))

func _draw_crop(w: float, h: float) -> void:
    var now: float = float(Time.get_ticks_msec()) * 0.001
    var sway: float = sin(now * 2.0 + float(crop_id)) * 2.0
    var factor: float = 0.38 if stage == 2 else (0.62 if stage == 3 else (0.83 if stage == 4 else 1.0))
    factor *= 1.0 + growth_pulse * 0.12
    var ground: Vector2 = Vector2(w * 0.5, h * 0.63)
    var top: Vector2 = ground + Vector2(sway * factor, -57.0 * factor)
    draw_line(ground, top, Color("#287b40"), 4.0)
    var leaf_count: int = 2 if stage == 2 else (4 if stage == 3 else 6)
    for i in range(leaf_count):
        var side: float = -1.0 if i % 2 == 0 else 1.0
        var level: float = float(i / 2) + 1.0
        var base_pos: Vector2 = lerp(ground, top, clampf(level / 4.0, 0.15, 0.95))
        var leaf_pos: Vector2 = base_pos + Vector2(side * 11.0 * factor + sway * 0.3, -7.0 * factor)
        draw_line(base_pos, leaf_pos, LEAF.darkened(0.1), 2.5)
        draw_circle(leaf_pos, 7.0 * factor, LEAF.lightened(float(i % 3) * 0.07))
    draw_circle(top, 6.5 * factor, Color("#70c15e"))
    if stage >= 4:
        var fruit_color: Color = FRUIT_COLORS[crop_id % FRUIT_COLORS.size()]
        for i in range(3 if stage == 5 else 1):
            var x: float = (float(i) - 1.0) * 13.0
            var y: float = -24.0 - float(i % 2) * 8.0
            draw_circle(ground + Vector2(x + sway * 0.5, y), 6.0 * factor, fruit_color)
            draw_circle(ground + Vector2(x - 1.0 + sway * 0.5, y - 1.0), 2.0, fruit_color.lightened(0.25))

func _draw_water(w: float, h: float) -> void:
    var t: float = 1.0 - water_left / 1.5
    var alpha: float = clampf(water_left / 0.6, 0.0, 1.0)
    for i in range(8):
        var x: float = w * 0.25 + float(i % 4) * w * 0.15
        var y: float = 7.0 + float(i / 4) * 8.0 + fmod(t * 86.0 + float(i * 11), h * 0.60)
        draw_line(Vector2(x, y - 9.0), Vector2(x, y), Color(0.24, 0.65, 1.0, alpha), 2.5)
        draw_circle(Vector2(x, y), 3.3, Color(0.40, 0.80, 1.0, alpha))
