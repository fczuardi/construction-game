class_name GeneralWiring
extends Node
## Comon connections between different game pieces

@export var character_body: PlayerRunner
@export var character_visuals: PlayerVisuals2
@export var cameras: PlayerCameras
@export var item_spawner: ItemSpawnerFromMap
@export var countdown: Timer
@export var first_stage_ground: Node3D
@export var second_stage_ground: Node3D
@export var hud_container: Control
@export var controls: PlayerControls
@export var start_title: FadeTitle
@export var game_over_message: FadeTitle
@export var game_over_credits: FadeTitle
@export var first_stage_message: FadeTitle
@export var second_stage_message: FadeTitle



@export var slowmo_scale := 0.25  # 25% speed

@export var _current_stage: int = 1

func _unhandled_input(e):
    if e.is_action_pressed("debug_slowmo"):   Engine.time_scale = slowmo_scale
    if e.is_action_released("debug_slowmo"):  Engine.time_scale = 1.0
    if e.is_action_pressed("debug_sprint"):
        character_body.set_speed_mode("run")
    if e.is_action_pressed("debug_half_map"):
        character_visuals.toggle_full_paper(false)
    if e.is_action_released("debug_half_map"):
        character_visuals.toggle_full_paper(true)


var  _stage_1_full_map: bool = true
var  _stage_2_full_map: bool = false

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
        EventBus.stage_1_ended.connect(_on_goal_reached)
    if countdown:
        countdown.timeout.connect(_on_timeout)
    EventBus.global_next_stage.connect(_on_next_stage)
    EventBus.global_restart_stage.connect(_on_restart_stage)
    EventBus.item_collected.connect(_on_item_collected)    
    _on_restart()

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
    if countdown:
        countdown.timeout.disconnect(_on_timeout)

func _on_item_collected(item: Collectible):
    if item.id == &"sneakers":
        character_visuals.set_sneakers_enabled(true)
        if character_visuals.is_run_enabled():
            character_body.set_speed_mode("run")
    if item.id == &"toilet_paper":
        _stage_2_full_map = true

    
var _alive = true
var _finished_level = false

func _on_timeout():
    character_body.set_speed_mode("stop")
    _trigger_game_over()
    
func _trigger_game_over():
    if !_finished_level:
        cameras.blend_time = 3.0
        cameras.activate_index(4)
    _alive = false
    countdown.paused = true
    var game_over_tween: Tween = create_tween()
    game_over_tween.tween_interval(3.0)
    game_over_tween.tween_callback(func ():
        game_over_message.auto_exit_time = 1.0
        game_over_message.enter()
    )
    game_over_tween.tween_interval(3.0)
    game_over_tween.tween_callback(func ():
        game_over_credits.auto_exit_time = 1.0
        game_over_credits.enter()
    )
    game_over_tween.tween_interval(3.0)
    game_over_tween.tween_callback(func ():
        EventBus.global_restart_game.emit()
    )
    item_spawner.map_scene = load("res://lib/maps/stage1_map.tscn")
    _current_stage = 1
    _stage_1_full_map = true
    _stage_2_full_map = false
    print("game over restart")


func _on_player_speed_change(_new_speed: float, mode: String):
    if mode == "stop":
#        if _alive and ! _finished_level:
        if _alive:
            _trigger_game_over()

@onready var stage_1_map: StageMap = $"../PlayerRunner/PlayerVisuals2/SubViewportContainer/SubViewport/Points Of Interest/Stage1Map"

func _on_restart():
    _alive = true
    _finished_level = false
    cameras.blend_time = 0.25
    cameras.activate_index(0)
    controls.toggle_input(PlayerControls.Side.NORTH, false)
    controls.toggle_input(PlayerControls.Side.SOUTH, false)
    countdown.start()
    countdown.paused = false
    character_visuals.set_sneakers_enabled(false)
    _on_size_changed()
    item_spawner.map_scene = load("res://lib/maps/stage%s_map.tscn" % str(_current_stage))
    if start_title:
        start_title.auto_exit_time = 1.0
        start_title.enter()
        var level_message = first_stage_message
        var level_ground = first_stage_ground
        var first_stage_map = character_visuals.get_node("./SubViewport/TearableMap/FullMapSize/Points Of Interest/Stage1Map")
        var second_stage_map = character_visuals.get_node("./SubViewport/TearableMap/FullMapSize/Points Of Interest/Stage2Map")
        var stage_map = first_stage_map

        if _current_stage == 1:
            character_visuals.toggle_full_paper(_stage_1_full_map)
        if _current_stage == 2:
            level_message = second_stage_message
            level_ground = second_stage_ground
            stage_map = second_stage_map
            character_visuals.toggle_full_paper(_stage_2_full_map)

        for n in [first_stage_ground, second_stage_ground]:
            n.visible = (n == level_ground)
            _toggle_collisions(n, (n == level_ground))
        for m in [first_stage_map, second_stage_map]:
            m.visible = (m == stage_map)

        if first_stage_message:
            var restart_tween: Tween = create_tween()
            restart_tween.tween_interval(3.0)
            restart_tween.tween_callback(func ():
                level_message.auto_exit_time = 1.0
                level_message.enter()
            )

func _on_next_stage():
    _current_stage += 1
    EventBus.global_restart_game.emit()
    get_tree().paused = false

func _on_restart_stage():
    EventBus.global_restart_game.emit()
    get_tree().paused = false
    
func _on_goal_reached():
    _finished_level = true
    countdown.paused = true
    cameras.activate_index(5)
    print("STAGE CLEAR")
    var game_over_tween: Tween = create_tween()
    game_over_tween.tween_interval(2.0)
    game_over_tween.tween_callback(func():
        EventBus.stage_completed.emit(true)
        get_tree().paused = true
    )
    
    
func _on_size_changed():
    var s := hud_container.get_viewport_rect().size
    hud_container.set_deferred("size", s)    

func _on_controls_layout_change(new_layout):
    controls.set_layout(new_layout)

func _on_controller_input(side: int, event: int):
    if character_body:
        match side:
            controls.Side.WEST:
                if event == controls.Event.DOWN: character_body.set_turn_axis(+0.5)
                elif event == controls.Event.UP:  character_body.set_turn_axis(0.0)
            controls.Side.EAST:
                if event == controls.Event.DOWN: character_body.set_turn_axis(-0.5)
                elif event == controls.Event.UP:  character_body.set_turn_axis(0.0)
            controls.Side.NORTH:
                if event == controls.Event.TOGGLE_ON:
                    if character_visuals.is_sneakers_enabled():
                        character_body.set_speed_mode("run")
                    else:
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



func _toggle_collisions(root: Node, on: bool) -> void:
    # prototype terrains s
    if root is CSGShape3D:
        root.use_collision = on

    # Handle bodies & areas
    if root is CollisionObject3D:
        if on:
            # restore original mask/layer if we saved them
            if root.has_meta("orig_layer"): root.collision_layer = int(root.get_meta("orig_layer"))
            if root.has_meta("orig_mask"):  root.collision_mask  = int(root.get_meta("orig_mask"))
        else:
            # save once, then zero them out
            if not root.has_meta("orig_layer"): root.set_meta("orig_layer", root.collision_layer)
            if not root.has_meta("orig_mask"):  root.set_meta("orig_mask",  root.collision_mask)
            root.collision_layer = 0
            root.collision_mask  = 0

        # Areas: also stop/start monitoring
        if root is Area3D:
            root.monitoring  = on
            root.monitorable = on

    # Also toggle shapes explicitly (nice when you prefer shape-level control)
    if root is CollisionShape3D:
        root.disabled = not on

    # Recurse
    for c in root.get_children():
        _toggle_collisions(c, on)
