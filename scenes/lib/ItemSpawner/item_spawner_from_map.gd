class_name ItemSpawnerFromMap
extends Node3D

## Map PackedScene (Node2D root with MapA/MapB/MapC + Stickers)
@export var map_scene: PackedScene

## World anchors (correspond to MapA/MapB/MapC). Must be siblings/children in 3D.
@export var world_A: Node3D
@export var world_B: Node3D
@export var world_C: Node3D

## Y height for spawned items (use terrain sample later if you want).
@export var spawn_height: float = 1.0

## Optional: random yaw for variety
@export var randomize_yaw: bool = true

var _spawned_items: Array[Node3D] = []

func _ready() -> void:
    assert(map_scene and world_A and world_B and world_C)
    EventBus.global_stage_started.connect(_on_stage_start)
    _spawn_from_map()

func _spawn_from_map() -> void:
    #print("_spawn_from_map", map_scene)
    # 1) Instantiate the map scene in memory (we don't need to add it to the tree).
    var map_root := map_scene.instantiate() as Control
    assert(map_root)

    # 2) Fetch the 2D anchors
    var map_A := map_root.get_node_or_null("MapA") as Node2D
    var map_B := map_root.get_node_or_null("MapB") as Node2D
    var map_C := map_root.get_node_or_null("MapC") as Node2D
    assert(map_A and map_B and map_C)

    # Precompute 2x2 inverse for map basis
    var u_vec := map_B.position - map_A.position   # map X axis (pixels)
    var v_vec := map_C.position - map_A.position   # map Y axis (pixels)
    var det := u_vec.x * v_vec.y - u_vec.y * v_vec.x
    assert(abs(det) > 0.00001, "Map anchors are collinear; pick non-collinear MapA/MapB/MapC")
    var inv_m00 :=  v_vec.y / det  #  (  v.y  -v.x ) / det
    var inv_m01 := -v_vec.x / det
    var inv_m10 := -u_vec.y / det  #  ( -u.y   u.x ) / det
    var inv_m11 :=  u_vec.x / det

    # 3) World basis (XZ plane)
    var WA := world_A.global_transform.origin
    var WB := world_B.global_transform.origin
    var WC := world_C.global_transform.origin
    var U3 := WB - WA     # world X direction/scale (Vector3)
    var V3 := WC - WA     # world Z direction/scale (Vector3)
    # Zero out any Y skew (keep ground planar). Optional but usually desired:
    U3.y = 0.0
    V3.y = 0.0

    # 4) Iterate stickers
    var stickers := map_root.get_node_or_null("Stickers")
    assert(stickers, "Add a Node2D named 'Stickers' in the map scene")
    for n in stickers.get_children():
        if not (n is Node2D):
            continue
        var node2 := n as Node2D
        if not node2.is_in_group("map_icon"):
            continue

        # Determine "kind"
        var kind: PackedScene = node2.kind

        # 5) Convert 2D map position -> (u,v) -> 3D world position
        var s := node2.position - map_A.position  # Vector2
        var u := inv_m00 * s.x + inv_m01 * s.y
        var v := inv_m10 * s.x + inv_m11 * s.y

        var world_pos := WA + U3 * u + V3 * v

        # 6) Spawn the corresponding scene
        if kind:
            var inst := kind.instantiate() as Node3D
            add_child(inst)
            inst.global_position = world_pos
            if inst.has_method("set_height"):
                inst.set_height(spawn_height)
            _spawned_items.push_front(inst)

func clear_all_items():
    for item in _spawned_items:
        if item != null:
            item.queue_free()
    _spawned_items = []
    
func _on_stage_start(_stage: int):
    clear_all_items()
    _spawn_from_map()
