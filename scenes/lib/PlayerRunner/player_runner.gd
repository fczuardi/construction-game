class_name PlayerRunner
extends CharacterBody3D
## Runner body: falls, queues yaw turns, moves forward with switchable speeds.

const VERSION := "0.5.1"


# important for tripping over trenches
signal collided(collider: Node, normal: Vector3, grounded: bool, speed_mps: float, speed_mode: String)


## DELME: unused signals
## TODO: check if anyone is consuming those signal below (we might have overdesigned)
# signal distance_moved(delta_m: float)
# signal turn_buffer_changed(remaining_deg: float)
# 
# there is a demo using it to display custom speed on screen
signal speed_changed(new_speed: float, mode: String)


# --- Defaults ------------------------
const DEFAULT_SPEED_STOP: float = 0.0
const DEFAULT_SPEED_WALK: float = 0.85
const DEFAULT_SPEED_JOG: float  = 2.4
const DEFAULT_SPEED_RUN: float  = 5.0
const DEFAULT_TURN_RATE: float = 180.0


# --- Exports -------------------------
@export var visuals: PlayerVisuals2

@export var speed_blend_time: float = 0.4  # seconds to reach ~63% toward the target; ~95% in ~3*tau

## Named speed modes (mode -> meters/second)
@export var speed_modes: Dictionary[String, float] = {
    "stop": DEFAULT_SPEED_STOP,
    "walk": DEFAULT_SPEED_WALK,
    "jog":  DEFAULT_SPEED_JOG,
    "run":  DEFAULT_SPEED_RUN,
}

## Default mode to use on reset/startup (must exist in speed_modes)
@export var default_speed_mode: String = "walk"

## Max rotate speed (deg/sec). Higher = snappier.
@export var turn_rate_deg := DEFAULT_TURN_RATE


# --- Private --------------------------
var _move_dir: Vector3
var _remaining_turn_deg: float  # +left / -right, consumed over time

var _target_speed: float
var _speed: float
var _speed_mode: String = "custom"  # "walk" | "run" | "custom"

var _have_last := false

var _last_pos: Vector3
var _start_xform: Transform3D


# --- Lifecycle -----------------------
func _ready() -> void:
    assert(visuals)
    if !visuals:
        return
    _start_xform = global_transform
    reset_to_start()
    EventBus.global_restart_game.connect(reset_to_start)


func _physics_process(delta: float) -> void:
    var pos := global_transform.origin
    if not _have_last:
        _last_pos = pos
        _have_last = true

    # gravity / falling
    if not is_on_floor():
        velocity += get_gravity() * delta
        if velocity.y < -1.0:
            set_speed_mode("stop")
            visuals.update_motion(velocity, is_on_floor())
    else:
        # consume turn buffer at a capped rate
        var max_step: float = turn_rate_deg * delta
        var step: float = clamp(_remaining_turn_deg, -max_step, max_step)
        if step != 0.0:
            _move_dir = _move_dir.rotated(Vector3.UP, deg_to_rad(step)).normalized()
            _remaining_turn_deg -= step
            # turn_buffer_changed.emit(_remaining_turn_deg)
        var k := _exp_k(delta, speed_blend_time)          # 0..1
        _speed = lerp(_speed, _target_speed, k)           # smooth toward target
        velocity = _move_dir * _speed

    move_and_slide()

    # update visuals directly
    if visuals.is_not_moving():
        set_speed_mode("stop")
    else:
        visuals.update_motion(velocity, is_on_floor())

    # ... update movement & yaw ...
    EventBus.player_runner_pose_updated.emit(global_transform.origin, rotation.y)

    # distance event
    var p := global_position
    var dlen := p.distance_to(_last_pos)
    if dlen > 0.0:
        # TODO uncomment when someone starts using this
        # distance_moved.emit(dlen)
        _last_pos = p

    # raw collision events
    for i in range(get_slide_collision_count()):
        var c := get_slide_collision(i)
        if c:
            collided.emit(c.get_collider(), c.get_normal(), is_on_floor(), _speed, _speed_mode)
            # TODO uncomment when someone starts using this
            # obstacle_bumped.emit(c.get_collider(), c.get_normal())

func _exp_k(dt: float, tau: float) -> float:
    if tau <= 0.0: 
        return 1.0
    return 1.0 - exp(-dt / tau)


# --- Public API -----------------------
func queue_turn(delta_deg: float) -> void:
    _remaining_turn_deg = clamp(_remaining_turn_deg + delta_deg, -360.0, 360.0)
    # turn_buffer_changed.emit(_remaining_turn_deg)

func set_speed_mode(mode: String) -> void:
    var key := mode.to_lower()
    if speed_modes.has(key):
        _target_speed = max(float(speed_modes[key]), 0.0)
        _speed_mode = key
        speed_changed.emit(_target_speed, _speed_mode)  # emit the new target for HUD etc.
    else:
        push_warning("PlayerRunner: unknown speed mode '%s'." % mode)

func set_speed_value(v: float) -> void:
    _target_speed = max(v, 0.0)
    _speed_mode = "custom"
    speed_changed.emit(_target_speed, _speed_mode)

func set_speed_value_instant(v: float) -> void:
    _target_speed = max(v, 0.0)
    _speed = _target_speed
    _speed_mode = "custom"
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
        _speed_mode = default_speed_mode
        _speed = max(float(speed_modes[_speed_mode]), 0.0)
        _target_speed = _speed
        speed_changed.emit(_speed, _speed_mode)
    else:
        _speed_mode = "custom"
        _speed = 0.0
        _target_speed = 0.0
    _last_pos = global_position
