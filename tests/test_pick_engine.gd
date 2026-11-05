extends SceneTree

## Headless unit tests for the roulette rules. No Steam installation needed:
## the pick engine only sees plain dictionaries.

var failures := 0


func check(condition: bool, label: String) -> void:
	if condition:
		print("PASS  ", label)
	else:
		failures += 1
		push_error("FAIL  " + label)


func game(id_value: int, genres: Array) -> Dictionary:
	return {"app_id": id_value, "name": "Game %d" % id_value, "genres": genres}


func _init() -> void:
	var games := [
		game(10, ["Action", "Indie"]),
		game(20, ["RPG"]),
		game(30, ["RPG", "Strategy"]),
		game(40, ["Sports"]),
		game(50, ["Indie"]),
	]

	check(PickEngine.filter_pool(games, "all", "").size() == 5, "all mode returns every game")
	check(PickEngine.filter_pool(games, "all", "RPG").size() == 5, "all mode ignores a genre")
	check(PickEngine.filter_pool(games, "all", "").size() == 5, "all mode ignores empty genre")

	var rpg := PickEngine.filter_pool(games, "genre", "RPG")
	check(rpg.size() == 2, "genre mode filters to exact tag")
	check(int(rpg[0].get("app_id", 0)) == 20 and int(rpg[1].get("app_id", 0)) == 30, "genre pool keeps matching games")

	var missing := PickEngine.make_roll(games, "genre", "Racing", 0, 11, 99)
	check(not bool(missing.get("ok", true)), "empty genre pool reports an error")
	check(int(missing.get("pool_size", -1)) == 0, "empty genre pool has size zero")

	var first := PickEngine.make_roll(games, "all", "", 0, 11, 42)
	var second := PickEngine.make_roll(games, "all", "", 0, 11, 42)
	check(bool(first.get("ok", false)), "seeded roll succeeds")
	check(int(first.get("winner", {}).get("app_id", 0)) == int(second.get("winner", {}).get("app_id", 0)), "same seed picks same winner")
	check(first.get("reel", []) == second.get("reel", []), "same seed builds same reel")
	check((first.get("reel", []) as Array).size() == 11, "default reel has 11 cards")
	check(int((first.get("reel", []) as Array)[-1].get("app_id", 0)) == int(first.get("winner", {}).get("app_id", 0)), "reel ends on the winner")

	var one_slot := PickEngine.make_roll(games, "genre", "Sports", 0, 1, 7)
	check((one_slot.get("reel", []) as Array).size() == 1, "single-slot roll returns just the winner")
	check(int(one_slot.get("winner", {}).get("app_id", 0)) == 40, "single-slot roll picks the only Sports game")

	var avoids_previous := true
	var no_adjacent_repeats := true
	var reel_lands_on_winner := true
	for seed_value in range(1, 60):
		var roll := PickEngine.make_roll(games, "all", "", 10, 11, seed_value)
		if int(roll.get("winner", {}).get("app_id", 0)) == 10:
			avoids_previous = false
		var reel: Array = roll.get("reel", [])
		if int(reel[-1].get("app_id", 0)) != int(roll.get("winner", {}).get("app_id", 0)):
			reel_lands_on_winner = false
		for index in range(1, reel.size() - 1):
			if int(reel[index].get("app_id", 0)) == int(reel[index - 1].get("app_id", 0)):
				no_adjacent_repeats = false
	check(avoids_previous, "avoid_app_id skips the previous winner across 59 seeds")
	check(no_adjacent_repeats, "reel avoids adjacent duplicates across 59 seeds")
	check(reel_lands_on_winner, "reel lands on the winner across 59 seeds")

	var two_game_pool := PickEngine.make_roll(games, "genre", "RPG", 20, 11, 8)
	check(int(two_game_pool.get("winner", {}).get("app_id", 0)) == 30, "avoid_app_id still works in a two-game pool")

	var dirty: Array = games.duplicate()
	dirty.append("not a game")
	dirty.append(null)
	check(PickEngine.filter_pool(dirty, "all", "").size() == 5, "invalid game entries are ignored")

	print("")
	if failures == 0:
		print("PICK ENGINE TESTS PASSED")
	else:
		push_error("PICK ENGINE TESTS FAILED: %d" % failures)
	quit(1 if failures > 0 else 0)
