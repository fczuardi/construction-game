# # The world environment
#
# This contains the "sun" light source, and the environment.
@tool
extends Node3D
class_name World

## ## Sun (DirectionalLight3D)
##
## Directional Lightning representing the sun, axis X is like the time between
## morning and late afternoon, while Y is the east-west direction where the
## sun rises and sets.
@onready var sun: DirectionalLight3D = %Sun
@export_group("Sun")

func hour_to_deg(h: float):
    return h / 24 * 360 - 270

func deg_to_hour(d: float):
    return (d + 270) / 360 * 24

## Time of the day in hours
@export_range(0.0, 24.0) var day_time: float = 11.0:
    get:
        if not sun:
            return 11.0
        return deg_to_hour(sun.rotation_degrees.x)
    set(new_t):
        if not sun:
            return
        sun.rotation_degrees.x = hour_to_deg(new_t)
        

## Where the sun rises relative to the parent scene X,Z plane,
## 0 means it will be aligned with the scene X axis  while 180 Z 
@export_range(-180.0, 180.0) var east_position: float = -140.0:
    get:
        if not sun:
            return -140.0
        return sun.rotation_degrees.y
    set(new_y):
        if not sun:
            return
        sun.rotation_degrees.y = new_y

func _ready() -> void:
    sun.rotation = Vector3(hour_to_deg(day_time), east_position, 0.0)


# ## Environment (WorldEnvironment)
#
# This contains the Sky, Clouds (Sky > Cover), Ground color, Light adjustments,
# and the overall "look" with Tonemap and Adjustments
