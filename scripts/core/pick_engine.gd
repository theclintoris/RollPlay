class_name PickEngine
extends RefCounted
## Pure, deterministic-when-seeded selection logic for the roulette.
## Keeping this separate makes the "no repeats" and genre rules easy to test.

const DEFAULT_REEL_SLOTS := 11


static func filter_pool(games: Array, mode: String, genre: String) -> Array:
	var pool: Array = []
	for game in games:
		if not game is Dictionary:
			continue
		if mode == "genre":
			if genre.is_empty():
				continue
			var genres: Array = game.get("genres", [])
			if not genres.has(genre):
				continue
		pool.append(game)
	return pool


static func make_roll(
	games: Array,
	mode: String,
	genre: String,
	avoid_app_id: int = 0,
	slots: int = DEFAULT_REEL_SLOTS,
	seed: int = 0
) -> Dictionary:
	var pool := filter_pool(games, mode, genre)
	if pool.is_empty():
		return {
			"ok": false,
			"error": "No games are available for that choice yet.",
			"pool_size": 0,
			"winner": {},
			"reel": [],
		}

	var rng := RandomNumberGenerator.new()
	rng.seed = _seed_value(seed)

	var candidates := pool.duplicate()
	if avoid_app_id > 0 and candidates.size() > 1:
		var narrowed: Array = []
		for game in candidates:
			if int(game.get("app_id", 0)) != avoid_app_id:
				narrowed.append(game)
		if not narrowed.is_empty():
			candidates = narrowed

	var winner: Dictionary = candidates[rng.randi_range(0, candidates.size() - 1)]
	var slot_count: int = maxi(1, slots)
	var reel: Array = []

	# Build a lively sequence of existing games, finishing on the actual winner.
	for index in range(slot_count - 1):
		var choices := pool
		if reel.size() > 0 and pool.size() > 2:
			var without_last: Array = []
			for game in pool:
				if int(game.get("app_id", 0)) != int(reel[-1].get("app_id", 0)):
					without_last.append(game)
			if not without_last.is_empty():
				choices = without_last
		var candidate: Dictionary = choices[rng.randi_range(0, choices.size() - 1)]
		reel.append(candidate)
	reel.append(winner)

	return {
		"ok": true,
		"error": "",
		"winner": winner,
		"reel": reel,
		"pool_size": pool.size(),
	}


static func _seed_value(seed: int) -> int:
	if seed != 0:
		return seed
	var bytes := Crypto.new().generate_random_bytes(8)
	var value := 0
	if bytes.size() >= 8:
		value = bytes.decode_s32(0)
		value ^= bytes.decode_s32(4) << 32
	value ^= Time.get_ticks_usec()
	return value
