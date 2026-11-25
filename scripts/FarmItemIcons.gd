extends RefCounted
# Original vector item art for the farm store. These are actual colored icons,
# generated as independent transparent textures, never text abbreviations.
static var cache: Dictionary = {}

static func _svg_picture(kind: String, idx: int) -> String:
    var leaf: String = "<path d='M48 31 Q39 14 28 23 Q30 36 47 37 M49 30 Q60 13 71 23 Q67 36 50 38' fill='#579969'/>"
    var veggie: String = ""
    var colors: Array[String] = ["#e88942", "#83b969", "#df6252", "#e9c75d", "#e39b42", "#d85169"]
    var color: String = colors[posmod(idx, colors.size())]
    if kind == "seed":
        veggie = "<rect x='22' y='14' width='52' height='69' rx='4' fill='#c49c64' stroke='#836b4e' stroke-width='2'/><rect x='26' y='18' width='44' height='60' rx='2' fill='#fbf0d1'/><path d='M27 26H69' stroke='#7c9f70' stroke-width='7'/>"
    if kind in ["seed", "produce"]:
        match idx:
            0:
                veggie += "<path d='M38 42Q48 33 59 42L49 79Z' fill='#ed8b42' stroke='#b16c36' stroke-width='2'/>"+leaf
            1:
                veggie += "<ellipse cx='48' cy='57' rx='24' ry='20' fill='#7bb65b'/><ellipse cx='42' cy='49' rx='16' ry='16' fill='#acd879'/><path d='M28 57Q48 45 67 59' fill='none' stroke='#548b49' stroke-width='3'/>"
            2:
                veggie += "<circle cx='48' cy='57' r='22' fill='#e66354'/><circle cx='41' cy='48' r='10' fill='#f48568' opacity='.6'/>"+leaf
            3:
                veggie += "<path d='M38 30Q49 26 59 32L60 77Q49 85 37 76Z' fill='#edcc5e'/><path d='M37 76Q18 64 30 41L40 53M59 76Q78 59 67 40L57 54' fill='#5e9a5b'/><path d='M42 44H56M42 55H56M42 66H56' stroke='#d9ab43' stroke-width='2'/>"
            4:
                veggie += "<ellipse cx='48' cy='57' rx='27' ry='21' fill='#e7a148'/><ellipse cx='48' cy='57' rx='17' ry='21' fill='#f4b453'/><path d='M48 35V27' stroke='#658b55' stroke-width='5'/>"
            5:
                veggie += "<path d='M27 42Q48 27 69 42Q69 67 48 83Q27 67 27 42Z' fill='#d95869'/>"+leaf+"<g fill='#fff0a9'><circle cx='40' cy='51' r='2'/><circle cx='54' cy='50' r='2'/><circle cx='48' cy='65' r='2'/><circle cx='37' cy='64' r='2'/></g>"
    elif kind == "tree":
        veggie = "<path d='M44 60L42 84H55L52 60Z' fill='#8b6647'/>"
        match idx:
            0: veggie += "<circle cx='48' cy='41' r='25' fill='#58946a'/><circle cx='33' cy='44' r='14' fill='#78ab6d'/><circle cx='62' cy='39' r='16' fill='#78ad76'/>"
            1: veggie += "<path d='M48 8L20 62H76Z' fill='#4c8064'/><path d='M48 28L27 72H69Z' fill='#6b9c6d'/>"
            2: veggie += "<path d='M48 15Q8 15 24 54Q8 76 34 69L44 45M48 15Q88 15 72 54Q88 76 61 69L52 45' fill='#81ac69'/><circle cx='48' cy='35' r='19' fill='#649966'/>"
            3: veggie += "<ellipse cx='48' cy='37' rx='15' ry='31' fill='#588e6d'/>"
            4: veggie += "<path d='M48 9Q12 18 31 43Q8 59 35 65Q48 82 61 65Q88 59 65 43Q84 18 48 9Z' fill='#719c65'/>"
    elif kind == "decor":
        # Distinct silhouettes indexed by each of the 16 decoration meshes.
        var variety: int = posmod(idx, 8)
        var accent: String = ["#ba9267","#789b7e","#cf8a62","#e0c775","#7bb5be","#a9a2ac","#a7786e","#d1ad6e"][variety]
        match variety:
            0: veggie = "<path d='M18 53H78V64H18Z M25 64V80H33V64 M65 64V80H73V64 M23 31H73V45H23Z' fill='"+accent+"'/>"
            1: veggie = "<path d='M18 35H78M18 56H78M26 20V81M48 20V81M70 20V81' stroke='"+accent+"' stroke-width='8'/>"
            2: veggie = "<path d='M30 47H66L60 79H36Z' fill='"+accent+"'/><circle cx='48' cy='30' r='15' fill='#92bd79'/><circle cx='36' cy='33' r='8' fill='#ce8196'/><circle cx='59' cy='32' r='8' fill='#dca2aa'/>"
            3: veggie = "<path d='M44 32H52V81H44Z' fill='#696d6d'/><rect x='29' y='14' width='38' height='32' rx='4' fill='"+accent+"'/><path d='M34 20H62V40H34Z' fill='#fff2b9'/>"
            4: veggie = "<ellipse cx='48' cy='65' rx='33' ry='16' fill='"+accent+"'/><ellipse cx='48' cy='61' rx='26' ry='9' fill='#80c5c9'/><path d='M48 28V59' stroke='#b1bdb5' stroke-width='6'/>"
            5: veggie = "<path d='M48 25V82M18 41H78' stroke='#8a714c' stroke-width='7'/><circle cx='48' cy='23' r='12' fill='#e2c99d'/><path d='M35 44H61L69 68H27Z' fill='"+accent+"'/>"
            6: veggie = "<path d='M44 48V84' stroke='#7e6b54' stroke-width='8'/><rect x='20' y='20' width='56' height='33' fill='"+accent+"'/><path d='M27 31H69M29 40H67' stroke='#efd5a8' stroke-width='3'/>"
            7: veggie = "<path d='M16 55L36 23L55 50L72 31L85 61L62 81H28Z' fill='"+accent+"'/><path d='M21 61H79' stroke='#f2d38b' stroke-width='6'/>"
        if idx >= 8:
            veggie += "<circle cx='73' cy='75' r='10' fill='#a4bf94' stroke='#618863' stroke-width='3'/>"
    elif kind == "plot":
        veggie = "<path d='M10 62L38 25H87L61 67Z' fill='#8c613f'/><path d='M20 60L45 29M36 64L60 29M52 65L76 31' stroke='#c09061' stroke-width='7'/>"
    elif kind == "feed":
        veggie = "<path d='M26 26H70L76 77H20Z' fill='#b99a69' stroke='#826b4e' stroke-width='3'/><path d='M30 42H66' stroke='#f0d9a8' stroke-width='6'/><circle cx='48' cy='59' r='10' fill='#89a866'/>"
    elif kind == "pig":
        veggie = "<ellipse cx='48' cy='54' rx='28' ry='24' fill='#e8a6a4'/><ellipse cx='48' cy='63' rx='13' ry='10' fill='#d88689'/><circle cx='42' cy='61' r='3' fill='#9a6568'/><circle cx='54' cy='61' r='3' fill='#9a6568'/><circle cx='38' cy='45' r='3' fill='#664a48'/><circle cx='59' cy='45' r='3' fill='#664a48'/>"
    elif kind == "gender":
        veggie = "<circle cx='48' cy='45' r='22' fill='none' stroke='#887eab' stroke-width='7'/><path d='M48 68V83M37 76H59' stroke='#887eab' stroke-width='7'/><path d='M63 31L79 15M67 15H79V27' stroke='#708dbb' stroke-width='6' fill='none'/>"
    elif kind == "pen":
        veggie = "<path d='M17 25V80M35 25V80M61 25V80M79 25V80M16 42H80M16 67H80' stroke='#ae8758' stroke-width='8'/>"
    else:
        veggie = "<path d='M23 31H73V77H23Z' fill='#bda47e'/><path d='M29 38H67V70H29Z' fill='#e7d4a9'/>"
    return "<svg xmlns='http://www.w3.org/2000/svg' viewBox='0 0 96 96' width='96' height='96'>" + veggie + "</svg>"

static func texture(kind: String, idx: int = 0) -> Texture2D:
    var key: String = kind + "_" + str(idx)
    if cache.has(key):
        return cache[key]
    var pic: Image = Image.new()
    var xml: String = _svg_picture(kind, idx)
    var err: Error = pic.load_svg_from_buffer(xml.to_utf8_buffer(), 1.0)
    if err != OK or pic.is_empty():
        return null
    var result: Texture2D = ImageTexture.create_from_image(pic)
    cache[key] = result
    return result
