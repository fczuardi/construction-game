class_name GeneralWiring
extends Node
## Comon connections between different game pieces

@export var hud_container: Control
@export var controls: PlayerControls
@export var character_body: PlayerRunner
@export var character_visuals: PlayerVisuals2
@export var cameras: PlayerCameras


@export var slowmo_scale := 0.25  # 25% speed

func _unhandled_input(e):
    if e.is_action_pressed("debug_slowmo"):   Engine.time_scale = slowmo_scale
    if e.is_action_released("debug_slowmo"):  Engine.time_scale = 1.0
    if e.is_action_pressed("debug_sprint"):
        character_body.set_speed_mode("run")



## wire
func _ready() -> void:
    # resize hud to diffferent viewport sizes
    if hud_container:
        get_tree().get_root().size_changed.connect(_on_size_changed)
    # listen for touch button layout changes (both hands, left thumb, right thumb)
    if controls:
        EventBus.touch_control_layout_changed.connect(_on_controls_layout_change)
    if character_body:
        character_body.speed_changed.connect(_on_player_speed_change)
    # connect inputs to body changes (turns/speed) and visuals (run animation, camera changes)
    if controls and character_body:
        controls.action.connect(_on_controller_input)
    if cameras and controls:
        EventBus.global_restart_game.connect(_on_restart)

## unwire
func _exit_tree() -> void:
    if hud_container:
        get_tree().get_root().size_changed.disconnect(_on_size_changed)
    if controls:
        EventBus.touch_control_layout_changed.disconnect(_on_controls_layout_change)
    if character_body:
        character_body.speed_changed.disconnect(_on_player_speed_change)
    if controls and character_body and character_visuals:
        controls.action.disconnect(_on_controller_input)
    if cameras and controls:
        EventBus.global_restart_game.disconnect(_on_restart)

var _alive = true
func _on_player_speed_change(_new_speed: float, mode: String):
    if mode == "stop" and _alive:
        print("gameover")
        cameras.blend_time = 3.0
        cameras.activate_index(4)
        _alive = false
        var game_over_tween: Tween = create_tween()
        game_over_tween.tween_interval(5.0)
        game_over_tween.tween_callback(func ():
            EventBus.global_restart_game.emit()
        )
func _on_restart():
    print("restart")
    _alive = true
    cameras.blend_time = 0.25
    cameras.activate_index(0)
    controls.toggle_input(PlayerControls.Side.NORTH, false)
    controls.toggle_input(PlayerControls.Side.SOUTH, false)

func _on_size_changed():
    var s := hud_container.get_viewport_rect().size
    hud_container.set_deferred("size", s)    

func _on_controls_layout_change(new_layout):
    controls.set_layout(new_layout)

func _on_controller_input(side: int, event: int):
    # player direction and speed changes
    if character_body:
        match side:
            controls.Side.WEST:
                character_body.queue_turn(+45)
            controls.Side.EAST:
                character_body.queue_turn(-45)
            controls.Side.NORTH:
                print("NORTH ", side, event)
                if event == controls.Event.TOGGLE_ON:
                    character_body.set_speed_mode("jog")
                else:
                    character_body.set_speed_mode("walk")
    
    # animation and camera changes        
    if character_visuals:
        var map_enabled: bool = character_visuals.is_map_enabled()
        var run_enabled: bool = character_visuals.is_run_enabled()
        match side:
            controls.Side.NORTH:
                run_enabled = event == controls.Event.TOGGLE_ON
            controls.Side.SOUTH:
                map_enabled = event == controls.Event.TOGGLE_ON
                character_visuals.set_map_enabled(map_enabled)
        if cameras:
            var camera_index = \
                    0 if map_enabled == false and run_enabled == false \
                    else 1 if map_enabled == false and run_enabled == true \
                    else 2 if map_enabled == true and run_enabled == false \
                    else 3 # map_enabled == true and run_enabled == true
            cameras.activate_index(camera_index)
