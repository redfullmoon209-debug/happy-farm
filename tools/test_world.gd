extends SceneTree
# Regression suite for the 450x450 purchasable land, shop furniture and GM playtest.
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

    # Restore the clean one-parcel starting state before isolated checks.
    game.unlocked_zones = [171]
    game.coins = 250
    game.placed_decor_data.clear()
    game.decor_kits = [0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0]
    game.saved_extra_plots.clear()
    game.plot_kits = 0
    game.placed_trees_data.clear()
    game._refresh_land_zones()
    game._rebuild_placed_world()

    check(game.WORLD_SIZE == 450.0, "world spans 450x450 units")
    check(game.zone_covers.size() == 324 and game.zone_signs.size() == 324, "324 land sectors are drawn")
    check(game.unlocked_zones.size() == 1, "new farmer owns one 25m sector")
    check(game.is_land_owned(Vector3(0,0,0)) and not game.is_land_owned(Vector3(-29,0,-15)), "starter centered and outside locked")
    check(not game.is_land_owned(Vector3(-60,0,-20)), "adjacent expansion is initially locked")
    check(not game.is_land_owned(Vector3(199,0,199)), "distant corner is initially locked")
    check(game.zone_can_be_bought(170), "only touching sectors are buyable")
    check(not game.zone_can_be_bought(0), "cannot buy disconnected corner")
    check(game.zone_price(170) == 300, "first 25x25 parcel costs 300 farm coins")
    check(not game.buy_land_zone(170), "cannot buy without enough money")
    check(game.coins == 250 and game.unlocked_zones.size() == 1, "failed purchase does not change balance")

    game.farmer.position = Vector3(-11,0,0)
    game.move_actor(Vector3(-1,0,0), 8.0, 1.0)
    check(game.farmer.position.x >= -12.5, "player cannot walk into locked land")
    game.coins = 5000
    check(game.buy_land_zone(170), "adjacent parcel can be bought with earned coins")
    check(game.coins == 4700, "parcel purchase subtracts exactly 300")
    check(game.unlocked_zones.size() == 2 and not game.zone_covers[170].visible, "new zone is visibly opened")
    check(game.zone_can_be_bought(169), "new adjacent region becomes buyable")
    game.move_actor(Vector3(-1,0,0), 8.0, 1.0)
    check(game.farmer.position.x < -12.5, "player can enter purchased land")

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
    game.gm_coin_input.value = 23456
    game.gm_set_money()
    check(game.coins == 23456, "GM sets exact coin balance")
    game.gm_level_input.value = 7
    game.gm_set_exact_level()
    check(game.farm_level == 7, "GM sets exact farm level")
    # The player MUST own and consume an item for each permanent sex switch.
    # GM testing no longer grants a free bypass of the item requirement.
    var old_position: Vector3 = game.farmer.position
    var old_gender: String = game.avatar_gender
    game.gender_change_tickets = 0
    game.consume_gender_change_ticket()
    check(game.avatar_gender == old_gender, "gender cannot change for free")
    game.buy_gender_change_ticket()
    check(game.gender_change_tickets == 1, "gender change card can be bought")
    game.consume_gender_change_ticket()
    check(game.avatar_gender != old_gender and game.farmer.position == old_position, "item changes sex preserving position")
    check(game.gender_change_tickets == 0, "gender change item is consumed")
    check(SAVES.normalize(game.snapshot()).get("avatar_gender") == game.avatar_gender, "avatar gender survives save normalization")
    game.buy_gender_change_ticket()
    game.consume_gender_change_ticket()
    check(game.avatar_gender == old_gender, "second item switches avatar back")

    var buy_position: Vector3 = Vector3(-23,0,3)
    check(game._can_place_on_grass(buy_position, "plot"), "free placement works inside purchased remote parcel")
    game.buy_plot_kit()
    check(game._place_new_plot(buy_position), "place crop plot on newly owned zone")
    check(game.plots.size() == 51 and game.is_plot_unlocked(50), "new bed works independently of level")
    check(not game._can_place_on_grass(buy_position, "plot"), "overlap is rejected")

    var decor_position: Vector3 = Vector3(-23,0,8)
    game.buy_decor_kit(0)
    check(game.tool_mode == "place_decor" and game.landscaping_mode, "shopping activates furniture placement")
    check(game._place_decoration(decor_position), "bench can be placed on new land")
    check(game.decor_nodes.size() == 1 and game.placed_decor_data.size() == 1, "bench appears in 3D")
    check(game.decor_kits[0] == 0, "placed item is consumed exactly once")
    check(not game._can_place_on_grass(decor_position, "plot"), "new furniture blocks overlapping beds")
    game.buy_decor_kit(4)
    check(game._place_decoration(Vector3(-20,0,-5)), "fountain can be placed in same expansion")
    check(game.decor_nodes.size() == 2, "two different purchased decorations coexist")

    var saved: Dictionary = SAVES.normalize(SAVES.package(game.snapshot()))
    check(not saved.is_empty(), "expanded farm passes existing backup validation")
    check(saved.get("unlocked_zones", []).has(170), "land ownership survives backup export")
    check(saved.get("placed_decor", []).size() == 2, "decoration placements survive backup export")
    check(saved.get("extra_plots", []).size() == 1, "new free-form plot survives backup export")
    var path: String = "user://happy_farm_world_test.json"
    check(SAVES.save_to(path, game.snapshot()), "expanded farm saves to browser-compatible file")
    var roundtrip: Dictionary = SAVES.load_from(path)
    check(roundtrip.get("unlocked_zones", []).has(170), "purchased area survives file round trip")
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
    check(SAVES.normalize(invalid).is_empty(), "reject decoration outside 450x450 map")

    # Never overwrite the player's real previous save from these tests.
    game._apply_snapshot(original_save)
    game._refresh_land_zones()
    game._rebuild_placed_world()
    check(game.save_game(), "restore original save after world test")

    if failures == 0:
        print("WORLD TESTS PASS: 450x450, land purchasing, movement, 16 decorations, GM and saves")
        quit(0)
    else:
        printerr("%d world test failures" % failures)
        quit(1)
