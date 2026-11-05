class_name ShelfCard
extends PanelContainer
## A browsable cover tile. Clicking it launches that game through Steam.

signal launch_requested(app_id: int)

const PAD := 10.0

var game: Dictionary = {}
var _built := false
var _cover_holder: Control
var _cover: CoverView
var _hover_bar: PanelContainer
var _title: Label
var _meta: Label
var _normal_style: StyleBoxFlat
var _hover_style: StyleBoxFlat
var _hovering := false
var _focused := false


func setup(value: Dictionary) -> void:
	game = value
	custom_minimum_size = Vector2(148, 0)
	focus_mode = Control.FOCUS_ALL
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	set_tooltip_text("Launch %s through Steam" % game.get("name", "this game"))
	if is_node_ready():
		_apply_game()


func _ready() -> void:
	if not _built:
		_build()
	mouse_entered.connect(_set_hover.bind(true))
	mouse_exited.connect(_set_hover.bind(false))
	focus_entered.connect(_set_focus.bind(true))
	focus_exited.connect(_set_focus.bind(false))
	gui_input.connect(_on_gui_input)
	_apply_game()
	_update_cover_height()


func _build() -> void:
	_normal_style = _card_style(Color("#f7f0e0"), Color("#d5cbb6"), 1)
	_hover_style = _card_style(Color("#fffbec"), Ui.LIME_DARK, 2)
	add_theme_stylebox_override("panel", _normal_style)

	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 9)
	add_child(column)

	_cover_holder = Control.new()
	_cover_holder.clip_contents = true
	_cover_holder.custom_minimum_size = Vector2(0, 200)
	_cover_holder.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	cover_holder_mouse_ignore(_cover_holder)
	column.add_child(_cover_holder)

	_cover = CoverView.new()
	_cover.radius = 9
	_cover.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_cover_holder.add_child(_cover)

	_hover_bar = PanelContainer.new()
	var bar_style := Ui.panel_style(Color(0.03, 0.04, 0.03, 0.93), 0)
	bar_style.corner_radius_bottom_left = 9
	bar_style.corner_radius_bottom_right = 9
	bar_style.content_margin_left = 10
	bar_style.content_margin_right = 10
	bar_style.content_margin_top = 5
	bar_style.content_margin_bottom = 5
	_hover_bar.add_theme_stylebox_override("panel", bar_style)
	_hover_bar.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	_hover_bar.offset_top = -30
	_hover_bar.offset_bottom = 0
	_hover_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_hover_bar.visible = false
	_cover_holder.add_child(_hover_bar)

	var bar_row := HBoxContainer.new()
	bar_row.add_theme_constant_override("separation", 6)
	_hover_bar.add_child(bar_row)
	var launch_label := Ui.label("LAUNCH", Ui.body(700), 9, Ui.CREAM)
	launch_label.add_theme_constant_override("outline_size", 0)
	bar_row.add_child(launch_label)
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bar_row.add_child(spacer)
	var arrow := Glyph.new()
	arrow.kind = Glyph.Kind.ARROW
	arrow.color = Ui.LIME
	arrow.custom_minimum_size = Vector2(14, 12)
	arrow.line_width = 1.6
	bar_row.add_child(arrow)

	_title = Ui.label("", Ui.body(700), 13, Ui.INK)
	_title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_title.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	_title.max_lines_visible = 2
	_title.custom_minimum_size = Vector2(0, 34)
	_title.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_child(_title)

	_meta = Ui.label("", Ui.body(600), 8, Ui.MUTED_INK)
	_meta.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	_meta.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_child(_meta)
	_built = true


func cover_holder_mouse_ignore(control: Control) -> void:
	control.mouse_filter = Control.MOUSE_FILTER_IGNORE


func _apply_game() -> void:
	if not _built:
		return
	_cover.set_game(game)
	_title.text = String(game.get("name", "Unknown game"))
	var genres: Array = game.get("genres", [])
	var genre_text := "UNCLASSIFIED" if genres.is_empty() else String(genres[0]).to_upper()
	var size_text := Ui.format_bytes(int(game.get("size_bytes", 0)))
	var library_text := String(game.get("library_label", "Steam"))
	_meta.text = "%s  ·  %s  ·  %s" % [genre_text, library_text, size_text]
	_hover_bar.visible = _hovering or _focused


func _update_cover_height() -> void:
	if not _built:
		return
	if _cover_holder == null:
		return
	var inner_width := maxf(96.0, size.x - PAD * 2.0)
	_cover_holder.custom_minimum_size = Vector2(0, roundf(inner_width * 1.5))


func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED:
		_update_cover_height()


func _set_hover(value: bool) -> void:
	_hovering = value
	_refresh_state()


func _set_focus(value: bool) -> void:
	_focused = value
	_refresh_state()


func _refresh_state() -> void:
	if not _built:
		return
	var active := _hovering or _focused
	add_theme_stylebox_override("panel", _hover_style if active else _normal_style)
	_hover_bar.visible = active


func _on_gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
			accept_event()
			launch_requested.emit(int(game.get("app_id", 0)))
	elif event is InputEventKey:
		if event.pressed and not event.echo and (event.keycode == KEY_ENTER or event.keycode == KEY_SPACE):
			accept_event()
			launch_requested.emit(int(game.get("app_id", 0)))


func _card_style(fill: Color, border: Color, border_width: int) -> StyleBoxFlat:
	var style := Ui.panel_style(fill, 12)
	style.border_color = border
	style.set_border_width_all(border_width)
	style.content_margin_left = PAD
	style.content_margin_right = PAD
	style.content_margin_top = PAD
	style.content_margin_bottom = PAD
	return style
