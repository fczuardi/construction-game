extends Node

signal touch_control_layout_changed(new_layout: Enums.TouchControlsLayout)
signal player_runner_pose_updated(world_pos: Vector3, yaw_radians: float)
signal player_visual_footstep_started(movement_base: String)
signal global_stage_started(stage: int)
signal global_restart_game()
signal global_restart_stage()
signal global_next_stage(full_map: bool, coins_collected: int)
signal item_collected(item: Collectible)
signal fatal_hit_received(world_pos: Vector3)
signal goal_unlocked()
signal stage_1_ended()
signal stage_completed(display_panel: bool)

func _test():
    ## unused code to avoid debugger warning of signal not used in the class
    touch_control_layout_changed.emit()
    player_runner_pose_updated.emit()
    global_restart_game.emit()
    item_collected.emit()
    player_visual_footstep_started.emit()
    fatal_hit_received.emit()
    goal_unlocked.emit()
    stage_1_ended.emit()
    stage_completed.emit()
    global_restart_stage.emit()
    global_next_stage.emit()
    global_stage_started.emit()
