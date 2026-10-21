extends Control
# Decorative icons are shapes, never emojis. No missing-font boxes.
var kind: String = "coin"

func _ready() -> void:
    custom_minimum_size = Vector2(24, 24)
    mouse_filter = Control.MOUSE_FILTER_IGNORE

func _draw() -> void:
    var c: Vector2 = size * 0.5
    match kind:
        "coin":
            draw_circle(c, 10, Color("#f8cc62"))
            draw_arc(c, 7.6, 0, TAU, 24, Color("#b9893e"), 2, true)
            draw_line(c + Vector2(-4, 0), c + Vector2(4, 0), Color("#ab7b2f"), 2, true)
        "seed":
            draw_line(c + Vector2(0, 10), c + Vector2(0, -6), Color("#397c47"), 3, true)
            draw_circle(c + Vector2(-5, -6), 6, Color("#82c778"))
            draw_circle(c + Vector2(6, -7), 6, Color("#52a363"))
        "water":
            draw_colored_polygon(PackedVector2Array([c+Vector2(-8,-4),c+Vector2(6,-4),c+Vector2(4,9),c+Vector2(-7,9)]), Color("#71bbd7"))
            draw_arc(c + Vector2(-1,-4), 7, PI, TAU, 12, Color("#d7f3f6"), 2.3, true)
            draw_line(c + Vector2(5,-3),c + Vector2(12,-7),Color("#71bbd7"),3,true)
        "pig":
            draw_circle(c + Vector2(-7, -7), 5, Color("#e8a1af"))
            draw_circle(c + Vector2(7, -7), 5, Color("#e8a1af"))
            draw_circle(c, 10, Color("#f7adbb"))
            draw_circle(c + Vector2(0, 4), 5, Color("#d88397"))
            draw_circle(c + Vector2(-4,-2), 1.6, Color("#554351"))
            draw_circle(c + Vector2(4,-2), 1.6, Color("#554351"))
        "shop":
            draw_rect(Rect2(c - Vector2(9, 4), Vector2(18, 13)), Color("#e9c298"))
            draw_rect(Rect2(c - Vector2(11, 9), Vector2(22, 8)), Color("#f5a875"))
            draw_rect(Rect2(c + Vector2(-3, 1), Vector2(6, 8)), Color("#85593b"))
