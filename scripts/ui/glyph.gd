class_name Glyph
extends Control
## Tiny custom-drawn marks. The bundled fonts deliberately contain no icon glyphs,
## so every star, die and arrow is part of RollPlay's own visual language.

enum Kind {
	STAR,
	D20,
	DICE,
	ARROW,
	SEARCH,
	CLOSE,
	REFRESH,
	CHEVRON,
	PLUS,
	SPARK,
}

@export var kind: Kind = Kind.STAR:
	set(value):
		kind = value
		queue_redraw()
@export var color: Color = Ui.CREAM:
	set(value):
		color = value
		queue_redraw()
@export var line_width: float = 1.8:
	set(value):
		line_width = value
		queue_redraw()
@export var filled: bool = false:
	set(value):
		filled = value
		queue_redraw()


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	custom_minimum_size = Vector2(20, 20)
	resized.connect(queue_redraw)


func _draw() -> void:
	var box := Rect2(Vector2.ZERO, size)
	var center := box.get_center()
	var radius := minf(size.x, size.y) * 0.5
	match kind:
		Kind.STAR:
			_star(center, radius * 0.96, radius * 0.4, 8, color)
		Kind.D20:
			_d20(center, radius * 0.98, color)
		Kind.SPARK:
			_star(center, radius * 0.98, radius * 0.2, 4, color)
		Kind.DICE:
			var side := radius * 1.55
			var rect := Rect2(center - Vector2(side, side) * 0.5, Vector2(side, side))
			draw_rect(rect, color, false, line_width, true)
			draw_circle(rect.position + rect.size * Vector2(0.28, 0.28), maxf(0.8, side * 0.075), color)
			draw_circle(rect.position + rect.size * Vector2(0.72, 0.28), maxf(0.8, side * 0.075), color)
			draw_circle(rect.position + rect.size * Vector2(0.5, 0.5), maxf(0.8, side * 0.075), color)
			draw_circle(rect.position + rect.size * Vector2(0.28, 0.72), maxf(0.8, side * 0.075), color)
			draw_circle(rect.position + rect.size * Vector2(0.72, 0.72), maxf(0.8, side * 0.075), color)
		Kind.ARROW:
			var y := center.y
			draw_line(Vector2(box.position.x + 2, y), Vector2(box.end.x - 4, y), color, line_width, true)
			draw_line(Vector2(box.end.x - 10, y - 6), Vector2(box.end.x - 4, y), color, line_width, true)
			draw_line(Vector2(box.end.x - 10, y + 6), Vector2(box.end.x - 4, y), color, line_width, true)
		Kind.SEARCH:
			var search_r := radius * 0.58
			draw_arc(center - Vector2(search_r * 0.2, search_r * 0.2), search_r, 0, TAU, 32, color, line_width, true)
			draw_line(center + Vector2(search_r * 0.55, search_r * 0.55), center + Vector2(search_r * 1.15, search_r * 1.15), color, line_width, true)
		Kind.CLOSE:
			var arm := radius * 0.55
			draw_line(center - Vector2(arm, arm), center + Vector2(arm, arm), color, line_width, true)
			draw_line(center + Vector2(arm, -arm), center + Vector2(-arm, arm), color, line_width, true)
		Kind.REFRESH:
			var refresh_r := radius * 0.62
			draw_arc(center, refresh_r, deg_to_rad(-70), deg_to_rad(210), 30, color, line_width, true)
			var tip := center + Vector2(cos(deg_to_rad(210)), sin(deg_to_rad(210))) * refresh_r
			draw_line(tip, tip + Vector2(6, -4), color, line_width, true)
			draw_line(tip, tip + Vector2(-1, -7), color, line_width, true)
		Kind.CHEVRON:
			var chevron_w := radius * 0.45
			var chevron_h := radius * 0.26
			draw_polyline(PackedVector2Array([
				center + Vector2(-chevron_w, -chevron_h),
				center + Vector2(0, chevron_h),
				center + Vector2(chevron_w, -chevron_h),
			]), color, line_width, true)
		Kind.PLUS:
			var arm2 := radius * 0.6
			draw_line(center - Vector2(arm2, 0), center + Vector2(arm2, 0), color, line_width, true)
			draw_line(center - Vector2(0, arm2), center + Vector2(0, arm2), color, line_width, true)


func _d20(center: Vector2, radius: float, shade: Color) -> void:
	var outer := PackedVector2Array()
	for angle_deg in [-90.0, -30.0, 30.0, 90.0, 150.0, 210.0]:
		var angle := deg_to_rad(angle_deg)
		outer.append(center + Vector2(cos(angle), sin(angle)) * radius)
	outer.append(outer[0])
	draw_polyline(outer, shade, line_width, true)

	var tri_center := center - Vector2(0, radius * 0.05)
	var tri := PackedVector2Array()
	for angle_deg in [90.0, 210.0, 330.0]:
		var angle := deg_to_rad(angle_deg)
		tri.append(tri_center + Vector2(cos(angle), sin(angle)) * radius * 0.61)
	tri.append(tri[0])
	draw_polyline(tri, shade, line_width * 0.86, true)
	draw_line(tri[0], outer[3], shade, line_width * 0.86, true)
	draw_line(tri[1], outer[5], shade, line_width * 0.86, true)
	draw_line(tri[2], outer[1], shade, line_width * 0.86, true)


func _star(center: Vector2, outer: float, inner: float, points: int, shade: Color) -> void:
	var vertices := PackedVector2Array()
	for index in range(points * 2):
		var angle := -PI * 0.5 + float(index) * PI / float(points)
		var length := outer if index % 2 == 0 else inner
		vertices.append(center + Vector2(cos(angle), sin(angle)) * length)
	if filled:
		draw_colored_polygon(vertices, shade)
	else:
		vertices.append(vertices[0])
		draw_polyline(vertices, shade, line_width, true)
