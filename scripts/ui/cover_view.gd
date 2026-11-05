class_name CoverView
extends Control
## A 2:3 cover with a designed, deterministic placeholder until Steam art arrives.

const PALETTES := [
	{"bg": Color("#20291c"), "accent": Color("#d8ff4e")},
	{"bg": Color("#2d1e1b"), "accent": Color("#ff8f74")},
	{"bg": Color("#1b252b"), "accent": Color("#9bc3ff")},
	{"bg": Color("#28222e"), "accent": Color("#f2ead7")},
	{"bg": Color("#2b2619"), "accent": Color("#ffd37a")},
]

@export var radius: int = 16:
	set(value):
		radius = value
		_bg_style = null
		queue_redraw()

var game: Dictionary = {}
var texture: Texture2D = null
var highlight: Color = Color.TRANSPARENT:
	set(value):
		highlight = value
		queue_redraw()

var _bg_style: StyleBoxFlat = null
var _app_id := 0


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	resized.connect(queue_redraw)
	if not CoverCache.cover_ready.is_connected(_on_cover_ready):
		CoverCache.cover_ready.connect(_on_cover_ready)
	_refresh()


func set_game(value: Dictionary) -> void:
	game = value
	_app_id = int(game.get("app_id", 0))
	_refresh()
	if is_inside_tree() and _app_id > 0 and texture == null:
		CoverCache.request_cover(game)
	queue_redraw()


func _refresh() -> void:
	_app_id = int(game.get("app_id", 0))
	texture = CoverCache.get_texture(_app_id) if _app_id > 0 else null
	queue_redraw()


func _on_cover_ready(app_id: int, loaded: Texture2D) -> void:
	if app_id == _app_id:
		texture = loaded
		queue_redraw()


func _draw() -> void:
	if size.x <= 0 or size.y <= 0:
		return
	var rect := Rect2(Vector2.ZERO, size)
	var palette: Dictionary = PALETTES[absi(_app_id) % PALETTES.size()]
	var accent: Color = palette["accent"]
	var style := _get_bg_style()
	draw_style_box(style, rect)

	if texture != null:
		draw_texture_rect(texture, rect, false)
		# A hairline keeps bright artwork from melting into the stage.
		draw_rect(rect, Color(1, 1, 1, 0.10), false, 1.0)
	else:
		_draw_placeholder(rect, palette)

	if highlight.a > 0.0:
		draw_rect(rect, highlight, false, 2.0, true)


func _get_bg_style() -> StyleBoxFlat:
	if _bg_style == null:
		_bg_style = Ui.panel_style(Color("#1a1e18"), radius)
	return _bg_style


func _draw_placeholder(rect: Rect2, palette: Dictionary) -> void:
	var bg: Color = palette["bg"]
	var accent: Color = palette["accent"]
	var inner := rect.grow(-1)
	draw_rect(inner, bg, true)
	var app_id := _app_id
	var seed_value := absi(app_id) * 7919

	# Layered geometry gives every missing cover its own little poster.
	draw_circle(Vector2(size.x * 0.86, size.y * 0.17), size.x * 0.42, Color(accent.r, accent.g, accent.b, 0.10))
	draw_circle(Vector2(size.x * 0.12, size.y * 0.79), size.x * 0.48, Color(0, 0, 0, 0.16))
	for index in range(3):
		var offset := float(index) * 13.0
		var point := Vector2(-size.x * 0.2, size.y * 0.58 + offset)
		draw_line(point, point + Vector2(size.x * 1.4, -size.x * 0.58), Color(1, 1, 1, 0.045), 1.0)
	draw_arc(Vector2(size.x * 0.98, size.y * 0.42), size.x * 0.52, PI * 0.62, PI * 1.52, 40, Color(accent.r, accent.g, accent.b, 0.38), 1.4, true)
	draw_arc(Vector2(size.x * 0.98, size.y * 0.42), size.x * 0.64, PI * 0.62, PI * 1.52, 40, Color(1, 1, 1, 0.08), 1.0, true)

	var initials := _initials(String(game.get("name", "?")))
	var big_font := Ui.display(760)
	var big_size := int(clampf(size.x * 0.42, 34.0, 76.0))
	var baseline := size.y * 0.48 + big_font.get_ascent(big_size) * 0.5
	draw_string(big_font, Vector2(size.x * 0.08, baseline), initials, HORIZONTAL_ALIGNMENT_LEFT, -1, big_size, Color(accent.r, accent.g, accent.b, 0.30))

	var top_label := "STEAM / %04d" % (app_id % 10000)
	draw_string(Ui.body(600), Vector2(size.x * 0.08, size.x * 0.14), top_label, HORIZONTAL_ALIGNMENT_LEFT, -1, 8, Color(1, 1, 1, 0.45))

	var genre_text := "INSTALLED"
	var genres: Array = game.get("genres", [])
	if not genres.is_empty():
		genre_text = String(genres[0]).to_upper()
	draw_string(Ui.body(600), Vector2(size.x * 0.08, size.y - size.x * 0.11), Ui.trim_text(genre_text, 18), HORIZONTAL_ALIGNMENT_LEFT, size.x * 0.8, 8, Color(1, 1, 1, 0.58))

	var name_text := Ui.trim_text(String(game.get("name", "Unknown game")), 28)
	var name_font := Ui.display(650)
	draw_multiline_string(
		name_font,
		Vector2(size.x * 0.08, size.y - size.x * 0.22),
		name_text,
		HORIZONTAL_ALIGNMENT_LEFT,
		size.x * 0.84,
		int(clampf(size.x * 0.082, 11.0, 17.0)),
		2,
		Color(1, 1, 1, 0.84)
	)

	# A small registration mark for the print-inspired feel.
	var mark := Vector2(size.x - 17, size.y - 17)
	if seed_value % 2 == 0:
		draw_line(mark - Vector2(5, 0), mark + Vector2(5, 0), Color(1, 1, 1, 0.22), 1.0)
		draw_line(mark - Vector2(0, 5), mark + Vector2(0, 5), Color(1, 1, 1, 0.22), 1.0)
	else:
		draw_arc(mark, 4.5, 0, TAU, 16, Color(1, 1, 1, 0.22), 1.0, true)


func _initials(value: String) -> String:
	var words := value.replace(":", " ").replace("-", " ").split(" ", false)
	var result := ""
	for word in words:
		if result.length() >= 2:
			break
		var cleaned := String(word).strip_edges()
		if cleaned.is_empty():
			continue
		result += cleaned.left(1).to_upper()
	if result.is_empty():
		return "?"
	return result
