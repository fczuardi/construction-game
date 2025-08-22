class_name PlayerVisuals
extends Node3D

@onready var anim_tree: AnimationTree = $Protagonist/AnimationTree
@onready var animation_player: AnimationPlayer = $Protagonist/AnimationPlayer
@onready var signal_emitter: Node = $Protagonist/SignalEmitter
@onready var map: Node3D = %Map
@onready var collision_capsule_walk: CollisionShape3D = %CollisionCapsuleWalk
@onready var collision_capsule_map: CollisionShape3D = %CollisionCapsuleMap
@onready var sholder_cam: Camera3D = %SholderCam
@onready var first_person_cam: Camera3D = %FirstPersonCam
@onready var face_cam: Camera3D = %FaceCam

var collision_shape: CapsuleShape3D
func _ready() -> void:
    assert(signal_emitter, "signal emitter unreacheable")

func _on_main_game_resetted() -> void:
    set_map_mode(false)

func set_map_mode(on: bool) -> void:
    collision_capsule_walk.disabled  = on
    collision_capsule_map.disabled = not on
    switch_cam(first_person_cam if on else sholder_cam)
    map.visible = on
    anim_tree["parameters/LastTransition/transition_request"] = "CheckMap" if on else "Walk"

func switch_cam(new_cur):
    for c in [face_cam, first_person_cam, sholder_cam]:
        c.current = (c == new_cur)
    
func _on_hud_map_toggled(toggled_on: bool) -> void:
    set_map_mode(toggled_on)

func _on_stage_1_goal_reached(_goal_pos, _goal_yaw_deg) -> void:
    # play the stop animation
    anim_tree["parameters/LastTransition/transition_request"] = "WalkStop"
    # inactivate all cameras, goal cam will assume
    #for c in [face_cam, first_person_cam, sholder_cam]:
        #c.current = false


func _on_main_game_ended() -> void:
    anim_tree["parameters/LastTransition/transition_request"] = "WalkStop"
