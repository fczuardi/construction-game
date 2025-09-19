class_name CameraYawSpring
extends Node3D
## Smoothly lag this pivot behind the player's yaw using exponential smoothing.
## Put this on the shared pivot that parents your shoulder rigs.

@export var lag_tau_s: float = 0.70               # bigger = more delay (0.5–1.2 sweet spot)
@export var max_follow_speed_deg: float = 540.0   # clamp angular speed; set 0 to disable
@export var tiny_epsilon_deg: float = 0.05
@export var debug_prints: bool = false

var _target_norm: float = 0.0   # latest player yaw (normalized degrees)

func _ready() -> void:
    # init target to current pivot yaw
    _target_norm = _norm(rotation_degrees.y)
    if not EventBus.player_runner_pose_updated.is_connected(_on_player_pose):
        EventBus.player_runner_pose_updated.connect(_on_player_pose)

func _exit_tree() -> void:
    if EventBus.player_runner_pose_updated.is_connected(_on_player_pose):
        EventBus.player_runner_pose_updated.disconnect(_on_player_pose)

func _on_player_pose(_pos: Vector3, yaw_rad: float) -> void:
    _target_norm = _norm(rad_to_deg(yaw_rad))  # body-led yaw from move_dir

func _process(delta: float) -> void:
    if lag_tau_s <= 0.0:
        # snap instantly if tau=0 (useful for testing)
        var v := rotation_degrees
        v.y = _unwrap_toward(v.y, _target_norm, _ang_delta(_norm(v.y), _target_norm))
        rotation_degrees = v
        return

    # compute signed shortest delta in normalized space
    var cur_unwrapped := rotation_degrees.y
    var cur_norm := _norm(cur_unwrapped)
    var delta_deg := _ang_delta(cur_norm, _target_norm)
    if abs(delta_deg) < tiny_epsilon_deg:
        return

    # exponential fraction this frame (independent of framerate)
    var k := 1.0 - exp(-delta / lag_tau_s)   # 0..1
    var step := delta_deg * k                # degrees to move this frame

    # optional clamp by max speed
    if max_follow_speed_deg > 0.0:
        var max_step := max_follow_speed_deg * delta
        step = clampf(step, -max_step, +max_step)

    # apply in UNWRAPPED space to avoid 360° flips, then write back
    var v := rotation_degrees
    v.y = v.y + step
    rotation_degrees = v

    if debug_prints:
        print("cam yaw cur=", cur_norm, " tgt=", _target_norm, " delta=", delta_deg, " step=", step)

# ---- helpers ----
func _norm(a: float) -> float:
    return wrapf(a, -180.0, 180.0)

func _ang_delta(cur_norm: float, tgt_norm: float) -> float:
    return _norm(tgt_norm - cur_norm)  # signed shortest path (-180..+180)

func _unwrap_toward(cur_unwrapped: float, tgt_norm: float, delta_norm: float) -> float:
    # move fully in one go while respecting unwrap (used only in snap case)
    return cur_unwrapped + delta_norm
