@tool
class_name PlayerControlsSkin
extends Control
## Applies a ColorPalette across an ordered list of Buttons.
## Skin-agnostic: only theme overrides, doesn’t touch child visuals.

@export var palette: ColorPalette:
    set(value):
        if palette:
            palette.changed.disconnect(_apply_if_ready) if palette.changed.is_connected(_apply_if_ready) else null
        palette = value
        if palette:
            palette.changed.connect(_apply_if_ready)
        _apply_if_ready()

@export var button_palette_order: Array[Button] = []:
    set(value):
        button_palette_order = value
        _apply_if_ready()

@export var rounded_radius: int = 25
@export var derive_hover_pressed: bool = true


func _ready() -> void:
    _apply_if_ready()

func _notification(what: int) -> void:
    if what == NOTIFICATION_THEME_CHANGED:
        _apply_if_ready()

func _apply_if_ready() -> void:
    if not is_inside_tree() or not palette or not button_palette_order:
        return

    var colors: PackedColorArray = palette.colors
    if colors.is_empty():
        return

    for i in range(button_palette_order.size()):
        var btn: Button = button_palette_order[i]
        if btn == null:
            continue

        var base: Color = colors[i % colors.size()]

        var normal_sb: StyleBoxFlat = btn.get_theme_stylebox("normal").duplicate()
        normal_sb.bg_color = base
        _set_round(normal_sb)
        btn.add_theme_stylebox_override("normal", normal_sb)

        if derive_hover_pressed:
            var hover_sb := normal_sb.duplicate()
            var pressed_sb := normal_sb.duplicate()
            var disabled_sb := normal_sb.duplicate()

            hover_sb.bg_color = _tint(base, 1.06)    # slightly lighter
            pressed_sb.bg_color = _tint(base, 0.90)  # slightly darker
            disabled_sb.bg_color = base.darkened(0.35); disabled_sb.set("draw_center", true)

            _set_round(hover_sb)
            _set_round(pressed_sb)
            _set_round(disabled_sb)
            btn.add_theme_stylebox_override("hover", hover_sb)
            btn.add_theme_stylebox_override("pressed", pressed_sb)
            btn.add_theme_stylebox_override("disabled", disabled_sb)

func _set_round(sb: StyleBoxFlat) -> void:
    sb.corner_radius_top_left = rounded_radius
    sb.corner_radius_top_right = rounded_radius
    sb.corner_radius_bottom_left = rounded_radius
    sb.corner_radius_bottom_right = rounded_radius

func _tint(c: Color, mul: float) -> Color:
    # simple perceptual-ish brighten/darken
    return Color(clamp(c.r * mul, 0.0, 1.0), clamp(c.g * mul, 0.0, 1.0), clamp(c.b * mul, 0.0, 1.0), c.a)

