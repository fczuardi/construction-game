class_name Stage
extends Node3D

signal goal_reached(goal_pos: Vector3, goal_yaw_deg: float)

@onready var goal_toilet_0: GoalArea = %GoalToilet0

func _ready() -> void:
    assert(goal_toilet_0)

func _on_goal_toilet_0_align_request(goal_pos: Vector3, goal_yaw_deg: float) -> void:
    goal_reached.emit(goal_pos, goal_yaw_deg)
