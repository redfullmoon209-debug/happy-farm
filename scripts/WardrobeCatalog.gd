extends RefCounted
# Shared FarmFlex wardrobe catalog. Starter is the existing embedded BaseBody,
# while Villager / Martial / Survival are independent equipment sets.
const SLOTS: Array[String] = ["headwear", "top", "gloves", "bottom", "shoes"]
const SETS: Dictionary = {
    "villager": {"th": "ชาวบ้าน", "en": "Villager"},
    "martial": {"th": "จอมยุทธ์", "en": "Martial"},
    "survivor": {"th": "ผู้รอดชีวิต", "en": "Survival"}
}
const PARTS: Dictionary = {
    "headwear": {"th": "หมวก", "en": "Hat"},
    "top": {"th": "เสื้อ", "en": "Top"},
    "gloves": {"th": "ถุงมือ", "en": "Gloves"},
    "bottom": {"th": "กางเกง/กระโปรง", "en": "Bottom"},
    "shoes": {"th": "รองเท้า", "en": "Shoes"}
}
# Keep legacy IDs so existing browser saves never lose their shoes.
const LEGACY_SHOES: Dictionary = {
    "female_martial_shoes": "female_martial_shoes",
    "female_survivor_shoes": "female_survivor_shoes"
}

static func item_id(gender: String, set_id: String, slot: String) -> String:
    return "%s_%s_%s" % [gender, set_id, slot]

static func all_items() -> Dictionary:
    var items: Dictionary = {}
    for gender in ["female", "male"]:
        for set_id in ["villager", "martial", "survivor"]:
            for slot in SLOTS:
                var id: String = item_id(gender, set_id, slot)
                items[id] = {
                    "name": "%s%s (%s)" % [str(PARTS[slot]["th"]), str(SETS[set_id]["th"]), "หญิง" if gender == "female" else "ชาย"],
                    "slot": slot, "gender": gender, "set": set_id
                }
    return items

# Same names as the source character creation/test page, not invented outfits.
# The currently shipped character GLBs contain only these individual garments.
# Never charge players for the missing top/glove/pants/hat meshes.
const SHOP_ITEMS: Dictionary = {
    "female_martial_shoes": 120,
    "female_survivor_shoes": 160
}
static func starter_inventory() -> Dictionary:
    var result: Dictionary = {}
    for id in all_items().keys():
        result[id] = 0
    return result

static func migrate_inventory(old: Dictionary) -> Dictionary:
    var result: Dictionary = starter_inventory()
    for id in result.keys():
        if old.has(id):
            result[id] = clampi(int(old[id]), 0, 99)
    return result

static func shop_price(item_id: String) -> int:
    return int(SHOP_ITEMS.get(item_id, -1))
