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
@export var steps_per_game :int = 100
## how many turns the player can use before game over
@export var turns_per_game :int = 15
## how many hits the player can use before game over
@export var hits_per_game :int = 5
## Signals
signal game_resetted
signal step_count_updated(new_total: int)
signal game_ended
signal stage_won
signal game_started

## Components
@onready var player_body: CharacterBody3D = %PlayerBody
@onready var player_visuals: PlayerVisuals = %PlayerVisuals
@onready var hud: HUD = %HUD

## globals
var _total_player_steps : int = 0
var  _total_player_turns: int
var _total_player_hits: int
        
var _reset_game_tween : Tween
var _game_started : bool = false
var _is_game_ending : bool = false

## Init
func _ready() -> void:
    # walk animations call a method that sends a signal on each new step
    assert(player_visuals.signal_emitter, "couldnt reach animation signal emitter")
    player_visuals.signal_emitter.step_finished.connect(_on_player_step_finished)
    hud.reset_requested.connect(reset)
    reset()

## restarts the game to it's initial state
func reset() -> void:
    _game_started = false
    _is_game_ending = false
    # reset step counter
    _total_player_steps = 0
    _total_player_hits = 0
    _total_player_turns = 0
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
    if _is_game_ending:
        return
    var is_defeated: bool = (
        _total_player_steps >= steps_per_game or
        _total_player_turns >= turns_per_game or 
        _total_player_hits >= hits_per_game
    )
    if not is_defeated:
        return
    _is_game_ending = true
    game_ended.emit()
    # wait some time and auto-restart
    if (_reset_game_tween):
        _reset_game_tween.kill()
    _reset_game_tween = get_tree().create_tween()
    _reset_game_tween.tween_callback(reset).set_delay(7)        


func _on_stage_1_goal_reached(goal_pos: Vector3, goal_yaw_deg: float) -> void:
    if _is_game_ending:
        # it's possible that the player is in a game over state
        # in that case entering the goal wont trigger a win
        # as the player defeat takes precedence
        return
    _is_game_ending = true
    stage_won.emit()
    if (_reset_game_tween):
        _reset_game_tween.kill()
    _reset_game_tween = get_tree().create_tween()
    _reset_game_tween.tween_callback(reset).set_delay(8)


func _on_player_body_obstacle_hit(new_total: int) -> void:
    _total_player_hits = new_total


func _on_player_body_turn_queued(new_total: int) -> void:
    _total_player_turns = new_total
