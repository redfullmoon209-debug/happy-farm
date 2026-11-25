extends SceneTree
# Automated save migrations and pen-capacity regression tests.
const SAVES = preload("res://scripts/SaveData.gd")
var failures: int = 0

func check(value: bool, label: String) -> void:
    if not value:
        failures += 1
        printerr("SAVE TEST FAIL: " + label)

func _initialize() -> void:
    # A save made before the expansion contains only the original 24 plots.
    var legacy_plots: Array = []
    for i in range(24):
        legacy_plots.append({})
    legacy_plots[0] = {
        "crop": 2, "tilled": true, "wet": true,
        "water_time": Time.get_unix_time_from_system()-20.0
    }
    legacy_plots[23] = {"crop": 1, "tilled": true, "wet": false, "water_time": 0.0}
    var legacy: Dictionary = {
        "coins": 192, "feed": 4, "pigs": 1,
        "seeds": [3, 1, 0, 0, 0, 0], "plots": legacy_plots
    }
    var updated: Dictionary = SAVES.normalize(legacy)
    check(not updated.is_empty(), "accept old 24-plot save")
    check(updated.get("plots", []).size() == 50, "migrate plots to 50")
    check(updated.has("plots") and int(updated["plots"][2].get("crop", -1)) == 2, "preserve first planted crop in center row")
    check(updated.has("plots") and int(updated["plots"][37].get("crop", -1)) == 1, "preserve last planted crop")
    check(updated.has("pens") and int(updated["pens"]) == 1, "create initial pen for old saves")
    check(int(updated.get("coins", -1)) == 192, "keep legacy money")
    check(updated.get("seeds", []).size() == 6, "keep old seed inventory")
    check(int(updated.get("gender_change_tickets", -1)) == 0, "old saves begin without gender change tickets")
    check(updated.get("wardrobe_market_v1", false), "old saves migrate to purchased wardrobe economy")
    check(int(updated.get("clothing_owned", {}).get("female_survivor_shoes", -1)) == 0,
        "legacy free shoes do not bypass the new farm-coin shop")
    check(int(updated.get("clothing_owned", {}).get("female_villager_gloves", -1)) == 0,
        "no invented free clothing is granted")
    check(SAVES.WARDROBE.available_item_ids().size() == 30,
        "three outfit collections and five separate pieces exist for both genders")
    check(SAVES.WARDROBE.shop_price("male_martial_top") > 0,
        "male modular shirt requires earned farm coins")
    check(SAVES.WARDROBE.shop_price("female_survivor_bottom") > 0,
        "female modular bottom has an item price")

    # New saves explicitly carry plot and pen counts.
    var farm: Dictionary = updated.duplicate(true)
    farm["coins"] = 430
    farm["pens"] = 3
    farm["pigs"] = 9
    farm["gender_change_tickets"] = 2
    farm["clothing_owned"]["female_survivor_shoes"] = 1
    farm["clothing_owned"]["female_martial_shoes"] = 1
    farm["clothing_equipped"] = {"shoes": "female_survivor_shoes"}
    var normalized: Dictionary = SAVES.normalize(farm)
    check(not normalized.is_empty(), "new 50-plot save with 3 pens and 9 pigs")
    check(int(normalized.get("pens", -1)) == 3, "persist purchased pens")
    check(int(normalized.get("pigs", -1)) == 9, "persist purchased pigs")
    check(int(normalized.get("gender_change_tickets", -1)) == 2, "persist purchased gender cards")
    check(str(normalized.get("clothing_equipped", {}).get("shoes", "")) == "female_survivor_shoes", "persist individual clothing slot")
    var mixed_clothes: Dictionary = farm.duplicate(true)
    mixed_clothes["clothing_equipped"] = {"shoes": "female_martial_shoes"}
    var mixed_save: Dictionary = SAVES.normalize(mixed_clothes)
    check(str(mixed_save.get("clothing_equipped", {}).get("shoes", "")) == "female_martial_shoes",
        "purchased shoes can be switched without replacing the avatar")
    var unowned: Dictionary = farm.duplicate(true)
    unowned["clothing_equipped"] = {"top": "female_villager_top"}
    check(SAVES.normalize(unowned).get("clothing_equipped", {}).is_empty(),
        "cannot equip unpaid garment from old character page")
    var forbidden_mix: Dictionary = farm.duplicate(true)
    forbidden_mix["clothing_equipped"] = {"gloves": "male_martial_gloves"}
    check(SAVES.normalize(forbidden_mix).get("clothing_equipped", {}).is_empty(),
        "incompatible equipment is not applied")
    var purchased_mixed: Dictionary = farm.duplicate(true)
    purchased_mixed["clothing_owned"]["female_villager_top"] = 1
    purchased_mixed["clothing_owned"]["female_martial_gloves"] = 1
    purchased_mixed["clothing_equipped"] = {
        "top": "female_villager_top",
        "gloves": "female_martial_gloves"
    }
    check(SAVES.normalize(purchased_mixed).get("clothing_equipped", {}).size() == 2,
        "save preserves independently equipped purchased top and gloves")
    var purchased_male: Dictionary = farm.duplicate(true)
    purchased_male["avatar_gender"] = "male"
    purchased_male["clothing_owned"]["male_survivor_bottom"] = 1
    purchased_male["clothing_equipped"] = {"bottom": "male_survivor_bottom"}
    check(str(SAVES.normalize(purchased_male).get("clothing_equipped", {}).get("bottom", "")) == "male_survivor_bottom",
        "male modular trousers survive a saved game")
    var package_data: Dictionary = SAVES.package(farm)
    var export_import: Dictionary = SAVES.normalize(JSON.parse_string(JSON.stringify(package_data)))
    check(export_import.size() > 0, "export and import new format")
    check(int(export_import.get("pens", -1)) == 3, "backup preserves pen count")
    check(int(export_import.get("gender_change_tickets", -1)) == 2, "backup preserves gender cards")
    check(export_import.get("clothing_equipped", {}).get("shoes", "") == "female_survivor_shoes", "backup preserves equipped shoes")

    var maximum: Dictionary = farm.duplicate(true)
    maximum["pens"] = 4
    maximum["pigs"] = 16
    check(not SAVES.normalize(maximum).is_empty(), "allow 4 pens and 16 pigs")
    var beyond_capacity: Dictionary = farm.duplicate(true)
    beyond_capacity["pens"] = 1
    beyond_capacity["pigs"] = 5
    check(SAVES.normalize(beyond_capacity).is_empty(), "reject more pigs than pen capacity")
    var too_many_pens: Dictionary = maximum.duplicate(true)
    too_many_pens["pens"] = 5
    check(SAVES.normalize(too_many_pens).is_empty(), "reject 5 pens")
    var too_many_pigs: Dictionary = maximum.duplicate(true)
    too_many_pigs["pigs"] = 17
    check(SAVES.normalize(too_many_pigs).is_empty(), "reject 17 pigs")
    var invalid_crop: Dictionary = farm.duplicate(true)
    invalid_crop["plots"][2]["crop"] = 999
    check(SAVES.normalize(invalid_crop).is_empty(), "reject invalid crop")
    check(SAVES.normalize({"unrelated": true}).is_empty(), "reject unrelated data")
    var negative_cards: Dictionary = farm.duplicate(true)
    negative_cards["gender_change_tickets"] = -1
    check(SAVES.normalize(negative_cards).is_empty(), "reject negative gender card counts")
    var invalid_outfit: Dictionary = farm.duplicate(true)
    invalid_outfit["clothing_equipped"] = {"top": "missing_skin"}
    check(SAVES.normalize(invalid_outfit).is_empty(), "reject items without real compatible model")

    # Exercise both flat autosaves and versioned downloaded backups.
    var path: String = "user://happy_farm_expansion_test.json"
    check(SAVES.save_to(path, farm), "write 50-plot save")
    var loaded: Dictionary = SAVES.load_from(path)
    check(int(loaded.get("pigs", -1)) == 9, "reload pigs")
    check(int(loaded.get("pens", -1)) == 3, "reload pens")
    check(loaded.get("plots", []).size() == 50, "reload 50 plots")
    DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
    check(SAVES.normalize(package_data).has("plots"), "open downloaded backup")

    if failures == 0:
        print("SAVE TESTS PASS: legacy 24-to-50 expansion, pen purchases, pig capacity, backups and round trip")
        quit(0)
    else:
        printerr("%d save tests failed" % failures)
        quit(1)
