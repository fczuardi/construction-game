class_name TrailCanvas
extends Node2D
## Append-only trail: stamps ink dots into an Image and updates an ImageTexture.
## No per-frame redraw; cost per dot is ~constant.




# ---- config
@export var tex_size: Vector2i = Vector2i(640, 1024)
@export var meters_per_dot: float = 21.0
@export var meters_to_pixels: float = 6.0
@export var dot_radius_px: int = 3
@export var dot_color: Color = Color("000641ff")   # BIC pen
@export var upload_every_ms: int = 120             # throttle GPU uploads

## where to display the texture inside the SubViewport
@export var target_rect: TextureRect                # assign a TextureRect (child of the SubViewport scene)

## If you’re still showing this via a SubViewport:
@export var subvp: SubViewport                      # optional; if present we trigger UPDATE_ONCE
@export var clear_viewport_bg: bool = false         # set true if you draw your paper BG in SubViewport

# ---- constants
const START_OFFSET_PX := Vector2(30, 400)
const ORIENTATION_PLAYER_UP := true

# ---- runtime state (pose → paper)
var _origin_world: Vector3
var _last_mark_world: Vector3
var _have_origin := false
var _accum := 0.0
var _offset_locked := false
var _start_px_offset := Vector2.ZERO

# ---- stamping buffers
var _paper_img: Image
var _trail_tex: ImageTexture
var _stamp_img: Image

# ---- throttling
var _dirty_since_last_upload := false
var _last_upload_ms := 0

func _ready() -> void:
    # 0) SubViewport: event-driven
    if subvp:
        subvp.render_target_update_mode = SubViewport.UPDATE_DISABLED
        subvp.render_target_clear_mode  = SubViewport.CLEAR_MODE_NEVER  # optional

    # 1) Create paper (transparent “ink layer”)
    _paper_img = Image.create(tex_size.x, tex_size.y, false, Image.FORMAT_RGBA8)
    _paper_img.fill(Color(0, 0, 0, 0))  # fully transparent

    # 2) Create GPU texture
    _trail_tex = ImageTexture.create_from_image(_paper_img)

    # 3) Build a small circular alpha stamp once
    _stamp_img = _make_dot_stamp(dot_radius_px, dot_color)

    # 4) Hook the texture to a target
    if target_rect:
        # Optional: add a paper background below in your scene (ColorRect/Sprite) if needed.
        target_rect.texture = _trail_tex

    # 5) Listen for poses
    if not PoseBus.pose_updated.is_connected(_on_pose_updated):
        PoseBus.pose_updated.connect(_on_pose_updated)

func _exit_tree() -> void:
    if PoseBus.pose_updated.is_connected(_on_pose_updated):
        PoseBus.pose_updated.disconnect(_on_pose_updated)

# --- Pose handler: place a dot every meters_per_dot
func _on_pose_updated(world_pos: Vector3, yaw_radians: float) -> void:
    if not _have_origin:
        _origin_world = world_pos
        _last_mark_world = world_pos
        _have_origin = true
        _accum = 0.0
        _stamp_world(world_pos, yaw_radians)   # first dot
        _upload_if_due(true)                   # force initial upload
        return

    var step := world_pos.distance_to(_last_mark_world)
    _accum += step
    if _accum >= meters_per_dot:
        _accum = 0.0
        _last_mark_world = world_pos
        _stamp_world(world_pos, yaw_radians)
        _upload_if_due(false)

# --- Convert world → texture coords and stamp one dot (or a short segment if you prefer)
func _stamp_world(world_pos: Vector3, yaw_radians: float) -> void:
    var p := _world_to_paper_px(world_pos, yaw_radians)

    if not _offset_locked:
        var center := Vector2(tex_size) * 0.5
        _start_px_offset = (center - p) + START_OFFSET_PX
        _offset_locked = true

    p += _start_px_offset

    # Build integer rects
    var tl_i: Vector2i = Vector2i(int(floor(p.x)) - dot_radius_px, int(floor(p.y)) - dot_radius_px)
    var src: Rect2i = Rect2i(Vector2i.ZERO, _stamp_img.get_size())
    var dst: Rect2i = Rect2i(tl_i, _stamp_img.get_size())

    # Image bounds
    var img_rect: Rect2i = Rect2i(Vector2i.ZERO, tex_size)

    # Fast reject if no overlap
    if not img_rect.intersects(dst):
        return

    # Clip destination to image bounds
    var clipped_dst: Rect2i = dst.intersection(img_rect)
    # Map that clip back into source space
    var src_offset: Vector2i = clipped_dst.position - dst.position
    var clipped_src: Rect2i = Rect2i(src.position + src_offset, clipped_dst.size)

    # Stamp (no lock/unlock in Godot 4)
    _paper_img.blend_rect(_stamp_img, clipped_src, clipped_dst.position)

    _dirty_since_last_upload = true


# --- Throttle texture uploads to the GPU
func _upload_if_due(force: bool) -> void:
    if not _dirty_since_last_upload:
        return
    var now := Time.get_ticks_msec()
    if force or now - _last_upload_ms >= upload_every_ms:
        _trail_tex.update(_paper_img)
        _last_upload_ms = now
        _dirty_since_last_upload = false
        if subvp:
            subvp.render_target_update_mode = SubViewport.UPDATE_ONCE


# --- Utility: make a circular dot stamp with alpha
func _make_dot_stamp(r: int, color: Color) -> Image:
    var d := r * 2 + 1
    var img := Image.create(d, d, false, Image.FORMAT_RGBA8)
    img.fill(Color(0,0,0,0))
    var rr := float(r)
    for y in d:
        for x in d:
            var dx := float(x - r)
            var dy := float(y - r)
            if dx*dx + dy*dy <= rr*rr + 0.25:  # +0.25 to anti-alias edges slightly
                img.set_pixel(x, y, color)
    return img

# --- Your existing math (unchanged)
func _world_to_paper_px(p_world: Vector3, yaw_radians: float) -> Vector2:
    var d := p_world - _origin_world
    var v := Vector2(d.x, -d.z)        # -Z forward maps to up on paper
    if ORIENTATION_PLAYER_UP:
        v = v.rotated(-yaw_radians)    # keep player forward = up
    v.x = -v.x                         # mirror left/right if needed
    return v * meters_to_pixels

# --- Optional helper if you ever need to clear (you said you won’t):
func clear_trail() -> void:
    _paper_img.fill(Color(0,0,0,0))
    _trail_tex.update(_paper_img)
    _dirty_since_last_upload = false
    _have_origin = false
    _accum = 0.0
    _offset_locked = false
    _start_px_offset = Vector2.ZERO
    if subvp:
        subvp.render_target_update_mode = SubViewport.UPDATE_ONCE
