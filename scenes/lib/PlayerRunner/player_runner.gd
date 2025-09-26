class_name PlayerRunner
extends CharacterBody3D
## Runner body: falls, queues yaw turns, moves forward with switchable speeds.

const VERSION := "0.6.0"

# --- Signals --------------------------
signal collided(collider: Node, normal: Vector3, grounded: bool, speed_mps: float, speed_mode: String)
signal turn_buffer_changed(remaining_deg: float)
signal speed_changed(new_speed: float, mode: String)
signal fell()

# --- Defaults ------------------------
const DEFAULT_SPEED_STOP: float = 0.0
const DEFAULT_SPEED_WALK: float = 0.85
const DEFAULT_SPEED_JOG:  float = 2.4
const DEFAULT_SPEED_RUN:  float = 5.0
const DEFAULT_TURN_RATE:  float = 180.0

# --- Exports -------------------------
@export var visuals: PlayerVisuals2
@export var speed_blend_time: float = 0.4

@export var speed_modes: Dictionary[String, float] = {
    "stop": DEFAULT_SPEED_STOP,
    "walk": DEFAULT_SPEED_WALK,
    "jog":  DEFAULT_SPEED_JOG,
    "run":  DEFAULT_SPEED_RUN,
}
@export var default_speed_mode: String = "walk"

@export var turn_rate_deg := DEFAULT_TURN_RATE
@export var snap_enabled: bool = true
@export var snap_increment_deg: float = 30.0
@export var snap_dead_zone_deg: float = 4.0

# --- Wall probe (logic-only) ----------
@export var wall_probe_length: float = 0.3          # forward cast distance
@export var wall_normal_min_horiz: float = 0.2      # min horizontal magnitude to count as wall
@export var wall_probe_layer_index: int = 2         # walls layer
@onready var _wall_probe: ShapeCast3D = get_node_or_null("WallProbe")

# --- Falling KO settings --------------
@export var fall_coyote_ms: int = 120
@export var fall_speed_trigger: float = -1.2
@export var fall_drop_trigger: float = 0.75

var _off_floor_since_ms: int = -1
var _fall_start_y: float = 0.0

# --- Private state --------------------
var _move_dir: Vector3
var _remaining_turn_deg: float
var _turn_axis: float = 0.0

var _target_speed: float
var _speed: float
var _speed_mode: String = "custom"

var _start_xform: Transform3D
var _last_pos: Vector3

var _turn_session_active: bool = false
var _turn_session_dir: int = 0     # -1 right/EAST, +1 left/WEST

# --- Setup ----------------------------
func _ready() -> void:
    assert(visuals)
    assert(_wall_probe)
    if !visuals:
        return

    _start_xform = global_transform
    reset_to_start()
    EventBus.global_restart_game.connect(reset_to_start)

    # CharacterBody3D tuning
    safe_margin = 0.02
    max_slides = 8
    floor_snap_length = 0.5

    # Probe setup (mask only walls)
    _wall_probe.enabled = true
    _wall_probe.collision_mask = 0
    _wall_probe.set_collision_mask_value(wall_probe_layer_index, true)
    _wall_probe.exclude_parent = true
    _aim_wall_probe(_move_dir)  # initialize direction

# --- Tick -----------------------------
func _physics_process(delta: float) -> void:
    var pos0 := global_position

    # A) Air vs ground
    if not is_on_floor():
        _update_fall_state(delta)
    else:
        _off_floor_since_ms = -1
        _update_turning(delta)
        _blend_speed(delta)
        _apply_horizontal_velocity()

    # B) Integrate
    move_and_slide()

    # C) Wall snap via probe (horizontal-only logic)
    _aim_wall_probe(_move_dir)
    var wall_n := _probe_best_wall_normal()
    if wall_n != Vector3.ZERO:
        _snap_parallel_to_wall(wall_n)
    else:
        _follow_actual_motion(pos0)

    # D) Visuals & events
    visuals.update_motion(velocity, is_on_floor())
    EventBus.player_runner_pose_updated.emit(global_transform.origin, atan2(_move_dir.x, _move_dir.z))

    var d2 := global_position.distance_to(_last_pos)
    if d2 > 0.0:
        _last_pos = global_position

    var sc := get_slide_collision_count()
    for i in range(sc):
        var c := get_slide_collision(i)
        if c:
            collided.emit(c.get_collider(), c.get_normal(), is_on_floor(), _speed, _speed_mode)

# --- Phase helpers ---------------------
func _update_fall_state(delta: float) -> void:
    if _off_floor_since_ms < 0:
        _off_floor_since_ms = Time.get_ticks_msec()
        _fall_start_y = global_position.y

    velocity += get_gravity() * delta

    var airtime := Time.get_ticks_msec() - _off_floor_since_ms
    var drop := _fall_start_y - global_position.y
    if airtime >= fall_coyote_ms and (velocity.y <= fall_speed_trigger or drop >= fall_drop_trigger):
        set_speed_mode("stop")
        fell.emit()

func _update_turning(delta: float) -> void:
    if _turn_axis != 0.0:
        var hold_step: float = turn_rate_deg * _turn_axis * delta
        _move_dir = _move_dir.rotated(Vector3.UP, deg_to_rad(hold_step)).normalized()

    var max_step: float = turn_rate_deg * delta
    var step: float = clamp(_remaining_turn_deg, -max_step, max_step)
    if step != 0.0:
        _move_dir = _move_dir.rotated(Vector3.UP, deg_to_rad(step)).normalized()
        _remaining_turn_deg -= step
        turn_buffer_changed.emit(_remaining_turn_deg)

func _blend_speed(delta: float) -> void:
    var k := _exp_k(delta, speed_blend_time)
    _speed = lerp(_speed, _target_speed, k)

func _apply_horizontal_velocity() -> void:
    var horiz := _move_dir * _speed
    velocity.x = horiz.x
    velocity.z = horiz.z
    velocity.y = 0.0

# --- Probe + snap ----------------------
func _aim_wall_probe(dir: Vector3) -> void:
    if not _wall_probe or dir.length() <= 0.001:
        return
    _wall_probe.rotation.y = atan2(dir.x, dir.z)            # face travel dir
    _wall_probe.target_position = Vector3.BACK * wall_probe_length  # cast along local +Z
    _wall_probe.force_shapecast_update()

func _probe_best_wall_normal() -> Vector3:
    if not _wall_probe or not _wall_probe.is_colliding():
        return Vector3.ZERO

    var move2 := _xz(_move_dir)
    if move2.length() <= 0.001:
        move2 = Vector3.FORWARD

    var best_n := Vector3.ZERO
    var best_dot := 1.0
    var hits := _wall_probe.get_collision_count()
    for i in range(hits):
        var n := _wall_probe.get_collision_normal(i)
        var n2 := _xz(n)
        var n2_len := n2.length()
        if n2_len < wall_normal_min_horiz:
            continue
        n2 /= n2_len

        var d := move2.dot(n2)       # smaller = more head-on
        if d < best_dot:
            best_dot = d
            best_n = n2
    return best_n

func _snap_parallel_to_wall(wall_n_xz: Vector3) -> void:
    print('snap to wall')
    var tangent := Vector3.UP.cross(wall_n_xz).normalized()    # along the wall
    if tangent.dot(_xz(_move_dir)) < 0.0:
        tangent = -tangent
    _move_dir = tangent
    velocity.x = _move_dir.x * _speed
    velocity.z = _move_dir.z * _speed

func _follow_actual_motion(pos0: Vector3) -> void:
    var motion := global_position - pos0
    if motion.length() > 0.001:
        _move_dir = _xz(motion).normalized()

# --- Math utils ------------------------
func _exp_k(dt: float, tau: float) -> float:
    if tau <= 0.0:
        return 1.0
    return 1.0 - exp(-dt / tau)

func _xz(v: Vector3) -> Vector3:
    return Vector3(v.x, 0.0, v.z)

func _yaw_from_move_dir_deg() -> float:
    return rad_to_deg(atan2(_move_dir.x, _move_dir.z))

func _wrap_deg(a: float) -> float:
    return wrapf(a, -180.0, 180.0)

func _snap_delta_deg() -> float:
    if snap_increment_deg <= 0.0:
        return 0.0
    var yaw := _yaw_from_move_dir_deg()
    var nearest : float = round(yaw / snap_increment_deg) * snap_increment_deg
    var delta := _wrap_deg(nearest - yaw)
    if abs(delta) <= snap_dead_zone_deg:
        return 0.0
    return delta

func snap_to_grid() -> void:
    if not snap_enabled:
        return
    var delta := _snap_delta_deg()
    if delta != 0.0:
        queue_turn(delta)

# --- Public API ------------------------
func set_turn_axis(v: float) -> void:
    v = clamp(v, -1.0, 1.0)
    var was_holding := _turn_axis != 0.0
    var new_holding := v != 0.0

    if (not was_holding) and new_holding:
        _turn_session_active = true
        _turn_session_dir = 1 if v > 0.0 else -1

    if was_holding and (not new_holding) and _turn_session_active:
        var inc := snap_increment_deg if snap_increment_deg > 0.0 else 45.0
        var yaw := _yaw_from_move_dir_deg()
        var target: float
        if _turn_session_dir > 0:
            target = floor(yaw / inc) * inc + inc   # next higher multiple (left)
        else:
            target = ceil(yaw / inc) * inc - inc    # next lower multiple (right)

        var delta := _wrap_deg(target - yaw)
        if sign(delta) != _turn_session_dir and abs(delta) > 0.001:
            delta = _wrap_deg(delta + _turn_session_dir * inc)
        if abs(delta) > 0.001:
            queue_turn(delta)

        _turn_session_active = false
        _turn_session_dir = 0

    _turn_axis = v

func queue_turn(delta_deg: float) -> void:
    _remaining_turn_deg = clamp(_remaining_turn_deg + delta_deg, -360.0, 360.0)
    turn_buffer_changed.emit(_remaining_turn_deg)

func set_speed_mode(mode: String) -> void:
    var key := mode.to_lower()
    if speed_modes.has(key):
        _target_speed = max(float(speed_modes[key]), 0.0)
        _speed_mode = key
        speed_changed.emit(_target_speed, _speed_mode)
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
