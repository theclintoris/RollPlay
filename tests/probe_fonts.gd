extends SceneTree
func _init() -> void:
	for p in [
		"res://assets/fonts/bricolage-grotesque-latin.woff2",
		"res://assets/fonts/dm-sans-latin.woff2",
		"res://assets/fonts/instrument-serif-italic-latin.woff2",
	]:
		var f: FontFile = load(p)
		print("--- ", p)
		print("name=", f.get_font_name(), " style=", f.get_font_style_name(), " weight=", f.get_font_weight(), " stretch=", f.get_font_stretch())
		print("variations=", f.get_supported_variation_list())
		if f.get_supported_chars().length() > 0:
			print("has_arrow=", f.has_char("→".unicode_at(0)), " has_star=", f.has_char("✳".unicode_at(0)), " has_mid=", f.has_char("·".unicode_at(0)))
	quit()
