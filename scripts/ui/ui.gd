class_name Ui
extends RefCounted
## Shared visual language for RollPlay: colours, type, panels and small helpers.

const INK := Color("#0a0b0a")
const INK_2 := Color("#111411")
const INK_3 := Color("#171b17")
const INK_4 := Color("#1e231e")
const CREAM := Color("#f2ead7")
const CREAM_2 := Color("#e7deca")
const CREAM_3 := Color("#d8cfba")
const LIME := Color("#d8ff4e")
const LIME_DARK := Color("#b4d62d")
const CORAL := Color("#ff8f74")
const SKY := Color("#9bc3ff")
const MUTED := Color("#9aa194")
const MUTED_DARK := Color("#6b7266")
const MUTED_INK := Color("#5d5b50")
const LINE := Color("#2b302a")
const LINE_LIGHT := Color("#d5cbb6")

const DISPLAY_PATH := "res://assets/fonts/bricolage-grotesque-latin.woff2"
const BODY_PATH := "res://assets/fonts/dm-sans-latin.woff2"
const SERIF_PATH := "res://assets/fonts/instrument-serif-italic-latin.woff2"

static var _variants: Dictionary = {}
static var _serif: Font = null
static var _wght_tag := -1


static func _weight_tag() -> int:
	if _wght_tag < 0:
		_wght_tag = TextServerManager.get_primary_interface().name_to_tag("wght")
	return _wght_tag


static func display(weight: int = 700) -> Font:
	weight = clampi(weight, 100, 800)
	var key := "display:%d" % weight
	if _variants.has(key):
		return _variants[key]
	var variation := FontVariation.new()
	variation.base_font = load(DISPLAY_PATH)
	variation.variation_opentype = {_weight_tag(): weight}
	_variants[key] = variation
	return variation


static func body(weight: int = 400) -> Font:
	weight = clampi(weight, 100, 1000)
	var key := "body:%d" % weight
	if _variants.has(key):
		return _variants[key]
	var variation := FontVariation.new()
	variation.base_font = load(BODY_PATH)
	variation.variation_opentype = {_weight_tag(): weight}
	_variants[key] = variation
	return variation


static func serif() -> Font:
	if _serif == null:
		_serif = load(SERIF_PATH)
	return _serif


static func label(text_value: String, font: Font, font_size: int, color: Color) -> Label:
	var item := Label.new()
	item.text = text_value
	item.add_theme_font_override("font", font)
	item.add_theme_font_size_override("font_size", font_size)
	item.add_theme_color_override("font_color", color)
	item.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return item


static func eyebrow(text_value: String, color: Color = MUTED) -> Label:
	return label(text_value.to_upper(), body(600), 9, color)


static func vbox(separation: int = 10) -> VBoxContainer:
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", separation)
	return box


static func hbox(separation: int = 10) -> HBoxContainer:
	var box := HBoxContainer.new()
	box.add_theme_constant_override("separation", separation)
	return box


static func margins(left: int, top: int, right: int, bottom: int) -> MarginContainer:
	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", left)
	margin.add_theme_constant_override("margin_top", top)
	margin.add_theme_constant_override("margin_right", right)
	margin.add_theme_constant_override("margin_bottom", bottom)
	return margin


static func panel_style(
	bg: Color,
	radius: int,
	border_color: Color = Color.TRANSPARENT,
	border_width: int = 0
) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = bg
	style.set_corner_radius_all(radius)
	style.corner_detail = 10
	style.anti_aliasing = true
	style.border_color = border_color
	style.set_border_width_all(border_width)
	return style


static func panel(bg: Color, radius: int, border_color: Color = Color.TRANSPARENT, border_width: int = 0) -> PanelContainer:
	var item := PanelContainer.new()
	item.add_theme_stylebox_override("panel", panel_style(bg, radius, border_color, border_width))
	return item


static func dot(color: Color, radius: float = 3.0) -> Panel:
	var item := Panel.new()
	item.custom_minimum_size = Vector2(radius * 2.0, radius * 2.0)
	item.mouse_filter = Control.MOUSE_FILTER_IGNORE
	item.add_theme_stylebox_override("panel", panel_style(color, int(radius)))
	return item


static func hline(color: Color = LINE, height: float = 1.0) -> ColorRect:
	var line := ColorRect.new()
	line.color = color
	line.custom_minimum_size = Vector2(0, height)
	line.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return line


static func vline(color: Color = LINE, width: float = 1.0) -> ColorRect:
	var line := ColorRect.new()
	line.color = color
	line.custom_minimum_size = Vector2(width, 0)
	line.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return line


static func button_style(
	button: Button,
	bg: Color,
	fg: Color,
	font_size: int = 12,
	radius: int = 10,
	border_color: Color = Color.TRANSPARENT,
	border_width: int = 0,
	hover_bg: Color = Color.TRANSPARENT,
	hover_fg: Color = Color.TRANSPARENT,
	pad_x: int = 16,
	pad_y: int = 9
) -> void:
	var normal := panel_style(bg, radius, border_color, border_width)
	normal.content_margin_left = pad_x
	normal.content_margin_right = pad_x
	normal.content_margin_top = pad_y
	normal.content_margin_bottom = pad_y
	var hover := normal.duplicate() as StyleBoxFlat
	hover.bg_color = hover_bg if hover_bg.a > 0.0 else bg.lightened(0.06)
	hover.border_color = border_color if border_width > 0 else Color.TRANSPARENT
	var pressed := normal.duplicate() as StyleBoxFlat
	pressed.bg_color = bg.darkened(0.08)
	var focus := normal.duplicate() as StyleBoxFlat
	focus.bg_color = Color.TRANSPARENT
	focus.border_color = LIME
	focus.set_border_width_all(2)
	var disabled := normal.duplicate() as StyleBoxFlat
	disabled.bg_color = bg
	disabled.border_color = border_color
	button.add_theme_stylebox_override("normal", normal)
	button.add_theme_stylebox_override("hover", hover)
	button.add_theme_stylebox_override("pressed", pressed)
	button.add_theme_stylebox_override("focus", focus)
	button.add_theme_stylebox_override("disabled", disabled)
	button.add_theme_font_override("font", body(600))
	button.add_theme_font_size_override("font_size", font_size)
	button.add_theme_color_override("font_color", fg)
	button.add_theme_color_override("font_hover_color", hover_fg if hover_fg.a > 0.0 else fg)
	button.add_theme_color_override("font_pressed_color", fg)
	button.add_theme_color_override("font_focus_color", fg)
	button.add_theme_color_override("font_disabled_color", MUTED_DARK if bg.a > 0.2 else fg * Color(1, 1, 1, 0.35))
	button.focus_mode = Control.FOCUS_ALL


static func display_style(button: Button, bg: Color, fg: Color, hover_bg: Color, hover_fg: Color) -> void:
	button_style(button, bg, fg, 13, 14, Color.TRANSPARENT, 0, hover_bg, hover_fg, 22, 14)
	button.add_theme_font_override("font", body(700))


static func trim_text(value: String, max_chars: int) -> String:
	var text := value.strip_edges()
	if text.length() <= max_chars:
		return text
	return text.left(maxi(0, max_chars - 1)).strip_edges() + "…"


static func format_bytes(bytes: int) -> String:
	if bytes <= 0:
		return "0 GB"
	var gb := float(bytes) / 1073741824.0
	if gb >= 1024.0:
		return "%.1f TB" % (gb / 1024.0)
	if gb >= 100.0:
		return "%d GB" % int(round(gb))
	return "%.1f GB" % gb


static func format_last_played(unix_seconds: int) -> String:
	if unix_seconds <= 0:
		return "NEVER PLAYED"
	var now := int(Time.get_unix_time_from_system())
	var seconds_ago := maxi(0, now - unix_seconds)
	if seconds_ago < 86400:
		return "PLAYED TODAY"
	if seconds_ago < 172800:
		return "PLAYED YESTERDAY"
	var months := ["JAN", "FEB", "MAR", "APR", "MAY", "JUN", "JUL", "AUG", "SEP", "OCT", "NOV", "DEC"]
	var date := Time.get_date_dict_from_unix_time(unix_seconds)
	return "LAST PLAYED %d %s" % [int(date.get("day", 1)), months[int(date.get("month", 1)) - 1]]


static func plural(count: int, singular: String, plural_form: String = "") -> String:
	if count == 1:
		return singular
	return plural_form if not plural_form.is_empty() else singular + "s"


static func set_anchors_full(control: Control) -> void:
	control.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
