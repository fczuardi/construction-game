@tool
class_name SunOrbit
extends Node3D
## Rig for controlling a directional light representing a “sun”:
##
## - `hour` (0..24) maps to pitch (X) over a 24h cycle
## - `east`(-180..180) azimuth, east-west direction (Y)
## - `season` (-23.4..23.4) axial tilt (Z)


# --- Constants ----------------------------------------------------------------

const VERSION := "0.1.0"
const DEFAULT_HOUR: float = 6.5 # sunrise
const DEFAULT_EAST: float = 0.0 # forward
const DEFAULT_SEASON: float = 0.0 # equinox
const DEFAULT_AUTO_INTENSITY: bool = false # keeps light energy fixed

# Auto-intensity fixed defaults (not exported; keep it simple)
const _DAY_ENERGY: float = 1.0
const _NIGHT_ENERGY: float = 0.02
const _GAMMA: float = 1.5 # 2.0 for longer golden hours
const _SHADOW_CUTOFF: float = 0.02

# Defaults when auto_intensity is OFF
const _DEFAULT_ENERGY: float = 1.0
const _DEFAULT_SHADOWS: bool = true


# --- Public API ---------------------------------------------------------------

## the light node to provide sun light and shadows
@export var sun_light: DirectionalLight3D

## minimal toggle: dim nights / brighten days automatically
@export var auto_intensity: bool = DEFAULT_AUTO_INTENSITY:
    get:
        return _auto_intensity
    set(value):
        _auto_intensity = value
        if is_instance_valid(sun_light):
            _apply_auto_intensity()


## The time of the day representing the light rotation
@export_range(0.0, 24.0, 0.01)
var hour: float = DEFAULT_HOUR:
    get:
        if is_instance_valid(sun_light):
            return _deg_to_hour(sun_light.rotation_degrees.x)
        return _hour_cached
    set(value):
        _hour_cached = value
        if is_instance_valid(sun_light):
            sun_light.rotation_degrees.x = _hour_to_deg(value)
            _apply_auto_intensity()

## Azimuth (yaw) of the sun path, in degrees.
## 0 = path aligned with +Z (forward), -90 = path aligned with +X (right / “east”), +90 = -X (“west”).
@export_range(-180.0, 180.0, 0.1)
var east: float = DEFAULT_EAST:
    get:
        return rotation_degrees.y
    set(value):
        rotation_degrees.y = value

## orbital plane, from winter solstice to summer solstice
@export_range(-23.4, 23.4, 0.1)
var season: float = DEFAULT_SEASON:
    get:
        return rotation_degrees.z
    set(value):
        rotation_degrees.z = value


# --- Editor conveniences ------------------------------------------------------

@export_group("Time Shortcuts")

@export_tool_button("Now")
var now_action: Callable = func ():
    var now: Dictionary = Time.get_datetime_dict_from_system()
    var current: float = float(now.hour) + float(now.minute) / 60.0
    hour = current

@export_tool_button("Sunrise")
var sunrise_action: Callable = func ():
    hour = 6.0

@export_tool_button("Noon")
var noon_action: Callable = func ():
    hour = 12.00

@export_tool_button("Sunset")
var sunset_action: Callable = func ():
    hour = 18.0


# --- Functions ----------------------------------------------------------------

# Cache for inspector reads before onready
var _hour_cached: float = DEFAULT_HOUR
var _auto_intensity: bool = DEFAULT_AUTO_INTENSITY

func _ready() -> void:
    if not is_instance_valid(sun_light):
        push_warning("SunOrbit: No DirectionalLight3D set in `sun_light`.")
        return

    sun_light.rotation_degrees.x = _hour_to_deg(_hour_cached)
    rotation_degrees.y = east
    rotation_degrees.z = season
    _apply_auto_intensity()

func _apply_auto_intensity() -> void:
    if  not is_instance_valid(sun_light):
        return
    if not _auto_intensity:
        sun_light.light_energy = _DEFAULT_ENERGY
        sun_light.shadow_enabled = _DEFAULT_SHADOWS
        return
    # Simple altitude proxy from hour: 6h→0, 12h→1, 18h→0, night→negative
    var alt_raw: float = sin(((hour - 6.0) / 12.0) * PI)
    var alt: float = max(0.0, alt_raw)
    var t: float = pow(alt, _GAMMA)
    var energy: float = lerp(_NIGHT_ENERGY, _DAY_ENERGY, t)
    sun_light.light_energy = energy

    # Optional perf nicety: toggle shadows at night
    var nightish: bool = alt < _SHADOW_CUTOFF
    sun_light.shadow_enabled = not nightish


static func _deg_to_hour(d: float) -> float:
    # Map angle [-180..180] to [0..24)
    return ((d + 270.0) / 360.0) * 24.0


static func _hour_to_deg(h: float) -> float:
    # Map [0..24) back to [-180..180]
    return (h / 24.0) * 360.0 - 270.0
