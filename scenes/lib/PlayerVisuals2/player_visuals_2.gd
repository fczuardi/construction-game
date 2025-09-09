@tool
class_name PlayerVisuals2
extends Node3D
## Second version of the PlayerVisuals component
## It renders motion, play animations.

@export var animation_tree: AnimationTree

# --- Tuning 
@export_group("Speed Bands")
@export var zero_speed_eps: float = 0.07
@export var walk_enter: float = 0.07
@export var walk_exit:  float = 0.50
@export var jog_enter:  float = 1.90
@export var jog_exit:   float = 1.60
@export var sprint_enter: float = 3.50
@export var sprint_exit:  float = 3.20
# @export_group("Stride")
# @export var stride_ref_speed: float = 0.9   # stride=1x at walk
# @export var stride_scale_min: float = 0.80
# @export var stride_scale_max: float = 1.35

# ## Movement (lower body, legs, hips, spine)
#
# Walk animations are a transition between 4 moving speeds:
#     idle -> walk -> jog -> sprint
# The choice of which walk animation to display is based on a speed number
# and a table of thresholds. For example, from 0.07 to 0.9 = walk animation.
#
# Idle and sprint are there for future possibilities since the game as it is
# currently uses only walk and jog speeds.

enum MovementBase { IDLE, WALK, JOG, SPRINT }
enum MovementEvent { STUMBLE, ROLL, TRIP_AND_FALL }
enum MovementEnd { MOVE, FALL }

const MOVEMENT_BASE_TRANSITION_PATH: StringName = &"parameters/MovementBase/transition_request"
const MOVEMENT_STATE: Dictionary[MovementBase, String] = {
    MovementBase.IDLE: "Standing",
    MovementBase.WALK: "Walking",
    MovementBase.JOG: "Jogging",
    MovementBase.SPRINT: "Sprinting",
}

# ## Upper body (arms, head)
# The shoulder and arms parts of the armature can have a different animation
# than the legs depending on the item the player is carrying or the action
# the player is executing. For example, looking at a map while walking or running.

enum UpperBodyBase { MAP }
enum UpperBodyEvent { STRETCH, POINT_FORWARD, POINT_BACKWARDS } 

const UPPER_BODY_BASE_TRANSITION_PATH: StringName = &"parameters/UpperBodyBase/transition_request"
const UPPER_BODY_BLEND_PATH: StringName = &"parameters/UpperBody/blend_amount"
const UPPER_BODY_STATE: Dictionary[UpperBodyBase, String] = {
    UpperBodyBase.MAP: "Reading",
}

# ## One-shot actions
#
# Both movement and upper body base animations can suffer interrutions upon
# events, like stumbling and tripping on trenches, or pointing to targets.
const MOVEMENT_EVENT_TRANSITION_PATH: StringName = &"parameters/MovementEvents/transition_request"
const MOVEMENT_EVENT_ONESHOT_PATH: StringName = &"parameters/MovementEventTrigger/request"
const MOVEMENT_EVENT: Dictionary[MovementEvent, String] = {
    MovementEvent.STUMBLE: "Stumble",
    MovementEvent.ROLL: "Roll",
}
const UPPER_BODY_EVENT_TRANSITION_PATH: StringName = &"parameters/UpperBodyEvents/transition_request"
const UPPER_BODY_EVENT_ONESHOT_PATH = "parameters/UpperBodyEventTrigger/request"
const UPPER_BODY_EVENT: Dictionary[UpperBodyEvent, String] = {
    UpperBodyEvent.STRETCH: "Stretch",
    UpperBodyEvent.POINT_FORWARD: "PointForward",
    UpperBodyEvent.POINT_BACKWARDS: "PointBackwards",
}

# ## Ending Hit (movement end)
# There are mainly 2 types of hits that triggers hit animations, those that dont
# interrupt the moving speed (events), like stumbles and rolls, and those that are stopping
# hits, like a fatal trip and fall. The animation tree has a final gate before output that
# is a transition between moving and non-loop ending animations.
const MOVEMENT_END_TRANSITION_PATH: StringName = &"parameters/MovementEnd/transition_request"
const MOVEMENT_STOP_STATE: Dictionary[MovementEnd, String] = {
    MovementEnd.MOVE: "Moving",
    MovementEnd.FALL: "Falling",
}


# --- Runtime cache -------------------------------------
var _last_base: MovementBase = MovementBase.IDLE
var _last_end: MovementEnd = MovementEnd.MOVE
var _last_blend: float = -1.0
var _last_stride: float = -1.0
var _pending_stumble: int = 0  # 0 none, 1 soft, 2 hard
var _last_facing: float = 0.0

func _ready() -> void:
    assert(animation_tree)
    if !animation_tree:
        return
    animation_tree.active = true
    _last_facing = rotation.y
    # for p in animation_tree.get_property_list():
    #     print(p.name)

# ---------------- Public API (reactive) ----------------

## Called every physics tick from PlayerRunner
func update_motion(velocity: Vector3, on_floor: bool) -> void:
    if !animation_tree:
        return
    # TODO: uncomment before release
    # if Engine.is_editor_hint():
    #     return

    var speed := velocity.length()

    # Keep facing stable when almost stopped
    if speed > zero_speed_eps:
        _last_facing = atan2(velocity.x, velocity.z)
    rotation.y = _last_facing

    # 1) Base locomotion selection with hysteresis
    var base := _classify_with_hysteresis(speed, _last_base)
    _update_movement_base(base)

    # 2) Stride playback scaling (optional but nice)
    # var stride := 1.0
    # if stride_ref_speed > 0.0:
    #     stride = clamp(speed / stride_ref_speed, stride_scale_min, stride_scale_max)
    # _set_stride(stride)

    # 3) Fire pending one-shots once
    if _pending_stumble == 2:
        _fire_hard_stumble()
        _pending_stumble = 0
    elif _pending_stumble == 1:
        _trigger_movement_event(MovementEvent.STUMBLE)
        _pending_stumble = 0

## Called by TrenchStumbleClassifier
func play_stumble(severity: float) -> void:
    _pending_stumble = 2 if (severity >= 0.8) else 1

## Simple toggle for upper-body overlay (map etc.)
func set_upper_body_enabled(on: bool) -> void:
    _toggle_upper_body_blend(on)


# ---------------- Internals (small helpers) ------------

func _toggle_upper_body_blend(on: bool):
    var blend_value: float = 1.0 if on else 0.0
    if blend_value == _last_blend:
        return
    animation_tree[UPPER_BODY_BLEND_PATH] = blend_value
    _last_blend = blend_value

func _fire_hard_stumble():
    _update_movement_end(MovementEnd.FALL)
    _last_end = MovementEnd.FALL


func _update_movement_end(end: MovementEnd):
    if end == _last_end:
        return
    animation_tree[MOVEMENT_END_TRANSITION_PATH] = MOVEMENT_STOP_STATE[end]
    _last_end = end

func _update_movement_base(base: MovementBase):
    if base == _last_base:
        return
    var name := MOVEMENT_STATE[base]
    animation_tree[MOVEMENT_BASE_TRANSITION_PATH] = name
    _last_base = base

func _trigger_movement_event(event: MovementEvent):
    animation_tree[MOVEMENT_EVENT_TRANSITION_PATH] = MOVEMENT_EVENT[event]
    animation_tree[MOVEMENT_EVENT_ONESHOT_PATH] = AnimationNodeOneShot.ONE_SHOT_REQUEST_FIRE

func _update_upper_body_base(base: UpperBodyBase): # TODO: use a proper enum once a new base is introduced
    animation_tree[UPPER_BODY_BASE_TRANSITION_PATH] = UPPER_BODY_STATE[base]

func _trigger_upper_body_event(event: UpperBodyEvent):
    animation_tree[UPPER_BODY_EVENT_TRANSITION_PATH] = UPPER_BODY_EVENT[event]
    animation_tree[UPPER_BODY_EVENT_ONESHOT_PATH] = AnimationNodeOneShot.ONE_SHOT_REQUEST_FIRE

func _classify_with_hysteresis(speed: float, current: MovementBase) -> MovementBase:
    match current:
        MovementBase.IDLE:
            if speed >= jog_enter:  return MovementBase.JOG
            if speed >= walk_enter: return MovementBase.WALK
            return MovementBase.IDLE
        MovementBase.WALK:
            if speed >= jog_enter:  return MovementBase.JOG
            if speed <= walk_exit:  return MovementBase.IDLE
            return MovementBase.WALK
        MovementBase.JOG:
            if speed >= sprint_enter: return MovementBase.SPRINT
            if speed <= jog_exit:     return (MovementBase.WALK if speed > walk_exit else MovementBase.IDLE)
            return MovementBase.JOG
        MovementBase.SPRINT:
            if speed <= sprint_exit: return MovementBase.JOG
            return MovementBase.SPRINT
        _:
            return MovementBase.IDLE

# func _set_stride(v: float) -> void:
#     if absf(v - _last_stride) < 0.01: return
#     animation_tree["%s/scale" % "parameters/StrideScale"] = v
#     _last_stride = v



# ## Inpector helper buttons
@export_group("Upper Body")
@export_tool_button("Enable")
var tool_enable_upper_body: Callable = func():
    set_upper_body_enabled(true)
@export_tool_button("Disable")
var tool_disable_upper_body: Callable = func():
    set_upper_body_enabled(false)

@export_group("Movement")
@export var tool_velocity: Vector3 = Vector3(0.0, 0.0, walk_exit + 0.1)
@export var tool_is_on_floor: bool = true
@export_tool_button("Update Motion")
var tool_speed: Callable = func():
    update_motion(tool_velocity, tool_is_on_floor)
@export_tool_button("Reset")
var tool_reset: Callable = func():
    tool_velocity = Vector3.ZERO
    tool_velocity.z = walk_exit + 0.1
    tool_is_on_floor = true
    _update_movement_end(MovementEnd.MOVE)
    update_motion(tool_velocity, tool_is_on_floor)

@export_group("Movement Events")
@export var tool_stumble_severity: float
@export_tool_button("Stumble")
var tool_play_stumble: Callable = func():
    play_stumble(tool_stumble_severity)
    update_motion(tool_velocity, tool_is_on_floor)

@export_group("Debug Upper Body")
@export_tool_button("Enable")
var tool_debug_enable_upper_body: Callable = func():
    _toggle_upper_body_blend(true)
@export_tool_button("Disable")
var tool_debug_disable_upper_body: Callable = func():
    _toggle_upper_body_blend(false)

@export_group("Debug Movement")
@export_tool_button("Stand")
var tool_idle: Callable = func():
    _update_movement_base(MovementBase.IDLE)
@export_tool_button("Walk")
var tool_walk: Callable = func():
    _update_movement_base(MovementBase.WALK)
@export_tool_button("Jog")
var tool_jog: Callable = func():
    _update_movement_base(MovementBase.JOG)
@export_tool_button("Sprint")
var tool_run: Callable = func():
    _update_movement_base(MovementBase.SPRINT)

@export_group("Debug Movement Event")
@export_tool_button("Stumble")
var tool_stumble: Callable = func():
    _trigger_movement_event(MovementEvent.STUMBLE)
@export_tool_button("Roll")
var tool_roll: Callable = func():
    _trigger_movement_event(MovementEvent.ROLL)

@export_group("Debug Upper Body Event")
@export_tool_button("Stretch")
var tool_stretch: Callable = func():
    _trigger_upper_body_event(UpperBodyEvent.STRETCH)
@export_tool_button("Point Forward")
var tool_point_forward: Callable = func():
    _trigger_upper_body_event(UpperBodyEvent.POINT_FORWARD)
@export_tool_button("Point Backwards")
var tool_point_backwards: Callable = func():
    _trigger_upper_body_event(UpperBodyEvent.POINT_BACKWARDS)

@export_group("Debug Movement End")
@export_tool_button("Fall")
var tool_end_fall: Callable = func():
    _update_movement_end(MovementEnd.FALL)
@export_tool_button("Move")
var tool_end_move: Callable = func():
    _update_movement_end(MovementEnd.MOVE)
