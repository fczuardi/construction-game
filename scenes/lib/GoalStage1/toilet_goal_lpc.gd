class_name ToiletGoal
extends Node3D


@onready var locked_toilet: StaticBody3D = %LockedToilet
@onready var open_toilet: StaticBody3D = %OpenToilet
@onready var pallet_bridge: StaticBody3D = %PalletBridge
@onready var goal_area: Area3D = %GoalArea

func _ready() -> void:
    _on_restart()
    EventBus.goal_unlocked.connect(_on_goal_unlocked)
    goal_area.body_entered.connect(_on_goal_achieved)
    
    
func _on_restart():
    _open_toilet(false)
    
func _on_goal_unlocked():
    _open_toilet(true)

func _on_goal_achieved(body: Node3D):
    if not (body is PlayerRunner):
        return
    EventBus.stage_1_ended.emit()

func _open_toilet(is_open: bool):
    var open_toilet_collision: CollisionShape3D = open_toilet.get_node_or_null("CollisionShape3D")
    var locked_toilet_collision: CollisionShape3D = locked_toilet.get_node_or_null("CollisionShape3D")
    var pallet_bridge_collision: CollisionShape3D = pallet_bridge.get_node_or_null("CollisionShape3D")
    goal_area.monitoring = is_open
    open_toilet.visible = is_open
    pallet_bridge.visible = is_open
    locked_toilet.visible = ! is_open
    open_toilet_collision.disabled = ! is_open
    pallet_bridge_collision.disabled = ! is_open
    locked_toilet_collision.disabled = is_open
    
    
