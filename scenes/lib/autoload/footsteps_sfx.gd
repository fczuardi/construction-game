class_name FootstepsSFX
extends Node

## Drop your two .ogg here (can add more; it cycles through them).
@export var walk_sounds: Array[AudioStream] = []
@export var jog_sounds: Array[AudioStream] = []
@export var run_sounds: Array[AudioStream] = []
@export var player_body: PlayerRunner
@export_range(0.0, 1.0) var volume = 0.15

## If true, plays at the item's world position (3D).
## If false, plays as a UI/global sound (2D).
@export var positional: bool = true

## Optional: audio bus name (create "SFX" bus in your project if you want)
@export var bus: StringName = &"SFX"

var _next_index: int = 0

func _ready() -> void:
    if not EventBus.player_visual_footstep_started.is_connected(_on_step):
        EventBus.player_visual_footstep_started.connect(_on_step)

func _on_step(movement_base: String) -> void:
    var sounds = walk_sounds
    match movement_base:
        "Walking":
            pass
        "Jogging":
            pass
        "Sprinting":
            pass
        _:
            pass        
    if sounds.is_empty():
        return

    var stream: AudioStream = sounds[_next_index]
    _next_index = (_next_index + 1) % sounds.size()

    if positional:
        var p := AudioStreamPlayer3D.new()
        var world_pos = player_body.global_position
        add_child(p)
        p.bus = bus
        p.stream = stream
        p.global_position = world_pos
        p.max_distance = 25.0
        p.volume_linear = volume
        p.play()
        p.finished.connect(p.queue_free)
    else:
        var p2 := AudioStreamPlayer.new()
        add_child(p2)
        p2.bus = bus
        p2.stream = stream
        p2.play()
        p2.finished.connect(p2.queue_free)
