@tool
class_name PlayerControls
extends Control
## 4-button pad with per-button toggle option.
## Single signal carries which side and event type.

signal action(side: int, event: int)

enum Side  { NORTH, SOUTH, WEST, EAST }
enum Event { TOGGLE_OFF, TOGGLE_ON, PRESS, DOWN, UP }

const VERSION := "0.6.0"

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
@onready var _btn_north: Button
@onready var _btn_south: Button
@onready var _btn_west:  Button
@onready var _btn_east:  Button

# Button cluster modes
# it is expected that each group has buttons named: 
#                           BtnNorth, BtnSouth, BtnWest, BtnEast
# only one cluster should be visible at any given time
@onready var right_side: Control = %RightSide
@onready var left_side: Control = %LeftSide
@onready var both_hands: Control = %BothHands

# Gate to disable all input quickly (pause, game over, menus)
var controls_enabled: bool = true

func _ready() -> void:
    mouse_filter = Control.MOUSE_FILTER_PASS
    _set_group(Enums.TouchControlsLayout.BOTH_HANDS)
    set_process_unhandled_input(enable_input_actions)

func _unhandled_input(event: InputEvent) -> void:
    if not enable_input_actions or not controls_enabled or not is_visible_in_tree() or get_tree().paused:
        return

    # DOWN (pressed)
    if event.is_action_pressed(input_north):
        _handle_kb_down(Side.NORTH, _btn_north, toggle_north)
    if event.is_action_pressed(input_south):
        _handle_kb_down(Side.SOUTH, _btn_south, toggle_south)
    if event.is_action_pressed(input_west):
        _handle_kb_down(Side.WEST,  _btn_west,  toggle_west)
    if event.is_action_pressed(input_east):
        _handle_kb_down(Side.EAST,  _btn_east,  toggle_east)

    # UP (released)
    if event.is_action_released(input_north):
        _handle_kb_up(Side.NORTH, _btn_north, toggle_north)
    if event.is_action_released(input_south):
        _handle_kb_up(Side.SOUTH, _btn_south, toggle_south)
    if event.is_action_released(input_west):
        _handle_kb_up(Side.WEST,  _btn_west,  toggle_west)
    if event.is_action_released(input_east):
        _handle_kb_up(Side.EAST,  _btn_east,  toggle_east)

# Keyboard helpers
func _handle_kb_down(side: int, btn: Button, is_toggle: bool) -> void:
    if is_toggle:
        btn.button_pressed = not btn.button_pressed  # fires toggled -> unified signal
    else:
        action.emit(side, Event.DOWN)

func _handle_kb_up(side: int, _btn: Button, is_toggle: bool) -> void:
    if is_toggle:
        return  # toggle already handled on press
    action.emit(side, Event.UP)

## Helpers
#func set_enabled(on: bool) -> void:
    #controls_enabled = on
    #for b in [_btn_north, _btn_south, _btn_west, _btn_east]:
        #b.disabled = not on
#
func _on_toggle_north(on: bool):
    action.emit(Side.NORTH, Event.TOGGLE_ON if on else Event.TOGGLE_OFF)
func _on_toggle_south(on: bool):
    action.emit(Side.SOUTH, Event.TOGGLE_ON if on else Event.TOGGLE_OFF)
func _on_toggle_west(on: bool):
    action.emit(Side.WEST, Event.TOGGLE_ON if on else Event.TOGGLE_OFF)
func _on_toggle_east(on: bool):
    action.emit(Side.EAST, Event.TOGGLE_ON if on else Event.TOGGLE_OFF)

# Enable/disable
func set_enabled(on: bool) -> void:
    controls_enabled = on
    for b in [_btn_north, _btn_south, _btn_west, _btn_east]:
        b.disabled = not on

# Signals for momentary buttons (now DOWN/UP)
func _on_down_north(): action.emit(Side.NORTH, Event.DOWN)
func _on_up_north():   action.emit(Side.NORTH, Event.UP)
func _on_down_south(): action.emit(Side.SOUTH, Event.DOWN)
func _on_up_south():   action.emit(Side.SOUTH, Event.UP)
func _on_down_west():  action.emit(Side.WEST,  Event.DOWN)
func _on_up_west():    action.emit(Side.WEST,  Event.UP)
func _on_down_east():  action.emit(Side.EAST,  Event.DOWN)
func _on_up_east():    action.emit(Side.EAST,  Event.UP)

func _set_connections():
    # NORTH
    if toggle_north:
        _btn_north.toggled.connect(_on_toggle_north)
    else:
        _btn_north.button_down.connect(_on_down_north)
        _btn_north.button_up.connect(_on_up_north)
    # SOUTH
    if toggle_south:
        _btn_south.toggled.connect(_on_toggle_south)
    else:
        _btn_south.button_down.connect(_on_down_south)
        _btn_south.button_up.connect(_on_up_south)
    # WEST
    if toggle_west:
        _btn_west.toggled.connect(_on_toggle_west)
    else:
        _btn_west.button_down.connect(_on_down_west)
        _btn_west.button_up.connect(_on_up_west)
    # EAST
    if toggle_east:
        _btn_east.toggled.connect(_on_toggle_east)
    else:
        _btn_east.button_down.connect(_on_down_east)
        _btn_east.button_up.connect(_on_up_east)

func _unset_connections():
    if not (_btn_north and _btn_south and _btn_west and _btn_east):
        return
    if toggle_north:
        _btn_north.toggled.disconnect(_on_toggle_north)
    else:
        _btn_north.button_down.disconnect(_on_down_north)
        _btn_north.button_up.disconnect(_on_up_north)
    if toggle_south:
        _btn_south.toggled.disconnect(_on_toggle_south)
    else:
        _btn_south.button_down.disconnect(_on_down_south)
        _btn_south.button_up.disconnect(_on_up_south)
    if toggle_west:
        _btn_west.toggled.disconnect(_on_toggle_west)
    else:
        _btn_west.button_down.disconnect(_on_down_west)
        _btn_west.button_up.disconnect(_on_up_west)
    if toggle_east:
        _btn_east.toggled.disconnect(_on_toggle_east)
    else:
        _btn_east.button_down.disconnect(_on_down_east)
        _btn_east.button_up.disconnect(_on_up_east)

func _set_group(group: Enums.TouchControlsLayout):
    var groupNode: Control
    match group:
        Enums.TouchControlsLayout.RIGHT_SIDE: groupNode = right_side
        Enums.TouchControlsLayout.LEFT_SIDE:  groupNode = left_side
        Enums.TouchControlsLayout.BOTH_HANDS: groupNode = both_hands
    _unset_connections()
    _btn_north = groupNode.find_child("BtnNorth", true)
    _btn_south = groupNode.find_child("BtnSouth", true)
    _btn_west  = groupNode.find_child("BtnWest",  true)
    _btn_east  = groupNode.find_child("BtnEast",  true)
    _set_connections()

    for b in [_btn_north, _btn_south, _btn_west, _btn_east]:
        b.focus_mode = Control.FOCUS_NONE
    _btn_north.toggle_mode = toggle_north
    _btn_south.toggle_mode = toggle_south
    _btn_west.toggle_mode  = toggle_west
    _btn_east.toggle_mode  = toggle_east

    for g in [right_side, left_side, both_hands]:
        g.visible = false
    groupNode.visible = true



@export_tool_button("Layout Left")
var set_layout_left = func():
    _set_group(Enums.TouchControlsLayout.LEFT_SIDE)

@export_tool_button("Layout Right")
var set_layout_right = func():
    _set_group(Enums.TouchControlsLayout.RIGHT_SIDE)
    
@export_tool_button("Layout Both")
var set_layout_both = func():
    _set_group(Enums.TouchControlsLayout.BOTH_HANDS)

## Public Methods
func set_layout(l: Enums.TouchControlsLayout):
    _set_group(l)

func toggle_input(side: PlayerControls.Side, on: bool) -> void:
    var btn: Button = [ _btn_north, _btn_south, _btn_west, _btn_east ][side]
    if not btn or not btn.toggle_mode:
        return
    btn.set_pressed_no_signal(on)
