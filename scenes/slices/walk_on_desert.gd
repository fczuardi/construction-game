extends Node3D

@onready var cameras: PlayerCameras = %Cameras
@onready var player_runner: PlayerRunner = %PlayerRunner
@onready var visuals: PlayerVisuals = %Visuals

func _reset() -> void:
    cameras.activate_index(0)

func _ready() -> void:
    _reset()
