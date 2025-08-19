## Construction Contractor
## an open-source game by Fabricio Zuardi

## This is the code responsible to game state related funcions, like
## start, reset, score and game over
class_name ConstructionContractorGame
extends Node

## Settings
## number of steps before main game start
@export var steps_until_start :int = 8
## how many steps the player can use before game over
@export var steps_per_game :int = 20

## Signals
signal game_resetted
signal step_count_updated(new_total: int)
signal game_ended
signal game_started

## Components
@onready var player_body: CharacterBody3D = %PlayerBody
@onready var player_visuals: PlayerVisuals = %PlayerVisuals

## globals
var _total_player_steps : int = 0
var _reset_game_tween : Tween
var _game_started : bool = false
var _game_ended : bool = false

## Init
func _ready() -> void:
    # walk animations call a method that sends a signal on each new step
    player_visuals.signal_emitter.step_finished.connect(_on_player_step_finished)
    reset()

## restarts the game to it's initial state
func reset() -> void:
    _game_started = false
    _game_ended = false
    # reset step counter
    _total_player_steps = 0
    # signal restart to  other components
    game_resetted.emit()
    
## Listeners
func _on_player_step_finished(_foot):
    _total_player_steps += 1
    step_count_updated.emit(_total_player_steps)
    check_game_start()
    check_game_over()    

# the actual gameplay starts only after a number of steps, the time to display the intro title screen    
func check_game_start():
    if _total_player_steps < steps_until_start or _game_started:
        return
    _game_started = true
    game_started.emit()

# game ends when a certain number of steps is reached
func check_game_over():
    if _total_player_steps < steps_per_game or _game_ended:
        return
    _game_ended = true
    game_ended.emit()
    # wait some time and auto-restart
    if (_reset_game_tween):
        _reset_game_tween.kill()
    _reset_game_tween = get_tree().create_tween()
    _reset_game_tween.tween_callback(reset).set_delay(7)        
