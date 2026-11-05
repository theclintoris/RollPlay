extends Node
## Headless probe for the library service and cover cache.

func _ready() -> void:
	await get_tree().process_frame
	await get_tree().create_timer(1.0).timeout
	var snap: Dictionary = SteamLibrary.snapshot()
	print("ok=", snap.get("ok"), " error=", snap.get("error"))
	print("steam_root=", snap.get("steam_root"))
	print("libraries=", (snap.get("libraries", []) as Array).size())
	print("games=", (snap.get("games", []) as Array).size())
	print("genres=", snap.get("genres"))
	print("stats=", snap.get("stats"))
	print("metadata=", snap.get("metadata"))
	var games: Array = snap.get("games", [])
	if not games.is_empty():
		var first: Dictionary = games[0]
		print("first=", first.get("name"), " id=", first.get("app_id"), " type=", first.get("type"), " genres=", first.get("genres"), " meta=", first.get("metadata"))
		var roll := SteamLibrary.make_roll("genre", "RPG", 0)
		print("roll_ok=", roll.get("ok"), " pool=", roll.get("pool_size"), " winner=", roll.get("winner", {}).get("name"), " reel=", (roll.get("reel", []) as Array).size())
		var texture := CoverCache.request_cover(first)
		print("immediate_texture=", texture)
		await get_tree().create_timer(6.0).timeout
		print("cover_after_wait=", CoverCache.has_cover(int(first.get("app_id"))), " progress=", CoverCache.progress())
	get_tree().quit()
