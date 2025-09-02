class_name DemoExitOverlay
extends CanvasLayer
## Touch-friendly overlay: big "Back" button to return to the demo index.

const VERSION := "0.1.0"

# Where to go back to
@export var index_scene: PackedScene
@export var index_scene_path: String = "res://demos/Index.tscn" # optional fallback (e.g. "res://scenes/Index.tscn")

# Button placement & size
## 0=TopLeft, 1=TopRight, 2=BottomLeft, 3=BottomRight
@export var corner: int = 0
@export var padding: int = 16
@export var button_size: Vector2 = Vector2(96, 96)
@export var label: String = "Back"

# Style niceties
@export var rounded: bool = true
@export var opacity: float = 0.65  # 0..1 background

var _btn: Button

func _ready() -> void:
    # If we weren't launched from Index, hide this overlay in direct (F6) runs
    var from_index := get_tree().root.has_meta("launched_from_index") \
        and bool(get_tree().root.get_meta("launched_from_index"))
    if not from_index:
        visible = false
        return

    # optional: clear the flag so nested scene changes don't inherit it
    get_tree().root.set_meta("launched_from_index", false)

    _make_button()
    _position_button()
    set_process_input(true)

func _make_button() -> void:
    _btn = Button.new()
    _btn.text = label
    _btn.toggle_mode = false
    _btn.focus_mode = Control.FOCUS_NONE
    _btn.custom_minimum_size = button_size
    # simple readable style
    _btn.modulate = Color(1, 1, 1, 1)
    _btn.add_theme_color_override("font_color", Color(1,1,1,1))
    _btn.add_theme_color_override("font_pressed_color", Color(1,1,1,1))
    var bg := StyleBoxFlat.new()
    bg.bg_color = Color(0, 0, 0, opacity)
    if rounded:
        bg.corner_radius_top_left = 12
        bg.corner_radius_top_right = 12
        bg.corner_radius_bottom_left = 12
        bg.corner_radius_bottom_right = 12
    _btn.add_theme_stylebox_override("normal", bg)
    var bgp := bg.duplicate()
    bgp.bg_color = Color(0, 0, 0, opacity + 0.15)
    _btn.add_theme_stylebox_override("pressed", bgp)
    _btn.add_theme_stylebox_override("hover", bgp)
    add_child(_btn)
    _btn.pressed.connect(_go_back)

func _position_button() -> void:
    _btn.anchor_left = 0
    _btn.anchor_top = 0
    _btn.anchor_right = 0
    _btn.anchor_bottom = 0
    _btn.size = button_size
    var vp :Vector2 = get_viewport().get_visible_rect().size
    var x :float = padding
    var y :float = padding
    match corner:
        1: x = vp.x - padding - button_size.x   # top-right
        2: y = vp.y - padding - button_size.y   # bottom-left
        3:
            x = vp.x - padding - button_size.x   # bottom-right
            y = vp.y - padding - button_size.y
    _btn.position = Vector2(x, y)

func _input(event: InputEvent) -> void:
    # Desktop convenience: Esc to return
    if event.is_action_pressed("ui_cancel"):
        _go_back()

func _go_back() -> void:
    if index_scene:
        get_tree().change_scene_to_packed(index_scene)
    elif index_scene_path != "":
        get_tree().change_scene_to_file(index_scene_path)
    else:
        push_warning("DemoExitOverlay: Set 'index_scene' (or 'index_scene_path').")
