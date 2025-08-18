class_name PlayerVisuals
extends Node3D

@onready var anim_tree: AnimationTree = %AnimationTree
@onready var animation_player: AnimationPlayer = %AnimationPlayer
@onready var signal_emitter: Node = %SignalEmitter

func _ready() -> void:
    assert(anim_tree)

func _on_game_resetted() -> void:
    anim_tree["parameters/LastTransition/transition_request"] = "Walk"
