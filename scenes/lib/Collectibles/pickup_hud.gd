class_name PickupHud
extends Control
@export var label: Label
var total_points := 0

func _ready() -> void:
    EventBus.item_collected.connect(_on_pick)

func _on_pick(_id: StringName, points: int, _pos: Vector3) -> void:
    total_points += points
    if label: label.text = str(total_points)
