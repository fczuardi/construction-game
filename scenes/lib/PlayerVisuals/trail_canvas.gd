class_name TrailCanvas
extends Node2D
## Draws trail dots into a SubViewport used as the clipboard paper texture.


# ---- defaults
const DEFAULT_PAPER_COLOR: Color = Color("9e8d6fff") # off-white
const DEFAULT_DOT_COLOR: Color = Color("000641ff") # BIC pen
# ---- internal constants
const MAX_POINTS := 4000
const START_OFFSET_PX := Vector2(0, 80)     # first dot nudge on paper
const ORIENTATION_PLAYER_UP := true         # sane default


## Public API
#---------------------------------------

## world meters between dots
@export var meters_per_dot: float = 3.0

## map scale
@export var meters_to_pixels: float = 5.0

## dot size in pixels
@export var dot_radius_px: float = 2.0

## paper color
@export var paper_color: Color = Color("9e8d6fff") # off-white

## ink color to draw the trail dots
@export var dot_color: Color = Color("000641ff")   # BIC pen

# ---- private state
var _runner: Node = null
var _origin_world: Vector3
var _last_mark_world: Vector3
var _have_origin := false
var _accum := 0.0
var _points_px: PackedVector2Array = []
var _start_px_offset := Vector2.ZERO
var _offset_locked := false

## Lifecycle
#---------------------------------------
func _ready() -> void:
    if not PoseBus.pose_updated.is_connected(_on_pose_updated):
        PoseBus.pose_updated.connect(_on_pose_updated)
    queue_redraw()

func _exit_tree() -> void:
    if PoseBus.pose_updated.is_connected(_on_pose_updated):
        PoseBus.pose_updated.disconnect(_on_pose_updated)

func _draw() -> void:
    # paper background (robust even if SubViewport clears)
    var s := get_viewport_rect().size
    draw_rect(Rect2(Vector2.ZERO, s), paper_color, true)
    # trail
    for p in _points_px:
        draw_circle(p, dot_radius_px, dot_color)


## Public Methods
#---------------------------------------
func clear_trail() -> void:
    _points_px.clear()
    _have_origin = false
    _accum = 0.0
    _offset_locked = false
    _start_px_offset = Vector2.ZERO
    queue_redraw()

# -------------------------------------------------
# signal handler from runner
# expected signal on runner: signal pose_updated(world_pos: Vector3, yaw_radians: float)
func _on_pose_updated(world_pos: Vector3, yaw_radians: float) -> void:
    if not _have_origin:
        _origin_world = world_pos
        _last_mark_world = world_pos
        _have_origin = true
        _accum = 0.0
        _append_point(world_pos, yaw_radians)
        return

    var step := world_pos.distance_to(_last_mark_world)
    _accum += step
    if _accum >= meters_per_dot:
        _last_mark_world = world_pos
        _accum = 0.0
        _append_point(world_pos, yaw_radians)

# -------------------------------------------------
# helpers
func _append_point(world_pos: Vector3, yaw_radians: float) -> void:
    var p := _world_to_paper_px(world_pos, yaw_radians)

    if not _offset_locked:
        var center := get_viewport_rect().size * 0.5
        _start_px_offset = (center - p) + START_OFFSET_PX
        _offset_locked = true

    p += _start_px_offset

    _points_px.append(p)
    if _points_px.size() > MAX_POINTS:
        _points_px.remove_at(0)
    queue_redraw()

func _world_to_paper_px(p_world: Vector3, yaw_radians: float) -> Vector2:
    var d := p_world - _origin_world
    var v := Vector2(d.x, -d.z)        # -Z (forward) maps to up on paper
    if ORIENTATION_PLAYER_UP:
        v = v.rotated(-yaw_radians)    # keep player forward = up
    v.x = -v.x #mirror left/right
    return v * meters_to_pixels
