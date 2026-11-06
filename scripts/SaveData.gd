extends RefCounted
# Browser-friendly, versioned and validated Happy Farm save data.
# This module keeps existing flat user:// saves compatible.

const FORMAT: String = "happy-farm-save"
const VERSION: int = 1
const PREVIOUS: String = "user://happy_farm_previous.json"
const MAX_BYTES: int = 524288
const NUM_CROPS: int = 6
const NUM_PLOTS: int = 50
const OLD_PLOTS: int = 24
const PLOTS_PER_ROW: int = 10
const PIGS_PER_PEN: int = 4
const MAX_PENS: int = 4
const MAX_FARM_LEVEL: int = 10
const MAX_EXTRA_PLOTS: int = 120
const MAX_PLANTED_TREES: int = 80
const TREE_VARIANTS = ["STOak2", "STPine3", "STWillow2", "STColumnar1", "STSwiggly1"]
const BASE_TREE_COUNT: int = 15
const WORLD_HALF: float = 200.0
const ZONE_COUNT: int = 100
const STARTER_ZONES = [44, 45, 54, 55]
const DECOR_TYPES: int = 16
const MAX_DECORATIONS: int = 260

static func _valid_position_number(raw: Variant, bound: float) -> bool:
    if not (raw is int or raw is float):
        return false
    var value: float = float(raw)
    return is_finite(value) and absf(value) <= bound

static func normalize(raw: Variant) -> Dictionary:
    if not (raw is Dictionary):
        return {}
    var data: Dictionary = raw
    if data.has("format"):
        if str(data.get("format", "")) != FORMAT or int(data.get("version", 0)) != VERSION:
            return {}
        if not (data.get("data") is Dictionary):
            return {}
        data = data["data"]

    for key in ["coins", "feed", "pigs", "seeds", "plots"]:
        if not data.has(key):
            return {}
    var input_seeds: Variant = data["seeds"]
    var input_plots: Variant = data["plots"]
    if not (input_seeds is Array) or not (input_plots is Array):
        return {}
    if input_seeds.size() != NUM_CROPS or (input_plots.size() != NUM_PLOTS and input_plots.size() != OLD_PLOTS):
        return {}

    for key in ["coins", "feed", "pigs"]:
        var value: Variant = data[key]
        if not (value is int or value is float):
            return {}
    var balance: int = int(data["coins"])
    var stock: int = int(data["feed"])
    var animal_count: int = int(data["pigs"])
    var pens_value: Variant = data.get("pens", maxi(1, (animal_count + PIGS_PER_PEN - 1) / PIGS_PER_PEN))
    if not (pens_value is int or pens_value is float):
        return {}
    var pen_count: int = int(pens_value)
    if balance < 0 or balance > 1000000000 or stock < 0 or stock > 100000:
        return {}
    if pen_count < 1 or pen_count > MAX_PENS or animal_count < 0 or animal_count > pen_count * PIGS_PER_PEN:
        return {}

    # Older browser saves have no farm progression. Preserve their contents
    # while adding a fresh level 1 / 0 EXP progression when first loaded.
    var level_value: Variant = data.get("farm_level", 1)
    var xp_value: Variant = data.get("farm_xp", 0)
    # Godot's JSON parser reads integer JSON numbers as floats; accept
    # either representation, but never accept fractional levels/EXP.
    if not (level_value is int or level_value is float) or not (xp_value is int or xp_value is float):
        return {}
    if not is_finite(float(level_value)) or not is_finite(float(xp_value)):
        return {}
    if float(level_value) != float(int(level_value)) or float(xp_value) != float(int(xp_value)):
        return {}
    var farm_level: int = int(level_value)
    var farm_xp: int = int(xp_value)
    if farm_level < 1 or farm_level > MAX_FARM_LEVEL or farm_xp < 0 or farm_xp > 1000000:
        return {}
    if farm_level == MAX_FARM_LEVEL:
        farm_xp = 0

    var plot_kits_value: Variant = data.get("plot_kits", 0)
    var wood_value: Variant = data.get("wood", 0)
    for quantity in [plot_kits_value, wood_value]:
        if not (quantity is int or quantity is float):
            return {}
        if not is_finite(float(quantity)) or float(quantity) != float(int(quantity)):
            return {}
        if int(quantity) < 0 or int(quantity) > 100000:
            return {}
    var safe_tree_kits: Array = []
    var raw_tree_kits: Variant = data.get("tree_kits", [0, 0, 0, 0, 0])
    if not (raw_tree_kits is Array) or raw_tree_kits.size() != TREE_VARIANTS.size():
        return {}
    for quantity in raw_tree_kits:
        if not (quantity is int or quantity is float):
            return {}
        if not is_finite(float(quantity)) or float(quantity) != float(int(quantity)):
            return {}
        if int(quantity) < 0 or int(quantity) > 100000:
            return {}
        safe_tree_kits.append(int(quantity))

    var safe_seeds: Array = []
    for value in input_seeds:
        if not (value is int or value is float):
            return {}
        var amount: int = int(value)
        if amount < 0 or amount > 100000:
            return {}
        safe_seeds.append(amount)

    var safe_plots: Array = []
    var max_timestamp: float = Time.get_unix_time_from_system() + 3600.0
    for original in input_plots:
        if not (original is Dictionary):
            return {}
        var cell: Dictionary = {}
        if original.has("tilled"):
            cell["tilled"] = bool(original["tilled"])
        if original.has("crop"):
            var crop_value: Variant = original["crop"]
            if not (crop_value is int or crop_value is float):
                return {}
            var crop_id: int = int(crop_value)
            if crop_id < 0 or crop_id >= NUM_CROPS:
                return {}
            cell["crop"] = crop_id
            cell["wet"] = bool(original.get("wet", false))
            var time_value: Variant = original.get("water_time", 0.0)
            if not (time_value is int or time_value is float):
                return {}
            var timestamp: float = float(time_value)
            if timestamp < 0.0 or timestamp > max_timestamp:
                return {}
            cell["water_time"] = timestamp
        safe_plots.append(cell)

    var safe_extra_plots: Array = []
    var raw_extra: Variant = data.get("extra_plots", [])
    if not (raw_extra is Array) or raw_extra.size() > MAX_EXTRA_PLOTS:
        return {}
    for entry in raw_extra:
        if not (entry is Dictionary):
            return {}
        if not _valid_position_number(entry.get("x"), 199.0) or not _valid_position_number(entry.get("z"), 199.0):
            return {}
        var cell: Dictionary = {"x": float(entry["x"]), "z": float(entry["z"])}
        if entry.has("tilled"):
            cell["tilled"] = bool(entry["tilled"])
        if entry.has("crop"):
            var crop_val: Variant = entry["crop"]
            if not (crop_val is int or crop_val is float) or not is_finite(float(crop_val)):
                return {}
            var crop_id: int = int(crop_val)
            if float(crop_val) != float(crop_id) or crop_id < 0 or crop_id >= NUM_CROPS:
                return {}
            cell["crop"] = crop_id
            cell["wet"] = bool(entry.get("wet", false))
            var time_val: Variant = entry.get("water_time", 0.0)
            if not (time_val is int or time_val is float) or not is_finite(float(time_val)):
                return {}
            var timestamp: float = float(time_val)
            if timestamp < 0.0 or timestamp > max_timestamp:
                return {}
            cell["water_time"] = timestamp
        safe_extra_plots.append(cell)

    var safe_placed_trees: Array = []
    var raw_trees: Variant = data.get("placed_trees", [])
    if not (raw_trees is Array) or raw_trees.size() > MAX_PLANTED_TREES:
        return {}
    for entry in raw_trees:
        if not (entry is Dictionary):
            return {}
        if not _valid_position_number(entry.get("x"), 199.0) or not _valid_position_number(entry.get("z"), 199.0):
            return {}
        var variant: String = str(entry.get("variant", ""))
        if not TREE_VARIANTS.has(variant):
            return {}
        var rotation_value: Variant = entry.get("rotation", 0.0)
        if not _valid_position_number(rotation_value, 360.0) or float(rotation_value) < 0.0:
            return {}
        safe_placed_trees.append({
            "x": float(entry["x"]), "z": float(entry["z"]),
            "variant": variant, "rotation": float(rotation_value)
        })

    var safe_removed_trees: Array = []
    var raw_removed: Variant = data.get("removed_trees", [])
    if not (raw_removed is Array) or raw_removed.size() > BASE_TREE_COUNT:
        return {}
    for value in raw_removed:
        if not (value is int or value is float) or not is_finite(float(value)):
            return {}
        var index: int = int(value)
        if float(value) != float(index) or index < 0 or index >= BASE_TREE_COUNT or safe_removed_trees.has(index):
            return {}
        safe_removed_trees.append(index)

    # New expansion fields default to the old central farm for existing saves.
    var unlocked_input: Variant = data.get("unlocked_zones", STARTER_ZONES.duplicate())
    if not (unlocked_input is Array) or unlocked_input.size() > ZONE_COUNT:
        return {}
    var safe_unlocked_zones: Array = []
    for raw_id in unlocked_input:
        if not (raw_id is int or raw_id is float) or not is_finite(float(raw_id)):
            return {}
        var sector: int = int(raw_id)
        if float(raw_id) != float(sector) or sector < 0 or sector >= ZONE_COUNT or safe_unlocked_zones.has(sector):
            return {}
        safe_unlocked_zones.append(sector)
    for required in STARTER_ZONES:
        if not safe_unlocked_zones.has(required):
            return {}

    var raw_decor_kits: Variant = data.get("decor_kits", [])
    if not (raw_decor_kits is Array):
        return {}
    if raw_decor_kits.is_empty():
        raw_decor_kits = []
        for _idx in range(DECOR_TYPES):
            raw_decor_kits.append(0)
    if raw_decor_kits.size() != DECOR_TYPES:
        return {}
    var safe_decor_kits: Array = []
    for qty in raw_decor_kits:
        if not (qty is int or qty is float) or not is_finite(float(qty)):
            return {}
        var amount: int = int(qty)
        if float(qty) != float(amount) or amount < 0 or amount > 100000:
            return {}
        safe_decor_kits.append(amount)

    var input_decor: Variant = data.get("placed_decor", [])
    if not (input_decor is Array) or input_decor.size() > MAX_DECORATIONS:
        return {}
    var safe_placed_decor: Array = []
    for entry in input_decor:
        if not (entry is Dictionary):
            return {}
        if not _valid_position_number(entry.get("x"), 199.0) or not _valid_position_number(entry.get("z"), 199.0):
            return {}
        var type_value: Variant = entry.get("type", -1)
        if not (type_value is int or type_value is float) or not is_finite(float(type_value)):
            return {}
        var type_index: int = int(type_value)
        if float(type_value) != float(type_index) or type_index < 0 or type_index >= DECOR_TYPES:
            return {}
        var rotation_value: Variant = entry.get("rotation", 0.0)
        if not _valid_position_number(rotation_value, 360.0) or float(rotation_value) < 0.0:
            return {}
        safe_placed_decor.append({
            "x": float(entry["x"]), "z": float(entry["z"]),
            "type": type_index, "rotation": float(rotation_value)
        })

    if input_plots.size() == OLD_PLOTS:
        # Legacy plots were a 6x4 farm. Retain their row/column ordering
        # inside the center columns of the new 10x5 farm.
        var expanded: Array = []
        for i in range(NUM_PLOTS):
            expanded.append({})
        for old_index in range(OLD_PLOTS):
            var old_row: int = old_index / 6
            var old_col: int = old_index % 6
            var new_index: int = old_row * PLOTS_PER_ROW + old_col + 2
            expanded[new_index] = safe_plots[old_index]
        safe_plots = expanded

    return {
        "coins": balance,
        "feed": stock,
        "pigs": animal_count,
        "pens": pen_count,
        "farm_level": farm_level,
        "farm_xp": farm_xp,
        "plot_kits": int(plot_kits_value),
        "tree_kits": safe_tree_kits,
        "wood": int(wood_value),
        "extra_plots": safe_extra_plots,
        "placed_trees": safe_placed_trees,
        "removed_trees": safe_removed_trees,
        "unlocked_zones": safe_unlocked_zones,
        "decor_kits": safe_decor_kits,
        "placed_decor": safe_placed_decor,
        "seeds": safe_seeds,
        "plots": safe_plots
    }

static func package(state: Dictionary) -> Dictionary:
    return {
        "format": FORMAT,
        "version": VERSION,
        "created_at": int(Time.get_unix_time_from_system()),
        "data": state.duplicate(true)
    }

static func load_from(path: String) -> Dictionary:
    if not FileAccess.file_exists(path):
        return {}
    var file: FileAccess = FileAccess.open(path, FileAccess.READ)
    if file == null:
        return {}
    if file.get_length() > MAX_BYTES:
        file.close()
        return {}
    var text_data: String = file.get_as_text()
    file.close()
    return normalize(JSON.parse_string(text_data))

static func save_to(path: String, state: Dictionary) -> bool:
    var validated: Dictionary = normalize(state)
    if validated.is_empty():
        return false
    var text_data: String = JSON.stringify(validated)
    if FileAccess.file_exists(path):
        var previous: Dictionary = load_from(path)
        if not previous.is_empty():
            DirAccess.copy_absolute(ProjectSettings.globalize_path(path), ProjectSettings.globalize_path(PREVIOUS))
    var file: FileAccess = FileAccess.open(path, FileAccess.WRITE)
    if file == null:
        return false
    file.store_string(text_data)
    file.flush()
    file.close()
    var verify: FileAccess = FileAccess.open(path, FileAccess.READ)
    if verify == null:
        return false
    var matched: bool = verify.get_as_text() == text_data
    verify.close()
    if not matched and FileAccess.file_exists(PREVIOUS):
        DirAccess.copy_absolute(ProjectSettings.globalize_path(PREVIOUS), ProjectSettings.globalize_path(path))
    return matched
