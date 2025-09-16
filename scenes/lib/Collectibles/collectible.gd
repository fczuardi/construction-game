class_name Collectible
extends Area3D

@export var id: StringName = &"coin"
@export var points: int = 1
@export var spin_deg_per_sec: float = 90.0
@export var bob_amp: float = 0.06
@export var bob_speed: float = 2.0

var _y0: float

func _ready() -> void:
    body_entered.connect(_on_body_entered)
    _y0 = position.y
    monitoring = true

func set_height(y: float):
    _y0 = y

func _process(delta: float) -> void:
    rotate_y(deg_to_rad(spin_deg_per_sec) * delta)
    position.y = _y0 + sin(Time.get_ticks_msec() / 1000.0 * bob_speed) * bob_amp

func _on_body_entered(body: Node) -> void:
    if not (body is PlayerRunner):
        return
    set_deferred("monitoring", false)
    EventBus.item_collected.emit(id, points, global_position)
    queue_free()
