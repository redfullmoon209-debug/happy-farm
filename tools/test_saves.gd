extends SceneTree
# Headless checks for save compatibility, data validation and file round trips.
const SAVES = preload("res://scripts/SaveData.gd")
var failures: int = 0

func check(value: bool, label: String) -> void:
    if not value:
        failures += 1
        printerr("SAVE TEST FAIL: " + label)

func _initialize() -> void:
    var plots: Array = []
    for i in range(24):
        plots.append({})
    plots[0] = {
        "crop": 2,
        "tilled": true,
        "wet": true,
        "water_time": Time.get_unix_time_from_system()-20.0
    }
    var seed_counts: Array = [3, 1, 0, 0, 0, 0]
    var state: Dictionary = {
        "coins": 192,
        "feed": 4,
        "pigs": 1,
        "seeds": seed_counts,
        "plots": plots
    }

    var normalized: Dictionary = SAVES.normalize(state)
    check(not normalized.is_empty(), "accept legacy flat save")
    check(int(normalized.get("coins", -1)) == 192, "preserve coins")
    check(normalized.has("plots") and normalized["plots"][0].get("crop", -1) == 2, "preserve planted crop")

    var packed: Dictionary = SAVES.package(state)
    var from_package: Dictionary = SAVES.normalize(JSON.parse_string(JSON.stringify(packed)))
    check(not from_package.is_empty(), "parse exported JSON backup")
    check(int(from_package.get("coins", -1)) == 192, "preserve backup balance")
    check(SAVES.normalize({"hello": "world"}).is_empty(), "reject unrelated JSON")

    var wrong_game: Dictionary = packed.duplicate(true)
    wrong_game["format"] = "unrelated-game"
    check(SAVES.normalize(wrong_game).is_empty(), "reject different game")
    var wrong_version: Dictionary = packed.duplicate(true)
    wrong_version["version"] = 99
    check(SAVES.normalize(wrong_version).is_empty(), "reject unknown save version")
    var bad_crop: Dictionary = state.duplicate(true)
    bad_crop["plots"][0]["crop"] = 999
    check(SAVES.normalize(bad_crop).is_empty(), "reject invalid crop id")

    var path: String = "user://happy_farm_test_save.json"
    check(SAVES.save_to(path, state), "save data to user files")
    var loaded: Dictionary = SAVES.load_from(path)
    check(int(loaded.get("coins", -1)) == 192, "load saved balance")
    check(loaded.has("seeds") and loaded["seeds"].size() == 6, "load seeds")
    DirAccess.remove_absolute(ProjectSettings.globalize_path(path))

    if failures == 0:
        print("SAVE TESTS PASS: legacy saves, export/import validation and file round trip")
        quit(0)
    else:
        printerr("%d save tests failed" % failures)
        quit(1)
