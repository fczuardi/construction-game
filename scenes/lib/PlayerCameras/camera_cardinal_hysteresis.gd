class_name CameraYawFollower
extends Node3D
## Always tween this pivot to the player's yaw with a fixed duration.
## Put this on the shared pivot that parents your shoulder rigs.

@export var tween_time: float = 1.0                          # same duration for any delta
@export var tween_ease: Tween.EaseType = Tween.EASE_IN_OUT
@export var tween_trans: Tween.TransitionType = Tween.TRANS_SINE
@export var retarget_threshold_deg: float = 8.0              # don't restart tween unless target moved this much
@export var tiny_delta_epsilon_deg: float = 0.1              # ignore micro noise
@export var debug_prints: bool = false

var _tween: Tween
var _last_target_norm: float = 1e9

func _ready() -> void:
    EventBus.player_runner_pose_updated.connect(_on_player_pose)

func _exit_tree() -> void:
    if EventBus.player_runner_pose_updated.is_connected(_on_player_pose):
        EventBus.player_runner_pose_updated.disconnect(_on_player_pose)

func _on_player_pose(_pos: Vector3, yaw_rad: float) -> void:
    var target_norm := _normalize_deg(rad_to_deg(yaw_rad))   # target (normalized)

    # Current angle in both frames
    var cur_unwrapped := rotation_degrees.y                  # real property (can drift)
    var cur_norm := _normalize_deg(cur_unwrapped)            # for math

    # Shortest signed delta in normalized space, then apply in unwrapped frame
    var delta := _shortest_to_target(cur_norm, target_norm)
    if abs(delta) < tiny_delta_epsilon_deg:
        return

    # If a tween is running, only retarget when target changed enough
    if _tween_running():
        if abs(_ang_dist_deg(target_norm, _last_target_norm)) < retarget_threshold_deg:
            return
        _tween.kill()

    _last_target_norm = target_norm
    var goal_y := cur_unwrapped + delta
    _tween_to(goal_y, tween_time)
    if debug_prints:
        print("cam-> target=", target_norm, " delta=", delta)

func _tween_to(goal_y: float, dur: float) -> void:
    _tween = create_tween()
    _tween.set_ease(tween_ease)
    _tween.set_trans(tween_trans)

    var start := rotation_degrees
    var goal := start
    goal.y = goal_y
    _tween.tween_property(self, "rotation_degrees", goal, dur)

    # Optional: rewrap at end so values don't grow unbounded
    _tween.tween_callback(func ():
        var v := rotation_degrees
        v.y = _normalize_deg(v.y)
        rotation_degrees = v
    )

func _tween_running() -> bool:
    return _tween != null and _tween.is_valid() and _tween.is_running()

# ---- angle helpers ----
func _normalize_deg(a: float) -> float:
    return wrapf(a, -180.0, 180.0)

func _ang_dist_deg(a: float, b: float) -> float:
    return _normalize_deg(b - a)

func _shortest_to_target(cur: float, target: float) -> float:
    return _ang_dist_deg(cur, target)
