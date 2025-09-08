class_name TrailCanvas
extends SubViewport
## Stamps ink dots into an TextureRect layer


## the dimensions of the base image
@export var tex_size: Vector2i = Vector2i(640, 1024)
## where should the first dot (player's origin) be plotted on the image
@export var starting_point: Vector2 = Vector2i(341.0, 137.0)
## Image to be used as ink dot
@export var dot_stamp: Image = load("res://imports/icons/circle-fill_12px.png")
## the ink color
@export var dot_color: Color = Color("000641ff")   # BIC pen
## minimal traveled distance before plotting a dot
@export var meters_per_dot: float = 3.0
## map scale, how many meters in the world moves is a pixel in the map
@export var meters_to_pixels: float = 24.381
## throttle GPU uploads
@export var upload_every_ms: int = 200 

## expected nodes
@onready var trail_layer: TextureRect = %TrailLayer


# ---- stamping buffers
var _paper_img: Image
var _trail_tex: ImageTexture
var _stamp_img: Image

# ---- runtime state
var _have_origin := false
var _origin_world: Vector3
var _last_mark_world: Vector3
var _accum := 0.0

# ---- throttling
var _dirty_since_last_upload := false
var _last_upload_ms := 0

func _ready():
    assert(dot_stamp)
    assert(trail_layer)

    trail_layer.self_modulate = dot_color
    # save on performance by only updating when needed
    # other functions will chaange to UPDATE_ONCE before drawing
    render_target_update_mode = SubViewport.UPDATE_DISABLED
    render_target_clear_mode  = SubViewport.CLEAR_MODE_NEVER

    # Create paper (transparent “ink layer”)
    _paper_img = Image.create(tex_size.x, tex_size.y, false, Image.FORMAT_RGBA8)
    _paper_img.fill(Color(0, 0, 0, 0))  # fully transparent

    # Create GPU texture
    _trail_tex = ImageTexture.create_from_image(_paper_img)

    # circular image to be the ink dot stamp
    _stamp_img = dot_stamp

    # hook texture to texturerect layer
    trail_layer.texture = _trail_tex

    # Listen for poses
    if not EventBus.player_runner_pose_updated.is_connected(_on_pose_updated):
        EventBus.player_runner_pose_updated.connect(_on_pose_updated)

func _exit_tree() -> void:
    if EventBus.player_runner_pose_updated.is_connected(_on_pose_updated):
        EventBus.player_runner_pose_updated.disconnect(_on_pose_updated)

func _draw_first_dot():
    var stamp_rect: Rect2i = Rect2i(Vector2i.ZERO, _stamp_img.get_size())
    var paper_pos_rect: Vector2i = starting_point as Vector2i

    # stamp dot on paper at position
    _paper_img.blend_rect(_stamp_img, stamp_rect, paper_pos_rect)

    _dirty_since_last_upload = true

    return

    # update GPU texture
    _trail_tex.update(_paper_img)

    # update SubViewport (self)
    render_target_update_mode = SubViewport.UPDATE_ONCE

func _on_pose_updated(world_pos: Vector3, yaw_radians: float) -> void:
    # --- first player pose update
    if not _have_origin:
        _origin_world = world_pos
        _last_mark_world = world_pos
        _draw_first_dot()
        _have_origin = true
        _accum = 0.0

    # --- from here on, stamp if distance from last mark is bigger than meters_per_dot ---
    var step := world_pos.distance_to(_last_mark_world)
    if step <= 0.0001:
        return                         # no movement

    _accum += step
    if _accum >= meters_per_dot:
        _accum = 0.0
        _last_mark_world = world_pos   # advance the "last marked" position
        _stamp_world(world_pos, yaw_radians)
        _upload_if_due(false)


# --- Convert world → paper px and stamp a dot
func _stamp_world(world_pos: Vector3, yaw_radians: float) -> void:
    var p := _world_to_paper_px(world_pos, yaw_radians)
    var dot_radius_px = _stamp_img.get_size().x / 2

    var tl_i: Vector2i = Vector2i(int(floor(p.x)) - dot_radius_px, int(floor(p.y)) - dot_radius_px)
    var src: Rect2i = Rect2i(Vector2i.ZERO, _stamp_img.get_size())
    var dst: Rect2i = Rect2i(tl_i, _stamp_img.get_size())

    var img_rect: Rect2i = Rect2i(Vector2i.ZERO, tex_size)
    if not img_rect.intersects(dst):
        return

    var clipped_dst: Rect2i = dst.intersection(img_rect)
    var src_offset: Vector2i = clipped_dst.position - dst.position
    var clipped_src: Rect2i = Rect2i(src.position + src_offset, clipped_dst.size)

    _paper_img.blend_rect(_stamp_img, clipped_src, clipped_dst.position)
    _dirty_since_last_upload = true

# --- World → paper mapping
func _world_to_paper_px(p_world: Vector3, yaw_radians: float) -> Vector2:
    # Delta from where the player started this map view
    var d := p_world - _origin_world               # (dx, dy, dz) in meters

    # Work in XZ plane
    var v := Vector2(d.x, -d.z)                     # v.y grows when walking +Z
    # Keep player’s forward as “up” on the paper
    v = v.rotated(-yaw_radians)

    # Pixels: +X => right, +Z => UP  (hence the minus on Y)
    return starting_point + Vector2(v.x, -v.y) * meters_to_pixels

# --- Throttle texture uploads to the GPU
func _upload_if_due(force: bool) -> void:
    if not _dirty_since_last_upload:
        return
    var now := Time.get_ticks_msec()
    if force or now - _last_upload_ms >= upload_every_ms:
        _trail_tex.update(_paper_img)
        _last_upload_ms = now
        _dirty_since_last_upload = false
        render_target_update_mode = SubViewport.UPDATE_ONCE

# --- Optional helper
func clear_trail() -> void:
    _paper_img.fill(Color(0,0,0,0))
    _trail_tex.update(_paper_img)
    _dirty_since_last_upload = false
    render_target_update_mode = SubViewport.UPDATE_ONCE
