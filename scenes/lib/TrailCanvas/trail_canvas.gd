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

# Add these exports near the others (optional but useful)
@export var invert_x: bool = false      # flip if left/right looks mirrored
@export var invert_z: bool = false       # paper "up" usually means world +Z upward on the image
@export var map_rotation_deg: float = 0 # fixed alignment offset for the blueprint (NOT player yaw)


## expected nodes
@onready var trail_layer: TextureRect = %TrailLayer
@onready var player_direction: Control = %PlayerDirection


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
    if not EventBus.global_restart_game.is_connected(reset_to_start):
        EventBus.global_restart_game.connect(reset_to_start)

func reset_to_start():
    clear_trail()

func get_trail_texture() -> Texture2D:
    return _trail_tex
   
func _exit_tree() -> void:
    if EventBus.player_runner_pose_updated.is_connected(_on_pose_updated):
        EventBus.player_runner_pose_updated.disconnect(_on_pose_updated)
    if EventBus.global_restart_game.is_connected(reset_to_start):
        EventBus.global_restart_game.disconnect(reset_to_start)

func _draw_first_dot():
    var stamp_rect: Rect2i = Rect2i(Vector2i.ZERO, _stamp_img.get_size())
    var paper_pos_rect: Vector2i = starting_point as Vector2i

    # stamp dot on paper at position
    _paper_img.blend_rect(_stamp_img, stamp_rect, paper_pos_rect)

    _dirty_since_last_upload = true

    return

var _last_yaw: float
func _on_pose_updated(world_pos: Vector3, _yaw_radians: float) -> void:
    _last_yaw = - _yaw_radians
    # --- first player pose update
    if not _have_origin:
        _origin_world = world_pos
        _last_mark_world = world_pos
        _draw_first_dot()
        _have_origin = true
        _accum = 0.0

    # --- distance check (unchanged) ---
    var step := world_pos.distance_to(_last_mark_world)
    if step <= 0.0001:
        return

    _accum += step
    if _accum >= meters_per_dot:
        _accum = 0.0
        _last_mark_world = world_pos
        _stamp_world(world_pos)   # <- ignore yaw here
        _upload_if_due(false)


func _stamp_world(world_pos: Vector3) -> void:
    var p := _world_to_paper_px(world_pos)
    player_direction.position = p
    player_direction.rotation = _last_yaw
    var dot_radius_px := _stamp_img.get_size().x / 2

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


func _world_to_paper_px(p_world: Vector3) -> Vector2:
    # Delta from the run start
    var d := p_world - _origin_world   # meters (dx, dy, dz)

    # Project to XZ plane in a fixed frame (no player yaw)
    var vx := d.x
    var vy := d.z

    # Optional fixed alignment for the blueprint (e.g., +15° if your plan isn’t axis-aligned)
    if map_rotation_deg != 0.0:
        var ang := deg_to_rad(map_rotation_deg)
        var cs := cos(ang)
        var sn := sin(ang)
        var rx :=  cs * vx - sn * vy
        var ry :=  sn * vx + cs * vy
        vx = rx
        vy = ry

    # Apply axis flips to match your paper orientation
    if invert_x: vx = -vx
    if invert_z: vy = -vy   # makes world +Z go "up" on paper

    # Scale to pixels and offset by starting point
    return starting_point + Vector2(vx, vy) * meters_to_pixels









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
