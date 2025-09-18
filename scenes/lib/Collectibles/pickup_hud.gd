class_name PickupHud
extends Control
@export var label: Label
var total_points := 0

func _ready() -> void:
    EventBus.item_collected.connect(_on_pick)
    EventBus.global_restart_game.connect(_on_restart)


func _on_pick(_id: StringName, points: int, _pos: Vector3) -> void:
    total_points += points
    if label: label.text = str(total_points)
    if total_points >= 6:
        EventBus.goal_unlocked.emit()
    
func _on_restart():
    total_points = 0
    label.text = str(total_points)
