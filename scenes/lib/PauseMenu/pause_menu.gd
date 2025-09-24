@tool
class_name PauseMenu
extends Control
## A toggleable overlay panel that pauses the game and present options, for
## example: a Quit Game button

## Enums
enum MenuCategoryIcon { SLICE, DEMO, NONE }

## Settings

var _category_icon_dict: Dictionary[MenuCategoryIcon, String] = {
    MenuCategoryIcon.NONE: "",
    MenuCategoryIcon.SLICE: "🍰",
    MenuCategoryIcon.DEMO: "🔩",
}
var _category_icon: MenuCategoryIcon = MenuCategoryIcon.NONE
@export var category_icon: MenuCategoryIcon:
    get():
        return _category_icon
    set(value):
        _category_icon = value
        if pause_menu_bg_icon:
            pause_menu_bg_icon.text = _category_icon_dict[value]

@export var items_to_hide: Array[NodePath] = []

@export var main_title: String

## Nodes
@onready var pause_menu_button: Button = %PauseMenuButton
@onready var pause_menu_panel: Panel = %PauseMenuPanel
@onready var pause_menu_bg_icon: Label = %PauseMenuBgIcon
@onready var slice_title_label: Label = %SliceTitleLabel
@onready var quit_game_menu_section: VBoxContainer = %QuitGameMenuSection
@onready var quit_session_title: Label = %"Quit Session Title"
@onready var credits_container: VBoxContainer = %"Credits Container"
@onready var credits_btn: Button = %"Credits Btn"
@onready var menu_sections: VBoxContainer = %MenuSections
@onready var credits_close_btn: Button = credits_container.get_node("%Credits Close Btn")

## Lifecycle
func _ready() -> void:
    process_mode = Node.PROCESS_MODE_ALWAYS
    pause_menu_panel.visible = false
    pause_menu_button.toggled.connect(_on_menu_toggled)
    category_icon = _category_icon
    slice_title_label.text = main_title
    _register_items_visibility()
    EventBus.stage_completed.connect(_on_stage_clear_toggled)
    credits_btn.button_down.connect(_on_credits)
    credits_close_btn.pressed.connect(_on_credits_close)    
    if OS.get_name() == "Web":
        quit_session_title.visible = false
        quit_game_menu_section.visible = false


func _on_credits():
    credits_container.visible = true
    menu_sections.visible = false


func _on_credits_close():
    credits_container.visible = false
    menu_sections.visible = true
    
    
## Helpers
var _visibility_before_hide: Dictionary[NodePath, bool] = {}

func _register_items_visibility():
    for node_path in items_to_hide:
        if has_node(node_path):
            _visibility_before_hide[node_path] =  get_node(node_path).visible

func _hide_items():
    for node_path in items_to_hide:
        if has_node(node_path):
            get_node(node_path).visible = false

func _untoggle_items_visibility():
    for node_path in items_to_hide:
        if has_node(node_path):
            get_node(node_path).visible = _visibility_before_hide[node_path]

func _on_stage_clear_toggled(on: bool):
    hide_panel()
    pause_menu_button.disabled = on
    pause_menu_button.visible = ! on

func show_panel():
    pause_menu_panel.visible = true
    pause_menu_panel.modulate.a = 0.0
    var tween = create_tween()
    tween.tween_property(pause_menu_panel, "modulate:a", 1.0, 0.25) # fade in over 0.25s

func hide_panel():
    var tween = create_tween()
    tween.tween_property(pause_menu_panel, "modulate:a", 0.0, 0.25) # fade out over 0.25s
    tween.finished.connect(func():
        pause_menu_panel.visible = false
    )
    pause_menu_button.set_pressed_no_signal(false)

func _on_menu_toggled(toggled_on: bool) -> void:
    get_tree().paused = toggled_on
    pause_menu_panel.visible = toggled_on
    if toggled_on == true:
        _register_items_visibility()
        _hide_items()
        show_panel()
    else:
        _untoggle_items_visibility()
        hide_panel()
