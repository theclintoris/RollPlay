class_name ConfettiField
extends Control
## A short, hand-cut confetti burst. No dependencies, no sprites.

var _pieces: Array[Dictionary] = []
var _active := false
var _age := 0.0
var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_rng.randomize()
	set_process(false)


func burst(origin_ratio: Vector2 = Vector2(0.5, 0.42), count: int = 52) -> void:
	burst_at(size * origin_ratio, count)


func burst_at(origin: Vector2, count: int = 52) -> void:
	_pieces.clear()
	_age = 0.0
	_active = true
	for index in range(count):
		var angle := _rng.randf_range(-PI * 0.92, -PI * 0.08)
		var speed := _rng.randf_range(180.0, 560.0)
		var velocity := Vector2(cos(angle), sin(angle)) * speed
		var palette := [Ui.LIME, Ui.CREAM, Ui.CORAL, Ui.SKY, Color("#ffd37a")]
		_pieces.append({
			"pos": origin + Vector2(_rng.randf_range(-28.0, 28.0), _rng.randf_range(-8.0, 8.0)),
			"vel": velocity,
			"gravity": _rng.randf_range(360.0, 620.0),
			"drag": _rng.randf_range(0.90, 0.985),
			"rot": _rng.randf_range(0.0, TAU),
			"spin": _rng.randf_range(-9.0, 9.0),
			"w": _rng.randf_range(4.0, 9.0),
			"h": _rng.randf_range(2.0, 5.0),
			"life": _rng.randf_range(1.15, 2.05),
			"age": 0.0,
			"color": palette[_rng.randi_range(0, palette.size() - 1)],
			"wobble": _rng.randf_range(-3.2, 3.2),
			"phase": _rng.randf_range(0.0, TAU),
		})
	set_process(true)
	queue_redraw()


func _process(delta: float) -> void:
	if not _active:
		return
	_age += delta
	var alive := 0
	for piece in _pieces:
		piece["age"] += delta
		if piece["age"] >= piece["life"]:
			continue
		var velocity: Vector2 = piece["vel"]
		velocity.y += piece["gravity"] * delta
		velocity.x *= pow(piece["drag"], delta * 60.0)
		piece["vel"] = velocity
		piece["pos"] += velocity * delta
		piece["rot"] += piece["spin"] * delta
		alive += 1
	if alive == 0:
		_active = false
		set_process(false)
		_pieces.clear()
	queue_redraw()


func _draw() -> void:
	for piece in _pieces:
		var progress: float = piece["age"] / piece["life"]
		if progress >= 1.0:
			continue
		var color: Color = piece["color"]
		color.a = 1.0 - pow(progress, 3.0)
		draw_set_transform(piece["pos"], piece["rot"], Vector2(1.0, absf(cos(piece["phase"] + _age * piece["wobble"]))))
		draw_rect(Rect2(-piece["w"] * 0.5, -piece["h"] * 0.5, piece["w"], piece["h"]), color, true)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
