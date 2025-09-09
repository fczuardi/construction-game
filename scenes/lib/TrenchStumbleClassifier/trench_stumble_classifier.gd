class_name TrenchStumbleClassifier
extends Node
## Subscribes to PlayerRunner.collided and triggers a stumble on trench lips.

@export var character_body: PlayerRunner
@export var character_visuals: PlayerVisuals

@export var walk_angle_deg := 9.0     # ~pickier at slow speed
@export var run_angle_deg := 6.0      # a bit more sensitive for sprint
@export var lateral_min := 0.15       # |normal.xz| must be at least this
@export var cooldown_sec := 0.35
@export var groups := ["trench"]      # geometry must belong to any of these groups

@export var debug_prints := false

var _cooldown_until_ms: int = 0

func _ready() -> void:
    assert(character_body)
    assert(character_visuals)
    character_body.collided.connect(_on_player_collided)

func _exit_tree() -> void:
    if character_body and character_body.collided.is_connected(_on_player_collided):
        character_body.collided.disconnect(_on_player_collided)

func _on_player_collided(collider: Node, normal: Vector3, grounded: bool, speed_mps: float, speed_mode: String) -> void:
    # Cooldown gate
    var now_ms := Time.get_ticks_msec()
    if now_ms < _cooldown_until_ms:
        return

    # Only trip while still grounded (we want stumble, not fall)
    if not grounded:
        return

    # Must be one of the trench groups
    if not _is_in_any_group(collider, groups):
        return

    # Basic lip/edge check from contact normal
    var n := normal.normalized()
    var lat := Vector2(n.x, n.z).length()     # 0..1
    if lat < lateral_min:
        return

    # Angle from Up (degrees)
    var ny: float = clamp(n.y, -1.0, 1.0)
    var angle_deg := rad_to_deg(acos(ny))

    var threshold := run_angle_deg if (speed_mode == "run") else walk_angle_deg
    if angle_deg < threshold:
        return

    # Map to a simple severity (0..1); keep it minimal
    var base := 0.85 if (speed_mode == "run") else 0.6
    var extra: float = clamp((angle_deg - threshold) / 12.0, 0.0, 0.35)
    var severity: float = clamp(base + extra, 0.3, 1.0)

    if debug_prints:
        print("[TrenchStumble] mode=", speed_mode, " angle=", angle_deg, " lat=", lat, " sev=", severity)

    # Trigger visuals and lock for a short cooldown
    character_visuals.play_stumble(severity)
    _cooldown_until_ms = now_ms + int(cooldown_sec * 1000.0)

func _is_in_any_group(node: Node, group_list) -> bool:
    for g in group_list:
        if node.is_in_group(g):
            return true
    return false
