extends VBoxContainer

@onready var quit_game_button: Button = %QuitGameButton
@onready var quit_game_confirm_dialog: HBoxContainer = %QuitGameConfirmDialog
@onready var cancel_button: Button = %CancelButton
@onready var confirm_button: Button = %ConfirmButton

func _ready() -> void:
    quit_game_confirm_dialog.visible = false
    quit_game_button.pressed.connect(_on_quit_btn_press)
    cancel_button.pressed.connect(_on_cancel_btn_press)
    confirm_button.pressed.connect(_on_confirm_quit_btn_press)
    
func _on_quit_btn_press():
    quit_game_button.visible = false
    quit_game_confirm_dialog.visible = true
    
func _on_cancel_btn_press():
    quit_game_confirm_dialog.visible = false
    quit_game_button.visible = true
    
func _on_confirm_quit_btn_press():
    get_tree().root.propagate_notification(NOTIFICATION_WM_CLOSE_REQUEST)
    get_tree().quit()
