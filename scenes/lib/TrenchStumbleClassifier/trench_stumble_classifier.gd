class_name TrenchStumbleClassifier
extends Node

@export var character_body: PlayerRunner
@export var character_visuals: PlayerVisuals2
@export var cameras: PlayerCameras
@export var touch_controls: PlayerControls

# Angle gates (degrees) per band
@export var walk_angle_deg := 9.0
@export var jog_angle_deg  := 7.5
@export var run_angle_deg  := 6.0

@export var lateral_min := 0.15
@export var cooldown_sec := 0.35
@export var groups: Array[StringName] = ["trench"]

# Speed bands (match your visuals / runner)
@export var jog_enter := 2.2
@export var run_enter := 4.6

@export var debug_prints := false

var _cooldown_until_ms := 500

func _ready() -> void:
    assert(character_body)
    assert(character_visuals)
    character_body.collided.connect(_on_player_collided)
    EventBus.fatal_hit_received.connect(_on_fatal_hit)

func _on_fatal_hit(_world_pos):
    character_visuals.play_stumble(1.0)

func _exit_tree() -> void:
    if character_body and character_body.collided.is_connected(_on_player_collided):
        character_body.collided.disconnect(_on_player_collided)
    EventBus.fatal_hit_received.disconnect(_on_fatal_hit)

func _on_player_collided(collider: Node, normal: Vector3, grounded: bool, speed_mps: float, speed_mode: String) -> void:
    # Cooldown & basic gates
    var now_ms := Time.get_ticks_msec()
    if now_ms < _cooldown_until_ms: return
    if not grounded: return
    if not _is_in_any_group(collider, groups): return

    # Lateralness guard (avoid floor taps)
    var n := normal.normalized()
    var lat := Vector2(n.x, n.z).length()
    if lat < lateral_min: return

    # Pick threshold from numeric speed (walk/jog/run)
    var angle_gate := walk_angle_deg
    if speed_mps >= run_enter:
        angle_gate = run_angle_deg
    elif speed_mps >= jog_enter:
        angle_gate = jog_angle_deg

    # Steepness: 0 on flat floor (n.y≈1), 1 on vertical (n.y≈0)
    var steep: float = clamp(1.0 - clamp(n.y, 0.0, 1.0), 0.0, 1.0)

    # Convert gate to a comparable steepness gate (no acos):
    # angle_gate_deg ≈ acos(n.y) → n.y_gate ≈ cos(angle_gate)
    var ny_gate := cos(deg_to_rad(angle_gate))
    var steep_gate := 1.0 - ny_gate  # how much "non-up" we require

    # Reject if not steep enough
    if steep < steep_gate:
        return

    # Map to severity smoothly; include lateralness and a mild speed factor
    var t: float = clamp((steep - steep_gate) / (1.0 - steep_gate + 1e-5), 0.0, 1.0)  # how far past the gate
    var speed_factor: float = clamp((speed_mps - 0.8) / (run_enter - 0.8 + 1e-5), 0.0, 1.0)  # ~0 at walk, ~1 near run
    var raw: float = t * lerp(0.6, 1.0, speed_factor) * lat

    var bump := 0.0
    if speed_mode == "jog":
        bump = 0.10
    elif speed_mode == "run":
        bump = 0.20
    # Final severity in a sane range (avoid pinning at 0.95)
    var severity: float = clamp(lerp(0.35, 0.95, raw) + bump, 0.0, 1.0)

    if debug_prints:
        var angle_deg := rad_to_deg(acos(clamp(n.y, -1.0, 1.0)))
        print("[TrenchStumble] spd=%.2f lat=%.2f ny=%.2f ang=%.1f gate=%.1f sev=%.2f" %
              [speed_mps, lat, n.y, angle_deg, float(angle_gate), severity])
    if character_visuals.is_map_enabled() or severity >= 0.40:
        if debug_prints:
            var angle_deg := rad_to_deg(acos(clamp(n.y, -1.0, 1.0)))
            print("[TrenchStumble Visual] spd=%.2f lat=%.2f ny=%.2f ang=%.1f gate=%.1f sev=%.2f" %
                [speed_mps, lat, n.y, angle_deg, float(angle_gate), severity])
        # change setup back to walk on any stumble
        character_visuals.set_map_enabled(false)
        character_body.set_speed_mode("walk")
        cameras.activate_index(0)
        touch_controls.toggle_input(touch_controls.Side.SOUTH, false)                
        touch_controls.toggle_input(touch_controls.Side.NORTH, false)                
        # warn the visuals so it can react according to severity
        character_visuals.play_stumble(severity)
    _cooldown_until_ms = now_ms + int(cooldown_sec * 1000.0)

func _is_in_any_group(node: Node, group_list) -> bool:
    for g in group_list:
        if node.is_in_group(g):
            return true
    return false
