extends RefCounted
# Exact names from the user's FBX.zip: 68 assets, no invented models.
const GROUPS: Dictionary = {
    "trees": ["CommonTree_1", "CommonTree_2", "CommonTree_3", "CommonTree_4", "CommonTree_5", "Pine_1", "Pine_2", "Pine_3", "Pine_4", "Pine_5", "TwistedTree_1", "TwistedTree_2", "TwistedTree_3", "TwistedTree_4", "TwistedTree_5", "DeadTree_1", "DeadTree_2", "DeadTree_3", "DeadTree_4", "DeadTree_5"],
    "bushes": ["Bush_Common", "Bush_Common_Flowers", "Clover_1", "Clover_2", "Fern_1", "Grass_Common_Short", "Grass_Common_Tall", "Grass_Wispy_Short", "Grass_Wispy_Tall", "Plant_1", "Plant_1_Big", "Plant_7", "Plant_7_Big"],
    "flowers": ["Flower_3_Group", "Flower_3_Single", "Flower_4_Group", "Flower_4_Single", "Petal_1", "Petal_2", "Petal_3", "Petal_4", "Petal_5", "Mushroom_Common", "Mushroom_Laetiporus"],
    "rocks": ["Rock_Medium_1", "Rock_Medium_2", "Rock_Medium_3", "Pebble_Round_1", "Pebble_Round_2", "Pebble_Round_3", "Pebble_Round_4", "Pebble_Round_5", "Pebble_Square_1", "Pebble_Square_2", "Pebble_Square_3", "Pebble_Square_4", "Pebble_Square_5", "Pebble_Square_6"],
    "paths": ["RockPath_Round_Small_1", "RockPath_Round_Small_2", "RockPath_Round_Small_3", "RockPath_Round_Thin", "RockPath_Round_Wide", "RockPath_Square_Small_1", "RockPath_Square_Small_2", "RockPath_Square_Small_3", "RockPath_Square_Thin", "RockPath_Square_Wide"]
}
const GROUP_LABELS: Dictionary = {
    "trees": "ต้นไม้", "bushes": "พุ่ม / หญ้า",
    "flowers": "ดอกไม้ / เห็ด", "rocks": "หิน", "paths": "ทางเดินหิน"
}
const FBX_ROOT: String = "res://assets/gm_models/"

static func all_names() -> Array[String]:
    var names: Array[String] = []
    for group_id in GROUPS.keys():
        for base_name in GROUPS[group_id]:
            names.append(str(base_name))
    return names

static func is_known(name: String) -> bool:
    for group_id in GROUPS.keys():
        if GROUPS[group_id].has(name):
            return true
    return false

static func scene_path(name: String) -> String:
    return FBX_ROOT + name + ".fbx"

static func exists(name: String) -> bool:
    return is_known(name) and ResourceLoader.exists(scene_path(name))

static func create_prop(name: String) -> Node3D:
    if not exists(name):
        return null
    var resource: Resource = load(scene_path(name))
    if not (resource is PackedScene):
        return null
    var instance: Node = (resource as PackedScene).instantiate()
    if instance is Node3D:
        return instance as Node3D
    instance.queue_free()
    return null
