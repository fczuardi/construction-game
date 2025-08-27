class_name PlayerControls
extends Control
## 4-button pad (north/south/west/east). Skin-agnostic: buttons are hit areas;
## put any visuals (Label, TextureRect, icon font, SVG) as children of each button.

signal action_north()
signal action_south()
signal action_west()
signal action_east()

const VERSION := "0.2.1"

# --- Optional keyboard/gamepad fallback (desktop/gamepad) ---------------------
@export var enable_input_actions: bool = true
@export var input_north: StringName = &"ui_up"
@export var input_south: StringName = &"ui_down"
@export var input_west:  StringName = &"ui_left"
@export var input_east:  StringName = &"ui_right"

# --- Node references (buttons only; visuals are your children) ----------------
@onready var _btn_north: Button = %BtnNorth
@onready var _btn_south: Button = %BtnSouth
@onready var _btn_west:  Button = %BtnWest
@onready var _btn_east:  Button = %BtnEast

# Gate to disable all input quickly (pause, game over, menus)
var controls_enabled: bool = true

func _ready() -> void:
    if not _btn_north or not _btn_south or not _btn_west or not _btn_east:
        push_warning("PlayerControls: add BtnNorth/BtnSouth/BtnWest/BtnEast buttons as children.")
        return

    # Make buttons act as touch hit areas without altering your visuals.
    for b in [_btn_north, _btn_south, _btn_west, _btn_east]:
        b.focus_mode = Control.FOCUS_NONE

    # Snappy feel on mobile: fire on touch-down
    _btn_north.button_down.connect(func(): if controls_enabled: action_north.emit())
    _btn_south.button_down.connect(func(): if controls_enabled: action_south.emit())
    _btn_west.button_down.connect(func():  if controls_enabled: action_west.emit())
    _btn_east.button_down.connect(func():  if controls_enabled: action_east.emit())

    set_process_unhandled_input(enable_input_actions)

func _unhandled_input(event: InputEvent) -> void:
    if not enable_input_actions or not controls_enabled or not is_visible_in_tree() or get_tree().paused:
        return

    # Desktop/gamepad fallback
    if event.is_action_pressed(input_north): action_north.emit()
    if event.is_action_pressed(input_south): action_south.emit()
    if event.is_action_pressed(input_west):  action_west.emit()
    if event.is_action_pressed(input_east):  action_east.emit()

# --- Helpers ------------------------------------------------------------------
func set_enabled(on: bool) -> void:
    controls_enabled = on
    _btn_north.disabled = not on
    _btn_south.disabled = not on
    _btn_west.disabled = not on
    _btn_east.disabled = not on
