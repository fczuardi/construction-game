class_name StageCompletedScreen
extends Control

@export var player_visuals: PlayerVisuals2
@export var countdown: CountdownTimer
@export var stage_clear_bg_texture: TextureRect
@export var clear_text_color: Color = Color("50514f")
@export var dirty_text_color: Color = Color.WHITE
@onready var stage_complete_label: Label = %StageCompleteLabel
@onready var summary: Label = %Summary
@onready var clean_panel: TextureRect = %"Clean Panel"
@onready var retry_stage_btn: Button = %"Retry Stage Btn"
@onready var next_stage_btn: Button = %"Next Stage Btn"
@onready var credits_btn: Button = %"Credits Btn"
@onready var credits_close_btn: Button = %"Credits Close Btn"
@onready var credits_container: VBoxContainer = %"Credits Container"
@onready var credits: RichTextLabel = %Credits
@onready var v_box_container: VBoxContainer = %VBoxContainer

func _ready() -> void:
    assert(countdown)
    process_mode = Node.PROCESS_MODE_ALWAYS
    visible = false
    credits_container.visible = false
    EventBus.stage_completed.connect(_on_stage_completed)
    EventBus.item_collected.connect(_on_item_collected)
    EventBus.global_restart_game.connect(_on_restart)
    retry_stage_btn.pressed.connect(_on_retry)
    next_stage_btn.button_down.connect(_on_continue)
    credits_btn.button_down.connect(_on_credits)
    credits_close_btn.pressed.connect(_on_credits_close)
    _on_restart()

var total_objects: int
var hidden_objects: int
var was_paper_collected: bool
func _on_restart():
    total_objects = 0
    hidden_objects = 0
    was_paper_collected = false
    
func _on_retry():
    print("try again pressed")
    EventBus.stage_completed.emit(false)
    EventBus.global_restart_stage.emit()

func _on_continue():
    print("continue pressed")
    EventBus.stage_completed.emit(false)
    EventBus.global_next_stage.emit()

func _on_credits():
    credits_container.visible = true
    v_box_container.visible = false


func _on_credits_close():
    credits_container.visible = false
    v_box_container.visible = true

func _on_item_collected(item: Collectible):
    total_objects += 1
    if item.is_hidden:
        hidden_objects += 1
    if item.id == &"toilet_paper":
        was_paper_collected = true

func _get_summary() -> String:
    var elapsed_time:float =  countdown.timer.wait_time - countdown.timer.time_left
    var t = countdown._format_time(elapsed_time)
    return """Time: %s
Objects: %s
Hidden Objects: %s""" % [t, total_objects, hidden_objects]       

var _font_color: Color
func _on_stage_completed(display: bool) -> void:
    visible = display
    if not display: return
    
    player_visuals.map_viewport.render_target_clear_mode = SubViewport.CLEAR_MODE_ONCE
    player_visuals.map_viewport.render_target_update_mode = SubViewport.UPDATE_ONCE
    stage_clear_bg_texture.texture = player_visuals.map_viewport.get_texture()
    summary.text = _get_summary()
    clean_panel.visible = was_paper_collected
    var font_color = clear_text_color if was_paper_collected else dirty_text_color
    _font_color = font_color
    credits.add_theme_color_override("default_color", font_color)
    stage_complete_label.text = "Stage Clear" if was_paper_collected else "Stage Complete"
    stage_complete_label.add_theme_color_override("font_color", font_color)
    summary.add_theme_color_override("font_color", font_color)
