extends SceneTree
# Level-gated farm progression, visible locks, XP and save compatibility.
const SAVES = preload("res://scripts/SaveData.gd")
var failures: int = 0

func check(okay: bool, reason: String) -> void:
    if not okay:
        failures += 1
        printerr("LEVEL TEST FAIL: " + reason)

func _initialize() -> void:
    call_deferred("_run_checks")

func _run_checks() -> void:
    var scene: PackedScene = load("res://scenes/Main.tscn")
    check(scene != null, "main scene exists")
    if scene == null:
        quit(1)
        return
    var game: Variant = scene.instantiate()
    root.add_child(game)

    # Start from a clean farm even when preceding tests wrote a browser save.
    game.farm_level = 1
    game.farm_xp = 0
    for i in range(game.plots.size()):
        game.plots[i] = {}
    game.update_plot_locks()

    check(game.plot_locks.size() == 50, "50 distinct 3D lock markers")
    check(game.unlocked_plot_count() == 5, "level 1 opens exactly five plots")
    check(game.is_plot_unlocked(43) and game.is_plot_unlocked(47), "starter beds are near the farmer")
    check(not game.is_plot_unlocked(0), "distant beds start locked")
    check(game.plot_locks[0].visible and not game.plot_locks[43].visible, "locked/open appearance matches access")
    check(game.farm_level_label != null, "farm level and EXP shown in UI")

    var seen: Dictionary = {}
    for i in range(50):
        var unlock_level: int = game.required_farm_level(i)
        check(unlock_level >= 1 and unlock_level <= 10, "required level stays within 1 to 10")
        seen[i] = game.PLOT_UNLOCK_ORDER.count(i)
    for i in range(50):
        check(seen[i] == 1, "plot unlock order covers each bed once")

    game.tool_mode = "plant"
    var seed_before: int = int(game.seeds[game.selected_seed])
    var coins_before: int = game.coins
    game.work_on(0)
    check(game.work_plot == -1, "locked plot cannot begin farm work")
    check(game.coins == coins_before and game.seeds[game.selected_seed] == seed_before, "locked action spends nothing")
    check(game.message.contains("Lv."), "locked plot explains its required level")

    game.work_plot = 43
    game.finish_work()
    check(game.plots[43].has("crop"), "planting allowed on starter bed")
    check(game.farm_xp == 8, "planting grants 8 EXP")
    check(game.seeds[game.selected_seed] == seed_before - 1, "planting consumes one seed")

    game.tool_mode = "water"
    game.work_plot = 43
    game.finish_work()
    check(game.plots[43].get("wet", false), "watering works")
    check(game.farm_xp == 12, "watering once grants 4 EXP")
    game.work_on(43)
    check(game.work_plot == -1 and game.farm_xp == 12, "repeated watering cannot farm EXP")

    game.plots[43]["water_time"] = Time.get_unix_time_from_system() - 200.0
    game.tool_mode = "harvest"
    game.work_plot = 43
    game.finish_work()
    check(game.farm_xp == 37, "harvesting grants 25 EXP")
    check(game.coins > coins_before, "harvesting keeps coin rewards")
    check(not game.plots[43].has("crop"), "harvest clears the crop")

    check(game.gain_farm_xp(38), "enough EXP levels the farm up")
    check(game.farm_level == 2 and game.farm_xp == 0, "level 2 carries correct EXP remainder")
    check(game.unlocked_plot_count() == 10, "level 2 opens ten beds")
    check(not game.plot_locks[40].visible, "newly unlocked beds remove their locks")
    check(game.plot_locks[33].visible, "level 3 remains locked at level 2")

    # An existing plot from a pre-levels save remains workable.
    game.farm_level = 1
    game.plots[0] = {"tilled": true}
    game.update_plot_locks()
    check(game.is_plot_unlocked(0), "legacy tilled plot remains available")
    check(not game.plot_locks[0].visible, "legacy plot is visibly usable")
    game.plots[0] = {}
    game.update_plot_locks()
    check(not game.is_plot_unlocked(0), "unused distant plot remains gated")

    # Level and EXP survive flat autosaves and versioned downloaded backups.
    game.farm_level = 4
    game.farm_xp = 83
    var state: Dictionary = game.snapshot()
    var normalized: Dictionary = SAVES.normalize(state)
    check(int(normalized.get("farm_level", 0)) == 4, "level survives save validation")
    check(int(normalized.get("farm_xp", -1)) == 83, "EXP survives save validation")
    var backup: Dictionary = SAVES.normalize(SAVES.package(state))
    check(int(backup.get("farm_level", 0)) == 4 and int(backup.get("farm_xp", -1)) == 83, "downloaded backup preserves progression")
    var save_path: String = "user://happy_farm_levels_test.json"
    check(SAVES.save_to(save_path, state), "write levelled farm")
    var loaded: Dictionary = SAVES.load_from(save_path)
    check(int(loaded.get("farm_level", 0)) == 4 and int(loaded.get("farm_xp", -1)) == 83, "level/EXP survive file round trip")
    DirAccess.remove_absolute(ProjectSettings.globalize_path(save_path))
    var invalid: Dictionary = state.duplicate(true)
    invalid["farm_level"] = 11
    check(SAVES.normalize(invalid).is_empty(), "reject impossible farm level")
    invalid = state.duplicate(true)
    invalid["farm_xp"] = -5
    check(SAVES.normalize(invalid).is_empty(), "reject negative EXP")

    game.farm_level = 9
    game.farm_xp = 0
    check(game.gain_farm_xp(game.xp_to_next_level()), "level 9 can reach level 10")
    check(game.farm_level == 10 and game.farm_xp == 0, "max level caps EXP")
    check(game.unlocked_plot_count() == 50, "max level unlocks all 50 beds")
    check(not game.plot_locks[0].visible, "last lock disappears at max level")

    if failures == 0:
        print("LEVEL TESTS PASS: 10 levels, 50 locks, EXP, old plots, backups and cap")
        quit(0)
    else:
        printerr("%d level test failures" % failures)
        quit(1)
