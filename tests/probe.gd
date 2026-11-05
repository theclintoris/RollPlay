extends SceneTree


func _init() -> void:
	var out: Array = []
	var code := OS.execute("reg", PackedStringArray(["query", "HKCU\\Software\\Valve\\Steam", "/v", "SteamPath"]), out, true)
	print("REG_CODE=", code)
	print("REG_OUT=", out)

	for path in [
		"res://assets/fonts/bricolage-grotesque-latin.woff2",
		"res://assets/fonts/dm-sans-latin.woff2",
		"res://assets/fonts/instrument-serif-italic-latin.woff2",
	]:
		var font = load(path)
		if font == null:
			print("FONT_FAIL=", path)
		else:
			print("FONT_OK=", path, " class=", font.get_class(), " name=", font.get_font_name())
	quit()
