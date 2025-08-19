class_name HUD
extends Control

@onready var game_title: CenterContainer = %GameTitle
@onready var game_buttons: VBoxContainer = %GameButtons
@onready var turn_left_button: Button = %TurnLeftButton
@onready var turn_right_button: Button = %TurnRightButton
@onready var map_button: Button = %MapButton
@onready var status_list: VBoxContainer = %StatusList
@onready var distance_value: Label = %DistanceValue
@onready var steps_value: Label = %StepsValue
@onready var game_over_title: CenterContainer = %GameOverTitle

signal turn_left_clicked
signal turn_right_clicked
signal map_toggled(toggled_on: bool)

var _total_distance : float = 0.0
var _fade_tween : Tween

func _ready() -> void:
    process_mode = Node.PROCESS_MODE_ALWAYS
    turn_left_button.mouse_filter  = Control.MOUSE_FILTER_STOP
    turn_right_button.mouse_filter = Control.MOUSE_FILTER_STOP
    turn_left_button.pressed.connect(func():  turn_left_clicked.emit())
    turn_right_button.pressed.connect(func(): turn_right_clicked.emit())
    map_button.toggled.connect(func(toggled_on: bool): map_toggled.emit(toggled_on))

func _on_game_resetted() -> void:
    _total_distance = 0.0
    game_title.modulate = Color.TRANSPARENT
    status_list.modulate = Color.TRANSPARENT
    game_buttons.modulate = Color.TRANSPARENT
    game_over_title.modulate = Color.TRANSPARENT
    update_ui_visibility([game_title], [])
    turn_left_button.disabled = true
    turn_right_button.disabled = true

func update_ui_visibility(fade_in:Array, fade_out:Array):
    if (_fade_tween):
        _fade_tween.kill()
    _fade_tween = get_tree().create_tween()
    _fade_tween.set_parallel()
    for element in fade_in:
        _fade_tween.tween_property(element, "modulate", Color.WHITE, 1.5).set_trans(Tween.TRANS_SINE)
    for element in fade_out:
        _fade_tween.tween_property(element, "modulate", Color.TRANSPARENT, 0.5)

func _on_walked_distance_updated(delta: float) -> void:
    _total_distance += delta
    distance_value.text = "%.0fm" % _total_distance

func _on_step_count_updated(new_total: int) -> void:
    steps_value.text = "%d" % new_total

func _on_game_started() -> void:
    update_ui_visibility([status_list, game_buttons], [game_title])
    turn_left_button.disabled = false
    turn_right_button.disabled = false

func _on_game_ended() -> void:
    update_ui_visibility([game_over_title], [game_buttons, status_list])
    turn_left_button.disabled = true
    turn_right_button.disabled = true


func _on_map_button_toggled(toggled_on: bool) -> void:
    pass # Replace with function body.
