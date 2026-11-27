extends RefCounted
# Shared FarmFlex wardrobe catalog. Starter is the existing embedded BaseBody,
# while Villager / Martial / Survival are independent equipment sets.
const FEMALE = preload("res://scripts/FemaleWardrobe.gd")
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
                    "name": "%s%s (%s)" % [("ชุดเต็มตัว" if full_set(id) else str(PARTS[slot]["th"])), str(SETS[set_id]["th"]), "หญิง" if gender == "female" else "ชาย"],
                    "slot": slot, "gender": gender, "set": set_id
                }
    items.merge(FEMALE.ITEMS)
    return items

const SET_BASE_PRICES: Dictionary = {"villager": 60, "martial": 125, "survivor": 155}
const PART_PRICES: Dictionary = {"headwear": 20, "top": 45, "gloves": 20, "bottom": 35, "shoes": 30}

const SET_NAMES = {"villager":"Villager", "martial":"Martial", "survivor":"Survival"}
const PART_NAMES = {"headwear":"Head", "top":"Top", "gloves":"Gloves", "bottom":"Pants", "shoes":"Boots"}

static func full_set(id: String) -> bool:
    var parts := id.split("_")
    return parts.size() == 3 and parts[1] in ["villager", "martial"] and parts[2] in ["top", "bottom"]

static func mesh_name(id: String) -> String:
    if FEMALE.ITEMS.has(id):
        return FEMALE.ITEMS[id]["mesh"]
    var parts := id.split("_")
    if parts.size() != 3 or not SET_NAMES.has(parts[1]) or not PART_NAMES.has(parts[2]):
        return ""
    if parts[1] == "villager" and parts[2] in ["headwear", "gloves"]:
        return ""
    if parts[0] == "female":
        # Saved legacy items keep their identity, quantity and full-set occupancy.
        return ("Pink_" if parts[1] == "martial" else "Black_Red_") + parts[2]
    var part: String = "Full_Set" if full_set(id) else PART_NAMES[parts[2]]
    return "%s_%s_%s" % [parts[0].capitalize(), SET_NAMES[parts[1]], part]

static func available_item_ids() -> Array[String]:
    var out: Array[String] = []
    for id: String in all_items():
        if not mesh_name(id).is_empty():
            out.append(id)
    return out

static func wear(current: Dictionary, id: String, slot: String) -> Dictionary:
    var result := current.duplicate()
    if slot in ["top", "bottom"]:
        for key in ["top", "bottom"]:
            if full_set(str(result.get(key, ""))):
                result.erase(key)
    if full_set(id):
        result["top"] = id
        result["bottom"] = id
    elif not id.is_empty():
        result[slot] = id
    else:
        result.erase(slot)
    return result

static func restore_equipped(saved: Dictionary, owned: Dictionary, gender: String) -> Dictionary:
    var result := {}
    for slot in ["bottom", "top", "shoes", "gloves", "headwear"]:
        var id := str(saved.get(slot, ""))
        if id.begins_with(gender + "_") and int(owned.get(id, 0)) > 0 and not mesh_name(id).is_empty():
            if id.ends_with("_" + slot) or (full_set(id) and slot in ["top","bottom"]):
                result = wear(result, id, slot)
    return result

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
    if FEMALE.ITEMS.has(item_id):
        return FEMALE.ITEMS[item_id]["price"]
    var parts: PackedStringArray = item_id.split("_")
    if parts.size() != 3 or parts[0] not in ["female", "male"]:
        return -1
    if not SET_BASE_PRICES.has(parts[1]) or not PART_PRICES.has(parts[2]):
        return -1
    return int(SET_BASE_PRICES[parts[1]]) + int(PART_PRICES[parts[2]])
