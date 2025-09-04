class_name PauseMenu
extends Control
## A toggleable overlay panel that pauses the game and present options, for
## example: a Quit Game button

## Enums
enum MenuCategoryIcon { SLICE, DEMO, NONE }

## Settings
@export var category_icon: MenuCategoryIcon = MenuCategoryIcon.NONE
@export var items_to_hide: Array[NodePath] = []

## Nodes
@onready var pause_menu_panel: Panel = %PauseMenuPanel
@onready var pause_menu_button: TextureButton = %PauseMenuButton

## Lifecycle
func _ready() -> void:
    process_mode = Node.PROCESS_MODE_ALWAYS
    pause_menu_panel.visible = false
    pause_menu_button.toggled.connect(_on_menu_toggled)

## Helpers
var _visibility_before_hide: Dictionary[NodePath, bool] = {}

func _register_items_visibility():
    for node_path in items_to_hide:
        _visibility_before_hide[node_path] =  get_node(node_path).visible

func _hide_items():
    for node_path in items_to_hide:
        get_node(node_path).visible = false

func _untoggle_items_visibility():
    for node_path in items_to_hide:
        get_node(node_path).visible = _visibility_before_hide[node_path]
    
func _on_menu_toggled(toggled_on: bool) -> void:
    get_tree().paused = toggled_on
    pause_menu_panel.visible = toggled_on
    if toggled_on == true:
        _register_items_visibility()
        _hide_items()
    else:
        _untoggle_items_visibility()
