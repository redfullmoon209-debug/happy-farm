extends SceneTree
# Send events through Godot's Input/Viewport pipeline, including the mouse
# events it synthesizes BEFORE raw touch. Calling Game._input alone misses it.
class CameraFarm:
    extends "res://scripts/Game.gd"
    var plot_taps: int = 0
    func click_plot(_pixel: Vector2) -> void:
        plot_taps += 1

var farm: CameraFarm
var problems: Array[String] = []
var checks: int = 0
var positions: Dictionary = {}

func _initialize() -> void:
    call_deferred("_check")

func expect(okay: bool, label: String) -> void:
    checks += 1
    if not okay:
        problems.append(label)

func send(event: InputEvent) -> void:
    # Test positions are logical viewport coordinates; the Input singleton
    # expects physical window coordinates before Godot's stretch transform.
    Input.parse_input_event(event.xformed_by(root.get_final_transform()))
    Input.flush_buffered_events()

func touch(id: int, pos: Vector2, pressed: bool = true, canceled: bool = false) -> void:
    var event: InputEventScreenTouch = InputEventScreenTouch.new()
    event.index = id
    event.position = pos
    event.pressed = pressed
    event.canceled = canceled
    send(event)
    if pressed and not canceled:
        positions[id] = pos
    else:
        positions.erase(id)

func drag(id: int, pos: Vector2) -> void:
    var event: InputEventScreenDrag = InputEventScreenDrag.new()
    event.index = id
    event.position = pos
    event.relative = pos - Vector2(positions.get(id, pos))
    send(event)
    positions[id] = pos

func release_all() -> void:
    for id: int in positions.keys():
        touch(id, positions[id], false)

func mouse(button: MouseButton, pressed: bool, pos: Vector2) -> void:
    var event: InputEventMouseButton = InputEventMouseButton.new()
    event.button_index = button
    event.pressed = pressed
    event.position = pos
    event.global_position = pos
    send(event)

func reset() -> void:
    release_all()
    farm._reset_camera_input()
    farm.shop_panel.hide()
    farm.bag_panel.hide()
    farm.restore_confirm.hide()
    farm.camera_yaw = 0.65
    farm.camera_pitch = -0.79
    farm.set_camera_zoom(39.0)
    farm.plot_taps = 0
    farm.jumping = 0.0
    farm.jump_velocity = 0.0
    farm.run_toggle = false

func _check() -> void:
    Input.emulate_mouse_from_touch = true
    farm = CameraFarm.new()
    root.add_child(farm)
    farm.set_process(false) # No farming/autosave side effects in input tests.
    # Keep headless dummy-audio playbacks out of this input-only fixture.
    # Audio has its own integration suite; no preference file is written here.
    farm.farm_audio.enabled = false
    farm.farm_audio.unlocked = true
    await process_frame
    var saved_state: Dictionary = farm.snapshot()
    var a: Vector2 = Vector2(590, 240)
    var b: Vector2 = Vector2(810, 240)
    expect(not farm.point_on_ui(a) and not farm.point_on_ui(b), "world gesture test points must be outside UI")

    # A tap commits once on release, never on the synthesized mouse-down.
    touch(7, a)
    expect(farm.plot_taps == 0, "touch-down must not work a plot")
    touch(7, a, false)
    expect(farm.plot_taps == 1, "single tap must work a plot exactly once")
    reset()
    touch(8, a)
    touch(8, a, false, true)
    expect(farm.plot_taps == 0 and farm.camera_touches.is_empty(), "canceled tap must release without working a plot")
    touch(8, a)
    touch(8, a + Vector2(70, 0), false)
    expect(farm.plot_taps == 0, "large release movement must not count as a tap even without a drag event")

    reset()
    touch(2, a)
    var yaw: float = farm.camera_yaw
    drag(2, a + Vector2(4, 0))
    expect(is_equal_approx(farm.camera_yaw, yaw), "tap jitter must not orbit")
    drag(2, a + Vector2(64, 20))
    expect(farm.camera_yaw < yaw, "one world finger must orbit")
    release_all()
    expect(farm.plot_taps == 0, "orbit release must not work a plot")

    # Spread/huddle, no yaw drift while pinching, third fingers cannot replace
    # either owner, and lifting either finger cannot turn into a plot tap.
    for lifted: int in [2, 11]:
        reset()
        touch(2, a)
        touch(11, b)
        var distance: float = farm.camera_distance
        var size_before: float = farm.camera.size
        yaw = farm.camera_yaw
        var pitch: float = farm.camera_pitch
        drag(11, b + Vector2(100, 0))
        expect(farm.camera_distance < distance and farm.camera.size < size_before, "spread must zoom in the orthographic view")
        var closer: float = farm.camera_distance
        drag(11, b)
        expect(farm.camera_distance > closer and is_equal_approx(farm.camera_distance, distance), "huddle must zoom out proportionally")
        expect(is_equal_approx(farm.camera_yaw, yaw) and is_equal_approx(farm.camera_pitch, pitch), "pinch must not orbit")
        touch(23, Vector2(980, 260))
        drag(23, Vector2(1030, 300))
        expect(farm.camera_touches.size() == 2 and is_equal_approx(farm.camera_distance, distance), "third world finger must not alter the pinch pair")
        touch(23, positions[23], false)
        touch(lifted, positions[lifted], false)
        var remaining: int = 11 if lifted == 2 else 2
        var last: Vector2 = positions[remaining]
        drag(remaining, last + Vector2(1, 0))
        expect(absf(farm.camera_yaw - yaw) < 0.01, "two-to-one transition must not jump the orbit")
        drag(remaining, last + Vector2(40, 0))
        expect(farm.camera_yaw < yaw, "remaining finger can orbit after pinch")
        release_all()
        expect(farm.plot_taps == 0 and farm.camera_touches.is_empty() and farm.touch_cam == -1, "pinch releases must not tap or leave stale fingers")

    reset()
    touch(2, a)
    touch(11, a) # Zero or nearly zero gaps must never divide by zero.
    drag(11, a + Vector2(1, 0))
    drag(11, a + Vector2(30, 0))
    expect(is_finite(farm.camera_distance) and is_equal_approx(farm.camera_distance, 39.0), "tiny pinch gaps must rebase safely")
    drag(11, a + Vector2(60, 0))
    expect(farm.camera_distance < 39.0, "pinch resumes after a degenerate gap")
    reset()
    touch(2, a)
    touch(11, b)
    touch(11, b, false, true)
    drag(2, a + Vector2(30, 0))
    release_all()
    expect(farm.plot_taps == 0 and farm.camera_touches.is_empty(), "canceling one pinch finger must not turn the other into a plot tap")

    # Movement and camera may operate simultaneously, with two more fingers
    # activating Run/Jump exactly once, independent of which finger was first.
    for stick_first: bool in [true, false]:
        reset()
        var center: Vector2 = farm.stick.get_global_rect().get_center()
        if stick_first:
            touch(0, center + Vector2(35, -20))
        touch(3, a)
        if not stick_first:
            touch(0, center + Vector2(35, -20))
        var direction: Vector2 = farm.stick.direction
        yaw = farm.camera_yaw
        drag(3, a + Vector2(30, 0))
        expect(farm.camera_yaw < yaw and farm.stick.direction.is_equal_approx(direction), "joystick plus orbit must keep independent owners")
        touch(4, b)
        var distance: float = farm.camera_distance
        drag(4, b + Vector2(70, 0))
        expect(farm.camera_distance < distance and farm.stick.finger_id == 0, "joystick plus pinch must zoom without stealing movement")
        for button: Button in [farm.run_button, farm.jump_button]:
            var pos: Vector2 = button.get_global_rect().get_center()
            touch(5, pos)
            touch(5, pos, false)
        expect(farm.run_toggle and farm.jump_velocity > 0.0, "run/jump must work while joystick and pinch are held")
        var before_move: Vector3 = farm.farmer.position
        farm._process(0.1)
        expect(farm.farmer.position.distance_to(before_move) > 0.1, "actor must still move while pinching")
        expect(farm.stick.direction.is_equal_approx(direction) and farm.plot_taps == 0, "action buttons must not change stick or work plots")
        release_all()
        expect(farm.stick.finger_id == -1 and farm.stick.direction == Vector2.ZERO, "joystick release after multitouch must recenter")

    # Test each action as the primary finger too, when Godot DOES emulate it.
    for button: Button in [farm.run_button, farm.jump_button, farm.zoom_in_button, farm.zoom_out_button]:
        reset()
        var pos: Vector2 = button.get_global_rect().get_center()
        touch(9, pos)
        touch(9, pos, false)
        if button == farm.run_button:
            expect(farm.run_toggle, "primary run touch must toggle exactly once")
        elif button == farm.jump_button:
            expect(farm.jump_velocity > 0.0, "primary jump touch must work")
        elif button == farm.zoom_in_button:
            expect(is_equal_approx(farm.camera_distance, 39.0 * 0.72), "primary zoom-in touch must execute once")
        else:
            expect(is_equal_approx(farm.camera_distance, 39.0 * 1.35), "primary zoom-out touch must execute once")
        expect(farm.camera_touches.is_empty() and farm.plot_taps == 0, "action finger must not enter camera or plot input")
        reset()
        touch(9, pos)
        drag(9, a)
        touch(9, a, false)
        expect(not farm.run_toggle and farm.jump_velocity == 0.0 and farm.camera_distance == 39.0 and farm.plot_taps == 0, "dragging off an action must cancel without becoming a world gesture")
        touch(9, pos)
        touch(9, pos, false, true)
        expect(not farm.run_toggle and farm.jump_velocity == 0.0 and farm.camera_distance == 39.0, "canceled action must not fire")

    reset()
    touch(2, a)
    drag(2, farm.run_button.get_global_rect().get_center())
    touch(2, farm.run_button.get_global_rect().get_center(), false)
    expect(not farm.run_toggle and farm.plot_taps == 0, "world finger crossing Run must keep camera ownership")
    reset()
    var center: Vector2 = farm.stick.get_global_rect().get_center()
    touch(0, center)
    drag(0, a)
    touch(0, a, false)
    expect(farm.camera_distance == 39.0 and farm.plot_taps == 0 and farm.stick.direction == Vector2.ZERO, "joystick finger crossing world must not work a plot or camera")
    reset()
    touch(9, farm.run_button.get_global_rect().get_center())
    touch(2, a)
    drag(2, a + Vector2(40, 0))
    expect(farm.camera_touches.size() == 1 and farm.camera_distance == 39.0, "held Run finger must not count toward a world pinch")
    release_all()

    # Ordinary GUI still receives emulated clicks; overlays block camera input.
    reset()
    var bag_pos: Vector2 = farm.bag_button.get_global_rect().get_center()
    touch(6, bag_pos)
    touch(6, bag_pos, false)
    expect(farm.bag_panel.visible, "native inventory GUI must still respond to touch")
    var bag_blank: Vector2 = farm.bag_panel.global_position + Vector2(8, 80)
    touch(7, bag_blank)
    drag(7, a)
    touch(7, a, false)
    expect(farm.camera_touches.is_empty() and farm.plot_taps == 0, "bag-owned touch cannot turn into camera or plot input")
    reset()
    farm.show_shop()
    touch(2, a)
    touch(11, b)
    drag(11, b + Vector2(90, 0))
    release_all()
    expect(farm.camera_distance == 39.0 and farm.camera_touches.is_empty(), "shop overlay must block world gestures")

    # Focus loss, browser interruption and orientation changes discard owners.
    for interruption: int in [Node.NOTIFICATION_WM_WINDOW_FOCUS_OUT, Node.NOTIFICATION_APPLICATION_FOCUS_OUT, Node.NOTIFICATION_APPLICATION_PAUSED, 0]:
        reset()
        touch(0, center + Vector2(25, 0))
        touch(2, a)
        touch(11, b)
        touch(5, farm.run_button.get_global_rect().get_center())
        if interruption == 0:
            farm.update_sizes()
        else:
            farm.notification(interruption)
        expect(farm.camera_touches.is_empty() and farm.touch_button_fingers.is_empty() and farm.stick.direction == Vector2.ZERO, "interruption must clear camera, action and joystick fingers")
        release_all()
        expect(farm.plot_taps == 0 and not farm.run_toggle, "late releases after interruption must not fire commands")
        touch(2, a)
        touch(11, b)
        drag(11, b + Vector2(40, 0))
        expect(farm.camera_distance < 39.0, "new pinch must work after interruption")

    # All zoom sources share limits; reverse motion at a clamp must respond
    # immediately rather than requiring the player to unwind an old baseline.
    reset()
    for target: float in [-100.0, 10000.0, NAN, INF]:
        farm.set_camera_zoom(target)
        expect(is_finite(farm.camera.size) and farm.camera_distance >= 6.0 and farm.camera_distance <= 78.0, "invalid/extreme zoom values must stay finite and bounded")
    for zoom_inward: bool in [true, false]:
        farm.set_camera_zoom(6.0 if zoom_inward else 78.0)
        touch(2, a)
        touch(11, b)
        drag(11, b + Vector2(100, 0) if zoom_inward else a + Vector2(30, 0))
        expect(is_equal_approx(farm.camera_distance, 6.0 if zoom_inward else 78.0), "pinch must clamp to the shared zoom limit")
        drag(11, b + Vector2(80, 0) if zoom_inward else a + Vector2(40, 0))
        expect(farm.camera_distance > 6.0 if zoom_inward else farm.camera_distance < 78.0, "pinch reversal must respond immediately at limit")
        release_all()

    reset()
    mouse(MOUSE_BUTTON_WHEEL_UP, true, a)
    expect(is_equal_approx(farm.camera_distance, 39.0 * 0.87), "PC mouse-wheel zoom-in must be preserved")
    mouse(MOUSE_BUTTON_WHEEL_DOWN, true, a)
    expect(is_equal_approx(farm.camera_distance, 39.0 * 0.87 * 1.15), "PC mouse-wheel zoom-out must be preserved")
    for step in range(60):
        mouse(MOUSE_BUTTON_WHEEL_UP, true, a)
    expect(farm.camera_distance == 6.0, "mouse wheel must respect minimum")
    for step in range(60):
        farm.zoom_out_button.pressed.emit()
    expect(farm.camera_distance == 78.0, "zoom buttons must respect maximum")
    yaw = farm.camera_yaw
    mouse(MOUSE_BUTTON_RIGHT, true, a)
    var motion: InputEventMouseMotion = InputEventMouseMotion.new()
    motion.position = a + Vector2(20, 0)
    motion.relative = Vector2(20, 0)
    send(motion)
    mouse(MOUSE_BUTTON_RIGHT, false, motion.position)
    expect(is_equal_approx(farm.camera_yaw, yaw - 20.0 * 0.007) and not farm.drag_camera, "PC right-mouse orbit must be preserved")
    farm.plot_taps = 0
    mouse(MOUSE_BUTTON_LEFT, true, a)
    mouse(MOUSE_BUTTON_LEFT, false, a)
    expect(farm.plot_taps == 1, "real PC mouse plot click must be preserved")

    # Check projected bed corners at maximum zoom on desktop and phone aspects.
    # Camera.size alone is not enough to prove a 50-bed map fits the viewport.
    reset()
    for viewport_size: Vector2i in [Vector2i(1280, 720), Vector2i(844, 390), Vector2i(390, 844)]:
        root.content_scale_size = viewport_size
        root.size = viewport_size
        await process_frame
        farm.update_sizes()
        farm.set_camera_zoom(78.0)
        var viewport_rect: Rect2 = root.get_visible_rect()
        var all_visible: bool = true
        for plot: Vector3 in farm.plot_places:
            for corner: Vector3 in [Vector3(-1.08, 0.22, -1.08), Vector3(1.08, 0.22, 1.08), Vector3(-1.08, 0.22, 1.08), Vector3(1.08, 0.22, -1.08)]:
                all_visible = all_visible and viewport_rect.has_point(farm.camera.unproject_position(plot + corner))
        expect(all_visible and farm.plot_places.size() == 50, "all 50 bed bounds must fit at maximum zoom: " + str(viewport_size))
        var far_size: float = farm.camera.size
        farm.set_camera_zoom(6.0)
        expect(farm.camera.size < far_size and farm.camera.size >= 3.6, "close orthographic zoom must remain usable: " + str(viewport_size))
        reset()
        var local_a: Vector2 = Vector2(viewport_size) * Vector2(0.38, 0.50)
        var local_b: Vector2 = Vector2(viewport_size) * Vector2(0.68, 0.50)
        expect(not farm.point_on_ui(local_a) and not farm.point_on_ui(local_b), "resized pinch points must stay outside UI: " + str(viewport_size))
        touch(2, local_a)
        touch(11, local_b)
        drag(11, local_b + Vector2(25, 0))
        expect(farm.camera_distance < 39.0, "pinch must still zoom after viewport/orientation change: " + str(viewport_size))
        release_all()
        expect(farm.plot_taps == 0 and farm.camera_touches.is_empty(), "resized pinch must not tap or leave stale owners: " + str(viewport_size))
    expect(farm.snapshot() == saved_state, "camera/input tests must preserve farm/save state")
    farm.queue_free()
    farm = null
    await process_frame
    if problems.is_empty():
        print("CAMERA TESTS PASS: %d checks (multitouch ownership, emulated mouse, cancellation, PC controls, 50-bed bounds)" % checks)
        quit(0)
    else:
        for problem in problems:
            printerr("CAMERA TEST FAIL: " + problem)
        quit(1)
