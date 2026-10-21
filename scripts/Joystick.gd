extends Control
# Thumb joystick that tracks a single finger and never steals other touches.
var direction: Vector2 = Vector2.ZERO
var finger_id: int = -1
var mouse_drag: bool = false

func _ready() -> void:
    mouse_filter = Control.MOUSE_FILTER_STOP
    custom_minimum_size = Vector2(144, 144)

func _input(event: InputEvent) -> void:
    if not visible:
        return
    if event is InputEventScreenTouch:
        if event.pressed and finger_id < 0 and get_global_rect().has_point(event.position):
            finger_id = event.index
            _move_stick(event.position)
            get_viewport().set_input_as_handled()
        elif not event.pressed and event.index == finger_id:
            finger_id = -1
            direction = Vector2.ZERO
            queue_redraw()
            get_viewport().set_input_as_handled()
    elif event is InputEventScreenDrag and event.index == finger_id:
        _move_stick(event.position)
        get_viewport().set_input_as_handled()
    elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
        if event.pressed and get_global_rect().has_point(event.position):
            mouse_drag = true
            _move_stick(event.position)
            get_viewport().set_input_as_handled()
        elif not event.pressed and mouse_drag:
            mouse_drag = false
            direction = Vector2.ZERO
            queue_redraw()
            get_viewport().set_input_as_handled()
    elif event is InputEventMouseMotion and mouse_drag:
        _move_stick(event.position)
        get_viewport().set_input_as_handled()

func _move_stick(screen: Vector2) -> void:
    var center: Vector2 = global_position + size * 0.5
    var travel: float = minf(size.x, size.y) * 0.31
    direction = ((screen - center) / maxf(1.0, travel)).limit_length(1.0)
    queue_redraw()

func _draw() -> void:
    var c: Vector2 = size * 0.5
    var r: float = minf(size.x, size.y) * 0.47
    draw_circle(c, r, Color(0.12, 0.29, 0.26, 0.37))
    draw_arc(c, r - 2.0, 0.0, TAU, 48, Color(0.97, 1.0, 0.97, 0.77), 3.0, true)
    draw_circle(c, r * 0.62, Color(1, 1, 1, 0.10))
    var thumb: Vector2 = c + direction * (r * 0.60)
    draw_circle(thumb, r * 0.36, Color("#e8f4e5"))
    draw_circle(thumb, r * 0.27, Color("#4b8d70"))
    draw_arc(thumb, r * 0.30, 0.0, TAU, 30, Color.WHITE, 2.0, true)
