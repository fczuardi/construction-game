class_name CountdownTimer
extends Label

@export var timer: Timer

# High Scores:
# running without bitcoin = 34s
# walking without bitcoin = 88s

const UPDATE_FREQUENCY: float = 1.0
const INITIAL_FONT_SIZE: int = 17
const MAX_FONT_SIZE: int = 36
const EASE_POWER := 3.0          # 2–5 works well (higher = more weight at the end)
const PULSE_START_SEC := 10.0     # add a heartbeat in the final seconds
const PULSE_STRENGTH := 0.5      # 0..0.3 extra size
const PULSE_BPM := 110.0         # beat rate for the pulse
const PULSE_COLOR := Color("#f4d35e")
const NORMAL_COLOR := Color(1, 1, 1)     # default white


var _time_acc: float = 0.0
func _process(delta: float) -> void:
    if ! timer:
        return
    _time_acc += delta
    if timer.paused:
        return
    _time_acc = 0.0

    text = _format_time(timer.time_left)

    # 0..1 linear progress
    var t := 1.0 - (timer.time_left / timer.wait_time)
    t = clamp(t, 0.0, 1.0)

    # --- Option A: power ease (late emphasis)
    #var eased := pow(t, EASE_POWER)

    # --- Option B: smoother step (S-curve, still pushes growth late)
    var eased := t * t * (3.0 - 2.0 * t)

    # Base scale from easing
    var max_increase := float(MAX_FONT_SIZE - INITIAL_FONT_SIZE)
    var font_size := INITIAL_FONT_SIZE + int(round(max_increase * eased))

    # Add a subtle pulse in the last N seconds
    if timer.time_left <= PULSE_START_SEC:
        var beat := sin(Time.get_ticks_msec() / 1000.0 * TAU * (PULSE_BPM / 60.0))
        var pulse: float = max(0.0, beat) * PULSE_STRENGTH   # only expand on the up-beat
        font_size += int(round(max_increase * pulse))
        add_theme_color_override("font_color", PULSE_COLOR)
    else:
        add_theme_color_override("font_color", NORMAL_COLOR)    
    add_theme_font_size_override("font_size", font_size)


func _format_time(seconds: float) -> String:
    var total_seconds := int(round(seconds))
    var minutes := total_seconds / 60
    var secs := total_seconds % 60
    return "%02d:%02d" % [minutes, secs]
