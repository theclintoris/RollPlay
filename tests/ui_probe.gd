extends Node

## Local-only smoke test for the built interface. It never launches a game.

var main: Control


func _ready() -> void:
	await get_tree().process_frame
	main = load("res://scenes/main.tscn").instantiate()
	add_child(main)
	await get_tree().create_timer(1.6).timeout

	print("UI snapshot games=", main._snapshot.get("games", []).size())
	print("UI roll disabled=", main._roll_button.disabled, " pool=", main._pool_size, " status=", main._status_label.text)
	print("UI viewport=", get_viewport().get_visible_rect().size)
	var scroll: ScrollContainer = main.get_child(1)
	var page: Control = scroll.get_child(0)
	print("UI page min=", page.get_combined_minimum_size(), " scroll=", scroll.size, " content=", scroll.get_v_scroll_bar().max_value)

	if DisplayServer.get_name() != "headless":
		await RenderingServer.frame_post_draw
		var shot := get_viewport().get_texture().get_image()
		var shot_path := ProjectSettings.globalize_path("res://.userdata/ui-idle.png")
		shot.save_png(shot_path)
		print("UI screenshot=", shot_path, " size=", shot.get_size())

	main._start_roll()
	await get_tree().create_timer(3.4).timeout
	print("UI roll result=", main._result.get("name", "?"), " visible=", main._copy_result.visible, " stage=", main._stage_badge_label.text)
	print("UI launch enabled=", not main._launch_button.disabled)

	if DisplayServer.get_name() != "headless":
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png(ProjectSettings.globalize_path("res://.userdata/ui-result.png"))

	main._set_mode("genre")
	await get_tree().process_frame
	print("UI genres chips=", main._genre_flow.get_child_count(), " selected=", main._genre, " pool=", main._pool_size)
	if DisplayServer.get_name() != "headless":
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png(ProjectSettings.globalize_path("res://.userdata/ui-genre.png"))

	main._select_genre("RPG")
	main._start_roll()
	await get_tree().create_timer(3.4).timeout
	print("UI RPG result=", main._result.get("name", "?"), " genres=", main._result.get("genres", []), " pool=", main._pool_size)

	main._open_drawer()
	await get_tree().create_timer(0.55).timeout
	print("UI drawer cards=", main._library_grid.get_child_count(), " filters=", main._genre_filter.item_count, " summary=", main._shelf_summary.text)

	for index in range(main._genre_filter.item_count):
		if String(main._genre_filter.get_item_metadata(index)) == "RPG":
			main._genre_filter.select(index)
			main._on_shelf_genre(index)
			break
	await get_tree().process_frame
	print("UI RPG shelf=", main._library_grid.get_child_count(), " summary=", main._shelf_summary.text)

	main._genre_filter.select(0)
	main._on_shelf_genre(0)
	await get_tree().process_frame
	print("UI all shelf=", main._library_grid.get_child_count(), " summary=", main._shelf_summary.text)
	if DisplayServer.get_name() != "headless":
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png(ProjectSettings.globalize_path("res://.userdata/ui-drawer.png"))

	main._search_field.text = "balatro"
	main._on_shelf_search("balatro")
	await get_tree().process_frame
	print("UI filtered cards=", main._library_grid.get_child_count(), " summary=", main._shelf_summary.text)
	if DisplayServer.get_name() != "headless":
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png(ProjectSettings.globalize_path("res://.userdata/ui-drawer-search.png"))

	main._search_field.text = ""
	main._close_drawer()
	await get_tree().create_timer(0.4).timeout
	print("UI done")
	get_tree().quit()
