extends Area3D

func _ready() -> void:
    body_entered.connect(_on_body_entered)
    monitoring = true

func _on_body_entered(body: Node) -> void:
    if not (body is PlayerRunner):
        return
    EventBus.fatal_hit_received.emit(global_position)
