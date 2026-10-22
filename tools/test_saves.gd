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

    # New saves explicitly carry plot and pen counts.
    var farm: Dictionary = updated.duplicate(true)
    farm["coins"] = 430
    farm["pens"] = 3
    farm["pigs"] = 9
    var normalized: Dictionary = SAVES.normalize(farm)
    check(not normalized.is_empty(), "new 50-plot save with 3 pens and 9 pigs")
    check(int(normalized.get("pens", -1)) == 3, "persist purchased pens")
    check(int(normalized.get("pigs", -1)) == 9, "persist purchased pigs")
    var package_data: Dictionary = SAVES.package(farm)
    var export_import: Dictionary = SAVES.normalize(JSON.parse_string(JSON.stringify(package_data)))
    check(export_import.size() > 0, "export and import new format")
    check(int(export_import.get("pens", -1)) == 3, "backup preserves pen count")

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
