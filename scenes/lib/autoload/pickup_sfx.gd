class_name PickupSFX
extends Node

## Drop your two .ogg here (can add more; it cycles through them).
@export var sounds: Array[AudioStream] = []

## If true, plays at the item's world position (3D).
## If false, plays as a UI/global sound (2D).
@export var positional: bool = true

## Optional: audio bus name (create "SFX" bus in your project if you want)
@export var bus: StringName = &"SFX"

var _next_index: int = 0

func _ready() -> void:
    if not EventBus.item_collected.is_connected(_on_item_collected):
        EventBus.item_collected.connect(_on_item_collected)

func _on_item_collected(item: Collectible) -> void:
    if sounds.is_empty():
        return

    var stream := sounds[_next_index]
    _next_index = (_next_index + 1) % sounds.size()

    if positional:
        var p := AudioStreamPlayer3D.new()
        add_child(p)
        p.bus = bus
        p.stream = stream
        p.global_position = item.global_position
        p.max_distance = 25.0
        p.play()
        p.finished.connect(p.queue_free)
    else:
        var p2 := AudioStreamPlayer.new()
        add_child(p2)
        p2.bus = bus
        p2.stream = stream
        p2.play()
        p2.finished.connect(p2.queue_free)
