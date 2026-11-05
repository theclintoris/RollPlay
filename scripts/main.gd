extends Control
## RollPlay's one-page arcade. The interface is built in code so the visual system
## stays in one place and every state is easy to iterate on.

const PAGE_WIDE := 42
const PAGE_NARROW := 26
const DRAWER_WIDTH := 600.0
const REEL_SIZE := Vector2(224, 336)
const REEL_GAP := 10.0
const DRAWER_OFFSETS := Vector2(-600, 0)

var _snapshot: Dictionary = {}
var _genres: Array = []
var _genre_counts: Dictionary = {}
var _mode := "all"
var _genre := ""
var _result: Dictionary = {}
var _last_winner := 0
var _rolling := false
var _launching := false
var _library_ready := false
var _pool_size := 0
var _drawer_open := false
var _shelf_genre := "all"
var _shelf_sort := 0
var _suppress_filters := false
var _roll_tween: Tween
var _pulse_tween: Tween
var _drawer_tween: Tween
var _toast_tween: Tween

var _page_margin: MarginContainer
var _status_dot: Panel
var _status_label: Label
var _refresh_button: Button
var _browse_button: Button
var _hero_note: Label
var _hero_meta: Label
var _error_banner: PanelContainer
var _error_text: Label
var _mode_all: Button
var _mode_genre: Button
var _genre_section: VBoxContainer
var _genre_flow: HFlowContainer
var _genre_hint: Label
var _genre_buttons: Dictionary = {}
var _genre_signature := "<unset>"
var _pool_count: Label
var _pool_unit: Label
var _pool_desc: Label
var _roll_button: Button
var _roll_content: Control
var _roll_button_label: Label
var _stage: PanelContainer
var _stage_badge_dot: Panel
var _stage_badge_label: Label
var _stage_footer: Label
var _cover_stack: Control
var _mystery_card: PanelContainer
var _reel_window: Control
var _reel: Control
var _winner_wrap: Control
var _winner_cover: CoverView
var _copy_idle: VBoxContainer
var _copy_rolling: VBoxContainer
var _copy_result: VBoxContainer
var _idle_title: Label
var _idle_body: Label
var _idle_note: Label
var _result_genres: Label
var _result_title: Label
var _result_desc: Label
var _result_meta: Label
var _launch_button: Button
var _reroll_button: Button
var _store_button: Button
var _stat_values: Dictionary = {}
var _confetti: ConfettiField
var _drawer_overlay: Control
var _drawer_backdrop: ColorRect
var _drawer_panel: PanelContainer
var _search_field: LineEdit
var _genre_filter: OptionButton
var _sort_filter: OptionButton
var _shelf_summary: Label
var _library_grid: GridContainer
var _shelf_empty: Label
var _toast: PanelContainer
var _toast_text: Label


func _ready() -> void:
	var app_theme := Theme.new()
	app_theme.default_font = Ui.body(400)
	app_theme.default_font_size = 13
	theme = app_theme
	get_window().title = "RollPlay — Steam library roulette"
	get_window().min_size = Vector2i(1200, 700)
	_fit_window_to_screen()
	resized.connect(_on_page_resized)

	add_child(_backdrop())
	_build_page()
	_confetti = ConfettiField.new()
	add_child(_confetti)
	_build_drawer()
	_build_toast()
	_connect_service()
	_on_page_resized()
	_refresh_roll_availability()
	call_deferred("_initial_state")


func _fit_window_to_screen() -> void:
	if DisplayServer.get_name() == "headless" or OS.get_environment("ROLLPLAY_NO_WINDOW_FIT") == "1":
		return
	var window := get_window()
	var screen := DisplayServer.window_get_current_screen()
	var usable := DisplayServer.screen_get_usable_rect(screen)
	var target := Vector2i(
		clampi(usable.size.x - 48, 1200, 1440),
		clampi(usable.size.y - 64, 700, 900)
	)
	window.size = target
	window.position = usable.position + (usable.size - target) / 2


func _backdrop() -> Control:
	var script := load("res://scripts/ui/backdrop.gd")
	var item: Control = script.new()
	item.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	return item


func _initial_state() -> void:
	var current := SteamLibrary.snapshot()
	if bool(current.get("ok", false)) and not (current.get("games", []) as Array).is_empty():
		_apply_snapshot(current, true)


func _connect_service() -> void:
	SteamLibrary.scan_started.connect(_on_scan_started)
	SteamLibrary.scan_finished.connect(_on_scan_finished)
	SteamLibrary.scan_failed.connect(_on_scan_failed)
	SteamLibrary.snapshot_changed.connect(_on_snapshot_changed)
	SteamLibrary.metadata_progress.connect(_on_metadata_progress)
	SteamLibrary.enrichment_finished.connect(_on_enrichment_finished)
	SteamLibrary.game_launched.connect(_on_game_launched)
	SteamLibrary.launch_failed.connect(_on_launch_failed)


# --- Page shell ------------------------------------------------------------


func _build_page() -> void:
	var scroll := ScrollContainer.new()
	scroll.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	scroll.follow_focus = true
	add_child(scroll)
	_style_scroll_bar(scroll.get_v_scroll_bar())

	_page_margin = Ui.margins(PAGE_WIDE, 18, PAGE_WIDE, 10)
	_page_margin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(_page_margin)

	var page := Ui.vbox(14)
	page.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_page_margin.add_child(page)
	page.add_child(_build_header())
	page.add_child(_build_hero())
	_error_banner = _build_error_banner()
	page.add_child(_error_banner)
	page.add_child(_build_main_row())
	page.add_child(_build_stats())
	page.add_child(_build_footer())


func _style_scroll_bar(bar: ScrollBar) -> void:
	bar.custom_minimum_size = Vector2(9, 0)
	var track := StyleBoxFlat.new()
	track.bg_color = Color(1, 1, 1, 0.035)
	track.set_corner_radius_all(4)
	track.content_margin_left = 2
	track.content_margin_right = 2
	var grabber := StyleBoxFlat.new()
	grabber.bg_color = Color(0.62, 0.66, 0.58, 0.42)
	grabber.set_corner_radius_all(4)
	var active := grabber.duplicate() as StyleBoxFlat
	active.bg_color = Ui.LIME_DARK
	bar.add_theme_stylebox_override("scroll", track)
	bar.add_theme_stylebox_override("grabber", grabber)
	bar.add_theme_stylebox_override("grabber_highlight", active)
	bar.add_theme_stylebox_override("grabber_pressed", active)


func _build_header() -> Control:
	var header := Ui.hbox(18)
	header.custom_minimum_size.y = 48
	var mark := Glyph.new()
	mark.kind = Glyph.Kind.D20
	mark.filled = false
	mark.color = Ui.LIME
	mark.custom_minimum_size = Vector2(23, 23)
	mark.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	header.add_child(mark)
	var brand := Ui.vbox(0)
	brand.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	brand.add_child(Ui.label("ROLLPLAY", Ui.display(760), 19, Ui.CREAM))
	brand.add_child(Ui.label("STEAM LIBRARY ROULETTE", Ui.body(650), 8, Ui.MUTED_DARK))
	header.add_child(brand)

	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(spacer)

	var status := Ui.hbox(8)
	status.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_status_dot = Ui.dot(Ui.MUTED_DARK, 3.2)
	_status_dot.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	status.add_child(_status_dot)
	_status_label = Ui.label("READING STEAM…", Ui.body(600), 9, Ui.MUTED)
	_status_label.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	status.add_child(_status_label)
	header.add_child(status)

	_refresh_button = Button.new()
	_refresh_button.text = "REFRESH"
	_refresh_button.custom_minimum_size.y = 36
	_refresh_button.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	Ui.button_style(_refresh_button, Color.TRANSPARENT, Ui.MUTED, 9, 8, Ui.LINE, 1, Color("#1b201a"), Ui.CREAM, 12, 8)
	_refresh_button.pressed.connect(_on_refresh_pressed)
	header.add_child(_refresh_button)

	_browse_button = Button.new()
	_browse_button.text = "BROWSE LIBRARY"
	_browse_button.custom_minimum_size.y = 36
	_browse_button.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	Ui.button_style(_browse_button, Ui.CREAM, Ui.INK, 9, 8, Color.TRANSPARENT, 0, Ui.LIME, Ui.INK, 14, 9)
	_browse_button.pressed.connect(_open_drawer)
	header.add_child(_browse_button)

	var outer := Ui.vbox(0)
	outer.add_child(header)
	var rule := Ui.hline(Ui.LINE, 1)
	outer.add_child(rule)
	return outer


func _build_hero() -> Control:
	var hero := Ui.hbox(38)
	hero.custom_minimum_size.y = 168
	var left := Ui.vbox(0)
	left.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	left.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var eyebrow_row := Ui.hbox(8)
	eyebrow_row.add_child(Ui.dot(Ui.LIME, 2.8))
	var eyebrow := Ui.eyebrow("STEAM LIBRARY ROULETTE  /  01", Ui.MUTED)
	eyebrow.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	eyebrow_row.add_child(eyebrow)
	left.add_child(eyebrow_row)
	var titles := Ui.vbox(-8)
	titles.add_child(Ui.label("Your library.", Ui.display(700), 61, Ui.CREAM))
	titles.add_child(Ui.label("one roll.", Ui.serif(), 72, Ui.LIME))
	left.add_child(titles)
	var meta_row := Ui.hbox(10)
	_hero_meta = Ui.label("READING YOUR STEAM LIBRARIES…", Ui.body(600), 9, Ui.MUTED_DARK)
	meta_row.add_child(_hero_meta)
	left.add_child(meta_row)
	hero.add_child(left)

	var right := Ui.vbox(12)
	right.custom_minimum_size.x = 306
	right.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	right.add_child(Ui.eyebrow("A SMALL RITUAL FOR A BIG BACKLOG", Ui.MUTED))
	_hero_note = Ui.label("Your installed games, read straight from Steam. Pick a mood, roll the dice, and skip the forty-minute scroll.", Ui.body(400), 13, Ui.MUTED)
	_hero_note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_hero_note.custom_minimum_size.x = 290
	right.add_child(_hero_note)
	var local_row := Ui.hbox(7)
	local_row.add_child(Ui.dot(Ui.LIME, 2.2))
	local_row.add_child(Ui.label("LOCAL ONLY  ·  NO SIGN-IN", Ui.body(600), 8, Ui.LIME_DARK))
	right.add_child(local_row)
	hero.add_child(right)
	return hero


func _build_error_banner() -> PanelContainer:
	var panel := Ui.panel(Color("#291614"), 12, Ui.CORAL, 1)
	var style := panel.get_theme_stylebox("panel") as StyleBoxFlat
	style.content_margin_left = 16
	style.content_margin_right = 16
	style.content_margin_top = 12
	style.content_margin_bottom = 12
	var row := Ui.hbox(12)
	panel.add_child(row)
	var mark := Ui.label("!", Ui.display(700), 18, Ui.CORAL)
	mark.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(mark)
	_error_text = Ui.label("Steam could not be read.", Ui.body(500), 12, Ui.CREAM)
	_error_text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_error_text.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(_error_text)
	var retry := Button.new()
	retry.text = "TRY AGAIN"
	Ui.button_style(retry, Color.TRANSPARENT, Ui.CORAL, 9, 7, Ui.CORAL, 1, Color("#3a1c18"), Ui.CREAM, 10, 7)
	retry.pressed.connect(_on_refresh_pressed)
	row.add_child(retry)
	panel.visible = false
	return panel


# --- Control console -------------------------------------------------------


func _build_main_row() -> HBoxContainer:
	var row := Ui.hbox(18)
	row.custom_minimum_size.y = 478
	var console := _build_console()
	console.size_flags_vertical = Control.SIZE_EXPAND_FILL
	row.add_child(console)
	_stage = _build_stage()
	_stage.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_stage.size_flags_vertical = Control.SIZE_EXPAND_FILL
	row.add_child(_stage)
	return row


func _build_console() -> PanelContainer:
	var panel := Ui.panel(Ui.CREAM, 20, Ui.LINE_LIGHT, 1)
	var style := panel.get_theme_stylebox("panel") as StyleBoxFlat
	style.content_margin_left = 26
	style.content_margin_right = 26
	style.content_margin_top = 24
	style.content_margin_bottom = 22
	panel.custom_minimum_size.x = 462
	var column := Ui.vbox(13)
	panel.add_child(column)

	var top := Ui.hbox(10)
	top.add_child(Ui.eyebrow("01 / SET THE ODDS", Ui.MUTED_INK))
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(spacer)
	top.add_child(Ui.label("MODE", Ui.body(650), 8, Ui.MUTED_INK))
	column.add_child(top)

	var toggle_shell := PanelContainer.new()
	toggle_shell.add_theme_stylebox_override("panel", Ui.panel_style(Ui.CREAM_2, 11))
	var toggle_style := toggle_shell.get_theme_stylebox("panel") as StyleBoxFlat
	toggle_style.content_margin_left = 4
	toggle_style.content_margin_right = 4
	toggle_style.content_margin_top = 4
	toggle_style.content_margin_bottom = 4
	column.add_child(toggle_shell)
	var tabs := Ui.hbox(4)
	toggle_shell.add_child(tabs)
	_mode_all = _make_tab("ANYTHING GOES")
	_mode_all.pressed.connect(_set_mode.bind("all"))
	tabs.add_child(_mode_all)
	_mode_genre = _make_tab("PICK A GENRE")
	_mode_genre.pressed.connect(_set_mode.bind("genre"))
	tabs.add_child(_mode_genre)
	_refresh_mode_tabs()

	_genre_section = Ui.vbox(7)
	_genre_flow = HFlowContainer.new()
	_genre_flow.add_theme_constant_override("h_separation", 6)
	_genre_flow.add_theme_constant_override("v_separation", 6)
	_genre_section.add_child(_genre_flow)
	_genre_hint = Ui.label("Only games tagged with this genre can be rolled.", Ui.body(400), 10, Ui.MUTED_INK)
	_genre_hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_genre_section.add_child(_genre_hint)
	_genre_section.visible = false
	column.add_child(_genre_section)

	var stretch := Control.new()
	stretch.size_flags_vertical = Control.SIZE_EXPAND_FILL
	stretch.custom_minimum_size.y = 1
	column.add_child(stretch)

	column.add_child(Ui.hline(Ui.LINE_LIGHT, 1))
	var pool_row := Ui.hbox(14)
	_pool_count = Ui.label("—", Ui.display(760), 46, Ui.INK)
	_pool_count.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	pool_row.add_child(_pool_count)
	var pool_meta := Ui.vbox(1)
	pool_meta.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_pool_unit = Ui.label("GAMES IN THE POOL", Ui.body(700), 9, Ui.MUTED_INK)
	pool_meta.add_child(_pool_unit)
	var pool_note := Ui.label("ONE ROLL, ONE PICK", Ui.body(600), 8, Ui.MUTED_INK)
	pool_meta.add_child(pool_note)
	pool_row.add_child(pool_meta)
	column.add_child(pool_row)
	_pool_desc = Ui.label("Every installed game is fair game.", Ui.body(400), 11, Ui.MUTED_INK)
	_pool_desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	column.add_child(_pool_desc)

	_roll_button = Button.new()
	_roll_button.custom_minimum_size.y = 74
	_roll_button.focus_mode = Control.FOCUS_ALL
	Ui.button_style(_roll_button, Ui.INK, Ui.CREAM, 15, 12, Color.TRANSPARENT, 0, Color("#1d2519"), Ui.CREAM, 18, 10)
	_roll_button.pressed.connect(_start_roll)
	column.add_child(_roll_button)
	_roll_content = Ui.hbox(12)
	_roll_content.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_roll_button.add_child(_roll_content)
	_roll_content.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_roll_content.offset_left = 18
	_roll_content.offset_right = -16
	var dice := Glyph.new()
	dice.kind = Glyph.Kind.DICE
	dice.color = Ui.LIME
	dice.line_width = 1.7
	dice.custom_minimum_size = Vector2(26, 26)
	dice.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_roll_content.add_child(dice)
	_roll_button_label = Ui.label("ROLL THE DICE", Ui.body(700), 15, Ui.CREAM)
	_roll_button_label.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_roll_content.add_child(_roll_button_label)
	var roll_spacer := Control.new()
	roll_spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_roll_content.add_child(roll_spacer)
	var keycap := PanelContainer.new()
	keycap.custom_minimum_size = Vector2(28, 24)
	keycap.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var cap_style := Ui.panel_style(Color(1, 1, 1, 0.10), 5, Color(1, 1, 1, 0.18), 1)
	cap_style.content_margin_left = 6
	cap_style.content_margin_right = 6
	cap_style.content_margin_top = 3
	cap_style.content_margin_bottom = 3
	keycap.add_theme_stylebox_override("panel", cap_style)
	var key := Ui.label("R", Ui.body(700), 9, Ui.CREAM)
	key.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	key.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	keycap.add_child(key)
	_roll_content.add_child(keycap)

	column.add_child(Ui.label("PRESS R ANYTIME  ·  LAUNCHES THROUGH STEAM", Ui.body(600), 8, Ui.MUTED_INK))
	return panel


func _make_tab(text_value: String) -> Button:
	var button := Button.new()
	button.text = text_value
	button.custom_minimum_size.y = 38
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button.focus_mode = Control.FOCUS_ALL
	return button


func _refresh_mode_tabs() -> void:
	var tabs := [[_mode_all, "all"], [_mode_genre, "genre"]]
	for entry in tabs:
		var button: Button = entry[0]
		var active: bool = _mode == entry[1]
		var fg := Ui.CREAM if active else Ui.MUTED_INK
		var bg := Ui.INK if active else Color.TRANSPARENT
		var hover := Ui.INK if active else Color(0, 0, 0, 0.05)
		Ui.button_style(button, bg, fg, 9, 8, Color.TRANSPARENT, 0, hover, Ui.CREAM if active else Ui.INK, 10, 7)
	_refresh_mode_badge()


func _refresh_mode_badge() -> void:
	# The compact MODE label doubles as a live readout.
	pass


func _set_mode(value: String) -> void:
	if _rolling or value == _mode:
		return
	_mode = value
	_genre_section.visible = _mode == "genre"
	_refresh_mode_tabs()
	_update_pool()


func _populate_genres() -> void:
	_genres = _snapshot.get("genres", [])
	var names: Array[String] = []
	_genre_counts.clear()
	for entry in _genres:
		names.append(String(entry.get("name", "")))
		_genre_counts[String(entry.get("name", ""))] = int(entry.get("count", 0))
	var signature := "|".join(names)
	if signature == _genre_signature and _genre_buttons.size() == names.size():
		# Metadata counts move while covers and genres stream in. Keep the
		# existing chips (and their focus) stable when the genre set is unchanged.
		for entry in _genres:
			var existing_name := String(entry.get("name", ""))
			if _genre_buttons.has(existing_name):
				_genre_buttons[existing_name].tooltip_text = "%d installed %s" % [int(entry.get("count", 0)), Ui.plural(int(entry.get("count", 0)), "game")]
		_genre_hint.text = "Only games tagged with this genre can be rolled." if not names.is_empty() else "Steam has no genre data for this library yet."
		_update_pool()
		return
	_genre_signature = signature
	for child in _genre_flow.get_children():
		_genre_flow.remove_child(child)
		child.queue_free()
	_genre_buttons.clear()
	if not names.has(_genre):
		_genre = names[0] if not names.is_empty() else ""
	for entry in _genres:
		var name := String(entry.get("name", ""))
		var button := Button.new()
		button.text = name.to_upper()
		button.tooltip_text = "%d installed %s" % [int(entry.get("count", 0)), Ui.plural(int(entry.get("count", 0)), "game")]
		button.focus_mode = Control.FOCUS_ALL
		button.pressed.connect(_select_genre.bind(name))
		_button_chip_style(button, name == _genre)
		_genre_buttons[name] = button
		_genre_flow.add_child(button)
	_genre_hint.text = "Only games tagged with this genre can be rolled." if not names.is_empty() else "Steam has no genre data for this library yet."
	if names.is_empty() and _mode == "genre":
		_pool_desc.text = "No genres are available to choose from yet."
	_update_pool()

func _button_chip_style(button: Button, active: bool) -> void:
	var bg := Ui.INK if active else Color.TRANSPARENT
	var fg := Ui.CREAM if active else Ui.MUTED_INK
	Ui.button_style(button, bg, fg, 8, 7, Ui.LINE_LIGHT, 1, Ui.INK_3 if active else Ui.LIME, Ui.CREAM if active else Ui.INK, 9, 5)
	button.add_theme_font_override("font", Ui.body(650))


func _select_genre(value: String) -> void:
	if _rolling:
		return
	_genre = value
	for name in _genre_buttons:
		_button_chip_style(_genre_buttons[name], name == _genre)
	_update_pool()


func _update_pool() -> void:
	if _snapshot.is_empty():
		return
	var games: Array = _snapshot.get("games", [])
	_pool_size = 0
	for game in games:
		if _mode == "all" or (_mode == "genre" and (game.get("genres", []) as Array).has(_genre)):
			_pool_size += 1
	_pool_count.text = str(_pool_size)
	_pool_unit.text = ("GAME" if _pool_size == 1 else "GAMES") + " IN THE POOL"
	if _mode == "all":
		_pool_desc.text = "Every installed game is fair game. The dice decide; you just press launch."
	elif _genre.is_empty():
		_pool_desc.text = "Choose a genre above to narrow the odds."
	elif _pool_size == 0:
		_pool_desc.text = "No installed games carry that tag. Try another genre."
	else:
		_pool_desc.text = "%d installed %s carry the %s tag. Nothing outside it can sneak in." % [_pool_size, Ui.plural(_pool_size, "game"), _genre]
	_refresh_roll_availability()


func _refresh_roll_availability() -> void:
	var can_roll := _library_ready and _pool_size > 0 and not _rolling
	_roll_button.disabled = not can_roll
	_roll_content.modulate = Color(1, 1, 1, 1) if can_roll else Color(1, 1, 1, 0.44)
	_refresh_button.disabled = false
	_browse_button.disabled = not _library_ready


# --- Stage -----------------------------------------------------------------


func _build_stage() -> PanelContainer:
	var panel := Ui.panel(Color("#10130f"), 20, Ui.LINE, 1)
	var style := panel.get_theme_stylebox("panel") as StyleBoxFlat
	style.content_margin_left = 24
	style.content_margin_right = 24
	style.content_margin_top = 22
	style.content_margin_bottom = 18
	var column := Ui.vbox(14)
	panel.add_child(column)

	var top := Ui.hbox(10)
	top.add_child(Ui.eyebrow("02 / THE DRAW", Ui.MUTED))
	var top_spacer := Control.new()
	top_spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(top_spacer)
	_stage_badge_dot = Ui.dot(Ui.LIME, 3.0)
	_stage_badge_dot.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	top.add_child(_stage_badge_dot)
	_stage_badge_label = Ui.label("READY", Ui.body(650), 8, Ui.MUTED)
	_stage_badge_label.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	top.add_child(_stage_badge_label)
	column.add_child(top)

	var body := Ui.hbox(28)
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.custom_minimum_size.y = 342
	column.add_child(body)
	_cover_stack = Control.new()
	_cover_stack.custom_minimum_size = REEL_SIZE
	_cover_stack.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	body.add_child(_cover_stack)

	_mystery_card = PanelContainer.new()
	_mystery_card.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var mystery_style := Ui.panel_style(Ui.LIME, 16)
	mystery_style.content_margin_left = 20
	mystery_style.content_margin_right = 20
	mystery_style.content_margin_top = 20
	mystery_style.content_margin_bottom = 20
	_mystery_card.add_theme_stylebox_override("panel", mystery_style)
	_cover_stack.add_child(_mystery_card)
	var mystery := Ui.vbox(4)
	mystery.alignment = BoxContainer.ALIGNMENT_CENTER
	_mystery_card.add_child(mystery)
	var mystery_top := Ui.label("ROLL TO REVEAL", Ui.body(700), 9, Ui.INK)
	mystery_top.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	mystery.add_child(mystery_top)
	var question := Ui.label("?", Ui.display(800), 126, Ui.INK)
	question.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	mystery.add_child(question)
	var die_row := Ui.hbox(0)
	die_row.alignment = BoxContainer.ALIGNMENT_CENTER
	var mystery_die := Glyph.new()
	mystery_die.kind = Glyph.Kind.D20
	mystery_die.color = Ui.INK
	mystery_die.custom_minimum_size = Vector2(20, 20)
	die_row.add_child(mystery_die)
	mystery.add_child(die_row)
	var mystery_bottom := Ui.label("YOUR NEXT GAME", Ui.body(700), 9, Ui.INK)
	mystery_bottom.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	mystery_bottom.size_flags_vertical = Control.SIZE_EXPAND_FILL
	mystery_bottom.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM
	mystery.add_child(mystery_bottom)

	_reel_window = Control.new()
	_reel_window.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_reel_window.clip_contents = true
	_reel_window.visible = false
	_cover_stack.add_child(_reel_window)
	_reel = Control.new()
	_reel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_reel_window.add_child(_reel)

	_winner_wrap = Control.new()
	_winner_wrap.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_winner_wrap.visible = false
	_winner_wrap.clip_contents = true
	_cover_stack.add_child(_winner_wrap)
	_winner_cover = CoverView.new()
	_winner_cover.radius = 16
	_winner_cover.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_winner_wrap.add_child(_winner_cover)

	var copy_host := Ui.vbox(0)
	copy_host.alignment = BoxContainer.ALIGNMENT_CENTER
	copy_host.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	copy_host.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.add_child(copy_host)

	_copy_idle = _build_idle_copy()
	_copy_rolling = _build_rolling_copy()
	_copy_result = _build_result_copy()
	copy_host.add_child(_copy_idle)
	copy_host.add_child(_copy_rolling)
	copy_host.add_child(_copy_result)
	_show_copy("idle")

	var footer := Ui.hbox(10)
	_stage_footer = Ui.label("SCANNING YOUR LIBRARY…", Ui.body(600), 8, Ui.MUTED_DARK)
	footer.add_child(_stage_footer)
	var footer_spacer := Control.new()
	footer_spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	footer.add_child(footer_spacer)
	footer.add_child(Ui.label("LOCAL ONLY  ·  NO ACCOUNT", Ui.body(600), 8, Ui.MUTED_DARK))
	column.add_child(Ui.hline(Ui.LINE, 1))
	column.add_child(footer)
	return panel


func _build_idle_copy() -> VBoxContainer:
	var state := Ui.vbox(12)
	state.alignment = BoxContainer.ALIGNMENT_CENTER
	state.add_child(Ui.eyebrow("YOUR EVENING, UNDECIDED", Ui.LIME))
	_idle_title = _wrap("The stage is set.", Ui.display(640), 35, Ui.CREAM, 360)
	state.add_child(_idle_title)
	_idle_body = _wrap("Pick a mode, set the odds, and let the dice pull one installed game out of the pile.", Ui.body(400), 13, Ui.MUTED, 360)
	state.add_child(_idle_body)
	_idle_note = Ui.label("83 GAMES  ·  10 GENRES  ·  2 LIBRARIES", Ui.body(600), 8, Ui.MUTED_DARK)
	state.add_child(_idle_note)
	return state


func _build_rolling_copy() -> VBoxContainer:
	var state := Ui.vbox(12)
	state.alignment = BoxContainer.ALIGNMENT_CENTER
	state.add_child(Ui.eyebrow("SHUFFLING THE LIBRARY", Ui.CORAL))
	var title := _wrap("Hold that thought.", Ui.display(640), 35, Ui.CREAM, 360)
	state.add_child(title)
	var body := _wrap("Every installed game is in the air. No algorithm, no backlog guilt — just the next thing you actually play.", Ui.body(400), 13, Ui.MUTED, 360)
	state.add_child(body)
	var status := Ui.label("THE DICE ARE WORKING…", Ui.body(600), 8, Ui.CORAL)
	state.add_child(status)
	state.visible = false
	return state


func _build_result_copy() -> VBoxContainer:
	var state := Ui.vbox(10)
	state.alignment = BoxContainer.ALIGNMENT_CENTER
	_result_genres = Ui.eyebrow("RESULT", Ui.LIME)
	state.add_child(_result_genres)
	_result_title = _wrap("", Ui.display(650), 34, Ui.CREAM, 0)
	_result_title.max_lines_visible = 2
	_result_title.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	_result_title.custom_minimum_size.y = 84
	state.add_child(_result_title)
	_result_desc = _wrap("", Ui.body(400), 12, Ui.MUTED, 0)
	_result_desc.max_lines_visible = 3
	_result_desc.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	_result_desc.custom_minimum_size.y = 60
	state.add_child(_result_desc)
	_result_meta = Ui.label("", Ui.body(600), 8, Ui.MUTED_DARK)
	_result_meta.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	state.add_child(_result_meta)
	var action_gap := Control.new()
	action_gap.custom_minimum_size.y = 3
	state.add_child(action_gap)
	_launch_button = Button.new()
	_launch_button.text = "LAUNCH ON STEAM"
	_launch_button.custom_minimum_size.y = 44
	Ui.button_style(_launch_button, Ui.LIME, Ui.INK, 11, 9, Color.TRANSPARENT, 0, Color("#e5ff87"), Ui.INK, 14, 11)
	_launch_button.pressed.connect(_launch_result)
	state.add_child(_launch_button)
	var secondary := Ui.hbox(8)
	_reroll_button = Button.new()
	_reroll_button.text = "ROLL AGAIN"
	_reroll_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_reroll_button.custom_minimum_size.y = 34
	Ui.button_style(_reroll_button, Color.TRANSPARENT, Ui.CREAM, 9, 8, Ui.LINE, 1, Color("#1b201a"), Ui.LIME, 10, 8)
	_reroll_button.pressed.connect(_start_roll)
	secondary.add_child(_reroll_button)
	_store_button = Button.new()
	_store_button.text = "STORE PAGE"
	_store_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_store_button.custom_minimum_size.y = 34
	Ui.button_style(_store_button, Color.TRANSPARENT, Ui.MUTED, 9, 8, Ui.LINE, 1, Color("#1b201a"), Ui.CREAM, 10, 8)
	_store_button.pressed.connect(_open_store_page)
	secondary.add_child(_store_button)
	state.add_child(secondary)
	state.visible = false
	return state


func _wrap(text_value: String, font: Font, font_size: int, color: Color, min_width: float) -> Label:
	var label := Ui.label(text_value, font, font_size, color)
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.custom_minimum_size.x = min_width
	label.add_theme_constant_override("line_spacing", 4)
	return label


func _show_copy(which: String) -> void:
	_copy_idle.visible = which == "idle"
	_copy_rolling.visible = which == "rolling"
	_copy_result.visible = which == "result"


func _set_stage_state(text_value: String, color: Color) -> void:
	_stage_badge_label.text = text_value
	_stage_badge_dot.add_theme_stylebox_override("panel", Ui.panel_style(color, 3))


# --- Rolls -----------------------------------------------------------------


func _start_roll() -> void:
	if _rolling or not _library_ready:
		return
	if _mode == "genre" and _genre.is_empty():
		_show_toast("Choose a genre first.", true)
		return
	var roll: Dictionary = SteamLibrary.make_roll(_mode, _genre, _last_winner)
	if not bool(roll.get("ok", false)):
		_show_toast(String(roll.get("error", "Nothing to roll yet.")), true)
		return
	_rolling = true
	_result = {}
	_refresh_roll_availability()
	_roll_button_label.text = "SHUFFLING…"
	_mystery_card.visible = false
	_winner_wrap.visible = false
	_reel_window.visible = true
	_show_copy("rolling")
	_set_stage_state("ROLLING", Ui.CORAL)
	_stage_footer.text = "CHOOSING FROM %d %s" % [int(roll.get("pool_size", 0)), Ui.plural(int(roll.get("pool_size", 0)), "GAME").to_upper()]
	_build_reel(roll)
	_start_badge_pulse()
	if _roll_tween != null and _roll_tween.is_valid():
		_roll_tween.kill()
	var winner: Dictionary = roll.get("winner", {})
	var reel_games: Array = roll.get("reel", []).duplicate()
	reel_games.append(winner)
	CoverCache.prefetch(reel_games)
	CoverCache.request_cover(winner)
	_roll_tween = create_tween()
	_roll_tween.set_trans(Tween.TRANS_QUART).set_ease(Tween.EASE_OUT)
	_roll_tween.tween_interval(0.16)
	var slots := maxi(1, (roll.get("reel", []) as Array).size() + 1)
	var pitch := REEL_SIZE.y + REEL_GAP
	var start_index := maxi(0, slots - 4)
	var end_index := slots - 1
	_reel.position.y = -start_index * pitch
	_roll_tween.tween_property(_reel, "position:y", -end_index * pitch, 2.7)
	_roll_tween.finished.connect(_finish_roll.bind(roll))


func _build_reel(roll: Dictionary) -> void:
	for child in _reel.get_children():
		_reel.remove_child(child)
		child.queue_free()
	var games: Array = roll.get("reel", [])
	var winner: Dictionary = roll.get("winner", {})
	games.append(winner)
	var pitch := REEL_SIZE.y + REEL_GAP
	_reel.custom_minimum_size = Vector2(REEL_SIZE.x, games.size() * pitch)
	_reel.size = _reel.custom_minimum_size
	for index in range(games.size()):
		var card := CoverView.new()
		card.position = Vector2(0, index * pitch)
		card.size = REEL_SIZE
		card.radius = 14
		_reel.add_child(card)
		card.set_game(games[index])
		card.mouse_filter = Control.MOUSE_FILTER_IGNORE


func _start_badge_pulse() -> void:
	if _pulse_tween != null and _pulse_tween.is_valid():
		_pulse_tween.kill()
	_stage_badge_dot.modulate.a = 1.0
	_pulse_tween = create_tween().set_loops()
	_pulse_tween.tween_property(_stage_badge_dot, "modulate:a", 0.28, 0.42)
	_pulse_tween.tween_property(_stage_badge_dot, "modulate:a", 1.0, 0.42)


func _finish_roll(roll: Dictionary) -> void:
	if _pulse_tween != null and _pulse_tween.is_valid():
		_pulse_tween.kill()
	_stage_badge_dot.modulate.a = 1.0
	_rolling = false
	_result = roll.get("winner", {})
	_last_winner = int(_result.get("app_id", 0))
	_reel_window.visible = false
	_mystery_card.visible = false
	_winner_wrap.visible = true
	_winner_cover.set_game(_result)
	_render_result(_result, int(roll.get("pool_size", 0)))
	_show_copy("result")
	_set_stage_state("RESULT / READY", Ui.LIME)
	_roll_button_label.text = "ROLL AGAIN"
	_refresh_roll_availability()
	_roll_button.grab_focus()
	call_deferred("_burst_confetti")


func _render_result(game: Dictionary, pool_size: int) -> void:
	var genres: Array = game.get("genres", [])
	var genre_text := "INSTALLED"
	if not genres.is_empty():
		genre_text = String(genres[0]).to_upper()
		if genres.size() > 1:
			genre_text += "  /  " + String(genres[1]).to_upper()
		if genres.size() > 2:
			genre_text += "  +%d" % (genres.size() - 2)
	_result_genres.text = genre_text
	_result_title.text = String(game.get("name", "Unknown game"))
	_result_desc.text = String(game.get("description", "")).strip_edges()
	if _result_desc.text.is_empty():
		_result_desc.text = "A game already sitting in your library. No pitch deck required."
	_result_meta.text = "%s  ·  %s  ·  %s" % [
		Ui.format_bytes(int(game.get("size_bytes", 0))),
		String(game.get("library_label", "STEAM")).to_upper(),
		Ui.format_last_played(int(game.get("last_played", 0))),
	]
	_launch_button.text = "LAUNCH ON STEAM"
	_store_button.disabled = String(game.get("store_url", "")).is_empty()
	_stage_footer.text = "ONE OF %d  ·  EVERY ROLL IS FAIR" % pool_size


func _burst_confetti() -> void:
	if _confetti == null:
		return
	var center: Vector2 = _cover_stack.get_global_rect().get_center() - _confetti.global_position
	_confetti.burst_at(center, 58)


func _launch_result() -> void:
	_launch_game(int(_result.get("app_id", 0)))


func _open_store_page() -> void:
	var url := String(_result.get("store_url", ""))
	if url.is_empty():
		return
	if OS.shell_open(url) != OK:
		_show_toast("The Steam store page could not be opened.", true)


func _launch_game(app_id: int) -> void:
	if app_id <= 0 or _launching:
		return
	if _drawer_open:
		_close_drawer()
	_set_launch_busy(true)
	SteamLibrary.launch(app_id)


func _set_launch_busy(busy: bool) -> void:
	_launching = busy
	if _launch_button == null:
		return
	_launch_button.disabled = busy
	_launch_button.text = "OPENING STEAM…" if busy else "LAUNCH ON STEAM"


# --- Library state ---------------------------------------------------------


func _on_scan_started() -> void:
	_library_ready = false
	_refresh_button.disabled = true
	_browse_button.disabled = true
	_error_banner.visible = false
	_set_status("READING STEAM…", Ui.MUTED)
	_set_stage_state("READING", Ui.CORAL)
	_stage_footer.text = "SCANNING YOUR LIBRARY…"
	if _rolling and _roll_tween != null and _roll_tween.is_valid():
		_roll_tween.kill()
	_rolling = false
	_result = {}
	_winner_wrap.visible = false
	_reel_window.visible = false
	_mystery_card.visible = true
	_show_copy("idle")
	_idle_title.text = "The stage is set."
	_idle_body.text = "Pick a mode, set the odds, and let the dice pull one installed game out of the pile."
	_idle_note.text = "READING YOUR STEAM LIBRARIES…"
	_roll_button_label.text = "ROLL THE DICE"
	_refresh_roll_availability()


func _on_scan_finished(snapshot: Dictionary) -> void:
	_library_ready = true
	_refresh_button.disabled = false
	_apply_snapshot(snapshot, true)


func _on_scan_failed(message: String) -> void:
	_library_ready = false
	_snapshot = {}
	_pool_size = 0
	_refresh_button.disabled = false
	_browse_button.disabled = true
	_error_banner.visible = true
	_error_text.text = message
	_set_status("LIBRARY UNAVAILABLE", Ui.CORAL)
	_set_stage_state("OFFLINE", Ui.CORAL)
	_stage_footer.text = "STEAM COULD NOT BE READ"
	_idle_title.text = "No library found."
	_idle_body.text = "RollPlay reads the games already installed by Steam. Make sure Steam is installed, then try again."
	_idle_note.text = "NO GAMES WERE HARMED"
	_hero_meta.text = "STEAM LIBRARY UNAVAILABLE"
	_roll_button_label.text = "ROLL THE DICE"
	_refresh_roll_availability()


func _apply_snapshot(snapshot: Dictionary, announce: bool) -> void:
	_snapshot = snapshot.duplicate(true)
	_genres = _snapshot.get("genres", [])
	var games: Array = _snapshot.get("games", [])
	if not _snapshot.is_empty():
		_genres = _snapshot.get("genres", [])
	_genre_counts.clear()
	_populate_genres()
	_update_pool()
	_update_library_facts()
	if announce:
		_set_status("%d GAMES  ·  %d GENRES" % [games.size(), _genres.size()], Ui.LIME)
		_set_stage_state("READY", Ui.LIME)
		_stage_footer.text = "%d GAMES READY  ·  %d LIBRARIES" % [games.size(), (_snapshot.get("libraries", []) as Array).size()]
		_idle_title.text = "The stage is set."
		_idle_body.text = "Pick a mode, set the odds, and let the dice pull one installed game out of the pile."
		_idle_note.text = "%d GAMES  ·  %d GENRES  ·  %d LIBRARIES" % [games.size(), _genres.size(), (_snapshot.get("libraries", []) as Array).size()]
		if games.is_empty():
			_library_ready = false
			_idle_title.text = "Your shelf is empty."
			_idle_body.text = "Steam is installed, but RollPlay could not find any fully installed games."
			_refresh_roll_availability()
		else:
			_roll_button.grab_focus()
	if _drawer_open:
		_populate_shelf_filters()
		_refresh_shelf()


func _update_library_facts() -> void:
	var games: Array = _snapshot.get("games", [])
	var stats: Dictionary = _snapshot.get("stats", {})
	var library_count := int(stats.get("libraries", (_snapshot.get("libraries", []) as Array).size()))
	_hero_meta.text = "%d GAMES ACROSS %d %s  ·  READ LOCALLY" % [games.size(), library_count, Ui.plural(library_count, "LIBRARY", "LIBRARIES")]
	_hero_note.text = "%d installed games across %d %s. Pick a mood, roll the dice, and skip the forty-minute scroll." % [games.size(), library_count, Ui.plural(library_count, "Steam library", "Steam libraries")]
	_stat_values["games"].text = str(int(stats.get("games", games.size()))) if not stats.is_empty() else "—"
	_stat_values["genres"].text = str(int(stats.get("genres", _genres.size()))) if not stats.is_empty() else "—"
	_stat_values["size"].text = Ui.format_bytes(int(stats.get("installed_bytes", 0)))
	_stat_values["libraries"].text = str(library_count)
	_browse_button.disabled = not _library_ready or games.is_empty()


func _on_snapshot_changed(snapshot: Dictionary) -> void:
	_snapshot = snapshot
	_genres = _snapshot.get("genres", [])
	_populate_genres()
	_update_pool()
	_update_library_facts()
	var live_games: Array = _snapshot.get("games", [])
	if _copy_idle.visible and not live_games.is_empty():
		_idle_note.text = "%d GAMES  ·  %d GENRES  ·  %d LIBRARIES" % [live_games.size(), _genres.size(), (_snapshot.get("libraries", []) as Array).size()]
	if _library_ready:
		_set_status("%d GAMES  ·  %d GENRES" % [(_snapshot.get("games", []) as Array).size(), _genres.size()], Ui.LIME)
	if _drawer_open:
		_refresh_shelf()


func _on_metadata_progress(completed: int, total: int) -> void:
	if total > 0 and _refresh_button != null:
		_refresh_button.tooltip_text = "Steam art metadata: %d of %d games" % [completed, total]


func _on_enrichment_finished() -> void:
	if _refresh_button != null:
		_refresh_button.tooltip_text = "Library art is up to date."


func _on_game_launched(_app_id: int, game_name: String) -> void:
	_show_toast("Launching %s through Steam…" % game_name)
	await get_tree().create_timer(2.2).timeout
	_set_launch_busy(false)


func _on_launch_failed(message: String) -> void:
	_set_launch_busy(false)
	_show_toast(message, true)


func _set_status(text_value: String, color: Color) -> void:
	_status_label.text = text_value.to_upper()
	_status_dot.add_theme_stylebox_override("panel", Ui.panel_style(color, 3.2))


func _on_refresh_pressed() -> void:
	if _rolling:
		return
	SteamLibrary.refresh()
	_show_toast("Rescanning your Steam libraries…")


func _on_page_resized() -> void:
	if _page_margin == null:
		return
	var narrow := size.x < 1300
	var pad := PAGE_NARROW if narrow else PAGE_WIDE
	if size.x > 1760:
		pad += int((size.x - 1760) * 0.5)
	_page_margin.add_theme_constant_override("margin_left", pad)
	_page_margin.add_theme_constant_override("margin_right", pad)


# --- Stats and footer ------------------------------------------------------


func _build_stats() -> Control:
	var wrap := Ui.vbox(0)
	wrap.add_child(Ui.hline(Ui.LINE, 1))
	var row := Ui.hbox(0)
	row.custom_minimum_size.y = 68
	wrap.add_child(row)
	var specs := [
		["games", "GAMES INSTALLED"],
		["genres", "GENRES IN PLAY"],
		["size", "ON DISK"],
		["libraries", "STEAM LIBRARIES"],
	]
	for index in range(specs.size()):
		if index > 0:
			var divider := Ui.vline(Ui.LINE, 1)
			divider.size_flags_vertical = Control.SIZE_EXPAND_FILL
			row.add_child(divider)
		var cell := Ui.hbox(12)
		cell.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		cell.custom_minimum_size.y = 66
		var value := Ui.label("—", Ui.display(650), 27, Ui.CREAM)
		value.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		cell.add_child(value)
		var caption := Ui.label(specs[index][1], Ui.body(600), 8, Ui.MUTED_DARK)
		caption.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		cell.add_child(caption)
		row.add_child(cell)
		_stat_values[specs[index][0]] = value
	wrap.add_child(Ui.hline(Ui.LINE, 1))
	return wrap


func _build_footer() -> Control:
	var row := Ui.hbox(16)
	row.custom_minimum_size.y = 34
	var version := str(ProjectSettings.get_setting("application/config/version", "0.1.0"))
	row.add_child(Ui.label("ROLLPLAY  /  YOUR LIBRARY, ONE ROLL.  /  V%s" % version, Ui.body(600), 8, Ui.MUTED_DARK))
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(spacer)
	row.add_child(Ui.label("NOT AFFILIATED WITH VALVE  ·  STEAM IS A TRADEMARK OF VALVE CORP.", Ui.body(500), 8, Ui.MUTED_DARK))
	return row


# --- Shelf drawer ----------------------------------------------------------


func _build_drawer() -> void:
	_drawer_overlay = Control.new()
	_drawer_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_drawer_overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	_drawer_overlay.visible = false
	add_child(_drawer_overlay)

	_drawer_backdrop = ColorRect.new()
	_drawer_backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_drawer_backdrop.color = Color(0.02, 0.025, 0.02, 0.0)
	_drawer_backdrop.gui_input.connect(_on_drawer_backdrop_input)
	_drawer_overlay.add_child(_drawer_backdrop)

	_drawer_panel = Ui.panel(Ui.CREAM, 0, Ui.LINE_LIGHT, 0)
	var panel_style := _drawer_panel.get_theme_stylebox("panel") as StyleBoxFlat
	panel_style.border_width_left = 1
	panel_style.content_margin_left = 26
	panel_style.content_margin_right = 26
	panel_style.content_margin_top = 24
	panel_style.content_margin_bottom = 20
	_drawer_panel.set_anchors_and_offsets_preset(Control.PRESET_RIGHT_WIDE)
	_drawer_panel.offset_left = -DRAWER_WIDTH
	_drawer_panel.offset_right = 0
	_drawer_panel.offset_top = 0
	_drawer_panel.offset_bottom = 0
	_drawer_overlay.add_child(_drawer_panel)

	var column := Ui.vbox(12)
	_drawer_panel.add_child(column)
	var header := Ui.hbox(12)
	var heading := Ui.vbox(2)
	heading.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	heading.add_child(Ui.eyebrow("THE WHOLE SHELF", Ui.MUTED_INK))
	heading.add_child(Ui.label("Your library.", Ui.display(700), 28, Ui.INK))
	heading.add_child(Ui.label("Every installed game. Click a cover to launch it.", Ui.body(400), 11, Ui.MUTED_INK))
	header.add_child(heading)
	var close := Button.new()
	close.text = "CLOSE"
	close.custom_minimum_size = Vector2(66, 34)
	Ui.button_style(close, Color.TRANSPARENT, Ui.MUTED_INK, 8, 8, Ui.LINE_LIGHT, 1, Ui.CREAM_2, Ui.INK, 8, 8)
	close.pressed.connect(_close_drawer)
	header.add_child(close)
	column.add_child(header)

	_search_field = LineEdit.new()
	_search_field.placeholder_text = "Search your library…"
	_search_field.clear_button_enabled = true
	_search_field.custom_minimum_size.y = 42
	var search_style := Ui.panel_style(Ui.CREAM_2, 9, Ui.LINE_LIGHT, 1)
	search_style.content_margin_left = 14
	search_style.content_margin_right = 14
	var search_focus := Ui.panel_style(Ui.CREAM_2, 9, Ui.LIME_DARK, 2)
	search_focus.content_margin_left = 14
	search_focus.content_margin_right = 14
	_search_field.add_theme_stylebox_override("normal", search_style)
	_search_field.add_theme_stylebox_override("focus", search_focus)
	_search_field.add_theme_font_override("font", Ui.body(400))
	_search_field.add_theme_font_size_override("font_size", 12)
	_search_field.add_theme_color_override("font_color", Ui.INK)
	_search_field.add_theme_color_override("font_placeholder_color", Ui.MUTED_INK)
	_search_field.add_theme_color_override("caret_color", Ui.INK)
	_search_field.add_theme_color_override("clear_button_color", Ui.MUTED_INK)
	_search_field.add_theme_color_override("clear_button_color_pressed", Ui.INK)
	_search_field.text_changed.connect(_on_shelf_search)
	column.add_child(_search_field)

	var filters := Ui.hbox(8)
	_genre_filter = OptionButton.new()
	_genre_filter.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_style_filter(_genre_filter)
	_genre_filter.item_selected.connect(_on_shelf_genre)
	filters.add_child(_genre_filter)
	_sort_filter = OptionButton.new()
	_sort_filter.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_style_filter(_sort_filter)
	_sort_filter.add_item("NAME A–Z")
	_sort_filter.add_item("RECENTLY PLAYED")
	_sort_filter.add_item("LARGEST FIRST")
	_sort_filter.item_selected.connect(_on_shelf_sort)
	filters.add_child(_sort_filter)
	column.add_child(filters)

	_shelf_summary = Ui.label("YOUR SHELF", Ui.body(600), 8, Ui.MUTED_INK)
	column.add_child(_shelf_summary)

	var shelf_scroll := ScrollContainer.new()
	shelf_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	shelf_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	column.add_child(shelf_scroll)
	_style_scroll_bar(shelf_scroll.get_v_scroll_bar())
	_library_grid = GridContainer.new()
	_library_grid.columns = 3
	_library_grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_library_grid.add_theme_constant_override("h_separation", 10)
	_library_grid.add_theme_constant_override("v_separation", 10)
	shelf_scroll.add_child(_library_grid)
	_shelf_empty = Ui.label("No games match this filter.", Ui.body(400), 12, Ui.MUTED_INK)
	_shelf_empty.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_shelf_empty.visible = false
	column.add_child(_shelf_empty)


func _style_filter(button: OptionButton) -> void:
	button.custom_minimum_size.y = 34
	Ui.button_style(button, Ui.CREAM_2, Ui.INK, 9, 8, Ui.LINE_LIGHT, 1, Ui.CREAM_3, Ui.INK, 10, 8)
	var popup := button.get_popup()
	popup.add_theme_stylebox_override("panel", Ui.panel_style(Ui.CREAM, 8, Ui.LINE_LIGHT, 1))
	popup.add_theme_stylebox_override("hover", Ui.panel_style(Ui.LIME, 4))
	popup.add_theme_color_override("font_color", Ui.INK)
	popup.add_theme_color_override("font_hover_color", Ui.INK)
	popup.add_theme_font_override("font", Ui.body(500))
	popup.add_theme_font_size_override("font_size", 11)


func _open_drawer() -> void:
	var games: Array = _snapshot.get("games", [])
	if games.is_empty():
		_show_toast("No installed games to browse yet.", true)
		return
	_drawer_open = true
	_drawer_overlay.visible = true
	_populate_shelf_filters()
	_refresh_shelf()
	_drawer_backdrop.color.a = 0.0
	_drawer_panel.offset_left = 0
	_drawer_panel.offset_right = DRAWER_WIDTH
	if _drawer_tween != null and _drawer_tween.is_valid():
		_drawer_tween.kill()
	_drawer_tween = create_tween().set_parallel(true)
	_drawer_tween.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	_drawer_tween.tween_property(_drawer_backdrop, "color:a", 0.64, 0.24)
	_drawer_tween.tween_property(_drawer_panel, "offset_left", -DRAWER_WIDTH, 0.32)
	_drawer_tween.tween_property(_drawer_panel, "offset_right", 0, 0.32)
	call_deferred("_focus_search")


func _focus_search() -> void:
	if _drawer_open and is_instance_valid(_search_field):
		_search_field.grab_focus()


func _close_drawer() -> void:
	if not _drawer_open:
		return
	_drawer_open = false
	if _drawer_tween != null and _drawer_tween.is_valid():
		_drawer_tween.kill()
	_drawer_tween = create_tween().set_parallel(true)
	_drawer_tween.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	_drawer_tween.tween_property(_drawer_backdrop, "color:a", 0.0, 0.2)
	_drawer_tween.tween_property(_drawer_panel, "offset_left", 0.0, 0.24)
	_drawer_tween.tween_property(_drawer_panel, "offset_right", DRAWER_WIDTH, 0.24)
	_drawer_tween.chain().tween_callback(_hide_drawer)
	_browse_button.grab_focus()


func _hide_drawer() -> void:
	if not _drawer_open:
		_drawer_overlay.visible = false


func _on_drawer_backdrop_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		_close_drawer()


func _populate_shelf_filters() -> void:
	_suppress_filters = true
	var selected_genre := _shelf_genre
	_genre_filter.clear()
	_genre_filter.add_item("ALL GENRES")
	_genre_filter.set_item_metadata(0, "all")
	for entry in _genres:
		var name := String(entry.get("name", ""))
		_genre_filter.add_item("%s  (%d)" % [name.to_upper(), int(entry.get("count", 0))])
		_genre_filter.set_item_metadata(_genre_filter.item_count - 1, name)
	_genre_filter.selected = 0
	for index in range(_genre_filter.item_count):
		if String(_genre_filter.get_item_metadata(index)) == selected_genre:
			_genre_filter.selected = index
			break
	_suppress_filters = false


func _refresh_shelf() -> void:
	if _suppress_filters or _library_grid == null:
		return
	for child in _library_grid.get_children():
		_library_grid.remove_child(child)
		child.queue_free()
	var query := _search_field.text.strip_edges().to_lower()
	var games: Array = (_snapshot.get("games", []) as Array).duplicate()
	var filtered: Array = []
	for game in games:
		if _shelf_genre != "all" and not (game.get("genres", []) as Array).has(_shelf_genre):
			continue
		if not query.is_empty() and not String(game.get("name", "")).to_lower().contains(query):
			continue
		filtered.append(game)
	match _shelf_sort:
		1:
			filtered.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return int(a.get("last_played", 0)) > int(b.get("last_played", 0)))
		2:
			filtered.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return int(a.get("size_bytes", 0)) > int(b.get("size_bytes", 0)))
		_:
			filtered.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return String(a.get("name", "")).naturalnocasecmp_to(String(b.get("name", ""))) < 0)
	for game in filtered:
		var card := ShelfCard.new()
		card.setup(game)
		card.launch_requested.connect(_launch_game)
		_library_grid.add_child(card)
	_shelf_summary.text = "%d OF %d GAMES" % [filtered.size(), games.size()]
	_shelf_empty.visible = filtered.is_empty()
	_shelf_summary.visible = true


func _on_shelf_search(_value: String) -> void:
	_refresh_shelf()


func _on_shelf_genre(index: int) -> void:
	if _suppress_filters:
		return
	_shelf_genre = String(_genre_filter.get_item_metadata(index))
	_refresh_shelf()


func _on_shelf_sort(index: int) -> void:
	if _suppress_filters:
		return
	_shelf_sort = index
	_refresh_shelf()


# --- Toast and input -------------------------------------------------------


func _build_toast() -> void:
	_toast = PanelContainer.new()
	_toast.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var style := Ui.panel_style(Ui.INK_3, 10, Ui.LINE, 1)
	style.content_margin_left = 16
	style.content_margin_right = 16
	style.content_margin_top = 10
	style.content_margin_bottom = 10
	_toast.add_theme_stylebox_override("panel", style)
	_toast.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
	_toast.offset_left = -230
	_toast.offset_right = 230
	_toast.offset_top = -76
	_toast.offset_bottom = -28
	_toast.visible = false
	add_child(_toast)
	_toast_text = Ui.label("", Ui.body(500), 11, Ui.CREAM)
	_toast_text.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_toast_text.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_toast_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_toast.add_child(_toast_text)


func _show_toast(message: String, error: bool = false) -> void:
	if _toast == null:
		return
	_toast_text.text = message
	var style := _toast.get_theme_stylebox("panel") as StyleBoxFlat
	style.border_color = Ui.CORAL if error else Ui.LINE
	_toast.visible = true
	_toast.modulate.a = 1.0
	if _toast_tween != null and _toast_tween.is_valid():
		_toast_tween.kill()
	_toast_tween = create_tween()
	_toast_tween.tween_interval(2.6)
	_toast_tween.tween_property(_toast, "modulate:a", 0.0, 0.35)
	_toast_tween.tween_callback(func() -> void: _toast.visible = false)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("close_overlay") and _drawer_open:
		get_viewport().set_input_as_handled()
		_close_drawer()
	elif event.is_action_pressed("roll") and not _drawer_open:
		get_viewport().set_input_as_handled()
		_start_roll()
