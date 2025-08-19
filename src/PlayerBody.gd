class_name PlayerBody
extends CharacterBody3D

## the base walking speed
@export var walk_speed = 1.11
## check map while walking speed
@export var check_map_walk_speed = 0.80

## max turn speed in degrees/second
@export var turn_rate_deg: float = 180.0


## lag between player turn and follow cameras catchup
@export var cam_lag_seconds := 0.35  # feel knob

signal walked_distance_updated(delta: float)

@onready var player_visuals: PlayerVisuals = %PlayerVisuals
@onready var cameras: Node3D = %Cameras

var _last_player_position :Vector3
## how much to turn (left or right) in degrees
var _next_direction: float
# TODO: this variable deserves a better name
## persistent movement direction
var move_dir: Vector3
## current walk speed
var _next_z_speed: float

func _ready() -> void:
    move_dir = transform.basis.z.normalized()
    print(player_visuals.anim_tree)
    for p in player_visuals.anim_tree.get_property_list():
        print("a ", p.name)
    print(player_visuals.anim_tree["parameters/LastTransition/current_state"])

func _on_game_resetted() -> void:
    # send back player body to "origin"
    position = Vector3(0.0, -1.0, 0.0)
    _last_player_position = position
    # face north
    player_visuals.rotation.y = 0    
    # initial direction = walking towards north
    _next_direction = -180
    _next_z_speed = walk_speed
    # start walking north
    velocity = Vector3(0.0, 0.0, _next_z_speed)

func _physics_process(delta: float) -> void:
    update_velocity(delta)
    
    move_and_slide()
    
    update_visuals_rotation(delta)
    update_follow_cameras(delta)
    update_walked_distance()

func update_velocity(delta: float) -> void:
    if not is_on_floor():
        velocity += get_gravity() * delta
        return
        

    # build target direction from desired yaw (_next_direction in degrees)
    var target_dir: Vector3 = Vector3.FORWARD.rotated(Vector3.UP, deg_to_rad(_next_direction)).normalized()
    # compute max step this frame (radians)
    var max_step := deg_to_rad(turn_rate_deg) * delta
    # angle between current and target (signed around Y)
    var angle := move_dir.signed_angle_to(target_dir, Vector3.UP)
    # clamp to max step and rotate
    var step :float = clamp(angle, -max_step, max_step)
    move_dir = move_dir.rotated(Vector3.UP, step).normalized()
    # apply velocity
    velocity = move_dir * _next_z_speed

func update_visuals_rotation(_delta:float):
    # Make visuals face velocity (not the body itself)
    if velocity.length() > 0.01: # this will probably always be true if this endless runner game continue to have no Idle/stop/frozen state
        var dir = velocity.normalized()
        player_visuals.rotation.y = atan2(dir.x, dir.z)

func update_follow_cameras(delta: float):
    var rotate_speed := 2.0 # 2 seconds
    var desired_yaw :float = player_visuals.rotation.y
    var k := 1.0 - exp(-delta / max(0.001, cam_lag_seconds))
    cameras.rotation.y = lerp_angle(cameras.rotation.y, desired_yaw, k)
    
## update distance walked on a physics cycle
func update_walked_distance():
    var pos = global_position
    if not _last_player_position.is_equal_approx(pos):
        var delta_dist = pos.distance_to(_last_player_position)
        walked_distance_updated.emit(delta_dist)
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

func set_next_direction(deg: float) -> void:
    _next_direction = wrapf(deg, -180.0, 180.0)

func _on_hud_turn_left_clicked() -> void:
    set_next_direction(_next_direction + 45.0)

func _on_hud_turn_right_clicked() -> void:
    set_next_direction(_next_direction - 45.0)

func _on_hud_map_toggled(toggled_on: bool) -> void:
    _next_z_speed = walk_speed if not toggled_on else check_map_walk_speed
