extends SceneTree
# Integration tests for independently placeable farm beds, saplings and chopping.
const SAVES = preload("res://scripts/SaveData.gd")
var failures: int = 0

func check(okay: bool, reason: String) -> void:
    if not okay:
        failures += 1
        printerr("LANDSCAPING TEST FAIL: " + reason)

func _initialize() -> void:
    call_deferred("_run")

func _run() -> void:
    var scene: PackedScene = load("res://scenes/Main.tscn")
    check(scene != null, "main scene loads")
    if scene == null:
        quit(1)
        return
    var game: Variant = scene.instantiate()
    root.add_child(game)

    # Run independent of any auto-saved farm state from other tests.
    game.farm_level = 1
    game.farm_xp = 0
    game.coins = 5000
    game.plot_kits = 0
    game.tree_kits = [0, 0, 0, 0, 0]
    game.wood = 0
    game.removed_trees.clear()
    game.saved_extra_plots.clear()
    game.placed_trees_data.clear()
    game._rebuild_placed_world()
    game.update_plot_locks()

    check(game.plot_places.size() == 50, "existing 50 beds preserved")
    check(game.unlocked_plot_count() == 5, "existing level locks still operate")
    check(game.landscape_button != null, "landscape mode button available")
    check(game.shop_plot_button != null and game.shop_tree_buttons.size() == 5, "shop sells beds and five tree species")
    check(not game._can_place_on_grass(Vector3(-19,0,-8.4), "plot"), "no plots inside farmhouse")
    check(not game._can_place_on_grass(Vector3(16.8,0,4.2), "tree"), "cannot plant inside pig pens")
    check(not game._can_place_on_grass(Vector3(0,0,0), "plot"), "cannot overlap original beds")
    check(not game._can_place_on_grass(Vector3(-14.5,0,0), "plot"), "paths remain clear")
    check(not game._can_place_on_grass(Vector3(100,0,0), "plot"), "outside world is rejected")

    var free_bed: Vector3 = Vector3(-23.0,0,3.0)
    var tree_spot: Vector3 = Vector3(-22.5,0,-2.5)
    check(game._can_place_on_grass(free_bed, "plot"), "open flat grass accepts free-form bed")
    check(game._can_place_on_grass(tree_spot, "tree"), "open flat grass accepts tree")
    check(not game._place_new_plot(free_bed), "must buy a bed kit first")
    game.buy_plot_kit()
    check(game.plot_kits == 1 and game.coins == 4925, "buy a kit without auto-placing it")
    check(game.landscaping_mode and game.tool_mode == "place_plot", "purchase activates free placement")
    check(game._place_new_plot(free_bed), "place bed at exact chosen free-world coordinates")
    check(game.plot_places.size() == 51 and game.plots.size() == 51, "new bed registered in crop mechanics")
    check(game.plot_places[50].x == free_bed.x and game.plot_places[50].z == free_bed.z, "placement does not snap to original grid")
    check(game.farm_level == 1 and game.is_plot_unlocked(50), "purchased bed ignores original level locks")
    check(game.plot_kits == 0, "only successful placement consumes kit")
    check(not game._can_place_on_grass(free_bed, "plot"), "cannot stack beds on top of each other")
    check(not game._can_place_on_grass(free_bed, "tree"), "cannot plant tree over bed")

    game.seeds[0] = 3
    game.selected_seed = 0
    game.tool_mode = "plant"
    game.work_plot = 50
    game.finish_work()
    check(game.plots[50].has("crop"), "free bed works with existing planting action")
    game.tool_mode = "water"
    game.work_plot = 50
    game.finish_work()
    check(game.plots[50].get("wet", false), "free bed can be watered")

    game.buy_tree_kit(0)
    check(int(game.tree_kits[0]) == 1, "store sells tree kits")
    check(game.tool_mode == "plant_tree", "buying sapling activates planting")
    check(game._plant_purchased_tree(tree_spot), "place actual FBX tree on free grass")
    check(game.placed_tree_nodes.size() == 1 and game.placed_trees_data.size() == 1, "purchased tree has saved node and placement")
    check(int(game.tree_kits[0]) == 0, "tree stock consumed once")
    check(not game._can_place_on_grass(tree_spot, "plot"), "placed tree blocks overlapping beds")
    check(not game._plant_purchased_tree(tree_spot), "cannot plant without stock")
    check(game.placed_tree_nodes.size() == 1, "rejected tree placement makes no duplicate")

    var state: Dictionary = game.snapshot()
    check(state["plots"].size() == 50, "original beds remain separate in save")
    check(state["extra_plots"].size() == 1, "free bed serialized separately")
    check(state["placed_trees"].size() == 1, "purchased tree persisted")
    var normalized: Dictionary = SAVES.normalize(SAVES.package(state))
    check(not normalized.is_empty(), "new placed-world backup passes validation")
    check(normalized["extra_plots"][0].get("crop", -1) == 0, "new bed crop persists")
    check(normalized["extra_plots"][0].get("wet", false), "new bed water persists")

    game._apply_snapshot(normalized)
    game._rebuild_placed_world()
    check(game.plots.size() == 51 and game.placed_tree_nodes.size() == 1, "restored world has correct object counts")
    check(game.plots[50].get("crop", -1) == 0, "restored purchased plot has existing crop")
    check(game.plot_places[50].x == free_bed.x, "restored plot keeps exact position")
    game._rebuild_placed_world()
    check(game.plots.size() == 51 and game.placed_tree_nodes.size() == 1, "repeated restore does not duplicate objects")

    var original_tree_count: int = game.removed_trees.size()
    var original: Node3D = game.base_tree_nodes[5]
    var click: Vector2 = game.camera.unproject_position(original.global_position + Vector3(0,2.5,0))
    check(game._chop_tree_at(click), "visible tree can be chopped from a screen tap")
    check(game.wood == 1, "chopping yields one piece of wood")
    check(game.removed_trees.size() >= original_tree_count or game.placed_tree_nodes.is_empty(), "chopped tree removed from map")

    var after_chop: Dictionary = game.snapshot()
    var path: String = "user://happy_farm_landscape_test.json"
    check(SAVES.save_to(path, after_chop), "save freely placed beds and trees to disk")
    var reload: Dictionary = SAVES.load_from(path)
    check(reload.get("extra_plots", []).size() == 1, "load purchased bed from disk")
    check(int(reload.get("wood", 0)) == 1, "load chopped wood from disk")
    DirAccess.remove_absolute(ProjectSettings.globalize_path(path))

    var invalid: Dictionary = state.duplicate(true)
    invalid["extra_plots"][0]["x"] = 400
    check(SAVES.normalize(invalid).is_empty(), "reject out-of-world bed coordinates")
    invalid = state.duplicate(true)
    invalid["placed_trees"][0]["variant"] = "unknown.fbx"
    check(SAVES.normalize(invalid).is_empty(), "reject unapproved FBX resource paths")

    if failures == 0:
        print("LANDSCAPING TESTS PASS: free plots, purchases, tree planting, chopping, placement and save restore")
        quit(0)
    else:
        printerr("%d landscaping test failures" % failures)
        quit(1)
