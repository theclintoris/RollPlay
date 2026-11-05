extends SceneTree

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	print("USER=", ProjectSettings.globalize_path("user://"))
	print("MKDIR=", DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("user://data")))
	var http := HTTPRequest.new()
	root.add_child(http)
	http.request_completed.connect(_on_done)
	var err := http.request("https://store.steampowered.com/api/appdetails?appids=2379780&filters=genres&l=english", PackedStringArray(["Accept: application/json", "User-Agent: RollPlay/0.1"]))
	print("REQ_ERR=", err)

func _on_done(result: int, code: int, headers: PackedStringArray, body: PackedByteArray) -> void:
	print("RESULT=", result, " CODE=", code, " BYTES=", body.size())
	print(body.get_string_from_utf8().substr(0, 300))
	quit()
