extends RefCounted
# All inventory captions live in code, never baked into PNG art.
# Add keys and languages here; no texture or icon needs to change.
const STRINGS: Dictionary = {
    "th": {
        "bag_title": "กระเป๋า",
        "headwear": "หมวก", "top": "เสื้อ", "gloves": "ถุงมือ",
        "bottom": "กางเกง", "shoes": "รองเท้า",
        "gender_male": "ชาย", "gender_female": "หญิง",
        "gender": "เพศ", "farm_level": "ฟาร์ม Lv.", "xp": "EXP",
        "coins": "เหรียญ", "worn": "สวมใส่",
        "empty_equipment": "ช่องว่าง — เลือกจากไอเทมด้านขวา",
        "bag_full": "ช่องเก็บไอเทม",
        "click_hint": "แตะไอเทมเพื่อใช้ / สวมใส่ • เลื่อนดูได้ 200 ช่อง",
        "wear": "สวมแล้ว", "equip": "แตะเพื่อสวม", "remove": "ถอด",
        "character_info": "ข้อมูลตัวละคร",
        "gender_ticket": "ใช้บัตรเปลี่ยนเพศ",
        "buy_shop": "ซื้อในร้านค้า",
        "unavailable": "ยังไม่มีชิ้นส่วนโมเดลสำหรับช่องนี้",
        "equipment_prompt": "เลือก%sจากช่องเก็บไอเทมด้านขวาเพื่อสวมใส่"
    },
    "en": {
        "bag_title": "Inventory",
        "headwear": "Head", "top": "Top", "gloves": "Glove",
        "bottom": "Pants", "shoes": "Shoes",
        "gender_male": "Male", "gender_female": "Female",
        "gender": "Gender", "farm_level": "Farm Lv.", "xp": "EXP",
        "coins": "Coins", "worn": "Equipped",
        "empty_equipment": "Empty slot — choose an item on the right",
        "bag_full": "Inventory slots",
        "click_hint": "Tap to use or equip • Scroll for 200 slots",
        "wear": "Equipped", "equip": "Tap to equip", "remove": "Remove",
        "character_info": "Character",
        "gender_ticket": "Use gender-change ticket",
        "buy_shop": "Buy in shop",
        "unavailable": "No separate 3D mesh for this equipment slot yet",
        "equipment_prompt": "Choose %s from the inventory on the right"
    }
}

static func label(key: String, locale: String = "th") -> String:
    var lang: String = "en" if locale.to_lower().begins_with("en") else "th"
    return str(STRINGS.get(lang, STRINGS["th"]).get(key, STRINGS["th"].get(key, key)))
