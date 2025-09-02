@tool
class_name FlatTerrain
extends StaticBody3D
## Simple flat ground for simple games
##
## - You wire plane/collider by hand.
## - Provide a Material resource (external .tres recommended).
## - UV tiling is driven by *tile size in meters* (repeats = size / tile).


# --- Constants ----------------------------------------------------------------

const VERSION := "0.2.0"
const DEFAULT_SIZE: float = 100.0
const DEFAULT_TILE_SIZE: float = 1.0  # meters per tile (100 repeats across a 100m plane)


# --- Public API ---------------------------------------------------------------

## the size in meters of the square to use
@export var size: float = DEFAULT_SIZE:
    set(value):
        size = max(0.1, value)
        _apply_size()
        _apply_tiling() # keep texel density consistent when size changes

## tile size in meters (meters per repeat). repeats = size / tile
@export var tile: float = DEFAULT_TILE_SIZE:
    set(value):
        tile = max(0.01, value)
        _apply_tiling()

@export_category("Required Nodes")

## the mesh to use as visuals
@export var plane: MeshInstance3D
## the collision shape
@export var collider: CollisionShape3D

@export_category("Material")
## External material resource (.tres). 
## If empty, uses plane's current material or a new StandardMaterial3D.
@export var material: Material:
    set(value):
        # update source ref and rebuild the override
        _disconnect_material_watch()
        material = value
        _connect_material_watch(material)
        _rebuild_material_from_source()


# --- Private ------------------------------------------------------------------

var _mat_instance: BaseMaterial3D # unique per-FlatTerrain override
var _watched_material: Resource  # the exported source we're mirroring


# --- Lifecycle ----------------------------------------------------------------

func _ready():
    if not is_instance_valid(plane) or not is_instance_valid(collider):
        push_warning("FlatTerrain: Fill 'plane' and 'collider' in the Inspector.")
        return

    _connect_material_watch(material)
    _rebuild_material_from_source()
    _apply_size()
    _apply_tiling()


# --- Helpers ------------------------------------------------------------------

func _apply_size() -> void:
    if is_instance_valid(plane):
        var pm: PlaneMesh = plane.mesh
        if pm:
            pm.size = Vector2(size, size)
    if is_instance_valid(collider):
        var box: BoxShape3D = collider.shape
        if box:
            var bh: float = box.size.y
            box.size = Vector3(size, bh, size)
            var t := collider.transform
            t.origin.y = -bh * 0.5
            collider.transform = t

func _apply_tiling() -> void:
    if _mat_instance:
        var repeats: float = size / tile
        _mat_instance.uv1_scale = Vector3(repeats, repeats, 1.0)


# --- Material handling ---------------------------------------------------------

func _rebuild_material_from_source() -> void:
    if not is_instance_valid(plane):
        return

    # pick a source: exported material (preferred) or plane's current material
    var src: Material = material if material != null else plane.get_active_material(0)
    var base: BaseMaterial3D = src as BaseMaterial3D

    if base == null:
        # If it's not a BaseMaterial3D (e.g., ShaderMaterial), just assign it directly.
        _mat_instance = null
        if src != null:
            plane.set_surface_override_material(0, src)
        return

    # check for possible scene bloat risk
    _warn_if_embedded_textures(base)

    # duplicate so edits here don't mutate the shared .tres
    _mat_instance = base.duplicate() as BaseMaterial3D
    plane.set_surface_override_material(0, _mat_instance)
    _apply_tiling()  # keep tiling after swap

func _connect_material_watch(src: Resource) -> void:
    if src == null:
        return
    if not src.is_connected("changed", Callable(self, "_on_material_source_changed")):
        src.changed.connect(_on_material_source_changed)

func _disconnect_material_watch() -> void:
    if _watched_material != null and _watched_material.is_connected("changed", Callable(self, "_on_material_source_changed")):
        _watched_material.changed.disconnect(Callable(self, "_on_material_source_changed"))
    _watched_material = null

func _on_material_source_changed() -> void:
    # the .tres was edited or reimported: re-dupe and reapply tiling
    _rebuild_material_from_source()

func _warn_if_embedded_textures(mat: BaseMaterial3D) -> void:
    var slots := {
        "albedo": mat.albedo_texture,
        "normal": mat.normal_texture,
        "roughness": mat.roughness_texture,
    }
    for slot_name in slots.keys():
        # ImageTexture usually implies embedded pixels; CompressedTexture2D is the safe imported type.
        if slots[slot_name] is ImageTexture:
            push_warning("FlatTerrain: '%s' uses ImageTexture (likely embedded). Prefer imported files (CompressedTexture2D)." % name)
            continue
