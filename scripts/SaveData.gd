extends RefCounted
# Browser-friendly, versioned and validated Happy Farm save data.
# This module keeps existing flat user:// saves compatible.

const FORMAT: String = "happy-farm-save"
const VERSION: int = 1
const PREVIOUS: String = "user://happy_farm_previous.json"
const MAX_BYTES: int = 524288
const NUM_CROPS: int = 6
const NUM_PLOTS: int = 24

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
    if input_seeds.size() != NUM_CROPS or input_plots.size() != NUM_PLOTS:
        return {}

    for key in ["coins", "feed", "pigs"]:
        var value: Variant = data[key]
        if not (value is int or value is float):
            return {}
    var balance: int = int(data["coins"])
    var stock: int = int(data["feed"])
    var animal_count: int = int(data["pigs"])
    if balance < 0 or balance > 1000000000 or stock < 0 or stock > 100000 or animal_count < 0 or animal_count > 8:
        return {}

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

    return {
        "coins": balance,
        "feed": stock,
        "pigs": animal_count,
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
