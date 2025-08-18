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
@onready var cameras: Node3D = %Cameras

## globals
var _last_player_position :Vector3
var _total_player_steps : int = 0
var _reset_game_tween : Tween
var _game_started : bool = false
var _game_ended : bool = false
## how much to turn (left or right) in degrees
var _next_direction : float

## Init
var move_dir: Vector3                # persistent movement direction
func _ready() -> void:
    for p in player_visuals.anim_tree.get_property_list():
        print(p.name)
    # walk animations call a method that sends a signal on each new step
    player_visuals.signal_emitter.step_finished.connect(_on_player_step_finished)
    move_dir = player_body.transform.basis.z.normalized()  # +Z

    reset()

## restarts the game to it's initial state
func reset() -> void:
    _game_started = false
    _game_ended = false
    # reset step counter
    _total_player_steps = 0
    # send back player body to "origin"
    player_body.position = Vector3(0.0, -1.0, 0.0)
    # face north
    player_visuals.rotation.y = 0
    # initial direction = walking towards north
    _next_direction = -180
    # start walking north
    player_body.velocity = Vector3(0.0, 0.0, walk_speed)
    # signal restart to  other components
    game_resetted.emit()

    
## Physics game loop
func _physics_process(delta: float) -> void:
    apply_gravity(delta)
    update_velocity(delta)
    player_body.move_and_slide()
    update_visuals_rotation(delta)
    update_follow_cameras(delta)
    update_status()

@export var turn_rate_deg := 180.0   # max turn speed in degrees/second
func update_velocity(delta: float) -> void:
    # 1) Build target direction from desired yaw (_next_direction in degrees)
    var target_dir: Vector3 = Vector3.FORWARD.rotated(Vector3.UP, deg_to_rad(_next_direction)).normalized()

    # 2) Compute max step this frame (radians)
    var max_step := deg_to_rad(turn_rate_deg) * delta

    # 3) Angle between current and target (signed around Y)
    var angle := move_dir.signed_angle_to(target_dir, Vector3.UP)

    # 4) Clamp to max step and rotate
    var step :float = clamp(angle, -max_step, max_step)
    move_dir = move_dir.rotated(Vector3.UP, step).normalized()

    # 5) Apply velocity
    player_body.velocity = move_dir * walk_speed

func aa_update_velocity(delta: float):
    # Get current forward (-Z of body, not visuals)
    var forward: Vector3 = player_body.transform.basis.z
    # Rotate towards next direction
    var turned: Vector3 = forward.rotated(Vector3.UP, deg_to_rad(_next_direction))    
    #works, but snappy
    player_body.velocity = turned * walk_speed 

func update_visuals_rotation(_delta:float):
    # Make visuals face velocity (not the body itself)
    if player_body.velocity.length() > 0.01: # this will probably always be true if this endless runner game continue to have no Idle/stop/frozen state
        var dir = player_body.velocity.normalized()
        player_visuals.rotation.y = atan2(dir.x, dir.z)

@export var cam_lag_seconds := 0.35  # feel knob
func update_follow_cameras(delta: float):
    var rotate_speed := 2.0 # 2 seconds
    var desired_yaw :float = player_visuals.rotation.y
    var k := 1.0 - exp(-delta / max(0.001, cam_lag_seconds))
    cameras.rotation.y = lerp_angle(cameras.rotation.y, desired_yaw, k)
    
func apply_gravity(delta):
    if not player_body.is_on_floor():
        player_body.velocity += player_body.get_gravity() * delta

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
    
## update metrics and send signals (ui listen to it)
func update_status():
    var pos = player_body.global_position
    if not _last_player_position.is_equal_approx(pos):
        var delta_dist = pos.distance_to(_last_player_position)
        # If you still want “northward progress” keep your z; otherwise:
        walked_distance_updated.emit(delta_dist)  # or accumulate yourself
        _last_player_position = pos


## Debug cheat/test mode
func _unhandled_input(event: InputEvent) -> void:
    if event is InputEventKey and event.pressed and not event.echo:
        match event.keycode:
            KEY_1:
                print("debug 1: turn left")
                _next_direction += 45.0
            KEY_2:
                print("debug 2: turn right")
                _next_direction -= 45.0
            KEY_3:
                print("debug 3")
            KEY_4:
                print("debug 4")
            KEY_5:
                print("debug 5")
        _next_direction = wrapf(_next_direction, -180.0, 180.0) # keep it between 180 and -180

    
