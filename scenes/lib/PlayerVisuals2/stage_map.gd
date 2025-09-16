class_name StageMap
extends Control

@onready var stickers: Node2D = %Stickers

func _ready() -> void:
    EventBus.item_collected.connect(_on_item_collected)
    EventBus.global_restart_game.connect(_on_restart)
    
func _on_item_collected(id: StringName, _points: int, _world_pos: Vector3):
    print(id)
    # Iterate MapSticker children under Stickers and flip visibility
    for child in stickers.get_children():
        if child is MapSticker:
            var sticker := child as MapSticker
            if sticker.item_id == id:
                _mark_sticker_collected(sticker)
                break  # stop at the first match; remove if duplicates are possible

func _mark_sticker_collected(sticker: MapSticker, collect_status: bool = true) -> void:
    var panel := sticker.get_node_or_null("Panel")
    var icon := sticker.get_node_or_null("Icon")
    var check := sticker.get_node_or_null("Checkmark")

    if panel is CanvasItem:
        (panel as CanvasItem).visible = not collect_status
    if icon is CanvasItem:
        (icon as CanvasItem).visible = not collect_status
    if check is CanvasItem:
        (check as CanvasItem).visible = collect_status

func _on_restart():
    for child in stickers.get_children():
        if child is MapSticker:
            var sticker := child as MapSticker
            _mark_sticker_collected(sticker, false)
