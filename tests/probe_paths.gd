extends SceneTree

func _init() -> void:
	print("APPDATA=", OS.get_environment("APPDATA"))
	print("USER=", ProjectSettings.globalize_path("user://"))
	print("DATA=", ProjectSettings.globalize_path("user://data"))
	print("EXISTS_USER=", DirAccess.dir_exists_absolute(ProjectSettings.globalize_path("user://")))
	var err = DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("user://data"))
	print("MKDIR_ERR=", err)
	var f = FileAccess.open("user://data/probe.txt", FileAccess.WRITE)
	print("WRITE=", f != null, " ERR=", FileAccess.get_open_error())
	if f:
		f.store_string("ok")
		f.close()
	quit()
