extends SceneTree
# Integration test: the entire farm is playable and purchases have 3D effects.
var failures: int = 0

func check(okay: bool, reason: String) -> void:
    if not okay:
        failures += 1
        printerr("FARM TEST FAIL: " + reason)

func _initialize() -> void:
    call_deferred("_run_checks")

func _run_checks() -> void:
    var level: PackedScene = load("res://scenes/Main.tscn")
    check(level != null, "main scene exists")
    if level == null:
        quit(1)
        return
    var game: Node3D = level.instantiate()
    root.add_child(game)

    check(game.plot_places.size() == 50, "50 clickable plot coordinates")
    check(game.plant_roots.size() == 50, "50 distinct plant containers")
    check(game.plots.size() == 50, "50 saved plot records")
    check(game.pen_nodes.size() == game.pens, "visible starting pig pens")
    check(game.pig_nodes.size() == game.pigs, "all saved pigs visible")
    check(game.shop_pig_button != null, "buy pig button")
    check(game.shop_pen_button != null, "buy pen button")

    game.coins = 100000
    while game.pens < 4:
        var before: int = game.pens
        game.buy_pen()
        check(game.pens == before + 1, "pen purchase increases capacity")
        check(game.pen_nodes.size() == game.pens, "purchased pen appears in scene")
    while game.pigs < 16:
        var before: int = game.pigs
        game.buy_pig()
        check(game.pigs == before + 1, "pig purchase increments count")
        check(game.pig_nodes.size() == game.pigs, "purchased pig appears in scene")
    check(game.pens == 4 and game.pigs == 16, "4 pens accommodate 16 pigs")
    check(game.shop_pen_button.disabled, "shop stops extra pen purchases")
    check(game.shop_pig_button.disabled, "shop stops extra pig purchases")
    var held_coins: int = game.coins
    game.buy_pen()
    game.buy_pig()
    check(game.coins == held_coins, "no charges after reaching limits")

    if failures == 0:
        print("FARM TESTS PASS: 50 plots, 4 pens, 16 pigs, 3D purchases, capacity guards")
        quit(0)
    else:
        printerr("%d farm test failures" % failures)
        quit(1)
