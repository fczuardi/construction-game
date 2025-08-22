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
@onready var turns_value: Label = %TurnsValue
@onready var hits_value: Label = %HitsValue


@onready var game_over_title: CenterContainer = %GameOverTitle
@onready var victory_title: CenterContainer = %VictoryTitle

signal turn_left_clicked
signal turn_right_clicked
signal map_toggled(toggled_on: bool)
signal reset_requested

var _total_distance : float = 0.0
var _fade_tween : Tween

func _ready() -> void:
    process_mode = Node.PROCESS_MODE_ALWAYS
    turn_left_button.mouse_filter  = Control.MOUSE_FILTER_STOP
    turn_right_button.mouse_filter = Control.MOUSE_FILTER_STOP
    turn_left_button.pressed.connect(func():  turn_left_clicked.emit())
    turn_right_button.pressed.connect(func(): turn_right_clicked.emit())
    map_button.toggled.connect(func(toggled_on: bool): map_toggled.emit(toggled_on))
    # prevent buttons from grabbing keyboard focus
    for b in [turn_left_button, turn_right_button]:
        b.focus_mode = Control.FOCUS_NONE
        b.mouse_filter = Control.MOUSE_FILTER_STOP  # still capture clicks/taps
    # TODO: setup signal listeners in code and not editor
    # for example main game start

func _unhandled_input(event: InputEvent) -> void:
    if event is InputEventKey and event.pressed and not event.echo:
        match event.keycode:
            KEY_LEFT:
                turn_left_clicked.emit()
            KEY_RIGHT:
                turn_right_clicked.emit()
            KEY_SPACE:
                map_button.button_pressed = !map_button.button_pressed
                map_toggled.emit(map_button.button_pressed)
            KEY_R:
                reset_requested.emit()
            KEY_1:
                print("debug 1: pause")
                get_tree().paused = true
            KEY_2:
                print("debug 2: unpause")
                get_tree().paused = false
            KEY_3:
                print("debug 3")
            KEY_4:
                print("debug 4")
            KEY_5:
                print("debug 5")

func _on_game_resetted() -> void:
    _total_distance = 0.0
    game_title.modulate = Color.TRANSPARENT
    status_list.modulate = Color.TRANSPARENT
    game_buttons.modulate = Color.TRANSPARENT
    game_over_title.modulate = Color.TRANSPARENT
    victory_title.modulate = Color.TRANSPARENT
    map_button.button_pressed = false
    update_ui_visibility([game_title], [])
    turn_left_button.disabled = true
    turn_right_button.disabled = true
    turns_value.text = "-"
    hits_value.text = "-"

func update_ui_visibility(fade_in:Array, fade_out:Array, delay: float = 0.0):
    if (_fade_tween):
        _fade_tween.kill()
    _fade_tween = get_tree().create_tween()
    _fade_tween.set_parallel()
    for element in fade_in:
        _fade_tween.tween_property(element, "modulate", Color.WHITE, 2).set_trans(Tween.TRANS_LINEAR).set_delay(delay)
    for element in fade_out:
        _fade_tween.tween_property(element, "modulate", Color.TRANSPARENT, 0.5)

func _on_walked_distance_updated(delta: float) -> void:
    _total_distance += delta
    distance_value.text = "%.0fm" % _total_distance

func _on_step_count_updated(new_total: int) -> void:
    steps_value.text = "%d" % new_total

func _on_game_started() -> void:
    update_ui_visibility([status_list, game_buttons], [game_title], 0.5)
    turn_left_button.disabled = false
    turn_right_button.disabled = false

func _on_game_ended() -> void:
    update_ui_visibility([game_over_title], [game_buttons, status_list])
    turn_left_button.disabled = true
    turn_right_button.disabled = true

func _on_player_body_obstacle_hit(new_total: int) -> void:
    hits_value.text = "%d" % new_total


func _on_player_body_turn_queued(new_total: int) -> void:
    turns_value.text = "%d" % new_total


func _on_main_stage_won() -> void:
    update_ui_visibility([victory_title, status_list], [game_title, game_buttons], 2)
    turn_left_button.disabled = true
    turn_right_button.disabled = true
