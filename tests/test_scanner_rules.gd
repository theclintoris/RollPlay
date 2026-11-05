extends SceneTree

## Headless rules tests that do not depend on a particular Steam installation.

var failures := 0


func check(condition: bool, label: String) -> void:
	if condition:
		print("PASS  ", label)
	else:
		failures += 1
		push_error("FAIL  " + label)


func _init() -> void:
	check(SteamScanner.looks_like_game("Balatro"), "normal game name is accepted")
	check(SteamScanner.looks_like_game("Age of Empires II: Definitive Edition"), "punctuation in game name is accepted")
	check(not SteamScanner.looks_like_game(""), "empty name is rejected")
	check(not SteamScanner.looks_like_game("   "), "whitespace name is rejected")
	check(not SteamScanner.looks_like_game("Steamworks Common Redistributables"), "Steam redistributables are rejected")
	check(not SteamScanner.looks_like_game("SteamVR"), "SteamVR is rejected")
	check(not SteamScanner.looks_like_game("Steam Linux Runtime 3.0 (sniper)"), "Steam Linux Runtime is rejected")
	check(not SteamScanner.looks_like_game("Proton Experimental"), "Proton is rejected")
	check(not SteamScanner.looks_like_game("My Game Dedicated Server"), "dedicated servers are rejected")
	check(not SteamScanner.looks_like_game("Wallpaper Engine"), "Wallpaper Engine is rejected")
	check(not SteamScanner.looks_like_game("Godot Engine"), "Godot Engine is rejected")
	check(not SteamScanner.looks_like_game("Game Soundtrack"), "soundtracks are rejected")
	check(not SteamScanner.looks_like_game("Game Artbook"), "artbooks are rejected")
	check(not SteamScanner.looks_like_game("Game Season Pass"), "season passes are rejected")
	check(not SteamScanner.looks_like_game("Game Demo"), "demos are rejected")
	check(not SteamScanner.looks_like_game("Game Playtest"), "playtests are rejected")

	check(SteamScanner.normalize_path("D:\\SteamLibrary\\steamapps\\") == "D:/SteamLibrary/steamapps", "Windows paths normalize to forward slashes")
	check(SteamScanner.normalize_path("C:/Steam/") == "C:/Steam", "trailing slash is removed")
	check(SteamScanner.normalize_path("C:/") == "C:/", "drive root is preserved")
	if OS.get_name() == "Windows":
		check(SteamScanner.library_label("D:/SteamLibrary") == "D:", "Windows libraries are labeled by drive")
	else:
		check(not SteamScanner.library_label("/mnt/games/SteamLibrary").is_empty(), "Unix libraries get a readable label")

	print("")
	if failures == 0:
		print("SCANNER TESTS PASSED")
	else:
		push_error("SCANNER TESTS FAILED: %d" % failures)
	quit(1 if failures > 0 else 0)
