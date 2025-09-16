class_name CollectiblePointer
extends Node3D

@export var visuals: Node                  # PlayerVisuals
@export var runner: Node                   # PlayerRunner (emits turn_buffer_changed)
@export var groups := ["collectible"]
@export var straight_epsilon_deg := 1.0    # <= this means "not turning"

@onready var sc_f: ShapeCast3D = %ShapeForward
@onready var sc_b: ShapeCast3D = %ShapeBack

var _is_turning := false
var _prev_ids_f: Dictionary = {}    # id -> true
var _prev_ids_b: Dictionary = {}

func _ready() -> void:
    sc_f.enabled = true
    sc_b.enabled = true
    if runner and runner.has_signal("turn_buffer_changed"):
        runner.turn_buffer_changed.connect(_on_turn_buffer_changed)

func _on_turn_buffer_changed(remaining_deg: float) -> void:
    _is_turning = abs(remaining_deg) > straight_epsilon_deg

func _physics_process(_dt: float) -> void:
    if _is_turning:
        _prev_ids_f.clear()
        _prev_ids_b.clear()
        return
    var new_id_f := _first_new_hit(sc_f, _prev_ids_f)
    if new_id_f != 0:
        _prev_ids_f[new_id_f] = true
        if visuals and visuals.has_method("play_point_forward"):
            visuals.play_point_forward()

    var new_id_b := _first_new_hit(sc_b, _prev_ids_b)
    if new_id_b != 0:
        _prev_ids_b[new_id_b] = true
        if visuals and visuals.has_method("play_point_back"):
            visuals.play_point_back()

    # prune dictionaries to only keep currently colliding ids (so leaving + re-entering can retrigger)
    _prev_ids_f = _current_hits_map(sc_f)
    _prev_ids_b = _current_hits_map(sc_b)
    
func _first_new_hit(sc: ShapeCast3D, prev: Dictionary) -> int:
    if not sc.is_colliding():
        return 0
    for i in range(sc.get_collision_count()):
        var c := sc.get_collider(i)
        if c and _is_collectible(c):
            var id := c.get_instance_id()
            if not prev.has(id):     # rising edge
                return id
    return 0

func _is_collectible(n: Object) -> bool:
    for g in groups:
        if n.is_in_group(g):
            return true
    return false
    
func _current_hits_map(sc: ShapeCast3D) -> Dictionary:
    var m := {}
    if sc.is_colliding():
        for i in range(sc.get_collision_count()):
            var c := sc.get_collider(i)
            if c and _is_collectible(c):
                m[c.get_instance_id()] = true
    return m
