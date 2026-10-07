extends "res://tests/progressive_room_states_visual_test.gd"

# Actual GPU readback; optional exact-base comparisons. No new golden approval.
# -- --capture=true --size=1920x1080 --out=C:/temp/pr17 --base=C:/temp/base
var _output := ""
var _reference := ""


func _capture() -> void:
	if DisplayServer.get_name() == "headless":
		push_error("Lighting visual validation requires actual Godot graphics.")
		get_tree().quit(1)
		return
	var parts := String(_options.get("size", "1920x1080")).split("x")
	get_window().borderless = true
	get_window().position = Vector2i.ZERO
	get_window().size = Vector2i(int(parts[0]), int(parts[1]))
	_toolbar.hide()
	_output = String(_options.get("out", "user://lighting-review"))
	_reference = String(_options.get("base", ""))
	if DirAccess.make_dir_recursive_absolute(_output) != OK:
		push_error("Cannot create output folder.")
		get_tree().quit(1)
		return
	for _index: int in range(20):
		await get_tree().process_frame
	CaseManager.reset_cases()
	for stage: int in range(4):
		SUPPORT.restore_stage(stage)
		_freeze_phases()
		var before := SUPPORT.authority_snapshot()
		var commissioning := CommissioningManager.get_commissioning_save_data()
		if not await _lighting_shot(CommissioningManager.STAGE_LABELS[stage].to_lower(), stage == 3):
			return
		if before != SUPPORT.authority_snapshot() or commissioning != CommissioningManager.get_commissioning_save_data():
			push_error("Lighting capture changed numerical or commissioning authority.")
			get_tree().quit(1)
			return
	for stage: int in [0, 3]:
		_open_case()
		SUPPORT.restore_stage(stage)
		_freeze_phases()
		var before := SUPPORT.authority_snapshot()
		if not await _lighting_shot(CommissioningManager.STAGE_LABELS[stage].to_lower() + "-case-panel", false):
			return
		if before != SUPPORT.authority_snapshot():
			push_error("Lighting capture changed open Case authority.")
			get_tree().quit(1)
			return
	var metadata := {"base_sha": LIGHTING_FIX.contract().base_sha, "approval": "Review captures only; no replacement golden approved", "godot": Engine.get_version_info(), "renderer": RenderingServer.get_current_rendering_method(), "adapter": RenderingServer.get_video_adapter_name(), "physical_size": str(get_window().size), "phase": "machine phases and conveyor time zero", "captures": _measurements}
	var file := FileAccess.open(_output.path_join("metadata.json"), FileAccess.WRITE)
	if file == null:
		push_error("Cannot write capture metadata.")
		get_tree().quit(1)
		return
	file.store_string(JSON.stringify(metadata, "\t"))
	print("Actual lighting review captures complete: " + _output)
	get_tree().quit(0)


func _lighting_shot(name_value: String, closeups: bool) -> bool:
	await get_tree().process_frame
	await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var image := get_viewport().get_texture().get_image()
	if image.get_size() != get_window().size or image.save_png(_output.path_join(name_value + ".png")) != OK:
		push_error("Actual lighting screenshot size/write failed.")
		get_tree().quit(1)
		return false
	var comparison := {"result": "No base comparison requested"}
	var old_image: Image
	if not _reference.is_empty():
		var old_path := _reference.path_join(name_value + ".png")
		if FileAccess.file_exists(old_path):
			old_image = Image.load_from_file(old_path)
			comparison = LIGHTING_FIX.compare_outside_regions(old_image, image, LIGHTING_FIX.affected_screen_regions(_room.get_node("%EnvironmentArt")))
			if not comparison.valid or comparison.outside_changed_pixels != 0:
				push_error("Pixels outside approved lighting bounds changed: " + name_value + " " + str(comparison))
				get_tree().quit(1)
				return false
			print("Pixel isolation %s: checked=%d outside_delta=%d total_delta=%d" % [name_value, comparison.outside_checked_pixels, comparison.outside_changed_pixels, comparison.all_changed_pixels])
		elif not name_value.ends_with("full_line_online-case-panel"):
			push_error("Required base capture missing: " + old_path)
			get_tree().quit(1)
			return false
		else:
			comparison = {"result": "No historical full-line Case Panel capture; independent UI regression and visual review"}
	_measurements.append({"capture": name_value, "stage": CommissioningManager.get_stage(), "comparison": comparison, "draw_calls": int(Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)), "primitives": int(Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME)), "texture_memory_bytes": int(Performance.get_monitor(Performance.RENDER_TEXTURE_MEM_USED)), "environment": _room.get_node("%EnvironmentArt").get_commissioning_snapshot()})
	if closeups and get_window().size == Vector2i(1920, 1080):
		var attachment := await _measure_bulb_attachment(image)
		_measurements[-1]["bulb_attachment"] = attachment
		for result: Dictionary in attachment:
			if result.gap_pixels != 0:
				push_error("Cone origin is detached from its bulb: " + str(result))
				get_tree().quit(1)
				return false
		var rules := LIGHTING_FIX.contract()
		for index: int in range(4):
			var centre_x := int(rules.cone_positions[index][0]) + 150
			var zone := Rect2i(maxi(centre_x - 210, 0), 220, 420, 790)
			var origin := Rect2i(centre_x - 150, 235, 300, 160)
			var label: String = ["receiving", "scanner", "sorter", "intake"][index]
			for entry: Array in [["zone", zone], ["bulb", origin]]:
				if image.get_region(entry[1]).save_png(_output.path_join("closeup-" + label + "-" + entry[0] + ".png")) != OK:
					push_error("Cannot save raw GPU close-up.")
					get_tree().quit(1)
					return false
				if old_image != null and old_image.get_region(entry[1]).save_png(_output.path_join("before-" + label + "-" + entry[0] + ".png")) != OK:
					push_error("Cannot save raw exact-base GPU close-up.")
					get_tree().quit(1)
					return false
	return true


func _measure_bulb_attachment(with_cones: Image) -> Array[Dictionary]:
	var environment := _room.get_node("%EnvironmentArt") as ArchiveRoomEnvironmentVisual
	environment.light_cones.hide()
	await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var without_cones := get_viewport().get_texture().get_image()
	environment.light_cones.show()
	var results: Array[Dictionary] = []
	for index: int in range(4):
		var lamp := environment.get_node("LampHousings/Art_7_%d" % index) as Sprite2D
		var housing := lamp.texture.get_image()
		var bulb_bottom := -1
		for y: int in range(housing.get_height()):
			for x: int in range(housing.get_width()):
				var color := housing.get_pixel(x, y)
				if color.a > 0.5 and color.r > 0.6 and color.g > 0.3 and color.b < 0.4:
					bulb_bottom = maxi(bulb_bottom, y)
		bulb_bottom += int(lamp.global_position.y)
		var cone := environment.get_node("LightCones/Art_8_%d" % index) as Sprite2D
		var first_visible := -1
		for y: int in range(bulb_bottom + 1, bulb_bottom + 81):
			for x: int in range(int(cone.global_position.x), int(cone.global_position.x) + cone.texture.get_width()):
				if with_cones.get_pixel(x, y) != without_cones.get_pixel(x, y):
					first_visible = y
					break
			if first_visible >= 0:
				break
		results.append({"region": index + 1, "bulb_bottom_y": bulb_bottom, "first_rendered_cone_delta_y": first_visible, "gap_pixels": first_visible - bulb_bottom - 1, "criterion": "first nonzero 8-bit GPU pixel difference, not perceptual brightness threshold"})
	print("Actual bulb/cone attachment: " + str(results))
	return results
