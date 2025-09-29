@tool
class_name PlayerVisuals2
extends Node3D
## Second version of the PlayerVisuals component
## It renders motion, play animations.

@export var animation_tree: AnimationTree
@export var map_mesh: MeshInstance3D
@export var clipboard_prop: Node3D
@export var map_viewport: SubViewport
@export var clear_stage_bg: TextureRect

# --- Tuning 
@export_group("Speed Bands")
@export var zero_speed_eps: float = 0.07
@export var walk_enter: float = 0.70
@export var walk_exit:  float = 0.10
@export var jog_enter:  float = 2.2
@export var jog_exit:   float = 1.8
@export var sprint_enter: float = 4.60
@export var sprint_exit:  float = 4.20
@onready var helmet_skin: BoneAttachment3D = %HelmetSkin


# ## Movement (lower body, legs, hips, spine)
#
# Walk animations are a transition between 4 moving speeds:
#     idle -> walk -> jog -> sprint
# The choice of which walk animation to display is based on a speed number
# and a table of thresholds. For example, from 0.07 to 0.9 = walk animation.
#
# Idle and sprint are there for future possibilities since the game as it is
# currently uses only walk and jog speeds.

enum MovementBase { IDLE, WALK, JOG, SPRINT, FALL }
enum MovementEvent { STUMBLE, ROLL, TRIP_AND_FALL }
enum MovementEnd { MOVE, FALL }

const MOVEMENT_BASE_TRANSITION_PATH: StringName = &"parameters/MovementBase/transition_request"
const MOVEMENT_STATE: Dictionary[MovementBase, String] = {
    MovementBase.IDLE: "Standing",
    MovementBase.WALK: "Walking",
    MovementBase.JOG: "Jogging",
    MovementBase.SPRINT: "Sprinting",
    MovementBase.FALL: "Falling",
}

## Stride Scale
# in order to have a believable speed transition with discrete animations, we play with their
# timescales while the next animation enter/exit threshold is not reached
@export_group("Stride")
@export var stride_scale_min: float = 0.50
@export var stride_scale_max: float = 1.50

# TODO: remember to update this to the same values used by player_runner
const MOVEMENT_SPEED: Dictionary[MovementBase, float] = {
    MovementBase.FALL: 0.07,
    MovementBase.IDLE: 0.07,
    MovementBase.WALK: 0.85,
    MovementBase.JOG: 2.40,
    MovementBase.SPRINT: 5.0,
}

# ## Upper body (arms, head)
# The shoulder and arms parts of the armature can have a different animation
# than the legs depending on the item the player is carrying or the action
# the player is executing. For example, looking at a map while walking or running.

enum UpperBodyBase { IDLE, MAP }
enum UpperBodyEvent { STRETCH, POINT_FORWARD, POINT_BACKWARDS } 

const UPPER_BODY_BASE_TRANSITION_PATH: StringName = &"parameters/UpperBodyBase/transition_request"
const UPPER_BODY_BLEND_PATH: String = "parameters/UpperBody/blend_amount"
const UPPER_BODY_STATE: Dictionary[UpperBodyBase, String] = {
    UpperBodyBase.IDLE: "Walking",
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
const UPPER_BODY_EVENT_ONESHOT_ACTIVE_PATH = "parameters/UpperBodyEventTrigger/active"
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
var _last_upper_body_base: UpperBodyBase = UpperBodyBase.MAP
var _last_blend: float = -1.0
var _last_stride: float = -1.0
var _pending_stumble: int = 0  # 0 none, 1 soft, 2 hard
var _last_facing: float = 0.0
var _stride_ref_speed: float = 0.85   # stride=1x at walk, replaced on update_motion with the new reference

@onready var boots: MeshInstance3D = %Ch17_Boots
@onready var boots_skin_left: BoneAttachment3D = %BootsSkinLeft
@onready var boots_skin_right: BoneAttachment3D = %BootsSkinRight

@export var anim_fall_coyote_ms: int = 120     # grace after leaving floor
@export var anim_fall_down_speed: float = -0.6 # require this downward speed OR grace to expire

@export_group("Visual Stability")
@export var speed_smooth_tau: float = 0.12
var _smoothed_speed: float = 0.0
var _anim_off_floor_since_ms: int = -1
var _anim_air_frames: int = 0


@onready var full_paper_clipboard = clipboard_prop.get_node("./FullPaper")
@onready var teared_map: Control = map_viewport.get_node("./TearableMap")
@onready var full_map: Control = map_viewport.get_node("./TearableMap/FullMapSize")
var _full_map_toggled: bool
func toggle_full_paper(on:bool):
    _full_map_toggled = on
    if ! full_paper_clipboard:
        return
    if on:
        full_map.position.y = 0.0
        full_paper_clipboard.visible = true
        teared_map.set_anchors_preset(Control.PRESET_FULL_RECT)
        teared_map.size.x = 640.0
        teared_map.size.y = 1024.0
        teared_map.position.y = 0.0
    else:
        full_paper_clipboard.visible = false
        full_map.position.y = -512.0
        teared_map.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
        teared_map.size.x = 640.0
        teared_map.size.y = 512.0
        teared_map.position.y = 512.0
    apply_map_texture()

func set_hat_skin(hat_name: StringName):
    for hat in helmet_skin.get_children():
        print(hat.name, " ", hat_name)
        hat.visible = hat.name == hat_name

func _ready() -> void:
    assert(animation_tree)
    assert(full_paper_clipboard)
    assert(full_map)
    assert(teared_map)
    assert(helmet_skin)
    if !animation_tree:
        return
    animation_tree.active = true
    if Engine.is_editor_hint():
         return
    EventBus.global_restart_game.connect(reset_to_start)

    _last_facing = rotation.y
    reset_to_start()
    #for p in animation_tree.get_property_list():
        #print(p.name)

func apply_map_texture():
    var material = StandardMaterial3D.new()
    var map_texture = map_viewport.get_texture()
    material.albedo_texture = map_texture
    map_viewport.render_target_update_mode = SubViewport.UPDATE_ONCE
    map_viewport.render_target_clear_mode = SubViewport.CLEAR_MODE_ONCE
    #map_mesh.set_surface_override_material(0, material)

func get_map_texture() -> Texture2D:
    map_viewport.render_target_update_mode = SubViewport.UPDATE_WHEN_VISIBLE
    #map_viewport.render_target_clear_mode = SubViewport.CLEAR_MODE_ALWAYS
    #map_viewport.transparent_bg = false
    #await RenderingServer.frame_post_draw
    return map_viewport.get_texture()

# ---------------- Public API (reactive) ----------------

var _last_velocity: Vector3

## Called every physics tick from PlayerRunner
func update_motion(velocity: Vector3, on_floor: bool) -> void:
    if !animation_tree or Engine.is_editor_hint():
        return

    _last_velocity = velocity
    var raw_speed := velocity.length()

    # Keep facing stable when almost stopped
    if raw_speed > zero_speed_eps:
        _last_facing = atan2(velocity.x, velocity.z)
    rotation.y = _last_facing

    # ---- Visual coyote time for fall (tolerate tiny step-offs) ----
    var now := Time.get_ticks_msec()
    if on_floor:
        _anim_off_floor_since_ms = -1
        _anim_air_frames = 0
    else:
        if _anim_off_floor_since_ms < 0:
            _anim_off_floor_since_ms = now
        _anim_air_frames += 1

    var grace_active := (not on_floor) and (_anim_off_floor_since_ms >= 0) and ((now - _anim_off_floor_since_ms) < anim_fall_coyote_ms)
    var falling_fast := velocity.y <= anim_fall_down_speed

    # ---- Visual speed smoothing + debounce around walk/idle thresholds ----
    var dt := 1.0 / float(Engine.get_physics_ticks_per_second())
    var k := 1.0 if speed_smooth_tau <= 0.0 else (1.0 - exp(-dt / speed_smooth_tau))
    _smoothed_speed = lerp(_smoothed_speed, raw_speed, k)

    # 1) Base locomotion with hysteresis (using smoothed speed) + fall override
    var base := _classify_with_hysteresis(_smoothed_speed, _last_base)

    # fall override (either dropping fast or grace expired + at least 2 frames airborne)
    var show_fall := (not on_floor) and (falling_fast or (not grace_active and _anim_air_frames >= 2))
    if show_fall:
        base = MovementBase.FALL

    _update_movement_base(base)

    # 2) Stride playback scaling (use smoothed speed for visual stability)
    var stride := 1.0
    if _stride_ref_speed > 0.0:
        var ref :float = max(_stride_ref_speed, 0.001)
        stride = clamp(_smoothed_speed / ref, stride_scale_min, stride_scale_max)
    _set_stride(stride)

    # 3) Fire pending one-shots once
    if _pending_stumble == 2:
        _fire_hard_stumble()
        _pending_stumble = 0
    elif _pending_stumble == 1:
        _trigger_movement_event(MovementEvent.STUMBLE)
        _pending_stumble = 0

func reset_to_start() -> void:
    #print_debug("reset to start")
    _smoothed_speed = 0.0

    _update_movement_base(MovementBase.WALK)
    _update_movement_end(MovementEnd.MOVE)
    _toggle_upper_body_blend(false)
    _pending_stumble = 0
    animation_tree[MOVEMENT_EVENT_ONESHOT_PATH] = AnimationNodeOneShot.ONE_SHOT_REQUEST_ABORT
    animation_tree[UPPER_BODY_EVENT_ONESHOT_PATH] = AnimationNodeOneShot.ONE_SHOT_REQUEST_ABORT
    toggle_full_paper(_full_map_toggled)    
    apply_map_texture()


## Called by TrenchStumbleClassifier
func play_stumble(severity: float) -> void:
    _pending_stumble = 2 if (severity >= 0.5) else 1

## Called by CollectiblePointer
func play_point_forward() -> void:
    _trigger_upper_body_event(UpperBodyEvent.POINT_FORWARD)
func play_point_back() -> void:
    _trigger_upper_body_event(UpperBodyEvent.POINT_BACKWARDS)
    
## Simple toggle for upper-body overlay (map etc.)
func set_upper_body_enabled(on: bool) -> void:
    _toggle_upper_body_blend(on)

func set_map_enabled(on: bool):
    if on:
        animation_tree[UPPER_BODY_BASE_TRANSITION_PATH] = UPPER_BODY_STATE[UpperBodyBase.MAP]
    set_upper_body_enabled(on)

func is_map_enabled() -> bool:
    var upper_on: bool = animation_tree[UPPER_BODY_BLEND_PATH] >= 0.5
    var map_base: bool = _last_upper_body_base == UpperBodyBase.MAP
    return upper_on && map_base

func set_sneakers_enabled(on: bool):
    if ! boots:
        return
    boots.visible = ! on
    boots_skin_left.visible = on
    boots_skin_right.visible =  on

func is_sneakers_enabled() -> bool:
    return boots_skin_right.visible
            
func is_run_enabled() -> bool:
    return _last_base == MovementBase.JOG or _last_base == MovementBase.SPRINT

func is_not_moving() -> bool:
    return _last_end == MovementEnd.FALL

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
    #print(MOVEMENT_STATE[_last_base], " to ", MOVEMENT_STATE[base], _smoothed_speed)
    var state_name := MOVEMENT_STATE[base]
    animation_tree[MOVEMENT_BASE_TRANSITION_PATH] = state_name
    _stride_ref_speed = MOVEMENT_SPEED[base]
    _last_base = base

func _trigger_movement_event(event: MovementEvent):
    animation_tree[MOVEMENT_EVENT_TRANSITION_PATH] = MOVEMENT_EVENT[event]
    animation_tree[MOVEMENT_EVENT_ONESHOT_PATH] = AnimationNodeOneShot.ONE_SHOT_REQUEST_FIRE

func _update_upper_body_base(base: UpperBodyBase):
    animation_tree[UPPER_BODY_BASE_TRANSITION_PATH] = UPPER_BODY_STATE[base]
    if base == _last_upper_body_base:
        return
    var state_name := UPPER_BODY_STATE[base]
    animation_tree[UPPER_BODY_BASE_TRANSITION_PATH] = state_name
    _last_upper_body_base = base

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

func _set_stride(v: float) -> void:
    if absf(v - _last_stride) < 0.01: return
    animation_tree["parameters/StrideScale/scale"] = v
    _last_stride = v



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

func _step_callback():
    EventBus.player_visual_footstep_started.emit(MOVEMENT_STATE[_last_base])
