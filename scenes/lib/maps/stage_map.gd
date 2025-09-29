class_name StageMap
extends Control

@export var maps: Array[Control]

func _ready() -> void:
    #print_debug("_ready")
    EventBus.global_stage_started.connect(_on_stage_started)
    EventBus.item_collected.connect(_on_item_collected)
    EventBus.global_restart_game.connect(_on_restart)
    EventBus.goal_unlocked.connect(_on_goal_unlocked)
    EventBus.global_next_stage.connect(_on_next_stage)
    
func _exit_tree() -> void:
    EventBus.global_next_stage.disconnect(_on_next_stage)
    EventBus.item_collected.disconnect(_on_item_collected)
    EventBus.global_restart_game.disconnect(_on_restart)
    EventBus.goal_unlocked.disconnect(_on_goal_unlocked)

var stickers: Node2D
func _on_stage_started(stage: int):
    #print_debug("_on_stage_started")
    stickers = maps[stage - 1].get_node("%Stickers")
    assert(stickers)
    
func _on_item_collected(item: Collectible):
    # Iterate MapSticker children under Stickers and flip visibility
    for child in stickers.get_children():
        if child is MapSticker:
            var sticker := child as MapSticker
            if sticker.item_id == item.id:
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
            
var _last_stage_paper_collected: bool
var _last_stage_coins_collected: int
func _on_next_stage(full_map, bitcoins_collected):
    print_debug("next stage:", full_map, ", ", bitcoins_collected)
    _last_stage_coins_collected = bitcoins_collected
    _last_stage_paper_collected = full_map
    
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
    print_debug("_on_restart, ",_last_stage_coins_collected, " ", _last_stage_paper_collected)
    for child in stickers.get_children():
        if child is MapSticker:
            var sticker := child as MapSticker
            _mark_sticker_collected(sticker, false)
            var display_optional_sticker := false
            if sticker.item_id == &"clipboard":
                display_optional_sticker = (not _last_stage_paper_collected)
            if sticker.item_id == &"sneakers":
                display_optional_sticker = (_last_stage_coins_collected > 0)
            print(sticker.item_id, " ", display_optional_sticker)
            _display_optional_stickers(sticker, display_optional_sticker)
