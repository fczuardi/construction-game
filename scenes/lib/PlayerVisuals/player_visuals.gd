@tool
class_name PlayerVisuals
extends Node3D
## Visual/animation presentation for the player (no gameplay).
## v1: Idle/Walk/Run + Map (upper-body) overlay.

signal state_changed(run_enabled: bool, map_enabled: bool)

# --- Editor wiring ----------------------------------------------------
## Optional: CharacterBody3D to read velocity/grounded from automatically.
@export var runner_path: NodePath

## Speed at which StrideScale = 1.0 (usually your walk speed in m/s).
@export var stride_ref_speed: float = 1.11
## Clamp range for stride time scaling (playback speed).
@export var stride_scale_min: float = 0.75
@export var stride_scale_max: float = 1.25

## Smoothing (seconds). 0 = snap.
@export var speed_smooth_time: float = 0.10
@export var yaw_smooth_time: float = 0.05

## Consider speeds below this as “stopped/idle”.
@export var zero_speed_epsilon: float = 0.05

# AnimationTree parameter paths (match your BlendTree layout)
const PATH_SM_PLAYBACK := "parameters/Locomotion/playback"
const PATH_STRIDE_SCALE := "parameters/StrideScale/scale"
const PATH_MAP_BLEND := "parameters/UpperBodyBlend/blend_amount"

# --- Runtime ----------------------------------------------------------
var _anim_tree: AnimationTree
var _sm: AnimationNodeStateMachinePlayback

var _run_enabled := false
var _map_enabled := false

var _vel := Vector3.ZERO
var _on_floor := true

var _speed_raw := 0.0
var _speed_param := 0.0
var _yaw := 0.0
var _yaw_target := 0.0

func _ready() -> void:
    _bind_anim_tree()
    _yaw = rotation.y
    _yaw_target = _yaw
    if _anim_tree:
        _anim_tree.active = true

func _process(delta: float) -> void:
    if Engine.is_editor_hint():
        return  # skip driving the AnimationTree when not playing
    # Optional auto-pull from runner
    if runner_path != NodePath():
        var runner := get_node_or_null(runner_path)
        if runner is CharacterBody3D:
            var cb := runner as CharacterBody3D
            _on_floor = cb.is_on_floor()
            _vel = cb.velocity

    # derive facing / speed
    _speed_raw = _vel.length()
    if _speed_raw > zero_speed_epsilon:
        _yaw_target = atan2(_vel.x, _vel.z)

    # smoothing
    var k_speed := _exp_k(delta, speed_smooth_time)
    _speed_param = lerp(_speed_param, _speed_raw, k_speed)

    var k_yaw := _exp_k(delta, yaw_smooth_time)
    _yaw = lerp_angle(_yaw, _yaw_target, k_yaw)
    rotation.y = _yaw

    if _anim_tree == null:
        return

    # 1) Stride playback scale
    var stride_scale := 1.0
    if stride_ref_speed > 0.0:
        stride_scale = clamp(_speed_raw / stride_ref_speed, stride_scale_min, stride_scale_max)
    _anim_tree.set(PATH_STRIDE_SCALE, stride_scale)

    # 2) Map overlay (upper body)
    if _map_enabled:
        _anim_tree.set(PATH_MAP_BLEND, 1.0)
    else:
        _anim_tree.set(PATH_MAP_BLEND, 0.0)

    # 3) Locomotion state
    if _sm:
        if _speed_raw <= zero_speed_epsilon:
            _sm.travel("Idle")
        else:
            if _run_enabled:
                _sm.travel("Run")
            else:
                _sm.travel("Walk")

# --- Public API --------------------------------------------------------
func update_motion(velocity: Vector3, on_floor: bool) -> void:
    _vel = velocity
    _on_floor = on_floor

func set_run_enabled(on: bool) -> void:
    if _run_enabled == on:
        return
    _run_enabled = on
    state_changed.emit(_run_enabled, _map_enabled)

func set_map_enabled(on: bool) -> void:
    if _map_enabled == on:
        return
    _map_enabled = on
    state_changed.emit(_run_enabled, _map_enabled)

func is_run_enabled() -> bool: return _run_enabled
func is_map_enabled() -> bool: return _map_enabled

func snap_facing(yaw_rad: float) -> void:
    _yaw = yaw_rad
    _yaw_target = yaw_rad
    rotation.y = yaw_rad

# --- Internals ---------------------------------------------------------
func _bind_anim_tree() -> void:
    _anim_tree = get_node_or_null("AnimationTree") as AnimationTree
    if _anim_tree == null:
        push_warning("PlayerVisuals: expected a child node named 'AnimationTree'.")
        return
    var pb = _anim_tree.get(PATH_SM_PLAYBACK)
    if pb is AnimationNodeStateMachinePlayback:
        _sm = pb
    else:
        push_warning("PlayerVisuals: couldn't get StateMachine playback at %s. Check your AnimationTree paths." % PATH_SM_PLAYBACK)

func _exp_k(delta: float, tau: float) -> float:
    if tau <= 0.0:
        return 1.0
    return 1.0 - exp(-delta / tau)
