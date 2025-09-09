extends Node

signal touch_control_layout_changed(new_layout: Enums.TouchControlsLayout)
signal player_runner_pose_updated(world_pos: Vector3, yaw_radians: float)

func _test():
    ## unused code to avoid debugger warning of signal not used in the class
    touch_control_layout_changed.emit()
    player_runner_pose_updated.emit()
