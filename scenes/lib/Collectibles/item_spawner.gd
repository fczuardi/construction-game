@tool
class_name ItemSpawner
extends Node3D

# Export phase, the scenes that will be baked in the build
@export var fallback_scenes: Array[PackedScene] = []  # ensure inclusion in export

# Development phase
# Scan all *.tscn collectibles from a folder (optionally recursive)
@export_dir var collectibles_dir: String = "res://lib/Collectibles"
@export var scan_subdirs: bool = false

# Parent whose DIRECT children (Marker3D / Node3D) are spawn points
@export var spawn_parent: NodePath

# Keeps rotation across respawns; set to 0 if you want to start from the first scene each time
@export var round_robin_start_idx: int = 0

var collectible_scenes: Array[PackedScene] = []
var _spawned: Array[Node] = []

var _spawn_group: StringName        # unique group tag per spawner instance
var _is_respawning := false

func _ready() -> void:
    _spawn_group = StringName("itemspawner_" + str(get_instance_id()))
    _refresh_scene_list()

    if Engine.is_editor_hint():
        return

    if EventBus.has_signal("global_restart_game") and not EventBus.global_restart_game.is_connected(_on_restart):
        EventBus.global_restart_game.connect(_on_restart)

    # Initial spawn deferred to avoid stacking with any editor-time leftovers
    _request_respawn()

func _exit_tree() -> void:
    if not Engine.is_editor_hint():
        if EventBus.has_signal("global_restart_game") and EventBus.global_restart_game.is_connected(_on_restart):
            EventBus.global_restart_game.disconnect(_on_restart)

# ---------- Public helpers ----------

func respawn() -> void:
    # Exposed in case you want to call from other scripts
    _request_respawn()

# ---------- Restart & Respawn pipeline ----------

func _on_restart() -> void:
    _request_respawn()

func _request_respawn() -> void:
    if _is_respawning:
        return
    _is_respawning = true
    _clear_all_spawned()
    # Defer the actual spawn to next frame so queue_free() finalizes
    call_deferred("_do_respawn")

func _do_respawn() -> void:
    _spawn_new()
    _is_respawning = false

# ---------- Clear & Spawn ----------

func _clear_all_spawned() -> void:
    # Clear tracked instances
    for n in _spawned:
        if is_instance_valid(n):
            n.queue_free()
    _spawned.clear()

    # Belt & suspenders: clear by unique group as well
    var leftovers := get_tree().get_nodes_in_group(_spawn_group)
    for n in leftovers:
        if is_instance_valid(n):
            n.queue_free()

func _spawn_new() -> void:
    var points := _get_spawn_nodes()
    var num_points := points.size()
    var num_scenes := collectible_scenes.size()

    if num_points == 0:
        push_warning("ItemSpawner: no spawn points found under %s" % str(spawn_parent))
        return
    if num_scenes == 0:
        push_warning("ItemSpawner: no .tscn scenes found in %s" % collectibles_dir)
        return

    var idx := round_robin_start_idx
    for i in range(num_points):
        var marker := points[i]
        var ps: PackedScene = collectible_scenes[idx % num_scenes]
        # random
        # var ps: PackedScene = collectible_scenes[randi() % num_scenes]
        idx += 1
        if ps == null:
            continue

        var item := ps.instantiate()
        add_child(item)
        (item as Node3D).global_position = marker.global_position

        item.add_to_group(_spawn_group)  # tag for robust clearing
        _spawned.append(item)

    round_robin_start_idx = idx % max(1, num_scenes)

# ---------- Spawn points & Scenes loading ----------

func _get_spawn_nodes() -> Array[Node3D]:
    var out: Array[Node3D] = []
    if spawn_parent == NodePath():
        return out
    var parent := get_node_or_null(spawn_parent)
    if not (parent and parent is Node3D):
        return out

    for c in parent.get_children():
        if c is Node3D:
            out.append(c as Node3D)

    # Deterministic order helps testing; comment out if you prefer scene order
    out.sort_custom(Callable(self, "_sort_by_name"))
    return out

func _sort_by_name(a: Node3D, b: Node3D) -> bool:
    return String(a.name) < String(b.name)


func _refresh_scene_list() -> void:
    collectible_scenes.clear()
    var found: Array[PackedScene] = []

    if collectibles_dir != "":
        var tscn_paths := _find_tscn_files(collectibles_dir, scan_subdirs)
        for p in tscn_paths:
            var res := ResourceLoader.load(p)
            if res is PackedScene:
                found.append(res)

    # Merge with fallback and dedupe by resource path
    var by_path := {}
    for s in fallback_scenes:
        if s != null:
            by_path[s.resource_path] = s
    for s in found:
        if s != null:
            by_path[s.resource_path] = s

    collectible_scenes = []
    for k in by_path.keys():
        collectible_scenes.append(by_path[k])

    if Engine.is_editor_hint():
        print_rich("[ItemSpawner] Loaded [b]%d[/b] scenes (scan:%d + fallback:%d) from %s"
            % [collectible_scenes.size(), found.size(), fallback_scenes.size(), collectibles_dir])




func _find_tscn_files(dir_path: String, recursive: bool) -> PackedStringArray:
    var results: PackedStringArray = []
    if not recursive:
        for filename in DirAccess.get_files_at(dir_path):
            if filename.ends_with(".tscn"):
                results.append(dir_path.path_join(filename))
        return results

    _collect_tscn_recursive(dir_path, results)
    return results

func _collect_tscn_recursive(path: String, out: PackedStringArray) -> void:
    for f in DirAccess.get_files_at(path):
        if f.ends_with(".tscn"):
            out.append(path.path_join(f))
    for d in DirAccess.get_directories_at(path):
        if d.begins_with("."):
            continue
        _collect_tscn_recursive(path.path_join(d), out)

# ---------- Optional editor preview ----------

func _spawn_preview() -> void:
    if collectible_scenes.is_empty():
        return
    var points := _get_spawn_nodes()
    if points.is_empty():
        return

    var idx := 0
    for marker in points:
        var ps: PackedScene = collectible_scenes[idx % collectible_scenes.size()]
        idx += 1
        if ps == null:
            continue
        var item := ps.instantiate()
        add_child(item)
        (item as Node3D).global_position = marker.global_position
        _spawned.append(item)
