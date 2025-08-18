class_name PlayerVisuals
extends Node3D

@onready var anim_tree: AnimationTree = %AnimationTree
@onready var animation_player: AnimationPlayer = %AnimationPlayer
@onready var signal_emitter: Node = %SignalEmitter

## 0.0 to 1.0: how the walk animation blends into (slo-mo) run
var _run_bone_blend : float # blend_position from AnimationNodeBlendSpace1D

## 1.0 to 2.0: the timescale from walk to run (compensates the slo-mo run)
var _run_speed_scale :float # scale from AnimationNodeTimeScale

## 0.0 to 1.0 change the upper body to text on a smartphone/tablet
var _texting_upper_body_blend : float # blend_amount from AnimationNodeBlend2

## 1.0 to 2.0 how close to max speed the animation should be
func multiply_walk_speed(run_scale: float):
    _run_bone_blend = clamp(run_scale -1.0, 0, 1)
    _run_speed_scale = clamp(run_scale, 1, 2)
    anim_tree["parameters/SpeedBlend/blend_position"] = _run_bone_blend 
    anim_tree["parameters/SpeedScale/scale"] = _run_speed_scale 

func _ready() -> void:
    assert(anim_tree)
    # TODO: references for SpeedBlend, SpeedScale for walk-run
    # TODO: reference to TextingBlend for using cellphone
    for p in anim_tree.get_property_list():
        print(p.name)
    _run_bone_blend = anim_tree["parameters/SpeedBlend/blend_position"]
    _run_speed_scale = anim_tree["parameters/SpeedScale/scale"]
    _texting_upper_body_blend = anim_tree["parameters/TextingBlend/blend_amount"]
