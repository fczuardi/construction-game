class_name TouchControlsMenu
extends Control
## Menu section for setting touch input preferences

# Config
var _player_controls: PlayerControls
var _player_controls_path
@export var player_controls_path: NodePath:
    set(value):
        _player_controls = get_node_or_null(value)
        _player_controls_path = value
    get():
        return _player_controls_path if _player_controls else ""

# Nodes
@onready var layout_left_btn: Button = %LayoutLeftBtn
@onready var layout_right_btn: Button = %LayoutRightBtn
@onready var layout_both_btn: Button = %LayoutBothBtn


# Lifecycle
func _ready() -> void:
    layout_left_btn.toggled.connect(_on_switch_left)
    layout_right_btn.toggled.connect(_on_switch_right)
    layout_both_btn.toggled.connect(_on_switch_both)
    layout_right_btn.disabled = true

# Helpers
func _check_switch_conditions(toggled_on: bool):
    assert(toggled_on == true, "untoggle shouldnt be possible, something is weird.")

func _reset_buttons():
    for b:Button in [layout_both_btn, layout_left_btn, layout_right_btn]:
        b.disabled = false
        b.set_pressed_no_signal(false)

func _switch_layout(button: Button, layout: Enums.TouchControlsLayout):
    button.disabled = true
    button.set_pressed_no_signal(true)
    EventBus.touch_control_layout_changed.emit(layout)

func _on_switch_left(toggled_on: bool):
    _check_switch_conditions(toggled_on)
    _reset_buttons()
    _switch_layout(layout_left_btn, Enums.TouchControlsLayout.LEFT_SIDE)

func _on_switch_right(toggled_on: bool):
    _check_switch_conditions(toggled_on)
    _reset_buttons()
    _switch_layout(layout_right_btn, Enums.TouchControlsLayout.RIGHT_SIDE)

func _on_switch_both(toggled_on: bool):
    _check_switch_conditions(toggled_on)
    _reset_buttons()
    _switch_layout(layout_both_btn, Enums.TouchControlsLayout.BOTH_HANDS)
