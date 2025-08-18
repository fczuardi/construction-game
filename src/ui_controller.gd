class_name UIController
extends Node

@onready var game_title: CenterContainer = %GameTitle
@onready var game_buttons: VBoxContainer = %GameButtons
@onready var status_list: VBoxContainer = %StatusList
@onready var distance_value: Label = %DistanceValue
@onready var steps_value: Label = %StepsValue
@onready var game_over_title: CenterContainer = %GameOverTitle


func _ready() -> void:
    process_mode = Node.PROCESS_MODE_ALWAYS

var _fade_tween : Tween
func update_ui_visibility(fade_in:Array, fade_out:Array):
    if (_fade_tween):
        _fade_tween.kill()
    _fade_tween = get_tree().create_tween()
    _fade_tween.set_parallel()
    for element in fade_in:
        _fade_tween.tween_property(element, "modulate", Color.WHITE, 1.5).set_trans(Tween.TRANS_SINE)
    for element in fade_out:
        _fade_tween.tween_property(element, "modulate", Color.TRANSPARENT, 0.5)

var _total_distance : float = 0
func _on_walked_distance_updated(delta: float) -> void:
    _total_distance += delta
    distance_value.text = "%.0fm" % _total_distance

func _on_step_count_updated(new_total: int) -> void:
    steps_value.text = "%d" % new_total


func _on_game_resetted() -> void:
    game_title.modulate = Color.TRANSPARENT
    status_list.modulate = Color.TRANSPARENT
    game_buttons.modulate = Color.TRANSPARENT
    game_over_title.modulate = Color.TRANSPARENT
    update_ui_visibility([game_title], [])
    # TODO: disable button interactivity

func _on_game_started() -> void:
    update_ui_visibility([status_list, game_buttons], [game_title])
    # TODO: enable button interactivity

func _on_game_ended() -> void:
    update_ui_visibility([game_over_title], [status_list, game_buttons])
    # TODO: disable button interactivity
