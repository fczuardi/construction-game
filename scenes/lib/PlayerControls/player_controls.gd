class_name PlayerControls
extends Control
## 4-button pad with per-button toggle option.
## Single signal carries which side and event type.

signal action(side: int, event: int)

enum Side  { NORTH, SOUTH, WEST, EAST }
enum Event { PRESS, TOGGLE_ON, TOGGLE_OFF }

const VERSION := "0.5.0"

# Optional keyboard/gamepad fallback
@export_category("Keyboard")
@export var enable_input_actions: bool = true
@export var input_north: StringName = &"ui_up"
@export var input_south: StringName = &"ui_down"
@export var input_west:  StringName = &"ui_left"
@export var input_east:  StringName = &"ui_right"

# Per-button toggle config (Inspector-friendly)
@export_category("Toggle Behavior")
@export var toggle_north: bool = false
@export var toggle_south: bool = false
@export var toggle_west:  bool = false
@export var toggle_east:  bool = false

# Button nodes (hit areas; keep your visuals as children)
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

    # Apply toggle modes + wire
    _btn_north.toggle_mode = toggle_north
    _btn_south.toggle_mode = toggle_south
    _btn_west.toggle_mode  = toggle_west
    _btn_east.toggle_mode  = toggle_east

    if toggle_north:
        _btn_north.toggled.connect(func(on: bool):
            if controls_enabled: action.emit(Side.NORTH, Event.TOGGLE_ON if on else Event.TOGGLE_OFF))
    else:
        _btn_north.button_down.connect(func():
            if controls_enabled: action.emit(Side.NORTH, Event.PRESS))

    if toggle_south:
        _btn_south.toggled.connect(func(on: bool):
            if controls_enabled: action.emit(Side.SOUTH, Event.TOGGLE_ON if on else Event.TOGGLE_OFF))
    else:
        _btn_south.button_down.connect(func():
            if controls_enabled: action.emit(Side.SOUTH, Event.PRESS))

    if toggle_west:
        _btn_west.toggled.connect(func(on: bool):
            if controls_enabled: action.emit(Side.WEST, Event.TOGGLE_ON if on else Event.TOGGLE_OFF))
    else:
        _btn_west.button_down.connect(func():
            if controls_enabled: action.emit(Side.WEST, Event.PRESS))

    if toggle_east:
        _btn_east.toggled.connect(func(on: bool):
            if controls_enabled: action.emit(Side.EAST, Event.TOGGLE_ON if on else Event.TOGGLE_OFF))
    else:
        _btn_east.button_down.connect(func():
            if controls_enabled: action.emit(Side.EAST, Event.PRESS))

    set_process_unhandled_input(enable_input_actions)

func _unhandled_input(event: InputEvent) -> void:
    if not enable_input_actions or not controls_enabled or not is_visible_in_tree() or get_tree().paused:
        return
    if event.is_action_pressed(input_north):
        _handle_kb(Side.NORTH, _btn_north, toggle_north)
    if event.is_action_pressed(input_south):
        _handle_kb(Side.SOUTH, _btn_south, toggle_south)
    if event.is_action_pressed(input_west):
        _handle_kb(Side.WEST, _btn_west, toggle_west)
    if event.is_action_pressed(input_east):
        _handle_kb(Side.EAST, _btn_east, toggle_east)

func _handle_kb(side: int, btn: Button, is_toggle: bool) -> void:
    if is_toggle:
        btn.button_pressed = not btn.button_pressed  # fires toggled → unified signal
    else:
        action.emit(side, Event.PRESS)

# Helpers
func set_enabled(on: bool) -> void:
    controls_enabled = on
    for b in [_btn_north, _btn_south, _btn_west, _btn_east]:
        b.disabled = not on
