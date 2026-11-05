extends Node
## Owns the scanned library, enriches it from Steam's public store API, and
## launches games through the steam:// protocol.
##
## The app never asks for a Steam login. Everything is read from the local
## steamapps manifests and a private, disposable metadata cache.

signal scan_started
signal scan_finished(snapshot: Dictionary)
signal scan_failed(message: String)
signal snapshot_changed(snapshot: Dictionary)
signal metadata_progress(completed: int, total: int)
signal enrichment_finished
signal game_launched(app_id: int, game_name: String)
signal launch_failed(message: String)

const CACHE_VERSION := 1
const MAX_CONCURRENT_REQUESTS := 3
const REQUEST_SPACING_MS := 80
const REQUEST_TIMEOUT := 20.0
const MAX_ATTEMPTS := 1
const SAVE_EVERY := 6
const NON_GENRE_LABELS := ["early access", "free to play"]

var _scanner := SteamScanner.new()
var _scan_result: Dictionary = {}
var _all_games: Array = []
var _games: Array = []
var _cache: Dictionary = {}
var _cache_path := ""
var _queue: Array = []
var _attempts: Dictionary = {}
var _failed_ids: Dictionary = {}
var _active_requests := 0
var _last_request_ms := 0
var _cooldown_until_ms := 0
var _metadata_total := 0
var _metadata_done := 0
var _metadata_since_emit := 0
var _saves_since_write := 0
var _cache_dirty := false
var _scanning := false
var _enriching := false
var _generation := 0
var _cache_days := 30
var _last_launch_app_id := 0
var _snapshot: Dictionary = {}


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	set_process(false)
	_cache_days = maxi(1, int(ProjectSettings.get_setting("rollplay/metadata/cache_days", 30)))
	_cache_path = AppPaths.path("metadata_cache.json")
	_load_cache()
	call_deferred("refresh")


func refresh() -> void:
	if _scanning:
		return
	_scanning = true
	_generation += 1
	_queue.clear()
	_attempts.clear()
	_failed_ids.clear()
	_metadata_total = 0
	_metadata_done = 0
	_metadata_since_emit = 0
	_enriching = false
	scan_started.emit()
	await get_tree().process_frame

	var result := _scanner.scan()
	if not bool(result.get("ok", false)):
		_scanning = false
		_scan_result = result
		_all_games = []
		_games = []
		_emit_snapshot(false)
		scan_failed.emit(String(result.get("error", "Steam could not be read.")))
		return

	_scan_result = result
	_all_games = result.get("games", [])
	for game in _all_games:
		_decorate_game(game)
	_rebuild_visible_games()
	_queue_missing_metadata()
	_scanning = false
	scan_finished.emit(snapshot())
	_start_enrichment()


## Public snapshot is a deep copy; the UI is free to keep or mutate it.
func snapshot() -> Dictionary:
	var games_copy: Array = _games.duplicate(true)
	var libraries: Array = _scan_result.get("libraries", []).duplicate(true)
	return {
		"ok": not _scan_result.is_empty() and bool(_scan_result.get("ok", false)),
		"error": String(_scan_result.get("error", "")),
		"steam_root": String(_scan_result.get("steam_root", "")),
		"libraries": libraries,
		"games": games_copy,
		"genres": _genre_counts(),
		"stats": _stats(),
		"metadata": {
			"ready": _known_metadata_count(),
			"total": _games.size(),
			"done": _metadata_done,
			"queued": _queue.size(),
			"active": _active_requests,
			"running": _enriching,
		},
		"scanned_at": int(_scan_result.get("scanned_at", 0)),
		"warnings": PackedStringArray(_scan_result.get("warnings", [])),
		"data_root": AppPaths.data_root(),
		"own_app_id": int(ProjectSettings.get_setting("rollplay/steam/app_id", 0)),
		"last_launch_app_id": _last_launch_app_id,
	}


func find_game(app_id: int) -> Dictionary:
	for game in _games:
		if int(game.get("app_id", 0)) == app_id:
			return game
	return {}


## Picks a game with the pure rules in PickEngine. Kept here so the UI does not
## need to know which games are currently visible.
func make_roll(mode: String, genre: String, avoid_app_id: int = 0) -> Dictionary:
	return PickEngine.make_roll(_games, mode, genre, avoid_app_id)


func launch(app_id: int) -> bool:
	var game := find_game(app_id)
	if game.is_empty():
		var missing := "That game is no longer in the installed library."
		launch_failed.emit(missing)
		return false
	var own_app_id := int(ProjectSettings.get_setting("rollplay/steam/app_id", 0))
	if own_app_id > 0 and app_id == own_app_id:
		launch_failed.emit("You are already inside RollPlay. Pick another game.")
		return false
	var error := OS.shell_open("steam://rungameid/%d" % app_id)
	if error != OK:
		launch_failed.emit("Steam could not be opened. Is the Steam client installed?")
		return false
	_last_launch_app_id = app_id
	game_launched.emit(app_id, String(game.get("name", "That game")))
	return true


func retry_metadata() -> void:
	if _enriching or _scanning:
		return
	_failed_ids.clear()
	_queue_missing_metadata()
	_start_enrichment()


# --- Scan and cache fusion -------------------------------------------------

func _decorate_game(game: Dictionary) -> void:
	var app_id := int(game.get("app_id", 0))
	var raw: Dictionary = _cache.get(str(app_id), {})
	var entry := _normalize_entry(raw)
	if entry.is_empty():
		game["metadata"] = "missing"
	else:
		_apply_entry(game, entry)
		game["metadata"] = "stale" if _entry_is_stale(entry) else "ready"
	game["cover_url"] = "https://cdn.akamai.steamstatic.com/steam/apps/%d/library_600x900.jpg" % app_id
	if String(game.get("header_url", "")).is_empty():
		game["header_url"] = "https://cdn.akamai.steamstatic.com/steam/apps/%d/header.jpg" % app_id
	game["store_url"] = "https://store.steampowered.com/app/%d/" % app_id


func _apply_entry(game: Dictionary, entry: Dictionary) -> void:
	game["type"] = String(entry.get("type", "unknown"))
	game["genres"] = (entry.get("genres", []) as Array).duplicate()
	game["description"] = String(entry.get("short_description", ""))
	game["header_image"] = String(entry.get("header_image", ""))
	game["header_url"] = String(entry.get("header_image", ""))
	game["store_name"] = String(entry.get("name", ""))
	game["is_free"] = bool(entry.get("is_free", false))


func _rebuild_visible_games() -> void:
	var visible: Array = []
	for game in _all_games:
		var game_type := String(game.get("type", "unknown"))
		if game_type == "game" or game_type == "unknown":
			visible.append(game)
	# The scanner already sorts, but keep this stable after cached filters.
	visible.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return String(a.get("name", "")).naturalnocasecmp_to(String(b.get("name", ""))) < 0
	)
	_games = visible


func _queue_missing_metadata() -> void:
	_queue.clear()
	_metadata_done = 0
	var fresh_or_known := 0
	for game in _all_games:
		var app_id := int(game.get("app_id", 0))
		var entry := _normalize_entry(_cache.get(str(app_id), {}))
		if entry.is_empty():
			if not _failed_ids.has(app_id):
				_queue.append(app_id)
			continue
		var game_type := String(entry.get("type", "unknown"))
		var needs_refresh := _entry_is_stale(entry) or game_type == "unknown"
		if game_type != "game" and game_type != "unknown":
			continue
		if needs_refresh and not _failed_ids.has(app_id):
			_queue.append(app_id)
		else:
			fresh_or_known += 1
	# Progress describes the whole visible library, including already-cached
	# games. That keeps the first-run counter from starting at an odd zero.
	_metadata_total = _queue.size() + fresh_or_known
	_metadata_done = fresh_or_known
	metadata_progress.emit(_metadata_done, _metadata_total)


func _decorate_from_cache(app_id: int) -> void:
	var entry := _normalize_entry(_cache.get(str(app_id), {}))
	if entry.is_empty():
		return
	for game in _all_games:
		if int(game.get("app_id", 0)) == app_id:
			_apply_entry(game, entry)
			game["metadata"] = "stale" if _entry_is_stale(entry) else "ready"
			break
	_rebuild_visible_games()


func _entry_for(app_id: int) -> Dictionary:
	return _normalize_entry(_cache.get(str(app_id), {}))


func _normalize_entry(raw: Variant) -> Dictionary:
	if not raw is Dictionary or raw.is_empty():
		return {}
	var raw_genres: Variant = raw.get("genres", [])
	var genres: Array = []
	var seen: Dictionary = {}
	if raw_genres is Array:
		for item in raw_genres:
			var label := ""
			if item is Dictionary:
				label = String(item.get("description", ""))
			else:
				label = String(item)
			label = label.strip_edges()
			if label.is_empty() or NON_GENRE_LABELS.has(label.to_lower()):
				continue
			var key := label.to_lower()
			if seen.has(key):
				continue
			seen[key] = true
			genres.append(label)
	var fetched_at := int(raw.get("fetched_at", raw.get("fetchedAt", 0)))
	if fetched_at > 10000000000:
		fetched_at = int(fetched_at / 1000)
	return {
		"name": String(raw.get("name", "")),
		"type": String(raw.get("type", "unknown")),
		"genres": genres,
		"header_image": String(raw.get("header_image", raw.get("headerImage", ""))),
		"short_description": String(raw.get("short_description", raw.get("shortDescription", ""))),
		"is_free": bool(raw.get("is_free", raw.get("isFree", false))),
		"fetched_at": fetched_at,
	}


func _entry_is_stale(entry: Dictionary) -> bool:
	var fetched_at := int(entry.get("fetched_at", 0))
	if fetched_at <= 0:
		return true
	return int(Time.get_unix_time_from_system()) - fetched_at > _cache_days * 86400


func _genre_counts() -> Array:
	var counts: Dictionary = {}
	for game in _games:
		for genre in game.get("genres", []):
			var label := String(genre)
			if label.is_empty():
				continue
			counts[label] = int(counts.get(label, 0)) + 1
	var list: Array = []
	for label in counts.keys():
		list.append({"name": label, "count": int(counts[label])})
	list.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		if int(a["count"]) != int(b["count"]):
			return int(a["count"]) > int(b["count"])
		return String(a["name"]).naturalnocasecmp_to(String(b["name"])) < 0
	)
	return list


func _stats() -> Dictionary:
	var installed := 0
	for game in _games:
		installed += int(game.get("size_bytes", 0))
	return {
		"games": _games.size(),
		"genres": _genre_counts().size(),
		"installed_bytes": installed,
		"libraries": (_scan_result.get("libraries", []) as Array).size(),
	}


func _known_metadata_count() -> int:
	var known := 0
	for game in _games:
		if String(game.get("metadata", "")) == "ready":
			known += 1
	return known


func _emit_snapshot(changed: bool) -> void:
	_snapshot = snapshot()
	if changed:
		snapshot_changed.emit(_snapshot)


# --- Metadata downloads ----------------------------------------------------

func _start_enrichment() -> void:
	if _scanning:
		return
	if _queue.is_empty():
		_enriching = false
		metadata_progress.emit(_metadata_done, _metadata_total)
		enrichment_finished.emit()
		_emit_snapshot(true)
		return
	_enriching = true
	set_process(true)


func _process(_delta: float) -> void:
	if not _enriching:
		return
	var now := Time.get_ticks_msec()
	if _active_requests >= MAX_CONCURRENT_REQUESTS:
		return
	if now < _cooldown_until_ms:
		return
	if now - _last_request_ms < REQUEST_SPACING_MS:
		return
	if _queue.is_empty():
		_check_enrichment_finished()
		return
	var app_id := int(_queue.pop_front())
	_last_request_ms = now
	_start_request(app_id)


func _start_request(app_id: int) -> void:
	var http := HTTPRequest.new()
	http.timeout = REQUEST_TIMEOUT
	http.use_threads = true
	http.max_redirects = 3
	add_child(http)
	_active_requests += 1
	var generation := _generation
	http.request_completed.connect(_on_metadata_response.bind(app_id, generation, http))
	var url := "https://store.steampowered.com/api/appdetails?appids=%d&filters=basic,genres&l=en" % app_id
	var error := http.request(url, [
		"User-Agent: RollPlay/0.1 (Steam library companion)",
		"Accept: application/json",
	], HTTPClient.METHOD_GET)
	if error != OK:
		_active_requests = maxi(0, _active_requests - 1)
		http.queue_free()
		_handle_metadata_failure(app_id, generation, 0)


func _on_metadata_response(
	result: int,
	response_code: int,
	_headers: PackedStringArray,
	body: PackedByteArray,
	app_id: int,
	generation: int,
	http: HTTPRequest
) -> void:
	if is_instance_valid(http):
		http.queue_free()
	_active_requests = maxi(0, _active_requests - 1)
	if generation != _generation:
		return
	if result != HTTPRequest.RESULT_SUCCESS or response_code != 200:
		if response_code == 429:
			_cooldown_until_ms = Time.get_ticks_msec() + 4000
		_handle_metadata_failure(app_id, generation, response_code)
		return
	var entry := _parse_metadata(app_id, body)
	if entry.is_empty():
		_handle_metadata_failure(app_id, generation, response_code)
		return
	_cache[str(app_id)] = entry
	_cache_dirty = true
	_saves_since_write += 1
	_attempts.erase(app_id)
	_metadata_done += 1
	_metadata_since_emit += 1
	_decorate_from_cache(app_id)
	metadata_progress.emit(_metadata_done, _metadata_total)
	if _saves_since_write >= SAVE_EVERY:
		_save_cache()
	if _metadata_since_emit >= 3 or _metadata_done >= _metadata_total:
		_metadata_since_emit = 0
		_emit_snapshot(true)
	if _queue.is_empty() and _active_requests == 0:
		_check_enrichment_finished()
	else:
		set_process(true)


func _parse_metadata(app_id: int, body: PackedByteArray) -> Dictionary:
	var parsed: Variant = JSON.parse_string(body.get_string_from_utf8())
	if not parsed is Dictionary:
		return {}
	var root: Variant = (parsed as Dictionary).get(str(app_id), {})
	if not root is Dictionary or not bool((root as Dictionary).get("success", false)):
		return {}
	var data: Variant = (root as Dictionary).get("data", {})
	if not data is Dictionary:
		return {}
	var data_dict: Dictionary = data
	var genres: Array = []
	if data_dict.get("genres", []) is Array:
		for item in data_dict.get("genres", []):
			if not item is Dictionary:
				continue
			var label := String(item.get("description", "")).strip_edges()
			if label.is_empty() or NON_GENRE_LABELS.has(label.to_lower()):
				continue
			genres.append(label)
	return {
		"name": String(data_dict.get("name", "")),
		"type": String(data_dict.get("type", "unknown")),
		"genres": genres,
		"header_image": String(data_dict.get("header_image", "")),
		"short_description": String(data_dict.get("short_description", data_dict.get("detailed_description", ""))),
		"is_free": bool(data_dict.get("is_free", false)),
		"fetched_at": int(Time.get_unix_time_from_system()),
	}


func _handle_metadata_failure(app_id: int, generation: int, response_code: int) -> void:
	if generation != _generation:
		return
	var attempt := int(_attempts.get(app_id, 0))
	if attempt < MAX_ATTEMPTS:
		_attempts[app_id] = attempt + 1
		_queue.push_back(app_id)
		set_process(true)
		return
	_attempts.erase(app_id)
	_failed_ids[app_id] = true
	_metadata_done += 1
	for game in _all_games:
		if int(game.get("app_id", 0)) == app_id:
			var old_entry := _entry_for(app_id)
			if old_entry.is_empty():
				game["metadata"] = "unavailable"
			else:
				game["metadata"] = "stale"
			break
	metadata_progress.emit(_metadata_done, _metadata_total)
	if _queue.is_empty() and _active_requests == 0:
		_check_enrichment_finished()
	else:
		_metadata_since_emit += 1
		if _metadata_since_emit >= 3:
			_metadata_since_emit = 0
			_emit_snapshot(true)
	if response_code == 0:
		push_warning("Steam metadata request failed for app %d" % app_id)


func _check_enrichment_finished() -> void:
	if _active_requests > 0 or not _queue.is_empty():
		set_process(true)
		return
	_enriching = false
	set_process(false)
	_save_cache()
	metadata_progress.emit(_metadata_done, _metadata_total)
	enrichment_finished.emit()
	_emit_snapshot(true)


# --- Disk cache ------------------------------------------------------------

func _load_cache() -> void:
	_cache.clear()
	if not FileAccess.file_exists(_cache_path):
		return
	var file := FileAccess.open(_cache_path, FileAccess.READ)
	if file == null:
		push_warning("Could not read metadata cache at %s" % _cache_path)
		return
	var text := file.get_as_text()
	file.close()
	var parsed: Variant = JSON.parse_string(text)
	if not parsed is Dictionary:
		push_warning("Metadata cache is not valid JSON; it will be rebuilt.")
		return
	var entries: Variant = (parsed as Dictionary).get("entries", {})
	if entries is Dictionary:
		_cache = entries
		# Normalize once so stale web-cache-style entries also work in dev.
		for key in _cache.keys():
			var entry := _normalize_entry(_cache[key])
			if entry.is_empty():
				_cache.erase(key)
			else:
				_cache[key] = entry


func _save_cache() -> void:
	if not _cache_dirty:
		return
	_cache_dirty = false
	_saves_since_write = 0
	var payload := {
		"version": CACHE_VERSION,
		"saved_at": int(Time.get_unix_time_from_system()),
		"entries": _cache,
	}
	var temp_path := _cache_path + ".tmp"
	var file := FileAccess.open(temp_path, FileAccess.WRITE)
	if file == null:
		push_warning("Could not write metadata cache to %s" % temp_path)
		_cache_dirty = true
		return
	file.store_string(JSON.stringify(payload, "\t"))
	file.close()
	if FileAccess.file_exists(_cache_path):
		DirAccess.remove_absolute(_cache_path)
	var rename_error := DirAccess.rename_absolute(temp_path, _cache_path)
	if rename_error != OK:
		push_warning("Could not replace metadata cache (error %d)." % rename_error)
		_cache_dirty = true
