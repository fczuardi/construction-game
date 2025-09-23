class_name PickupHud
extends Control
@export var label: Label
var total_points := 0
var required_objects := 6

func _ready() -> void:
    EventBus.item_collected.connect(_on_pick)
    EventBus.global_restart_game.connect(_on_restart)

func _update_label():
    if label: 
        label.text = "%s / %s" % [str(total_points), str(required_objects)]

func _on_pick(item: Collectible) -> void:
    if item.is_required:
        total_points += item.points
    _update_label()
    if total_points >= required_objects:
        EventBus.goal_unlocked.emit()
    
func _on_restart():
    total_points = 0
    _update_label()
