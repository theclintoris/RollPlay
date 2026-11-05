extends Control
## Quiet, editorial backdrop: charcoal paper, soft coloured blooms and a faint grid.

var _speckles: Array[Vector3] = []


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_build_speckles()
	resized.connect(queue_redraw)


func _build_speckles() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 913742
	for index in range(46):
		_speckles.append(Vector3(rng.randf(), rng.randf(), rng.randf_range(0.4, 1.4)))


func _draw() -> void:
	var bounds := Rect2(Vector2.ZERO, size)
	draw_rect(bounds, Ui.INK, true)
	_bloom(Vector2(size.x * 0.12, -80.0), 660.0, Ui.LIME, 0.045)
	_bloom(Vector2(size.x * 0.92, size.y * 0.72), 560.0, Ui.CORAL, 0.026)
	_bloom(Vector2(size.x * 0.55, size.y * 0.15), 520.0, Ui.SKY, 0.018)

	for x in range(0, int(size.x) + 120, 96):
		draw_line(Vector2(x, 0), Vector2(x, size.y), Color(1, 1, 1, 0.026), 1.0)
	for y in range(0, int(size.y) + 120, 96):
		draw_line(Vector2(0, y), Vector2(size.x, y), Color(1, 1, 1, 0.023), 1.0)

	# Oversized drafting circles anchor the page without shouting.
	draw_arc(Vector2(size.x * 0.88, -30), 260, 0, TAU, 96, Color(1, 1, 1, 0.035), 1.0, true)
	draw_arc(Vector2(size.x * 0.9, -30), 320, 0, TAU, 96, Color(1, 1, 1, 0.024), 1.0, true)
	draw_arc(Vector2(-60, size.y * 0.8), 210, 0, TAU, 96, Color(1, 1, 1, 0.028), 1.0, true)

	for point in _speckles:
		var pos := Vector2(point.x * size.x, point.y * size.y)
		draw_circle(pos, point.z, Color(1, 1, 1, 0.055))
		if int(point.x * 1000) % 7 == 0:
			draw_line(pos - Vector2(3, 0), pos + Vector2(3, 0), Color(1, 1, 1, 0.075), 1.0)
			draw_line(pos - Vector2(0, 3), pos + Vector2(0, 3), Color(1, 1, 1, 0.075), 1.0)


func _bloom(center: Vector2, radius: float, color: Color, strength: float) -> void:
	for index in range(7):
		var ratio := 1.0 - float(index) / 7.0
		var shade := Color(color.r, color.g, color.b, strength * (0.35 + float(index) * 0.12))
		draw_circle(center, radius * ratio, shade)
