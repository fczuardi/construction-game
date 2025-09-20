class_name ShowcaseHub
extends Node3D
## Moves the latest collected item to a showcase spot in the world.

@export var showcase_spot: Node3D          # assign your Marker3D
@export var reparent_to: Node3D            # optional: a neutral parent for showcased items
@export var face_camera: Camera3D          # optional: rotate Y to face this camera

var _current: Node3D

func show_item(item: Node3D) -> void:
    if item == null or showcase_spot == null:
        return

    # remove the previous one (or stash it if you prefer pooling)
    if _current and is_instance_valid(_current):
        _current.queue_free()
        _current = null

    # Optional: reparent so level unloads don’t affect it
    if reparent_to and item.get_parent() != reparent_to:
        item.get_parent().remove_child(item)
        reparent_to.add_child(item)

    # Put it at the spot (global)
    item.global_transform = showcase_spot.global_transform

    # Optional: scale normalize
    if item.showcase_scale > 0.0:
        item.scale = Vector3.ONE * item.showcase_scale

    # Optional: Y-face the camera (keeps item’s up)
    if face_camera:
        var item_pos := item.global_transform.origin
        var cam_pos := face_camera.global_transform.origin
        var dir := (cam_pos - item_pos)
        dir.y = 0.0
        if dir.length() > 0.001:
            item.look_at(item_pos + dir, Vector3.UP)

    # Make sure it no longer collides or triggers gameplay
    _disable_collisions_recursive(item)

    _current = item
    # Schedule removal
    var t := get_tree().create_timer(3.0)
    t.timeout.connect(func ():
        if item and is_instance_valid(item):
            item.queue_free()
    )

func _disable_collisions_recursive(n: Node) -> void:
    if n is CollisionObject3D:
        var co := n as CollisionObject3D
        co.collision_layer = 0
        co.collision_mask = 0
        if co is Area3D:
            (co as Area3D).monitoring = false
            (co as Area3D).monitorable = false
    for c in n.get_children():
        _disable_collisions_recursive(c)
