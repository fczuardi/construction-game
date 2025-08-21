class_name Stage
extends Node3D

signal stage_completed

func _on_goal_area_body_entered(body: Node3D) -> void:
    if body.is_in_group("player"):
        stage_completed.emit()
