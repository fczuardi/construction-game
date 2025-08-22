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
## time between hits on the same obstacle to count it again
@export var hit_cooldown: float = 1.5   # seconds

signal walked_distance_updated(delta: float)
signal turn_queued(new_total: int)
signal obstacle_hit(new_total: int)

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
## current turn count (the player has a limited number to spend)
var turn_count: int
## hit on obstacles counter
var obstacle_hits: int
## helper dictionary to count same obstacle only after a cooldown time
var _last_hit_time: Dictionary     # Dictionary: collider -> last time

var initial_transform : Transform3D
func _ready() -> void:
    initial_transform = transform
    move_dir = transform.basis.z.normalized()
    #for p in player_visuals.anim_tree.get_property_list():
        #print("a ", p.name)
    #print(player_visuals.anim_tree["parameters/LastTransition/current_state"])

func _on_game_resetted() -> void:
    # send back player body to "origin"
    position = Vector3(0.0, -1.0, 0.0)
    global_transform = initial_transform

    _last_player_position = position
    # face north
    player_visuals.rotation.y = 0    
    # initial direction = walking towards north
    _next_direction = -179
    _next_z_speed = walk_speed
    # start walking north
    velocity = Vector3(0.0, 0.0, _next_z_speed)
    _last_hit_time = {}
    # counters
    turn_count = 0
    obstacle_hits = 0

func _physics_process(delta: float) -> void:
    update_velocity(delta)
    
    move_and_slide()
    update_visuals_rotation(delta)
    update_follow_cameras(delta)
    update_walked_distance()
    _count_obstacle_hits()


func _count_obstacle_hits() -> void:
    var n := get_slide_collision_count()
    for i in n:
        var c := get_slide_collision(i)
        if c == null: continue
        var other :Node3D = c.get_collider()
        if other and other.is_in_group("obstacles"):
            var now := Time.get_ticks_msec() * 0.001
            var last = _last_hit_time.get(other, -1e9)
            if now - last >= hit_cooldown:
                obstacle_hits += 1
                _last_hit_time[other] = now
                obstacle_hit.emit(obstacle_hits)
                
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
func set_next_direction(deg: float) -> void:    
    _next_direction = wrapf(deg, -180.0, 180.0)
    turn_count += 1
    turn_queued.emit(turn_count)

func _on_hud_turn_left_clicked() -> void:
    set_next_direction(_next_direction + 45.0)

func _on_hud_turn_right_clicked() -> void:
    set_next_direction(_next_direction - 45.0)

func _on_hud_map_toggled(toggled_on: bool) -> void:
    _next_z_speed = walk_speed if not toggled_on else check_map_walk_speed

func _on_stage_1_goal_reached(goal_pos: Vector3, goal_yaw_deg: float) -> void:
    global_position = goal_pos
    velocity = Vector3.ZERO

    rotation.y = deg_to_rad(goal_yaw_deg)

    var dir := Vector3.FORWARD.rotated(Vector3.UP, deg_to_rad(goal_yaw_deg))
    move_dir = dir.normalized()
    _next_direction = goal_yaw_deg
    _next_z_speed = 0
    %PlayerVisuals.rotation.y = deg_to_rad(goal_yaw_deg)  # if visuals rotate separately

    


func _on_main_game_ended() -> void:
    velocity = Vector3.ZERO
    _next_z_speed = 0
