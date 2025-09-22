class_name StageMap
extends Control

@onready var stickers: Node2D = %Stickers

func _ready() -> void:
    EventBus.item_collected.connect(_on_item_collected)
    EventBus.global_restart_game.connect(_on_restart)
    EventBus.goal_unlocked.connect(_on_goal_unlocked)
    
func _on_item_collected(id: StringName, _points: int, _world_pos: Vector3):
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
    var hidden_panel := sticker.get_node_or_null("HiddenPanel")
    var hidden_icon := sticker.get_node_or_null("HiddenIcon")
    var check := sticker.get_node_or_null("Checkmark")

    for i in [panel, icon, hidden_panel, hidden_icon]:
        # some stickers dont have regular panel, and others dont have hidden
        if !i:
            continue
        if collect_status == true:
            i.visible = false
        # unchecking should not make hidden icons visible, only the regular
        elif i == panel or i == icon:
            i.visible = true
    if check is CanvasItem:
        (check as CanvasItem).visible = collect_status

func _on_goal_unlocked():
    for child in stickers.get_children():
        if child is MapSticker:
            var sticker := child as MapSticker
            _display_optional_stickers(sticker, true)
    
func _display_optional_stickers(sticker: MapSticker, _is_visible: bool = true):
    var panel := sticker.get_node_or_null("Panel")
    var icon := sticker.get_node_or_null("Icon")
    var hidden_panel := sticker.get_node_or_null("HiddenPanel")
    var hidden_icon := sticker.get_node_or_null("HiddenIcon")
    var check := sticker.get_node_or_null("Checkmark")
    if check.visible:
        return
    if !hidden_icon:
        return
    for i in [panel, icon, hidden_panel, hidden_icon]:
        if !i:
            continue
        if i is CanvasItem and i == icon or i == panel:
            (i as CanvasItem).visible = not _is_visible
        else:
            (i as CanvasItem).visible = _is_visible

func _on_restart():
    for child in stickers.get_children():
        if child is MapSticker:
            var sticker := child as MapSticker
            _mark_sticker_collected(sticker, false)
            _display_optional_stickers(sticker, false)
