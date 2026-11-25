extends Control
# FarmFlex ivory joystick artwork is independently authored in four layers.
# Each rendered transparent PNG is loaded independently; SVG masters remain editable.
const BASE_TEXTURE: Texture2D = preload("res://assets/ui/farmflex_joystick/joystick_base.png")
const ARROWS_TEXTURE: Texture2D = preload("res://assets/ui/farmflex_joystick/joystick_arrows.png")
const THUMB_TEXTURE: Texture2D = preload("res://assets/ui/farmflex_joystick/joystick_thumb.png")
const EFFECT_TEXTURE: Texture2D = preload("res://assets/ui/farmflex_joystick/joystick_effect.png")
# Thumb joystick that tracks a single finger and never steals other touches.
var direction: Vector2 = Vector2.ZERO
var finger_id: int = -1
var mouse_drag: bool = false

func _ready() -> void:
    mouse_filter = Control.MOUSE_FILTER_STOP
    custom_minimum_size = Vector2(144, 144)

func _input(event: InputEvent) -> void:
    if not is_visible_in_tree():
        return
    if event is InputEventMouse and event.device == InputEvent.DEVICE_ID_EMULATION:
        return
    if event is InputEventScreenTouch:
        if event.canceled and event.index == finger_id:
            reset_input()
            get_viewport().set_input_as_handled()
        elif event.pressed and not event.canceled and finger_id < 0 and get_global_rect().has_point(event.position):
            mouse_drag = false
            finger_id = event.index
            _move_stick(event.position)
            get_viewport().set_input_as_handled()
        elif not event.pressed and event.index == finger_id:
            finger_id = -1
            mouse_drag = false
            direction = Vector2.ZERO
            queue_redraw()
            get_viewport().set_input_as_handled()
    elif event is InputEventScreenDrag and event.index == finger_id:
        _move_stick(event.position)
        get_viewport().set_input_as_handled()
    elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
        # A touch browser may synthesize a duplicate left-mouse event.
        if finger_id >= 0:
            return
        if event.pressed and get_global_rect().has_point(event.position):
            mouse_drag = true
            _move_stick(event.position)
            get_viewport().set_input_as_handled()
        elif not event.pressed and mouse_drag:
            mouse_drag = false
            direction = Vector2.ZERO
            queue_redraw()
            get_viewport().set_input_as_handled()
    elif event is InputEventMouseMotion and mouse_drag and finger_id < 0:
        _move_stick(event.position)
        get_viewport().set_input_as_handled()

func reset_input() -> void:
    finger_id = -1
    mouse_drag = false
    direction = Vector2.ZERO
    queue_redraw()

func _move_stick(screen: Vector2) -> void:
    var center: Vector2 = global_position + size * 0.5
    var travel: float = minf(size.x, size.y) * 0.31
    direction = ((screen - center) / maxf(1.0, travel)).limit_length(1.0)
    queue_redraw()

func _draw() -> void:
    var center: Vector2 = size * 0.5
    var diameter: float = minf(size.x, size.y) * 0.94
    var base_rect: Rect2 = Rect2(center - Vector2.ONE*diameter*0.5, Vector2.ONE*diameter)
    draw_texture_rect(BASE_TEXTURE, base_rect, false)
    draw_texture_rect(ARROWS_TEXTURE, base_rect, false)
    # Glow is an independent artwork layer, only visible while steering.
    if direction.length_squared() > 0.012:
        draw_texture_rect(EFFECT_TEXTURE, base_rect, false, Color(1.0, 1.0, 1.0, 0.40))
    # Only the center knob with the new silver/red logo moves with a finger.
    var knob_diameter: float = diameter * 0.43
    var thumb_center: Vector2 = center + direction * diameter * 0.29
    var thumb_rect: Rect2 = Rect2(thumb_center - Vector2.ONE*knob_diameter*0.5, Vector2.ONE*knob_diameter)
    draw_texture_rect(THUMB_TEXTURE, thumb_rect, false)
