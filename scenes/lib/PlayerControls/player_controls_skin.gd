@tool
class_name PlayerControlsSkin
extends Control
## Applies a ColorPalette across an ordered list of Buttons.
## Skin-agnostic: only theme overrides, doesn’t touch child visuals.

@export var palette: ColorPalette:
    set(value):
        palette = value
        _apply_if_ready()

@export var button_palette_order: Array[Button] = []:
    set(value):
        button_palette_order = value
        _apply_if_ready()

func _ready() -> void:
    _apply_if_ready()

func _apply_if_ready() -> void:
    if not palette or not button_palette_order:
        if Engine.is_editor_hint():
            push_warning("you need a palette and the ordered buttons to follow the colors")
        return
    for i in range(button_palette_order.size()):
        var btn: Button = button_palette_order[i]
        var sb: StyleBoxFlat = btn.get_theme_stylebox("normal").duplicate()
        sb.bg_color = palette.colors[i]
        btn.add_theme_stylebox_override("normal", sb)
