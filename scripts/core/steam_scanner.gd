class_name SteamScanner
extends RefCounted
## Finds the local Steam installation, every library folder, and installed games
## by reading Valve's public steamapps metadata. No account sign-in is involved.

const FULLY_INSTALLED_BIT := 4

const NON_GAME_APP_IDS := {
	228980: true,   # Steamworks Common Redistributables
	250820: true,   # SteamVR
	404790: true,   # Godot Engine
	1070560: true,  # Steam Linux Runtime 1.0 (scout)
	1391110: true,  # Steam Linux Runtime 2.0 (soldier)
	1493710: true,  # Proton Experimental
	1628350: true,  # Steam Linux Runtime 3.0 (sniper)
	2180100: true,  # Proton Hotfix
}

const NAME_EXCLUDES := [
	"steamworks common redistributables",
	"steam linux runtime",
	"steamvr",
	"steam audio",
	"steam link",
	"steam play",
	"steamworks sdk",
	"steam client",
	"steam console",
	"proton experimental",
	"proton hotfix",
	"dedicated server",
	"godot engine",
	"wallpaper engine",
	"soundtrack",
	"sound track",
	"artbook",
	"art book",
	"season pass",
	"expansion pass",
	"bonus content",
]

var last_error := ""
var last_warnings: PackedStringArray = []


func scan() -> Dictionary:
	last_error = ""
	last_warnings = []

	var roots := find_steam_roots()
	if roots.is_empty():
		last_error = "Steam was not found on this computer."
		return _failure(last_error)

	var libraries := collect_libraries(roots)
	if libraries.is_empty():
		last_error = "Steam is installed, but no game libraries could be read."
		return _failure(last_error)

	var games: Array[Dictionary] = []
	for library in libraries:
		var apps_path: String = library.get("path", "").path_join("steamapps")
		var files := DirAccess.get_files_at(apps_path)
		if files.is_empty():
			last_warnings.append("Could not list %s" % apps_path)
			continue

		for file_name in files:
			if not file_name.begins_with("appmanifest_") or not file_name.ends_with(".acf"):
				continue
			var game := _read_manifest(apps_path.path_join(file_name), library.get("path", ""))
			if game.is_empty():
				continue
			games.append(game)

	games.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return String(a.get("name", "")).naturalnocasecmp_to(String(b.get("name", ""))) < 0
	)

	for library in libraries:
		var library_games := 0
		var library_size := 0
		for game in games:
			if game.get("library_path", "") == library.get("path", ""):
				library_games += 1
				library_size += int(game.get("size_bytes", 0))
		library["game_count"] = library_games
		library["installed_size_bytes"] = library_size

	var result := {
		"ok": true,
		"error": "",
		"steam_root": roots[0],
		"libraries": libraries,
		"games": games,
		"scanned_at": int(Time.get_unix_time_from_system()),
		"warnings": last_warnings,
	}
	return result


func find_steam_roots() -> Array[String]:
	var candidates: Array[String] = []
	for variable in ["STEAM_PATH", "STEAM_COMPAT_CLIENT_INSTALL_PATH"]:
		var from_env := OS.get_environment(variable).strip_edges()
		if not from_env.is_empty():
			candidates.append(from_env)

	match OS.get_name():
		"Windows":
			candidates.append_array(_windows_registry_paths())
			var program_files_x86 := OS.get_environment("ProgramFiles(x86)").strip_edges()
			var program_files := OS.get_environment("ProgramFiles").strip_edges()
			if not program_files_x86.is_empty():
				candidates.append(program_files_x86.path_join("Steam"))
			if not program_files.is_empty():
				candidates.append(program_files.path_join("Steam"))
			candidates.append("C:/Program Files (x86)/Steam")
			candidates.append("C:/Program Files/Steam")
			candidates.append("D:/Steam")
		"macOS":
			var home := OS.get_environment("HOME").strip_edges()
			if not home.is_empty():
				candidates.append(home.path_join("Library/Application Support/Steam"))
		"Linux", "FreeBSD", "NetBSD", "OpenBSD", "BSD":
			var home := OS.get_environment("HOME").strip_edges()
			if home.is_empty():
				home = "~"
			candidates.append(home.path_join(".steam/steam"))
			candidates.append(home.path_join(".steam/root"))
			candidates.append(home.path_join(".local/share/Steam"))
			candidates.append(home.path_join(".var/app/com.valvesoftware.Steam/data/Steam"))
			candidates.append(home.path_join(".var/app/com.valvesoftware.Steam/.local/share/Steam"))
			candidates.append(home.path_join("snap/steam/common/.local/share/Steam"))

	var roots: Array[String] = []
	var seen: Dictionary = {}
	for candidate in candidates:
		var cleaned := normalize_path(candidate)
		if cleaned.is_empty() or seen.has(_path_key(cleaned)):
			continue
		if _is_steam_library(cleaned):
			seen[_path_key(cleaned)] = true
			roots.append(cleaned)
	return roots


func collect_libraries(roots: Array[String]) -> Array[Dictionary]:
	var libraries: Array[Dictionary] = []
	var seen: Dictionary = {}
	for root in roots:
		_add_library(root, root, libraries, seen)
		var library_file := root.path_join("steamapps/libraryfolders.vdf")
		var parsed := VdfParser.parse_file(library_file)
		if parsed.is_empty():
			continue
		var block: Dictionary = parsed.get("libraryfolders", {})
		if not block is Dictionary:
			continue
		for key in block.keys():
			var entry = block[key]
			var library_path := ""
			if entry is Dictionary:
				library_path = String(entry.get("path", ""))
			elif entry is String and String(key).is_valid_int():
				library_path = entry
			library_path = normalize_path(library_path)
			if library_path.is_empty():
				continue
			_add_library(library_path, root, libraries, seen)
	return libraries


func _add_library(path_value: String, steam_root: String, libraries: Array[Dictionary], seen: Dictionary) -> void:
	var cleaned := normalize_path(path_value)
	if cleaned.is_empty() or seen.has(_path_key(cleaned)):
		return
	if not DirAccess.dir_exists_absolute(cleaned.path_join("steamapps")):
		return
	seen[_path_key(cleaned)] = true
	libraries.append({
		"path": cleaned,
		"label": library_label(cleaned),
		"steam_root": steam_root,
		"game_count": 0,
		"installed_size_bytes": 0,
	})


func _read_manifest(manifest_path: String, library_path: String) -> Dictionary:
	var parsed := VdfParser.parse_file(manifest_path)
	var app: Dictionary = parsed.get("AppState", {})
	if app.is_empty():
		return {}

	var app_id := int(String(app.get("appid", "0")))
	var name := String(app.get("name", "")).strip_edges()
	if app_id <= 0 or name.is_empty():
		return {}
	var own_app_id := int(ProjectSettings.get_setting("rollplay/steam/app_id", 0))
	if own_app_id > 0 and app_id == own_app_id:
		return {}
	if NON_GAME_APP_IDS.has(app_id) or not looks_like_game(name):
		return {}

	var state_flags := int(String(app.get("StateFlags", "0")))
	if (state_flags & FULLY_INSTALLED_BIT) == 0:
		return {}

	return {
		"app_id": app_id,
		"name": name,
		"installed_dir": String(app.get("installdir", "")),
		"size_bytes": int(String(app.get("SizeOnDisk", "0"))),
		"last_played": int(String(app.get("LastPlayed", "0"))),
		"last_updated": int(String(app.get("lastupdated", "0"))),
		"build_id": String(app.get("buildid", "")),
		"library_path": library_path,
		"library_label": library_label(library_path),
		"state_flags": state_flags,
		"genres": [],
		"type": "unknown",
		"description": "",
		"header_image": "",
		"metadata": "pending",
	}


func _windows_registry_paths() -> Array[String]:
	var found: Array[String] = []
	var queries := [
		["HKCU\\Software\\Valve\\Steam", "SteamPath"],
		["HKLM\\SOFTWARE\\WOW6432Node\\Valve\\Steam", "InstallPath"],
		["HKLM\\SOFTWARE\\Valve\\Steam", "InstallPath"],
	]
	for query in queries:
		var output: Array = []
		var code := OS.execute(
			"reg.exe",
			PackedStringArray(["query", query[0], "/v", query[1]]),
			output,
			true,
			false
		)
		if code != 0:
			continue
		for chunk in output:
			for line in String(chunk).replace("\r", "").split("\n"):
				var marker := line.find("REG_SZ")
				if marker < 0:
					continue
				var value := line.substr(marker + 6).strip_edges()
				if not value.is_empty():
					found.append(value)
	return found


func _failure(message: String) -> Dictionary:
	return {
		"ok": false,
		"error": message,
		"steam_root": "",
		"libraries": [],
		"games": [],
		"scanned_at": int(Time.get_unix_time_from_system()),
		"warnings": last_warnings,
	}


static func looks_like_game(app_name: String) -> bool:
	var name := app_name.to_lower().strip_edges()
	if name.is_empty():
		return false
	for phrase in NAME_EXCLUDES:
		if name.contains(phrase):
			return false
	if name.ends_with(" demo") or name.ends_with(" playtest"):
		return false
	return true


static func normalize_path(value: String) -> String:
	var path := value.strip_edges().replace("\\", "/")
	while path.ends_with("/") and path.length() > 3:
		path = path.left(-1)
	return path


static func library_label(path_value: String) -> String:
	var path := normalize_path(path_value)
	if OS.get_name() == "Windows" and path.length() >= 2 and path[1] == ":":
		return path.substr(0, 2).to_upper()
	if path.begins_with("/Volumes/"):
		return path.get_slice("/", 3)
	var label := path.get_file()
	return label if not label.is_empty() else path


static func _is_steam_library(path_value: String) -> bool:
	return DirAccess.dir_exists_absolute(path_value.path_join("steamapps"))


static func _path_key(path_value: String) -> String:
	return path_value.to_lower() if OS.get_name() == "Windows" else path_value
