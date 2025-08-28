@tool
## Sun
##
## A directional light with shortcuts to handle it as the sun
extends DirectionalLight3D
class_name Sun

## The time of the day representing the light rotation
@export_range(0, 24) var hours: float = 14.0:
    get:
        if not self:
            return 6.0
        return _deg_to_hour(rotation_degrees.x)
    set(new_t):
        if not self:
            return
        rotation_degrees.x = _hour_to_deg(new_t)

# converts an angle between -180..180 into a float between 0..24
# examples: (+ or -) 180° is 6h, -90° is noon, 0° is 18:00, 90° is midnight,        
func _deg_to_hour(d: float):
    return (d + 270) / 360 * 24

# the conversion from hours back to angle
func _hour_to_deg(h: float):
    return h / 24 * 360 - 270

## the direction of sun rise and sunset
## -90° is East-West axis being aligned with the X axis
@export_range(-180, 180) var east_direction: float = 160.0:
    get:
        return rotation_degrees.y
    set(new_y):
        rotation_degrees.y = new_y
