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

func _move_stick(screen: Vector2) -> void:
    var center: Vector2 = global_position + size * 0.5
    var travel: float = minf(size.x, size.y) * 0.31
    direction = ((screen - center) / maxf(1.0, travel)).limit_length(1.0)
    queue_redraw()

func _draw() -> void:
    var c: Vector2 = size * 0.5
    var r: float = minf(size.x, size.y) * 0.47
    # High-contrast analog base visible over bright farm grass and paths.
    draw_circle(c, r, Color(0.10, 0.24, 0.20, 0.76))
    draw_arc(c, r-2.0, 0.0, TAU, 48, Color("#e9f5de"), 3.0, true)
    draw_arc(c, r*0.69, 0.0, TAU, 40, Color(0.91, 0.97, 0.91, 0.28), 2.0, true)
    for arrow: Vector2 in [Vector2.UP, Vector2.DOWN, Vector2.LEFT, Vector2.RIGHT]:
        var point: Vector2 = c+arrow*(r*0.77)
        draw_line(point-arrow*5.0, point+arrow*3.0, Color("#d9e9d7"), 2.5, true)
    var thumb: Vector2 = c + direction * (r * 0.61)
    draw_circle(thumb, r * 0.36, Color("#f7fff1"))
    draw_circle(thumb, r * 0.29, Color("#4b9472"))
    draw_circle(thumb, r * 0.17, Color("#79c29a"))
    draw_arc(thumb, r * 0.31, 0.0, TAU, 32, Color.WHITE, 1.5, true)
