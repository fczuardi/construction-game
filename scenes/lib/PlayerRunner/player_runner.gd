class_name PlayerRunner
extends CharacterBody3D
## Prototype runner: always falls, queues yaw turns, walks forward.


const VERSION := "0.2.0"


signal distance_moved(delta_m: float)
signal obstacle_bumped(collider: Node, surface_normal: Vector3)
signal turn_buffer_changed(remaining_deg: float)


# --- Defaults ------------------------

const DEFAULT_SPEED_READING: float = 0.80
const DEFAULT_SPEED_WALKING: float = 1.11
const DEFAULT_TURN_RATE: float = 180.0


# --- Exports (tiny surface) -----------

## regular walk speed
@export var move_speed:= DEFAULT_SPEED_WALKING
## a slowed-down speed, used for reading/look at a map or phone while walking
@export var map_walk_speed:= DEFAULT_SPEED_READING
## max rotate speed (deg/sec). high values = snappy turns, lower values = laggy
@export var turn_rate_deg:= DEFAULT_TURN_RATE
## a packed scene to use as the player visuals to follow the runner capsule
@export var visuals_scene: PackedScene:
    set(value):
        visuals_scene = value
        _rebuild_visuals()


# --- Private --------------------------

var _visuals: Node3D  # the instantiated visuals child
var _move_dir: Vector3
var _remaining_turn_deg: float  # +left / -right, consumed over time
var _speed: float
var _last_pos: Vector3
var _start_xform: Transform3D


func _ready() -> void:
    # If no visuals were instanced via the export, allow a manual child named PlayerVisuals
    if _visuals == null:
        _visuals = get_node_or_null("PlayerVisuals")
        if _visuals:
            _visuals.visible = true 

    # capture spawn first
    _start_xform = global_transform
    reset_to_start()


func _physics_process(delta: float) -> void:
    # gravity / falling
    if not is_on_floor():
        velocity += get_gravity() * delta
    else:
        # consume turn buffer at a capped rate
        var max_step: float = turn_rate_deg * delta
        var step: float = clamp(_remaining_turn_deg, -max_step, max_step)
        if step != 0.0:
            _move_dir = _move_dir.rotated(Vector3.UP, deg_to_rad(step)).normalized()
            _remaining_turn_deg -= step
            turn_buffer_changed.emit(_remaining_turn_deg)
        velocity = _move_dir * _speed

    move_and_slide()

    # face visuals to velocity
    if _visuals and velocity.length() > 0.01:
        var d := velocity.normalized()
        _visuals.rotation.y = atan2(d.x, d.z)

    # distance event
    var p := global_position
    var dlen := p.distance_to(_last_pos)
    if dlen > 0.0:
        distance_moved.emit(dlen)
        _last_pos = p

    # raw collision events
    for i in range(get_slide_collision_count()):
        var c := get_slide_collision(i)
        if c:
            obstacle_bumped.emit(c.get_collider(), c.get_normal())


func _rebuild_visuals() -> void:
    # Remove previous visuals instance if present
    if is_instance_valid(_visuals):
        _visuals.queue_free()
        _visuals = null

    # Instance the new visuals, if any
    if visuals_scene:
        var inst := visuals_scene.instantiate()
        if inst is Node3D:
            _visuals = inst
            _visuals.name = "PlayerVisuals"
            add_child(_visuals)
            # make it editable/visible in the scene tree while in the editor
            if Engine.is_editor_hint():
                _visuals.owner = owner
        else:
            push_warning("PlayerRunner: visuals_scene root must be a Node3D (got %s)." % inst.get_class())
            inst.queue_free()


# --- Public API -----------------------

func queue_turn(delta_deg: float) -> void:
    _remaining_turn_deg = clamp(_remaining_turn_deg + delta_deg, -360.0, 360.0)
    turn_buffer_changed.emit(_remaining_turn_deg)

func set_map_mode(on: bool) -> void:
    _speed = map_walk_speed if on else move_speed

func reset_to_start() -> void:
    global_transform = _start_xform
    velocity = Vector3.ZERO
    _move_dir = global_transform.basis.z.normalized()
    _remaining_turn_deg = 0.0
    _speed = move_speed
    _last_pos = global_position
