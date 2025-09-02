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


## other cameras not child of the main rig
@export var extra_rigs: Array[NodePath] = []   # add this

@export var wiggle_run_enabled: bool = true
@export var wiggle_pos_amp: Vector3 = Vector3(0.02, 0.05, 0.0) # x=sway, y=bob, z=push/pull
@export var wiggle_freq_hz: float = 2.0
@export var wiggle_roll_deg: float = 0.8

var _wiggle_t: float = 0.0


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
    _next_rig = next_rig
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

    # Time only advances in-game (keeps editor preview stable).
    if !Engine.is_editor_hint():
        _wiggle_t += delta

    # Live target (rig keeps moving with the player)
    var tgt_tf := _rig_nodes[_active].global_transform
    var tgt_fov := _out_cam.fov
    if _rig_cams[_active] != null:
        tgt_fov = _rig_cams[_active].fov

    # Blend or follow
    var out_tf: Transform3D
    var out_fov: float
    if _t < 1.0 and blend_time > 0.0:
        _t = min(1.0, _t + delta / blend_time)
        var t := _ease(_t)
        var pos := _from_tf.origin.lerp(tgt_tf.origin, t)
        var q := Quaternion(_from_tf.basis).slerp(Quaternion(tgt_tf.basis), t)
        out_tf = Transform3D(Basis(q), pos)
        out_fov = lerpf(_from_fov, tgt_fov, t)
    else:
        out_tf = tgt_tf
        out_fov = tgt_fov

    # Optional run wiggle applied in camera-local space
    if wiggle_run_enabled and _is_run_rig(_active):
        var w := TAU * wiggle_freq_hz * _wiggle_t
        var sway_x := sin(w * 0.5) * wiggle_pos_amp.x           # gentle left/right
        var bob_y:float = abs(sin(w)) * wiggle_pos_amp.y            # up/down (always up on impact)
        var push_z := sin(w) * wiggle_pos_amp.z                 # fore/aft, usually small or zero
        var roll_r := sin(w) * deg_to_rad(wiggle_roll_deg)      # tiny roll

        var wiggle_basis := Basis(Vector3(0,0,1), roll_r)       # roll around camera forward
        var wiggle_tf := Transform3D(wiggle_basis, Vector3(sway_x, bob_y, push_z))
        out_tf = out_tf * wiggle_tf                              # apply in camera local space

    _out_cam.global_transform = out_tf
    _out_cam.fov = out_fov


# --- Public API ---
func activate_index(i: int) -> void:
    if _rig_nodes.is_empty():
        return
    var idx := clampi(i, 0, _rig_nodes.size() - 1)
    if idx == _active and _t >= 1.0:
        return
    _begin_blend_to(idx)

func activate_name(rig_name: String) -> void:
    for i in _rig_nodes.size():
        if _rig_nodes[i].name == rig_name:
            activate_index(i)
            return

@export_tool_button("Next Rig")
var _next_rig: Callable

func next_rig() -> void:
    if _rig_nodes.is_empty():
        return
    activate_index((_active + 1) % _rig_nodes.size())

func current_rig_name() -> String:
    var rig_name = _rig_nodes[_active].name
    if not rig_name:
        return ""
    return rig_name

func current_rig_index() -> int:
    return _active

# --- Internals ---

func _is_run_rig(i: int) -> bool:
    var n := _rig_nodes[i].name.to_lower()
    return n.find("run") != -1


func _collect_rigs() -> void:
    _rig_nodes.clear()
    _rig_cams.clear()

    # 1) direct children (world-aligned shoulder rigs)
    for child in get_children():
        if child is Node3D and child != _out_cam:
            _rig_nodes.append(child)
            var cam: Camera3D = child.get_node_or_null("Camera3D")
            if cam == null:
                cam = child.get_node_or_null("SpringArm3D/Camera3D")
            _rig_cams.append(cam)

    # 2) extra rigs (yaw-follow FP rigs under visuals/yaw pivot)
    for p in extra_rigs:
        var n := get_node_or_null(p)
        if n is Node3D and not _rig_nodes.has(n):
            _rig_nodes.append(n)
            var cam2: Camera3D = n.get_node_or_null("Camera3D")
            if cam2 == null:
                cam2 = n.get_node_or_null("SpringArm3D/Camera3D")
            _rig_cams.append(cam2)


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
