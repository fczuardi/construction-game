## Construction Contractor
## an open-source game by Fabricio Zuardi

## This is the main game file, it should centralize the references for most of the important systems.
class_name ConstructionContractorGame
extends Node

## Settings
## The base walking speed
@export var walk_speed = 1.11
## number of steps before main game start
@export var steps_until_start :int = 8
## how many steps the player can use before game over
@export var steps_per_game :int = 100

## Signals
signal game_resetted
signal walked_distance_updated(new_total: float)
signal step_count_updated(new_total: int)
signal game_ended
signal game_started

## Components
@onready var player_body: CharacterBody3D = %PlayerBody
@onready var player_visuals: PlayerVisuals = %PlayerVisuals

## globals
var _last_player_position :Vector3
var _total_player_steps : int = 0
var _reset_game_tween : Tween
var _game_started : bool = false
var _game_ended : bool = false
var _target_forward_speed : float

## Init
func _ready() -> void:
    for p in player_visuals.anim_tree.get_property_list():
        print(p.name)
    player_visuals.signal_emitter.step_finished.connect(_on_player_step_finished)
    reset()
## restarts the game to it's initial state
func reset() -> void:
    _game_started = false
    _game_ended = false
    _total_player_steps = 0
    _target_forward_speed = walk_speed
    player_body.position = Vector3(0.0, -1.0, 0.0)
    game_resetted.emit()

    
## Physics game loop
func _physics_process(delta: float) -> void:    
    update_forward_speed(delta)
    _apply_gravity(delta)
    player_body.move_and_slide()    
    update_status()

func _apply_gravity(delta):
    if not player_body.is_on_floor():
        player_body.velocity += player_body.get_gravity() * delta

## updates the player body velocity on the Z axis
const ACCEL := 12.0      # m/s² when speeding up
const DECEL := 12.0     # m/s² when slowing down
func update_forward_speed(delta:float):
    var speed = player_body.velocity.z
    var rate := ACCEL if (_target_forward_speed > speed) else DECEL
    player_body.velocity.z = move_toward(speed, _target_forward_speed, rate * delta)
    # TODO: maybe use signal instead of calling another component's function
    player_visuals.multiply_walk_speed(player_body.velocity.z/walk_speed)
    
## Listeners
func _on_player_step_finished(_foot):
    _total_player_steps += 1
    step_count_updated.emit(_total_player_steps)
    check_game_start()
    check_game_over()    
func check_game_start():
    if _total_player_steps < steps_until_start or _game_started:
        return
    _game_started = true
    game_started.emit()

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
    
## update metrics and send signals (ui listen to it)
func update_status():
    var current_position = player_body.global_position
    if current_position != _last_player_position:
        walked_distance_updated.emit(player_body.global_position.z)


## Debug cheat/test mode
func _unhandled_input(event: InputEvent) -> void:
    if event is InputEventKey and event.pressed and not event.echo:
        match event.keycode:
            KEY_1:
                print("walk")
                _target_forward_speed = walk_speed
            KEY_2:
                print("walk * 1.25")
                _target_forward_speed = 1.3 * walk_speed
            KEY_3:
                print("walk * 1.75")
                _target_forward_speed = 3 * walk_speed                
            KEY_4:
                print("walk * 1.85")
                _target_forward_speed = 4 * walk_speed

            KEY_5:
                print("walk * 2")
                _target_forward_speed = 5.0 * walk_speed

    
