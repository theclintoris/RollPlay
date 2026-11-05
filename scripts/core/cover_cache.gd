extends Node
## Downloads 2:3 Steam cover art into a local cache and keeps textures in memory.
## Artwork is optional: the UI draws its own designed placeholders while it loads.

signal cover_ready(app_id: int, texture: Texture2D)
signal cover_failed(app_id: int)
signal progress_changed(loaded: int, requested: int)

const COVER_SIZE := Vector2i(360, 540)
const MAX_ACTIVE := 4
const REQUEST_SPACING_MS := 70
const MAX_ATTEMPTS := 2

var _textures: Dictionary = {}
var _queue: Array[Dictionary] = []
var _queued: Dictionary = {}
var _active: Dictionary = {}
var _attempts: Dictionary = {}
var _last_start_ms := 0
var _requested_total := 0
var _loaded_total := 0
var _cache_dir := ""
var _running := false


func _ready() -> void:
	_cache_dir = AppPaths.covers_dir()
	set_process(true)


func get_texture(app_id: int) -> Texture2D:
	if _textures.has(app_id):
		return _textures[app_id]
	var path := _cover_path(app_id)
	if not FileAccess.file_exists(path):
		return null
	var image := Image.load_from_file(path)
	if image == null or image.is_empty():
		DirAccess.remove_absolute(path)
		return null
	var texture := ImageTexture.create_from_image(image)
	_textures[app_id] = texture
	return texture


func has_cover(app_id: int) -> bool:
	return _textures.has(app_id) or FileAccess.file_exists(_cover_path(app_id))


## Add a game cover to the download queue. Safe to call repeatedly.
func request_cover(game: Dictionary) -> Texture2D:
	var app_id := int(game.get("app_id", 0))
	if app_id <= 0:
		return null
	var existing := get_texture(app_id)
	if existing != null:
		return existing
	if _queued.has(app_id) or _active.has(app_id):
		return null
	var cover_url := String(game.get("cover_url", ""))
	var header_url := String(game.get("header_url", ""))
	if header_url.is_empty():
		header_url = "https://cdn.akamai.steamstatic.com/steam/apps/%d/header.jpg" % app_id
	if cover_url.is_empty():
		cover_url = header_url
	_queue.append({
		"app_id": app_id,
		"url": cover_url,
		"fallback_url": header_url,
	})
	_queued[app_id] = true
	_requested_total += 1
	_running = true
	_emit_progress()
	return null


func prefetch(games: Array) -> void:
	for game in games:
		if game is Dictionary:
			request_cover(game)


func progress() -> Dictionary:
	return {
		"loaded": _loaded_total,
		"requested": _requested_total,
		"queued": _queue.size(),
		"active": _active.size(),
	}


func _process(_delta: float) -> void:
	if not _running:
		return
	var now := Time.get_ticks_msec()
	if _active.size() < MAX_ACTIVE and now - _last_start_ms >= REQUEST_SPACING_MS:
		_start_next()
	if _queue.is_empty() and _active.is_empty():
		_running = false


func _start_next() -> void:
	if _queue.is_empty():
		return
	var item: Dictionary = _queue.pop_front()
	var app_id := int(item.get("app_id", 0))
	_queued.erase(app_id)
	if _textures.has(app_id):
		_loaded_total += 1
		_emit_progress()
		return

	var http := HTTPRequest.new()
	http.timeout = 25.0
	http.use_threads = true
	http.max_redirects = 3
	add_child(http)
	_active[app_id] = http
	http.request_completed.connect(_on_request_completed.bind(app_id, http, item))
	var url := String(item.get("url", ""))
	var error := http.request(url, [
		"User-Agent: RollPlay/0.1 (Steam library companion)",
		"Accept: image/avif,image/webp,image/jpeg,image/png,*/*",
	], HTTPClient.METHOD_GET)
	_last_start_ms = Time.get_ticks_msec()
	if error != OK:
		_active.erase(app_id)
		http.queue_free()
		_handle_failure(app_id, item)


func _on_request_completed(
	result: int,
	response_code: int,
	_headers: PackedStringArray,
	body: PackedByteArray,
	app_id: int,
	http: HTTPRequest,
	item: Dictionary
) -> void:
	if is_instance_valid(http):
		http.queue_free()
	_active.erase(app_id)
	if result != HTTPRequest.RESULT_SUCCESS or response_code != 200 or body.is_empty():
		_handle_failure(app_id, item)
		return

	var image := Image.new()
	var load_error := image.load_jpg_from_buffer(body)
	if load_error != OK:
		load_error = image.load_png_from_buffer(body)
	if load_error != OK:
		load_error = image.load_webp_from_buffer(body)
	if load_error != OK or image.is_empty():
		_handle_failure(app_id, item)
		return

	_crop_to_poster(image)
	var texture := ImageTexture.create_from_image(image)
	_textures[app_id] = texture
	var path := _cover_path(app_id)
	if image.save_jpg(path, 0.9) != OK:
		push_warning("Could not save cover art to %s" % path)
	_loaded_total += 1
	_attempts.erase(app_id)
	_emit_progress()
	cover_ready.emit(app_id, texture)


func _handle_failure(app_id: int, item: Dictionary) -> void:
	var attempts := int(_attempts.get(app_id, 0))
	_attempts[app_id] = attempts + 1
	# The wide header image is a useful fallback when a library capsule is missing.
	if attempts == 0 and not String(item.get("fallback_url", "")).is_empty():
		var fallback := String(item.get("fallback_url", ""))
		if fallback != String(item.get("url", "")):
			_queue.push_front({
				"app_id": app_id,
				"url": fallback,
				"fallback_url": "",
			})
			_queued[app_id] = true
			return
	if attempts < MAX_ATTEMPTS:
		_queue.push_back(item)
		_queued[app_id] = true
		return
	_queued.erase(app_id)
	_loaded_total += 1
	_emit_progress()
	cover_failed.emit(app_id)


func _emit_progress() -> void:
	progress_changed.emit(_loaded_total, _requested_total)


func _cover_path(app_id: int) -> String:
	return _cache_dir.path_join("%d.jpg" % app_id)


func _crop_to_poster(image: Image) -> void:
	var width := image.get_width()
	var height := image.get_height()
	if width <= 0 or height <= 0:
		return
	var target_ratio := 2.0 / 3.0
	var current_ratio := float(width) / float(height)
	if current_ratio > target_ratio:
		var crop_width := int(round(height * target_ratio))
		var x := maxi(0, (width - crop_width) / 2)
		var source := Image.new()
		source.copy_from(image)
		image.blit_rect(source, Rect2i(x, 0, crop_width, height), Vector2i.ZERO)
	else:
		var crop_height := int(round(width / target_ratio))
		var y := maxi(0, (height - crop_height) / 2)
		var source := Image.new()
		source.copy_from(image)
		image.blit_rect(source, Rect2i(0, y, width, crop_height), Vector2i.ZERO)
	image.resize(COVER_SIZE.x, COVER_SIZE.y, Image.INTERPOLATE_LANCZOS)
