extends Node3D

@onready var cameras: PlayerCameras = %Cameras
@onready var player_runner: PlayerRunner = %PlayerRunner
@onready var visuals: PlayerVisuals = %Visuals
@onready var player_controls: PlayerControls = %PlayerControls

func _reset() -> void:
    cameras.activate_index(0)

func _ready() -> void:
    player_controls.action.connect(_on_controller_input)
    _reset()
    
func _on_controller_input(side: int, event: int):
    var map_enabled: bool = visuals.is_map_enabled()
    var run_enabled: bool = visuals.is_run_enabled()
    match side:
        player_controls.Side.WEST:
            player_runner.queue_turn(+45)
        player_controls.Side.EAST:
            player_runner.queue_turn(-45)
        player_controls.Side.NORTH:
            run_enabled = event == player_controls.Event.TOGGLE_ON
            visuals.set_run_enabled(run_enabled)
            if run_enabled:
                player_runner.set_speed_mode("run")
            else:
                player_runner.set_speed_mode("walk")
        player_controls.Side.SOUTH:
            map_enabled = event == player_controls.Event.TOGGLE_ON
            visuals.set_map_enabled(map_enabled)
    var camera_index = \
            0 if map_enabled == false and run_enabled == false \
            else 1 if map_enabled == false and run_enabled == true \
            else 2 if map_enabled == true and run_enabled == false \
            else 3 # map_enabled == true and run_enabled == true
    cameras.activate_index(camera_index)
