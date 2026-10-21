extends Control
# Procedural seed illustrations for inventory cards: no emoji or web assets.
var crop_id: int = 0

func _ready() -> void:
    custom_minimum_size = Vector2(54, 57)
    mouse_filter = Control.MOUSE_FILTER_IGNORE

func _draw() -> void:
    var c: Vector2 = size * 0.5
    # A seed packet with a cream label and a small illustrated vegetable.
    var packet: Rect2 = Rect2(c.x - 22, c.y - 24, 44, 49)
    draw_rect(packet, Color("#cba872"), true)
    draw_rect(Rect2(c.x - 19, c.y - 21, 38, 39), Color("#fff6d9"), true)
    draw_rect(Rect2(c.x - 19, c.y - 21, 38, 6), Color("#7aa47b"), true)
    draw_rect(Rect2(c.x - 14, c.y + 20, 28, 2), Color("#8c7758"), true)
    match crop_id:
        0: # Carrot
            draw_colored_polygon(PackedVector2Array([
                c+Vector2(-9,-5), c+Vector2(9,-5), c+Vector2(1,17)
            ]), Color("#ef9148"))
            draw_line(c+Vector2(-3,-5),c+Vector2(-9,-16),Color("#49955d"),3,true)
            draw_line(c+Vector2(1,-5),c+Vector2(2,-17),Color("#5ead6b"),3,true)
            draw_line(c+Vector2(4,-6),c+Vector2(10,-14),Color("#448f57"),3,true)
        1: # Lettuce
            for p in [Vector2(-10,4),Vector2(10,4),Vector2(-7,-5),Vector2(7,-6),Vector2(0,-11)]:
                draw_circle(c+p,8,Color("#83be65"))
            draw_circle(c+Vector2(0,3),11,Color("#add77e"))
            draw_line(c+Vector2(-7,2),c+Vector2(4,9),Color("#5f9c57"),2,true)
        2: # Tomato
            draw_circle(c+Vector2(0,2),14,Color("#e56155"))
            draw_circle(c+Vector2(0,-1),8,Color("#f17867"))
            for i in range(5):
                var angle: float = float(i)*TAU/5.0
                var tip: Vector2 = c+Vector2(sin(angle)*8,cos(angle)*8)-Vector2(0,12)
                draw_line(c+Vector2(0,-10),tip,Color("#4d985b"),3,true)
        3: # Corn
            draw_colored_polygon(PackedVector2Array([
                c+Vector2(-8,-12),c+Vector2(8,-12),c+Vector2(10,11),c+Vector2(-8,11)
            ]),Color("#edc960"))
            for x in [-4.0,2.0]:
                for y in [-7.0,0.0,7.0]:
                    draw_circle(c+Vector2(x,y),2.4,Color("#f6db82"))
            draw_colored_polygon(PackedVector2Array([
                c+Vector2(-9,13),c+Vector2(-15,-3),c+Vector2(-10,-11),c+Vector2(-2,13)
            ]),Color("#69a868"))
            draw_colored_polygon(PackedVector2Array([
                c+Vector2(9,13),c+Vector2(15,-3),c+Vector2(10,-11),c+Vector2(2,13)
            ]),Color("#609e60"))
        4: # Pumpkin
            draw_circle(c+Vector2(-7,4),11,Color("#e79543"))
            draw_circle(c+Vector2(7,4),11,Color("#e79543"))
            draw_circle(c+Vector2(0,4),13,Color("#f3a44e"))
            draw_line(c+Vector2(0,-8),c+Vector2(2,-15),Color("#527a4f"),4,true)
            draw_line(c+Vector2(-2,-4),c+Vector2(-3,14),Color("#d28239"),2,true)
            draw_line(c+Vector2(5,-4),c+Vector2(4,14),Color("#d28239"),2,true)
        5: # Strawberry
            draw_colored_polygon(PackedVector2Array([
                c+Vector2(-13,-6),c+Vector2(13,-6),c+Vector2(10,6),c+Vector2(0,17),c+Vector2(-10,6)
            ]),Color("#e35f72"))
            for p in [Vector2(-7,-1),Vector2(1,-2),Vector2(7,3),Vector2(-3,8),Vector2(1,12)]:
                draw_circle(c+p,1.7,Color("#ffe7a0"))
            draw_line(c+Vector2(0,-9),c+Vector2(0,-16),Color("#4d9560"),3,true)
            draw_line(c+Vector2(0,-8),c+Vector2(-10,-12),Color("#69aa61"),4,true)
            draw_line(c+Vector2(0,-8),c+Vector2(10,-12),Color("#69aa61"),4,true)
