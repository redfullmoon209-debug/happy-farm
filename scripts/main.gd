extends Control

# Happy Farm - native Godot 4 game for PC and Chrome (web export).
const SAVE_PATH = "user://happy_farm.json"
const ATLAS = preload("res://assets/tiny_farm.png")
const PLOT_VIEW = preload("res://scripts/plot_view.gd")
const FONT = preload("res://assets/NotoSansThai-Regular.ttf")
const CROPS = [
    {"name":"แครอต", "icon":"🥕", "cost":8, "sell":18, "seconds":15},
    {"name":"ผักกาด", "icon":"🥬", "cost":10, "sell":24, "seconds":20},
    {"name":"มะเขือเทศ", "icon":"🍅", "cost":12, "sell":28, "seconds":25},
    {"name":"ข้าวโพด", "icon":"🌽", "cost":18, "sell":43, "seconds":32},
    {"name":"ฟักทอง", "icon":"🎃", "cost":25, "sell":62, "seconds":45},
    {"name":"มันหวาน", "icon":"🍠", "cost":13, "sell":30, "seconds":25},
    {"name":"สตรอว์เบอร์รี", "icon":"🍓", "cost":20, "sell":54, "seconds":35},
    {"name":"แตงโม", "icon":"🍉", "cost":30, "sell":76, "seconds":50},
    {"name":"สับปะรด", "icon":"🍍", "cost":35, "sell":90, "seconds":55},
    {"name":"แอปเปิล", "icon":"🍎", "cost":40, "sell":103, "seconds":60},
    {"name":"ส้ม", "icon":"🍊", "cost":38, "sell":96, "seconds":55},
    {"name":"มะม่วง", "icon":"🥭", "cost":48, "sell":130, "seconds":70}
]
const BG := Color("#eaf5d8")
const INK := Color("#264331")
const GREEN := Color("#327a50")
const SOIL := Color("#75513b")
var money: int = 350
var feed: int = 4
var seeds: Array = []
var plots: Array = []
var pigs: Array = []
var selected_crop: int = 0
var mode: String = "plant"
var tab: String = "farm"
var status: String = "เลือกเมล็ดพืช แล้วแตะแปลงดินเพื่อปลูก"
var elapsed: float = 0.0
var page: VBoxContainer
var stat_label: Label
var tab_row: HBoxContainer
var plot_views: Array = []

func _ready() -> void:
    load_state()
    setup_ui()
    render()
    get_viewport().size_changed.connect(render)

func _process(delta: float) -> void:
    elapsed += delta
    if elapsed >= 1.0:
        elapsed = 0.0
        if tab == "farm" or tab == "pig":
            render()

func load_state() -> void:
    if not FileAccess.file_exists(SAVE_PATH):
        for i in range(CROPS.size()):
            seeds.append(3 if i < 3 else 0)
        for i in range(24):
            plots.append({})
        pigs = [{"hunger":75,"born":Time.get_unix_time_from_system()}]
        return
    var f = FileAccess.open(SAVE_PATH, FileAccess.READ)
    if f == null:
        return
    var data = JSON.parse_string(f.get_as_text())
    if not (data is Dictionary):
        return
    money = int(data.get("money", 350))
    feed = int(data.get("feed", 4))
    seeds = data.get("seeds", [])
    plots = data.get("plots", [])
    pigs = data.get("pigs", [])
    while seeds.size() < CROPS.size():
        seeds.append(0)
    while plots.size() < 24:
        plots.append({})

func save_state() -> void:
    var f = FileAccess.open(SAVE_PATH, FileAccess.WRITE)
    if f == null:
        return
    f.store_string(JSON.stringify({
        "money":money, "feed":feed, "seeds":seeds,
        "plots":plots, "pigs":pigs
    }))

func setup_ui() -> void:
    var back = ColorRect.new()
    back.color = BG
    back.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    back.mouse_filter = Control.MOUSE_FILTER_IGNORE
    add_child(back)
    var scroll := ScrollContainer.new()
    scroll.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
    add_child(scroll)
    page = VBoxContainer.new()
    page.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    page.add_theme_constant_override("separation", 12)
    scroll.add_child(page)
    var margin := MarginContainer.new()
    margin.add_theme_constant_override("margin_left", 18)
    margin.add_theme_constant_override("margin_right", 18)
    margin.add_theme_constant_override("margin_top", 12)
    margin.add_theme_constant_override("margin_bottom", 35)
    scroll.remove_child(page)
    scroll.add_child(margin)
    margin.add_child(page)

func label(parent: Node, value: String, font_size: int = 23, color: Color = INK) -> Label:
    var l := Label.new()
    l.text = value
    l.add_theme_font_override("font", FONT)
    l.add_theme_font_size_override("font_size", font_size)
    l.add_theme_color_override("font_color", color)
    l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    parent.add_child(l)
    return l

func button(parent: Node, value: String, callback: Callable, fill: Color = GREEN) -> Button:
    var b := Button.new()
    b.text = value
    b.custom_minimum_size = Vector2(105, 59)
    b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    b.add_theme_font_override("font", FONT)
    b.add_theme_font_size_override("font_size", 19)
    b.add_theme_color_override("font_color", Color.WHITE)
    var style := StyleBoxFlat.new()
    style.bg_color = fill
    style.set_corner_radius_all(12)
    style.set_content_margin_all(11)
    b.add_theme_stylebox_override("normal", style)
    var hover := style.duplicate()
    hover.bg_color = fill.lightened(0.12)
    b.add_theme_stylebox_override("hover", hover)
    var pressed := style.duplicate()
    pressed.bg_color = fill.darkened(0.15)
    b.add_theme_stylebox_override("pressed", pressed)
    b.pressed.connect(callback)
    parent.add_child(b)
    return b

func clear_page() -> void:
    for child in page.get_children():
        page.remove_child(child)
        child.queue_free()

func render() -> void:
    if page == null:
        return
    clear_page()
    plot_views.clear()
    label(page, "HAPPY FARM   |   ฟาร์มสุขใจ", 36, GREEN)
    label(page, "เหรียญ: %d     อาหารหมู: %d     หมู: %d ตัว" % [money, feed, pigs.size()], 22)
    var tabs := HBoxContainer.new()
    tabs.add_theme_constant_override("separation", 8)
    page.add_child(tabs)
    button(tabs, "แปลงผัก", func(): set_tab("farm"), GREEN if tab == "farm" else Color("#7f9784"))
    button(tabs, "คอกหมู", func(): set_tab("pig"), GREEN if tab == "pig" else Color("#7f9784"))
    button(tabs, "ร้านค้า", func(): set_tab("shop"), GREEN if tab == "shop" else Color("#7f9784"))
    label(page, status, 18, Color("#805c36"))
    if tab == "farm":
        render_farm()
    elif tab == "pig":
        render_pigs()
    else:
        render_shop()

func set_tab(name: String) -> void:
    tab = name
    render()

func render_farm() -> void:
    var preview := TextureRect.new()
    preview.texture = ATLAS
    preview.custom_minimum_size = Vector2(350, 165)
    preview.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
    preview.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
    preview.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
    page.add_child(preview)
    label(page, "เมล็ดที่เลือก: %s (เหลือ %d)   |   โหมด: %s" % [
        CROPS[selected_crop]["name"], int(seeds[selected_crop]),
        "รดน้ำ" if mode == "water" else "ปลูก/เก็บเกี่ยว"
    ], 20)
    var modes := HBoxContainer.new()
    page.add_child(modes)
    button(modes, "ปลูก / เก็บเกี่ยว", func(): change_mode("plant"), GREEN if mode=="plant" else Color("#7c937d"))
    button(modes, "รดน้ำ", func(): change_mode("water"), Color("#438ac3") if mode=="water" else Color("#7c937d"))
    label(page, "เลือกพืช", 21)
    var choose := GridContainer.new()
    choose.columns = 3 if get_viewport_rect().size.x < 660 else 4
    page.add_child(choose)
    for i in range(CROPS.size()):
        var crop: Dictionary = CROPS[i]
        button(choose, "%s  x%d" % [crop["name"], int(seeds[i])], choose_seed.bind(i),
            Color("#358158") if selected_crop == i else Color("#818d76"))
    label(page, "แตะช่องดิน: ปลูก / เก็บเกี่ยวเมื่อโต (ต้องรดน้ำก่อน)", 20)
    var grid := GridContainer.new()
    grid.columns = 3 if get_viewport_rect().size.x < 660 else 6
    grid.add_theme_constant_override("h_separation", 7)
    grid.add_theme_constant_override("v_separation", 7)
    page.add_child(grid)
    for i in range(plots.size()):
        var cell: Dictionary = plots[i]
        var plot = PLOT_VIEW.new()
        plot.custom_minimum_size = Vector2(120, 135)
        plot.pressed.connect(plot_pressed.bind(i))
        grid.add_child(plot)
        plot.set_plot(cell, CROPS)
        plot_views.append(plot)
    label(page, "คำแนะนำ: เมล็ดซื้อได้ที่ร้านค้า; ต้นไม้ผลไม้ในเวอร์ชันทดสอบปลูกและเก็บเกี่ยวเช่นเดียวกับผัก", 17)

func change_mode(value: String) -> void:
    mode = value
    render()

func choose_seed(i: int) -> void:
    selected_crop = i
    mode = "plant"
    render()

func plot_pressed(i: int) -> void:
    var cell: Dictionary = plots[i]
    if cell.is_empty():
        if mode == "water":
            status = "ช่องนี้ยังไม่มีต้นไม้"
        elif int(seeds[selected_crop]) <= 0:
            status = "เมล็ดหมด! ไปซื้อเพิ่มที่ร้านค้า"
            tab = "shop"
        else:
            seeds[selected_crop] = int(seeds[selected_crop]) - 1
            plots[i] = {"seed":selected_crop,"time":Time.get_unix_time_from_system(),"wet":false}
            status = "ปลูก%sแล้ว กดรดน้ำ!" % CROPS[selected_crop]["name"]
    else:
        var crop: Dictionary = CROPS[int(cell["seed"])]
        if mode == "water":
            cell["wet"] = true
            plots[i] = cell
            status = "รดน้ำ%sแล้ว" % crop["name"]
        elif Time.get_unix_time_from_system() - float(cell["time"]) >= float(crop["seconds"]) and bool(cell.get("wet", false)):
            money += int(crop["sell"])
            plots[i] = {}
            status = "เก็บเกี่ยว%s ขายได้ %d เหรียญ" % [crop["name"], int(crop["sell"])]
        else:
            status = "พืชยังไม่พร้อม ลองรดน้ำแล้วรอเติบโต"
    save_state()
    render()
    if i < plot_views.size():
        if mode == "water" and not plots[i].is_empty():
            plot_views[i].animate_water()
        else:
            plot_views[i].animate_plant()

func render_shop() -> void:
    label(page, "ร้านเมล็ดพันธุ์", 27, GREEN)
    var shop := GridContainer.new()
    shop.columns = 2 if get_viewport_rect().size.x < 660 else 3
    page.add_child(shop)
    for i in range(CROPS.size()):
        var crop: Dictionary = CROPS[i]
        button(shop, "%s\n%d เหรียญ / เมล็ด" % [crop["name"],crop["cost"]],
            buy_seed.bind(i), GREEN)
    label(page, "ของใช้และสัตว์เลี้ยง", 26, GREEN)
    button(page, "ซื้ออาหารหมู 5 ชุด = 35 เหรียญ", buy_feed)
    button(page, "ซื้อลูกหมู 1 ตัว = 150 เหรียญ", buy_pig)
    label(page, "เมื่อซื้อเสร็จให้กลับไปแปลงผัก หรือคอกหมู", 18)

func buy_seed(i: int) -> void:
    var crop: Dictionary = CROPS[i]
    if money < int(crop["cost"]):
        status = "เหรียญไม่พอซื้อเมล็ด%s" % crop["name"]
    else:
        money -= int(crop["cost"])
        seeds[i] = int(seeds[i]) + 1
        status = "ซื้อเมล็ด%s สำเร็จ" % crop["name"]
    save_state()
    render()

func buy_feed() -> void:
    if money < 35:
        status = "เหรียญไม่พอซื้ออาหาร"
    else:
        money -= 35
        feed += 5
        status = "ซื้ออาหารหมู 5 ชุดแล้ว"
    save_state()
    render()

func buy_pig() -> void:
    if money < 150:
        status = "เหรียญไม่พอซื้อลูกหมู"
    elif pigs.size() >= 8:
        status = "คอกหมูเต็มแล้ว (สูงสุด 8 ตัว)"
    else:
        money -= 150
        pigs.append({"hunger":75,"born":Time.get_unix_time_from_system()})
        status = "ลูกหมูย้ายเข้าคอกแล้ว!"
    save_state()
    render()

func render_pigs() -> void:
    label(page, "คอกหมู  |  รองรับหมู 8 ตัว", 27, GREEN)
    label(page, "ให้อาหารหมูจนความอิ่มเต็ม แล้วรับโบนัสเมื่อโต", 19)
    if pigs.is_empty():
        label(page, "ยังไม่มีหมู ไปที่ร้านค้าเพื่อซื้อลูกหมู", 20)
    for i in range(pigs.size()):
        var pig: Dictionary = pigs[i]
        var hunger := int(pig.get("hunger", 0))
        var age := Time.get_unix_time_from_system() - float(pig.get("born", 0))
        var row := HBoxContainer.new()
        page.add_child(row)
        label(row, "หมู #%d   อิ่ม %d/100   อายุ %ds" % [i+1,hunger,int(age)], 20)
        button(row, "ให้อาหาร", feed_pig.bind(i), Color("#ae7c41"))
        if hunger >= 100 and age > 30.0:
            button(row, "เก็บปุ๋ย +25", collect_fertilizer.bind(i), GREEN)
    button(page, "ไปซื้ออาหารและลูกหมูเพิ่ม", func(): set_tab("shop"))
    label(page, "ปุ๋ยในต้นแบบจำหน่ายทันทีเป็น 25 เหรียญ เพื่อให้ทดสอบเศรษฐกิจฟาร์มได้", 17)

func feed_pig(i: int) -> void:
    if feed <= 0:
        status = "อาหารหมูหมด ไปซื้อเพิ่มที่ร้านค้า"
    elif int(pigs[i]["hunger"]) >= 100:
        status = "หมูตัวนี้อิ่มแล้ว!"
    else:
        feed -= 1
        pigs[i]["hunger"] = mini(100, int(pigs[i]["hunger"]) + 25)
        status = "หมูกินอาหารแล้ว"
    save_state()
    render()

func collect_fertilizer(i: int) -> void:
    if int(pigs[i]["hunger"]) < 100:
        return
    if Time.get_unix_time_from_system() - float(pigs[i]["born"]) <= 30:
        return
    money += 25
    pigs[i]["hunger"] = 45
    pigs[i]["born"] = Time.get_unix_time_from_system()
    status = "เก็บปุ๋ยหมูสำเร็จ +25 เหรียญ"
    save_state()
    render()
