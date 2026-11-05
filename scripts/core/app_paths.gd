class_name AppPaths
extends RefCounted
## Resolves a writable data directory for caches and settings.
##
## user:// is the normal location. Portable builds and sandboxed environments can
## override it with ROLLPLAY_DATA_DIR, and the app falls back to a local folder if
## the user data directory is not writable.

const APP_FOLDER := "RollPlay"

static var _root := ""
static var _warnings: PackedStringArray = []


static func data_root() -> String:
	if not _root.is_empty():
		return _root

	var candidates: Array[String] = []
	var override := OS.get_environment("ROLLPLAY_DATA_DIR").strip_edges()
	if not override.is_empty():
		if override.is_absolute_path():
			candidates.append(override)
		else:
			candidates.append(ProjectSettings.globalize_path("res://").path_join(override).simplify_path())

	candidates.append(ProjectSettings.globalize_path("user://"))
	candidates.append(ProjectSettings.globalize_path("res://.userdata"))
	candidates.append(OS.get_executable_path().get_base_dir().path_join("RollPlayData"))

	for candidate in candidates:
		var cleaned := _clean(candidate)
		if cleaned.is_empty():
			continue
		if _is_writable(cleaned):
			_root = cleaned
			return _root
		_warnings.append("Not writable: %s" % cleaned)

	_root = OS.get_executable_path().get_base_dir().path_join("RollPlayData")
	_warnings.append("No writable data directory found; using %s" % _root)
	return _root


static func path(file_name: String) -> String:
	return data_root().path_join(file_name)


static func ensure_dir(folder_name: String) -> String:
	var folder := data_root().path_join(folder_name)
	DirAccess.make_dir_recursive_absolute(folder)
	return folder


static func covers_dir() -> String:
	return ensure_dir("covers")


static func warnings() -> PackedStringArray:
	return _warnings


static func _clean(path_value: String) -> String:
	var cleaned := path_value.replace("\\", "/").strip_edges()
	while cleaned.ends_with("/") and cleaned.length() > 3:
		cleaned = cleaned.left(-1)
	return cleaned


static func _is_writable(folder: String) -> bool:
	var error := DirAccess.make_dir_recursive_absolute(folder)
	if error != OK and error != ERR_ALREADY_EXISTS:
		return false
	var test_path := folder.path_join(".rollplay_write_test")
	var file := FileAccess.open(test_path, FileAccess.WRITE)
	if file == null:
		return false
	file.store_string("ok")
	file.close()
	DirAccess.remove_absolute(test_path)
	return true
