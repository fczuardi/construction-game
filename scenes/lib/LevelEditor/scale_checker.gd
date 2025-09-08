# ScaleCheck.gd (Godot 4.4)
# Attach to any Node3D in your level editor scene.

@tool
extends Node3D

@export var plan_mesh: MeshInstance3D         # your plane that shows the floor plan
@export var texture_width_px: int = 640       # your image width
@export var texture_height_px: int = 1024     # your image height

@export var span_a: Node3D                    # place on one wall of a known dimension
@export var span_b: Node3D                    # place on the opposite wall
@export var expected_span_feet: float = 20.0  # e.g., "20'-0\""

const FT_TO_M := 0.3048

func _ready() -> void:
    if Engine.is_editor_hint():
        _report()

func _notification(what):
    if Engine.is_editor_hint() and what == NOTIFICATION_TRANSFORM_CHANGED:
        _report()

func _get_plane_size_m() -> Vector2:
    var plane := plan_mesh
    if not plane or not plane.mesh:
        return Vector2.ZERO
    var pm := plane.mesh
    if pm is PlaneMesh:
        # PlaneMesh.size is in meters
        return (pm as PlaneMesh).size
    # Fallback: try to infer from the AABB (works for QuadMesh too)
    var aabb := pm.get_aabb()
    return Vector2(aabb.size.x * plan_mesh.scale.x, aabb.size.z * plan_mesh.scale.z)

func _report() -> void:
    var size_m := _get_plane_size_m()  # x=width, y=height (meters)
    if size_m == Vector2.ZERO:
        print("ScaleCheck: assign a Plane/Quad mesh to 'plan_mesh'.")
        return

    # World distance between markers (meters)
    if not (span_a and span_b):
        print("ScaleCheck: assign span_a/span_b.")
        return
    var measured_m := span_a.global_position.distance_to(span_b.global_position)

    var expected_m := expected_span_feet * FT_TO_M

    # Pixels-per-meter derived from the plane size vs. texture size
    var px_per_meter_w := float(texture_width_px) / size_m.x
    var px_per_meter_h := float(texture_height_px) / size_m.y
    # They should match if aspect is correct; report both.
    var meters_to_pixels_recommended := (px_per_meter_w + px_per_meter_h) * 0.5

    var err_pct := (measured_m - expected_m) / expected_m * 100.0

    print("================= ScaleCheck =================")
    print("Plane size:  W = %.3f m, H = %.3f m" % [size_m.x, size_m.y])
    print("Texture:     %d x %d px" % [texture_width_px, texture_height_px])
    print("px per m:    width=%.3f, height=%.3f  -> avg=%.3f" %
        [px_per_meter_w, px_per_meter_h, meters_to_pixels_recommended])
    print("Known span:  expected=%.3f m (%.1f ft)  measured=%.3f m  error=%.2f%%" %
        [expected_m, expected_span_feet, measured_m, err_pct])
    print("=> Put this into TrailCanvas.meters_to_pixels:  %.3f" % meters_to_pixels_recommended)
    print("==============================================")
