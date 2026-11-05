extends SceneTree

func _init() -> void:
	print("--- VDF ---")
	var libs := VdfParser.parse_file("C:/Program Files (x86)/Steam/steamapps/libraryfolders.vdf")
	print("top=", libs.keys())
	var folders: Dictionary = libs.get("libraryfolders", {})
	print("folders=", folders.size())
	for key in folders.keys():
		var e = folders[key]
		if e is Dictionary:
			print(key, " path=", e.get("path"), " apps=", (e.get("apps", {}) as Dictionary).size())

	var acf := VdfParser.parse_file("D:/SteamLibrary/steamapps/appmanifest_2379780.acf")
	print("acf_app=", acf.get("AppState", {}).get("name"), " state=", acf.get("AppState", {}).get("StateFlags"))

	print("--- SCAN ---")
	var scanner := SteamScanner.new()
	var started := Time.get_ticks_msec()
	var result := scanner.scan()
	print("elapsed_ms=", Time.get_ticks_msec() - started)
	print("ok=", result.get("ok"), " error=", result.get("error"))
	print("root=", result.get("steam_root"))
	print("libraries=", result.get("libraries"))
	print("games=", (result.get("games", []) as Array).size())
	for game in (result.get("games", []) as Array).slice(0, 8):
		print(game.get("app_id"), " | ", game.get("name"), " | ", game.get("library_label"), " | ", game.get("size_bytes"))
	print("warnings=", result.get("warnings"))
	print("data_root=", AppPaths.data_root())
	quit()
