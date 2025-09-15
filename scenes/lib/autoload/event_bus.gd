extends Node

signal touch_control_layout_changed(new_layout: Enums.TouchControlsLayout)
signal player_runner_pose_updated(world_pos: Vector3, yaw_radians: float)
signal global_restart_game()
signal item_collected(id: StringName, points: int, world_pos: Vector3)


func _test():
    ## unused code to avoid debugger warning of signal not used in the class
    touch_control_layout_changed.emit()
    player_runner_pose_updated.emit()
    global_restart_game.emit()
    item_collected.emit()
