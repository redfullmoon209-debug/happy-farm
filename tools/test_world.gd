extends SceneTree
# Regression suite for the 400x400 purchasable land, shop furniture and GM playtest.
const SAVES = preload("res://scripts/SaveData.gd")
var failures: int = 0

func check(okay: bool, name: String) -> void:
    if not okay:
        failures += 1
        printerr("WORLD TEST FAIL: " + name)

func _initialize() -> void:
    call_deferred("_test")

func _test() -> void:
    var scene: PackedScene = load("res://scenes/Main.tscn")
    check(scene != null, "main farm is loadable")
    if scene == null:
        quit(1)
        return
    var game: Variant = scene.instantiate()
    root.add_child(game)
    var original_save: Dictionary = game.snapshot()

    # Restore the clean 4-sector starting state before isolated checks.
    game.unlocked_zones = [44, 45, 54, 55]
    game.coins = 250
    game.placed_decor_data.clear()
    game.decor_kits = [0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0]
    game.saved_extra_plots.clear()
    game.plot_kits = 0
    game.placed_trees_data.clear()
    game._refresh_land_zones()
    game._rebuild_placed_world()

    check(game.WORLD_SIZE == 400.0, "world spans 400x400 units")
    check(game.zone_covers.size() == 100 and game.zone_signs.size() == 100, "100 land sectors are drawn")
    check(game.unlocked_zones.size() == 4, "new farmer owns the central four sectors")
    check(game.is_land_owned(Vector3(0,0,0)) and game.is_land_owned(Vector3(-29,0,-15)), "existing farm remains usable")
    check(not game.is_land_owned(Vector3(-60,0,-20)), "adjacent expansion is initially locked")
    check(not game.is_land_owned(Vector3(199,0,199)), "distant corner is initially locked")
    check(game.zone_can_be_bought(43), "only touching sectors are buyable")
    check(not game.zone_can_be_bought(0), "cannot buy disconnected corner")
    check(game.zone_price(43) == 300, "first 40x40 parcel costs 300 farm coins")
    check(not game.buy_land_zone(43), "cannot buy without enough money")
    check(game.coins == 250 and game.unlocked_zones.size() == 4, "failed purchase does not change balance")

    game.farmer.position = Vector3(-39,0,-20)
    game.move_actor(Vector3(-1,0,0), 8.0, 1.0)
    check(game.farmer.position.x >= -40.0, "player cannot walk into locked land")
    game.coins = 5000
    check(game.buy_land_zone(43), "adjacent parcel can be bought with earned coins")
    check(game.coins == 4700, "parcel purchase subtracts exactly 300")
    check(game.unlocked_zones.size() == 5 and not game.zone_covers[43].visible, "new zone is visibly opened")
    check(game.zone_can_be_bought(42), "new adjacent region becomes buyable")
    game.move_actor(Vector3(-1,0,0), 8.0, 1.0)
    check(game.farmer.position.x < -40.0, "player can enter purchased land")

    # All 50 original bed locks still operate independently of purchased land.
    game.farm_level = 1
    for i in range(50):
        game.plots[i] = {}
    game.update_plot_locks()
    check(game.unlocked_plot_count() == 5 and not game.is_plot_unlocked(0), "old crop progression remains intact")

    check(game.shop_decor_buttons.size() == 16 and game.decor_kits.size() == 16, "16 decoration types available in store")
    check(game.gm_button != null and game.GM_TEST_MODE, "temporary GM test button is installed")
    var credits_before: int = game.coins
    game.gm_grant_coins(10000)
    check(game.coins == credits_before + 10000, "GM grants test coins without requiring purchases")

    var buy_position: Vector3 = Vector3(-59,0,-19)
    check(game._can_place_on_grass(buy_position, "plot"), "free placement works inside purchased remote parcel")
    game.buy_plot_kit()
    check(game._place_new_plot(buy_position), "place crop plot on newly owned zone")
    check(game.plots.size() == 51 and game.is_plot_unlocked(50), "new bed works independently of level")
    check(not game._can_place_on_grass(buy_position, "plot"), "overlap is rejected")

    var decor_position: Vector3 = Vector3(-54,0,-20)
    game.buy_decor_kit(0)
    check(game.tool_mode == "place_decor" and game.landscaping_mode, "shopping activates furniture placement")
    check(game._place_decoration(decor_position), "bench can be placed on new land")
    check(game.decor_nodes.size() == 1 and game.placed_decor_data.size() == 1, "bench appears in 3D")
    check(game.decor_kits[0] == 0, "placed item is consumed exactly once")
    check(not game._can_place_on_grass(decor_position, "plot"), "new furniture blocks overlapping beds")
    game.buy_decor_kit(4)
    check(game._place_decoration(Vector3(-51,0,-27)), "fountain can be placed in same expansion")
    check(game.decor_nodes.size() == 2, "two different purchased decorations coexist")

    var saved: Dictionary = SAVES.normalize(SAVES.package(game.snapshot()))
    check(not saved.is_empty(), "expanded farm passes existing backup validation")
    check(saved.get("unlocked_zones", []).has(43), "land ownership survives backup export")
    check(saved.get("placed_decor", []).size() == 2, "decoration placements survive backup export")
    check(saved.get("extra_plots", []).size() == 1, "new free-form plot survives backup export")
    var path: String = "user://happy_farm_world_test.json"
    check(SAVES.save_to(path, game.snapshot()), "expanded farm saves to browser-compatible file")
    var roundtrip: Dictionary = SAVES.load_from(path)
    check(roundtrip.get("unlocked_zones", []).has(43), "purchased area survives file round trip")
    check(roundtrip.get("placed_decor", []).size() == 2, "furniture survives file round trip")
    DirAccess.remove_absolute(ProjectSettings.globalize_path(path))

    game._apply_snapshot(saved)
    game._refresh_land_zones()
    game._rebuild_placed_world()
    game._rebuild_placed_world()
    check(game.decor_nodes.size() == 2 and game.plots.size() == 51, "restoring repeatedly never duplicates decorations")

    var invalid: Dictionary = saved.duplicate(true)
    invalid["unlocked_zones"].append(999)
    check(SAVES.normalize(invalid).is_empty(), "reject invalid sector IDs")
    invalid = saved.duplicate(true)
    invalid["placed_decor"][0]["type"] = 999
    check(SAVES.normalize(invalid).is_empty(), "reject invalid decoration types")
    invalid = saved.duplicate(true)
    invalid["placed_decor"][0]["x"] = 222.0
    check(SAVES.normalize(invalid).is_empty(), "reject decoration outside 400x400 map")

    # Never overwrite the player's real previous save from these tests.
    game._apply_snapshot(original_save)
    game._refresh_land_zones()
    game._rebuild_placed_world()
    check(game.save_game(), "restore original save after world test")

    if failures == 0:
        print("WORLD TESTS PASS: 400x400, land purchasing, movement, 16 decorations, GM and saves")
        quit(0)
    else:
        printerr("%d world test failures" % failures)
        quit(1)
