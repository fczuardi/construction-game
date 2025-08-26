@tool
class_name FollowCamera
extends Node3D
## Mobile-friendly follow cam: smooth third-person behind/above,
## toggleable first-person map view


const VERSION := "0.1.0"


# --- Defaults ------------------------

const DEFAULT_DISTANCE: float = 6.0
const DEFAULT_HEIGHT: float = 2.0
const DEFAULT_LOOK_AT_HEIGHT: float = 1.2
const DEFAULT_FP_EYE_HEIGHT: float = 1.6
const DEFAULT_MAP_PITCH: float = 45
const DEFAULT_SMOOTHING: float = 0.15


# --- Exports (tiny surface) -----------

## Who to follow (usually the PlayerRunner or its visuals)
@export var target_path: NodePath:
    set(value):
        target_path = value
        _bind_target()

## Third-person follow distance (meters, behind the target along its forward)
@export var distance:= DEFAULT_DISTANCE
## Third-person camera height above target (meters)
@export var height:= DEFAULT_HEIGHT
## Look-at height offset on the target (where the camera looks)
@export var look_at_height:= DEFAULT_LOOK_AT_HEIGHT
## First-person eye height (meters above target origin)
@export var fp_eye_height:= DEFAULT_FP_EYE_HEIGHT
## Map view downward pitch (deg, negative looks down)
@export var map_pitch_deg:= DEFAULT_MAP_PITCH
## Smoothing time constant in seconds (0 = snap)
@export var smoothing:= DEFAULT_SMOOTHING


# --- Private --------------------------

@onready var _cam: Camera3D = get_node_or_null("Camera3D")
var _target: Node3D
var _map_mode: bool = false

func _ready() -> void:
    _bind_target()
    if _cam == null:
        push_warning("FollowCamera: Add a Camera3D as a direct child.")
    # Snap on first frame
    _update_desired(0.0, true)

func _process(delta: float) -> void:
    _update_desired(delta, false)

func _bind_target() -> void:
    _target = get_node_or_null(target_path)


# --- Public API -----------------------

func set_map_mode(on: bool) -> void:
    _map_mode = on

## instant snaps to the current camera destination, skipping the smoothing transition
func snap_to_target() -> void:
    _update_desired(0.0, true)

@export_tool_button("Map")
var map_action: Callable = func():
    set_map_mode(true)

@export_tool_button("Shoulder")
var shoulder_action: Callable = func():
    set_map_mode(false)

@export_tool_button("Follow")
var follow_action: Callable = snap_to_target


# --- Core -----------------------------

func _update_desired(delta: float, snap: bool) -> void:
    if _cam == null or _target == null:
        return

    var tpos: Vector3 = _target.global_transform.origin
    var tfwd: Vector3 = _target.global_transform.basis.z.normalized() # your game uses +Z as forward

    var desired_pos: Vector3
    var desired_dir: Vector3

    if _map_mode:
        # First-person: sit at eye height and look down at an angle
        desired_pos = tpos + Vector3(0.0, fp_eye_height, 0.0)

        var forward: Vector3 = tfwd
        var right: Vector3 = _target.global_transform.basis.x.normalized()  # target's local +X (right)
        desired_dir = forward.rotated(right, deg_to_rad(map_pitch_deg))
    else:
        # Third-person: behind target along -forward, at given height, looking at target's upper body
        desired_pos = tpos + (-tfwd * distance) + Vector3(0.0, height, 0.0)
        desired_dir = (tpos + Vector3(0.0, look_at_height, 0.0)) - desired_pos

    # Build desired transform by aiming at a point
    var dir_norm: Vector3 = desired_dir.normalized()
    var look_point: Vector3 = desired_pos + dir_norm  # any point ahead along the desired direction

    var desired_tf: Transform3D = Transform3D.IDENTITY
    desired_tf.origin = desired_pos
    desired_tf = desired_tf.looking_at(look_point, Vector3.UP)  # camera will face the look point

    if snap or smoothing <= 0.0:
        _cam.global_transform = desired_tf
        return

    # Exponential smoothing for both position and rotation
    var k: float = 1.0 - exp(-delta / smoothing)

    var cur_tf := _cam.global_transform
    var new_pos := cur_tf.origin.lerp(desired_tf.origin, k)
    var new_q := Quaternion(cur_tf.basis).slerp(Quaternion(desired_tf.basis), k)

    _cam.global_transform = Transform3D(Basis(new_q), new_pos)
