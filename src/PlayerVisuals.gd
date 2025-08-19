class_name PlayerVisuals
extends Node3D

@onready var anim_tree: AnimationTree = %AnimationTree
@onready var animation_player: AnimationPlayer = %AnimationPlayer
@onready var signal_emitter: Node = %SignalEmitter
@onready var sholder_cam: Camera3D = %SholderCam
@onready var first_person_cam: Camera3D = %FirstPersonCam
@onready var face_cam: Camera3D = %FaceCam

func _ready() -> void:
    assert(anim_tree)
    for p in anim_tree.get_property_list():
        print(p.name)

func _on_game_resetted() -> void:
    anim_tree["parameters/LastTransition/transition_request"] = "Walk"
    switch_cam(sholder_cam)

func switch_cam(new_cur):
    for c in [face_cam, first_person_cam, sholder_cam]:
        c.current = (c == new_cur)

func _on_hud_map_toggled(toggled_on: bool) -> void:
    print(toggled_on)
    if (toggled_on):
        switch_cam(first_person_cam)
        anim_tree["parameters/LastTransition/transition_request"] = "CheckMap"
    else:
        switch_cam(sholder_cam)
        anim_tree["parameters/LastTransition/transition_request"] = "Walk"
