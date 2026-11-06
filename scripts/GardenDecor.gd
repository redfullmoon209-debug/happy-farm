extends RefCounted
# Lightweight modular 3D props for Happy Farm's free-form decoration shop.
# Replace individual props with authored models later without changing saves.

static func _material(color: Color) -> StandardMaterial3D:
    var result: StandardMaterial3D = StandardMaterial3D.new()
    result.albedo_color = color
    result.roughness = 0.89
    return result

static func _cube(root: Node3D, position: Vector3, size: Vector3, color: Color) -> MeshInstance3D:
    var node: MeshInstance3D = MeshInstance3D.new()
    var mesh: BoxMesh = BoxMesh.new()
    mesh.size = size
    node.mesh = mesh
    node.material_override = _material(color)
    node.position = position
    root.add_child(node)
    return node

static func _round(root: Node3D, position: Vector3, size: Vector3, color: Color) -> MeshInstance3D:
    var node: MeshInstance3D = MeshInstance3D.new()
    var mesh: SphereMesh = SphereMesh.new()
    mesh.radius = 0.5
    mesh.height = 1.0
    mesh.radial_segments = 8
    mesh.rings = 5
    node.mesh = mesh
    node.position = position
    node.scale = size
    node.material_override = _material(color)
    root.add_child(node)
    return node

static func _cylinder(root: Node3D, position: Vector3, height: float, radius: float, color: Color, top_radius: float = -1.0) -> MeshInstance3D:
    var node: MeshInstance3D = MeshInstance3D.new()
    var mesh: CylinderMesh = CylinderMesh.new()
    mesh.height = height
    mesh.top_radius = radius if top_radius < 0.0 else top_radius
    mesh.bottom_radius = radius
    mesh.radial_segments = 10
    node.mesh = mesh
    node.position = position
    node.material_override = _material(color)
    root.add_child(node)
    return node

static func _flowers(root: Node3D, count: int, spread: float) -> void:
    var colors: Array[Color] = [Color("#f5a0a9"), Color("#f6dd81"), Color("#a7c2ef"), Color("#f9c8e9")]
    for i in range(count):
        var angle: float = float(i) * TAU / float(maxi(count, 1))
        var x: float = cos(angle) * spread
        var z: float = sin(angle) * spread
        _cylinder(root, Vector3(x,0.22,z), 0.40, 0.035, Color("#347a46"))
        _round(root, Vector3(x,0.46,z), Vector3(0.22,0.16,0.22), colors[i % colors.size()])
        _round(root, Vector3(x,0.47,z), Vector3(0.085,0.08,0.085), Color("#f0a84b"))

static func make(parent: Node3D, position: Vector3, decor_type: int, yaw: float = 0.0) -> Node3D:
    var root: Node3D = Node3D.new()
    root.name = "GardenDecoration_%d" % decor_type
    root.position = position
    root.rotation_degrees.y = yaw
    parent.add_child(root)
    var wood: Color = Color("#97704e")
    var trim: Color = Color("#c49a65")
    var stone: Color = Color("#aeb5aa")
    var green: Color = Color("#5c9867")
    match decor_type:
        0: # Bench
            _cube(root, Vector3(0,0.65,0), Vector3(1.8,0.16,0.67), trim)
            _cube(root, Vector3(0,1.20,-0.32), Vector3(1.8,0.8,0.14), wood)
            for x in [-0.65,0.65]:
                _cube(root, Vector3(x,0.34,0.0), Vector3(0.15,0.68,0.55), wood)
        1: # A short wooden fence segment
            for x in [-0.7,0.7]:
                _cube(root, Vector3(x,0.67,0), Vector3(0.17,1.35,0.18), wood)
            for y in [0.44,0.96]:
                _cube(root, Vector3(0,y,0), Vector3(1.5,0.14,0.14), trim)
        2: # Flowers in ceramic planter
            _cylinder(root, Vector3(0,0.27,0), 0.54, 0.44, Color("#bf805c"), 0.53)
            _cylinder(root, Vector3(0,0.55,0), 0.11, 0.51, Color("#c69472"))
            _flowers(root, 6, 0.27)
        3: # Garden lamp
            _cylinder(root, Vector3(0,1.17,0), 2.25, 0.095, Color("#4c635a"))
            _cube(root, Vector3(0,2.30,0), Vector3(0.48,0.44,0.48), Color("#f1d888"))
            _cube(root, Vector3(0,2.59,0), Vector3(0.59,0.15,0.59), Color("#536c60"))
        4: # Fountain with water basin
            _cylinder(root, Vector3(0,0.35,0), 0.7, 1.32, stone)
            _cylinder(root, Vector3(0,0.73,0), 0.11, 1.17, Color("#70baca"))
            _cylinder(root, Vector3(0,1.04,0), 0.75, 0.16, stone)
            _round(root, Vector3(0,1.47,0), Vector3(0.32,0.35,0.32), Color("#85cada"))
        5: # Scarecrow
            _cylinder(root, Vector3(0,1.35,0), 2.70, 0.09, wood)
            _cube(root, Vector3(0,1.82,0), Vector3(1.75,0.14,0.14), wood)
            _cube(root, Vector3(0,1.65,0), Vector3(0.72,0.83,0.40), Color("#d99e6a"))
            _round(root, Vector3(0,2.35,0), Vector3(0.48,0.50,0.48), Color("#e6c48e"))
            _cylinder(root, Vector3(0,2.65,0), 0.16, 0.42, Color("#bb8d55"))
        6: # Wooden sign
            _cube(root, Vector3(0,0.85,0), Vector3(0.17,1.70,0.17), wood)
            _cube(root, Vector3(0,1.45,0.04), Vector3(1.40,0.66,0.17), trim)
            for x in [-0.47,0.47]:
                _round(root, Vector3(x,1.44,0.14), Vector3(0.06,0.06,0.06), Color("#664e39"))
        7: # Straw bales
            _cube(root, Vector3(-0.28,0.32,0), Vector3(0.95,0.63,0.72), Color("#d4b367"))
            _cube(root, Vector3(0.53,0.29,0.15), Vector3(0.85,0.58,0.72), Color("#e3c47b"))
            _cube(root, Vector3(0.06,0.88,-0.10), Vector3(0.93,0.56,0.72), Color("#d6b36a"))
        8: # Picnic table
            _cube(root, Vector3(0,0.90,0), Vector3(1.8,0.15,1.05), trim)
            for z in [-0.87,0.87]:
                _cube(root, Vector3(0,0.49,z), Vector3(1.8,0.14,0.36), wood)
            for x in [-0.56,0.56]:
                _cube(root, Vector3(x,0.45,0), Vector3(0.13,0.82,0.85), wood)
        9: # Stone well
            _cylinder(root, Vector3(0,0.53,0), 1.05, 0.82, stone)
            _cylinder(root, Vector3(0,1.04,0), 0.08, 0.92, Color("#d6c3a3"))
            for x in [-0.66,0.66]:
                _cube(root, Vector3(x,1.64,0), Vector3(0.14,1.45,0.14), wood)
            _cube(root, Vector3(0,2.38,0), Vector3(1.90,0.20,1.28), Color("#b36e55"))
        10: # Hedge shrub
            for x,z,size in [[0.0,0.0,1.25],[-0.52,0.24,0.86],[0.52,-0.10,0.91]]:
                _round(root, Vector3(x,0.62,z), Vector3(size,size,size), green)
        11: # Paving stone
            _cube(root, Vector3(0,0.07,0), Vector3(1.45,0.12,1.45), Color("#d0c7b0"))
            for x,z in [[-0.35,-0.34],[0.38,0.32]]:
                _round(root, Vector3(x,0.14,z), Vector3(0.28,0.06,0.25), stone)
        12: # Mailbox
            _cube(root, Vector3(0,0.62,0), Vector3(0.14,1.24,0.14), wood)
            _cube(root, Vector3(0,1.32,0), Vector3(0.69,0.46,0.55), Color("#6f98b6"))
            _cube(root, Vector3(0.22,1.43,0.29), Vector3(0.14,0.08,0.08), Color("#e2c68d"))
        13: # Gazebo
            _cylinder(root, Vector3(0,0.15,0), 0.30, 2.15, Color("#c6ad81"))
            for x in [-1.40,1.40]:
                for z in [-1.40,1.40]:
                    _cube(root, Vector3(x,1.30,z), Vector3(0.16,2.5,0.16), wood)
            _cylinder(root, Vector3(0,2.65,0), 0.75, 2.28, Color("#ae785e"), 0.15)
        14: # Rock garden
            for x,z,size in [[-0.65,0.2,0.98],[0.40,-0.36,0.75],[0.8,0.48,0.68]]:
                _round(root, Vector3(x,0.35 * size,z), Vector3(size,size*0.72,size*0.8), stone)
            _round(root, Vector3(-0.05,0.20,0.6), Vector3(0.55,0.34,0.54), green)
        15: # Small lantern
            _cube(root, Vector3(0,0.18,0), Vector3(0.46,0.18,0.46), Color("#54685a"))
            _cube(root, Vector3(0,0.53,0), Vector3(0.36,0.50,0.36), Color("#f5df91"))
            _cube(root, Vector3(0,0.82,0), Vector3(0.50,0.13,0.50), Color("#54685a"))
        _:
            _cube(root, Vector3(0,0.25,0), Vector3.ONE*0.5, stone)
    return root
