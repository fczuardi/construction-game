class_name FadeTitle
extends Control
## this is the class to make a control such as the Game Title, or a 
## game over message enter the screen with a fade in, or leave it with a fade out

@export var out_color: Color = Color.TRANSPARENT
@export var in_color: Color = Color.WHITE
@export var auto_exit: bool = true ## automatically leaves the screen after auto_exit_time seconds
@export var auto_exit_time: float = 3.0
@export var fade_time: float = 1.0   ## duration of fade in/out


var _tween: Tween

func _ready() -> void:
    modulate = out_color
    
func enter() -> void:
    _kill_tween()
    _tween = get_tree().create_tween()
    _tween.tween_property(self, "modulate", in_color, fade_time)
    if auto_exit:
        _tween.tween_interval(auto_exit_time)
        _tween.tween_callback(exit)

func exit() -> void:
    _kill_tween()
    _tween = get_tree().create_tween()
    _tween.tween_property(self, "modulate", out_color, fade_time)

func show_instant() -> void:
    _kill_tween()
    modulate = in_color

func hide_instant() -> void:
    _kill_tween()
    modulate = out_color

func _kill_tween() -> void:
    if _tween and _tween.is_valid():
        _tween.kill()
