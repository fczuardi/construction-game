@tool
class_name PlayerCameras
extends Node3D
## Virtual-camera blender for a player.
## - Put this as a child of PlayerRunner (or anywhere).
## - Under it, create one child *rig* per preset:
##     RigRoot (Node3D or SpringArm3D) -> ... -> Camera3D (preview-only)
## - Only OutputCamera (child of this node) actually renders.
## - Switch with activate_name()/activate_index()/next_rig(); wire those to signals elsewhere.

signal active_rig_changed(name: String, index: int)

## PlayerCameras/OutputCamera
@export var output_camera_path: NodePath = "OutputCamera"  

## Transition time in seconds
@export_range(0.0, 5.0, 0.01) var blend_time: float = 0.35

@export_tool_button("Next Rig")
var _next_btn: Callable = func():
    next_rig()

# --- Runtime state ---
@onready var _out_cam: Camera3D = get_node_or_null(output_camera_path)

var _rig_nodes: Array[Node3D] = []
var _rig_cams: Array[Camera3D] = []     # optional, for FOV copy per rig

var _active: int = 0
var _t: float = 1.0
var _from_tf: Transform3D = Transform3D.IDENTITY
var _to_tf: Transform3D = Transform3D.IDENTITY
var _from_fov: float = 70.0
var _to_fov: float = 70.0

func _ready() -> void:
    _collect_rigs()
    if _out_cam:
        _out_cam.current = true
    if _rig_nodes.is_empty():
        push_warning("PlayerCameras: no rigs found. Add child Node3D rigs with Camera3D inside.")
        return
    _snap_to(0)

func _process(delta: float) -> void:
    if _out_cam == null or _rig_nodes.is_empty():
        return

    if _t < 1.0 and blend_time > 0.0:
        _t = min(1.0, _t + delta / blend_time)
        var t := _ease(_t)

        var pos := _from_tf.origin.lerp(_to_tf.origin, t)
        var q0 := Quaternion(_from_tf.basis)
        var q1 := Quaternion(_to_tf.basis)
        var q := q0.slerp(q1, t)

        _out_cam.global_transform = Transform3D(Basis(q), pos)
        _out_cam.fov = lerpf(_from_fov, _to_fov, t)
    elif _t >= 1.0:
        _out_cam.global_transform = _to_tf
        _out_cam.fov = _to_fov

# --- Public API ---
func activate_index(i: int) -> void:
    if _rig_nodes.is_empty():
        return
    var idx := clampi(i, 0, _rig_nodes.size() - 1)
    if idx == _active and _t >= 1.0:
        return
    _begin_blend_to(idx)

func activate_name(name: String) -> void:
    for i in _rig_nodes.size():
        if _rig_nodes[i].name == name:
            activate_index(i)
            return

func next_rig() -> void:
    if _rig_nodes.is_empty():
        return
    activate_index((_active + 1) % _rig_nodes.size())

func current_rig_name() -> String:
    return _rig_nodes[_active].name if !_rig_nodes.is_empty() else ""

func current_rig_index() -> int:
    return _active

# --- Internals ---
func _collect_rigs() -> void:
    _rig_nodes.clear()
    _rig_cams.clear()
    for child in get_children():
        if child is Node3D and child != _out_cam:
            _rig_nodes.append(child)
            # find a Camera3D inside rig
            var cam: Camera3D = child.get_node_or_null("Camera3D")
            if cam == null:
                cam = child.get_node_or_null("SpringArm3D/Camera3D")
            _rig_cams.append(cam)

func _snap_to(i: int) -> void:
    _active = i
    _t = 1.0

    var tf := _rig_nodes[i].global_transform
    _from_tf = tf
    _to_tf = tf

    var fov := 70.0
    if _rig_cams[i] != null:
        fov = _rig_cams[i].fov
    _from_fov = fov
    _to_fov = fov

    if _out_cam:
        _out_cam.global_transform = tf
        _out_cam.fov = _to_fov

    active_rig_changed.emit(_rig_nodes[i].name, i)

func _begin_blend_to(i: int) -> void:
    if _out_cam == null:
        return
    _from_tf = _out_cam.global_transform
    _from_fov = _out_cam.fov

    _to_tf = _rig_nodes[i].global_transform
    if _rig_cams[i] != null:
        _to_fov = _rig_cams[i].fov
    else:
        _to_fov = _out_cam.fov

    _active = i
    _t = 0.0
    active_rig_changed.emit(_rig_nodes[i].name, i)

func _ease(t: float) -> float:
    return t * t * (3.0 - 2.0 * t)
