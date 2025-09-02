class_name PlayerRunner
extends CharacterBody3D
## Runner body: falls, queues yaw turns, moves forward with switchable speeds.
## Controls direction of a visuals node (player's character).

const VERSION := "0.5.0"


signal distance_moved(delta_m: float)
signal obstacle_bumped(collider: Node, surface_normal: Vector3)
signal turn_buffer_changed(remaining_deg: float)
signal speed_changed(new_speed: float, mode: String)


# --- Defaults ------------------------
const DEFAULT_SPEED_WALK: float = 1.11
const DEFAULT_SPEED_RUN: float  = 2.50
const DEFAULT_TURN_RATE: float = 180.0


# --- Exports -------------------------
## Named speed modes (mode -> meters/second)
@export var speed_modes: Dictionary[String, float] = {
    "walk": DEFAULT_SPEED_WALK,
    "run":  DEFAULT_SPEED_RUN,
}

## Default mode to use on reset/startup (must exist in speed_modes)
@export var default_speed_mode: String = "walk"

## Max rotate speed (deg/sec). Higher = snappier.
@export var turn_rate_deg := DEFAULT_TURN_RATE

## Reference to an existing visuals node in the scene (must be a Node3D)
@export var visuals_path: NodePath


# --- Private --------------------------
var _visuals: Node3D
var _move_dir: Vector3
var _remaining_turn_deg: float  # +left / -right, consumed over time

var _speed: float
var _speed_mode: String = "custom"  # "walk" | "run" | "custom"

var _last_pos: Vector3
var _start_xform: Transform3D


# --- Lifecycle -----------------------
func _ready() -> void:
    _visuals = get_node_or_null(visuals_path) as Node3D
    if _visuals == null:
        push_warning("PlayerRunner: visuals_path not set or not a Node3D")
    _start_xform = global_transform
    reset_to_start()

func _physics_process(delta: float) -> void:
    # gravity / falling
    if not is_on_floor():
        velocity += get_gravity() * delta
    else:
        # consume turn buffer at a capped rate
        var max_step: float = turn_rate_deg * delta
        var step: float = clamp(_remaining_turn_deg, -max_step, max_step)
        if step != 0.0:
            _move_dir = _move_dir.rotated(Vector3.UP, deg_to_rad(step)).normalized()
            _remaining_turn_deg -= step
            turn_buffer_changed.emit(_remaining_turn_deg)
        velocity = _move_dir * _speed

    move_and_slide()

    # distance event
    var p := global_position
    var dlen := p.distance_to(_last_pos)
    if dlen > 0.0:
        distance_moved.emit(dlen)
        _last_pos = p

    # raw collision events
    for i in range(get_slide_collision_count()):
        var c := get_slide_collision(i)
        if c:
            obstacle_bumped.emit(c.get_collider(), c.get_normal())


# --- Public API -----------------------
func queue_turn(delta_deg: float) -> void:
    _remaining_turn_deg = clamp(_remaining_turn_deg + delta_deg, -360.0, 360.0)
    turn_buffer_changed.emit(_remaining_turn_deg)

## Set by mode name (must exist in speed_modes)
func set_speed_mode(mode: String) -> void:
    var key := mode.to_lower()
    if speed_modes.has(key):
        var prev := _speed
        _speed = max(float(speed_modes[key]), 0.0)
        _speed_mode = key
        if !is_equal_approx(prev, _speed):
            speed_changed.emit(_speed, _speed_mode)
    else:
        push_warning("PlayerRunner: unknown speed mode '%s'." % mode)

## Set any raw speed (m/s); marks mode as "custom"
func set_speed_value(v: float) -> void:
    var prev := _speed
    _speed = max(v, 0.0)
    _speed_mode = "custom"
    if !is_equal_approx(prev, _speed):
        speed_changed.emit(_speed, _speed_mode)

func current_speed() -> float:
    return _speed

func current_speed_mode() -> String:
    return _speed_mode

func reset_to_start() -> void:
    global_transform = _start_xform
    velocity = Vector3.ZERO
    _move_dir = global_transform.basis.z.normalized()
    _remaining_turn_deg = 0.0
    if speed_modes.has(default_speed_mode):
        set_speed_mode(default_speed_mode)
    else:
        set_speed_value(0.0)
    _last_pos = global_position
