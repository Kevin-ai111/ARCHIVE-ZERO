extends Node

const ROOM := preload("res://scenes/world/archive_room.tscn")
const SUPPORT := preload("res://tests/commissioning_test_support.gd")
const LIGHTING := preload("res://tests/lighting_fix_test_support.gd")
var _checks := 0
var _failures := 0


func _ready() -> void:
	SimulationManager.set_process(false)
	GameState.set_process(false)
	call_deferred("_run")


func _run() -> void:
	var rules := LIGHTING.contract()
	_check(rules.assets.size() == 2, "Exactly two explicitly approved runtime replacements")
	for path: String in rules.assets:
		var asset: Dictionary = rules.assets[path]
		_check(FileAccess.get_sha256("res://" + path) == asset.sha256, "Exact corrected ART SHA: " + path)
		var image := Image.load_from_file(ProjectSettings.globalize_path("res://" + path))
		_check(image.get_size() == Vector2i(asset.dimensions[0], asset.dimensions[1]) and image.get_format() == Image.FORMAT_RGBA8, "Unchanged dimensions and original RGBA")
		var config := ConfigFile.new()
		_check(config.load("res://" + path + ".import") == OK, "Existing texture import exists")
		_check(config.get_value("params", "compress/mode") == 0 and not config.get_value("params", "mipmaps/generate"), "Lossless, mipmaps disabled")
		_check(config.get_value("params", "process/channel_remap/alpha") == 3 and not config.get_value("params", "process/premult_alpha"), "Alpha channel preserved")
	_check(FileAccess.get_sha256("res://" + rules.locked_service_marking.path) == rules.locked_service_marking.sha256, "Service marking art is byte-locked")
	var room := ROOM.instantiate() as Node2D
	add_child(room)
	await get_tree().process_frame
	var environment := room.get_node("%EnvironmentArt") as ArchiveRoomEnvironmentVisual
	var base: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://tests/fixtures/lighting_fix_base_environment.json"))
	_check(JSON.parse_string(JSON.stringify(environment.get_layout_snapshot())) == base, "Every environment position/scale/texture path/Z/instance count matches exact base")
	_check(environment.texture_filter == CanvasItem.TEXTURE_FILTER_LINEAR and not environment.is_processing(), "Original linear filtering, no frame controller")
	var original: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://tests/fixtures/phase5d_state_matrix.json"))
	for stopped: bool in [false, true]:
		SUPPORT.prepare_isolation_fixture(stopped)
		for stage: int in range(4):
			SUPPORT.restore_stage(stage)
			var authority := SUPPORT.authority_snapshot()
			var commissioning := CommissioningManager.get_commissioning_save_data()
			environment.apply_commissioning_stage(stage)
			var applications := environment.state_application_count
			environment.apply_commissioning_stage(stage)
			_check(environment.state_application_count == applications, "Lighting refresh retains approved stage caching")
			var snapshot := environment.get_commissioning_snapshot()
			for element: String in original.elements:
				var expected: Dictionary = original.elements[element].states[original.states[stage]]
				var alpha := LIGHTING.expected_alpha(element, stage, expected.alpha_multiplier)
				var actual := ProgressiveRoomStateMatrix.get_value(element, stage)
				var color := Color(expected.modulate_rgba[0], expected.modulate_rgba[1], expected.modulate_rgba[2], expected.modulate_rgba[3] * alpha)
				_check(actual.visible == expected.visible and (actual.modulate as Color).is_equal_approx(color) and is_equal_approx(actual.alpha_multiplier, alpha), "Only approved alpha delta; RGB/visibility/unrelated values unchanged: " + element)
				for target: Dictionary in snapshot.elements[element].targets:
					_check(target.visible == expected.visible and (target.effective_modulate as Color).is_equal_approx(color), "Real inherited CanvasItem response: " + element)
				if LIGHTING.is_lighting_entry(element) and expected.visible:
					var family := "service_markings" if element == "service_markings" else ("light_cone" if element.begins_with("light_cone_") else "floor_light_pool")
					var limits: Array = rules.ranges[family][stage]
					_check(alpha >= limits[0] and alpha <= limits[1], "All active lighting alpha values within approved ART ranges")
			_check(SUPPORT.authority_snapshot() == authority and CommissioningManager.get_commissioning_save_data() == commissioning, "Lighting cannot mutate production/cases/commissioning/save authority")
	_check(SaveManager.SAVE_VERSION == 3 and CaseManager.CASE_SAVE_VERSION == 1 and CommissioningManager.COMMISSIONING_SAVE_VERSION == 1, "Save contracts remain 3/1/1")
	_test_pixel_guard()
	SUPPORT.restore_stage(3)
	CaseManager.reset_cases()
	room.queue_free()
	await get_tree().process_frame
	if _failures == 0:
		print("Lighting correction tests passed: %d checks; two corrected textures, locked service art, exact alpha/geometry, authority isolation." % _checks)
	else:
		push_error("Lighting correction tests failed: %d/%d" % [_failures, _checks])
	get_tree().quit(0 if _failures == 0 else 1)


func _test_pixel_guard() -> void:
	var original := Image.create(6, 6, false, Image.FORMAT_RGBA8)
	var changed := original.duplicate() as Image
	var regions: Array[Rect2] = [Rect2(2, 2, 2, 2)]
	changed.set_pixel(2, 2, Color.WHITE)
	var allowed := LIGHTING.compare_outside_regions(original, changed, regions)
	_check(allowed.valid and allowed.all_changed_pixels == 1 and allowed.outside_checked_pixels == 32 and allowed.outside_changed_pixels == 0, "Pixel guard permits only in-region change")
	changed.set_pixel(0, 0, Color.WHITE)
	_check(LIGHTING.compare_outside_regions(original, changed, regions).outside_changed_pixels == 1, "Negative control: unrelated pixel change detected")
	_check(not LIGHTING.compare_outside_regions(original, Image.create(7, 6, false, Image.FORMAT_RGBA8), regions).valid, "Negative control: size mismatch fails")


func _check(condition: bool, detail: String) -> void:
	_checks += 1
	if not condition:
		_failures += 1
		push_error("FAIL: " + detail)
