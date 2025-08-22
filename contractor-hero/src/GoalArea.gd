class_name GoalArea
extends Area3D

signal align_request(goal_pos: Vector3, goal_yaw_deg: float)

@onready var goal_cam: Camera3D = %GoalCam
@onready var entrance_pivot: Marker3D = %EntrancePivot

func _ready() -> void:
    assert(entrance_pivot)
    assert(goal_cam)

func _on_body_entered(body: Node3D) -> void:
    if body.is_in_group("player"):
        var xf := entrance_pivot.global_transform
        var basis := xf.basis.orthonormalized()  # remove any non-uniform scale
        var fwd := basis.z                      # assume pivot faces into the booth
        var yaw_rad := atan2(fwd.x, fwd.z)
        goal_cam.current = true
        align_request.emit(xf.origin, rad_to_deg(yaw_rad))
        
        
        
        
