extends SceneTree
func _init() -> void:
	var targets = [
		"res://.tmp_probe.txt",
		"D:/Deepseek Workspaces/Game Dev/RollPlayGodot/.tmp_abs.txt",
		"C:/Users/Clintoris/AppData/Local/Temp/rollplay_probe.txt",
		"C:/Users/Clintoris/AppData/Roaming/RollPlay/probe2.txt",
		"user://probe3.txt",
	]
	for p in targets:
		var f = FileAccess.open(p, FileAccess.WRITE)
		var err = FileAccess.get_open_error()
		print(p, " => open=", f != null, " err=", err)
		if f:
			f.store_string("ok")
			f.close()
	quit()
