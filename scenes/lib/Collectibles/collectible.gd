class_name Collectible
extends Area3D

@export var id: StringName = &"coin"
@export var points: int = 1
@export var spin_deg_per_sec: float = 90.0
@export var bob_amp: float = 0.06
@export var bob_speed: float = 2.0
@export var showcase_scale: float = 5.0
@export var is_hidden: bool = false
@export var is_required: bool = true

var burst_scene := preload("res://lib/PickupBurst/PickupBurst.tscn")

var _y0: float
var _y_discount: float

func _ready() -> void:
    body_entered.connect(_on_body_entered)
    _y0 = position.y
    _y_discount = 0.8 if is_hidden else 0.0
    monitoring = true

func set_height(y: float):
    _y0 = y
    print("after set_height:", _y0, " item:", id)

func _process(delta: float) -> void:
    rotate_y(deg_to_rad(spin_deg_per_sec) * delta)
    var y = _y0 - _y_discount if monitoring else _y0
    position.y = y + sin(Time.get_ticks_msec() / 1000.0 * bob_speed) * bob_amp

func _on_body_entered(body: Node) -> void:
    if not (body is PlayerRunner):
        return
    set_deferred("monitoring", false)
    EventBus.item_collected.emit(self)
    _play_pickup_vfx(global_position)
    #queue_free()
    var hub := get_tree().get_first_node_in_group("ShowcaseHub")  # if you add the hub to this group
    if hub and "show_item" in hub:
        hub.show_item(self)
    else:
        # fallback if not found
        queue_free()
    
    

func _play_pickup_vfx(at: Vector3) -> void:
    var vfx := burst_scene.instantiate() as CPUParticles3D
    vfx.global_transform.origin = at
    
    get_tree().current_scene.add_child(vfx)   # or another VFX container
    if vfx.has_method("play_and_free"):
        vfx.play_and_free()
    else:
        vfx.emitting = true
        get_tree().create_timer(vfx.lifetime + 0.15).timeout.connect(vfx.queue_free)
