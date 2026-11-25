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

# Three recognizable collection styles, now backed by modular 3D garment
# geometry generated in FarmFlexGarments.gd for both character rigs.
# They are new test garments, not missing GLB meshes from the selection page.
const SET_BASE_PRICES: Dictionary = {"villager": 60, "martial": 125, "survivor": 155}
const PART_PRICES: Dictionary = {"headwear": 20, "top": 45, "gloves": 20, "bottom": 35, "shoes": 30}

static func available_item_ids() -> Array[String]:
    var out: Array[String] = []
    for gender in ["female", "male"]:
        for set_id in ["villager", "martial", "survivor"]:
            for slot in SLOTS:
                out.append(item_id(gender, set_id, slot))
    return out

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
    var parts: PackedStringArray = item_id.split("_")
    if parts.size() != 3 or parts[0] not in ["female", "male"]:
        return -1
    if not SET_BASE_PRICES.has(parts[1]) or not PART_PRICES.has(parts[2]):
        return -1
    return int(SET_BASE_PRICES[parts[1]]) + int(PART_PRICES[parts[2]])
