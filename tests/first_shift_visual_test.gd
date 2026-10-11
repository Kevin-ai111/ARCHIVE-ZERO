extends Node

# Opt-in graphical proof for PR #18. It drives only public First Shift and Case
# APIs, then captures the real ArchiveRoom viewport.
const ROOM := preload("res://scenes/world/archive_room.tscn")

var _options := {}
var _room: Node2D
var _hud: Variant
var _captures: Array[Dictionary] = []


func _ready() -> void:
	SimulationManager.set_process(false)
	GameState.set_process(false)
	for argument: String in OS.get_cmdline_user_args():
		var pair := argument.trim_prefix("--").split("=", true, 1)
		if pair.size() == 2:
			_options[pair[0]] = pair[1]
	call_deferred("_capture_sequence")


func _capture_sequence() -> void:
	if DisplayServer.get_name() == "headless":
		push_error("First Shift evidence requires the graphical renderer.")
		get_tree().quit(1)
		return
	var parts := String(_options.get("size", "1920x1080")).split("x")
	var physical_size := Vector2i(int(parts[0]), int(parts[1]))
	var output := String(_options.get("out", "user://first-shift-proof"))
	DirAccess.make_dir_recursive_absolute(output)
	get_window().borderless = true
	get_window().position = Vector2i.ZERO
	get_window().size = physical_size
	FirstShiftManager.start_new_game()
	_room = ROOM.instantiate()
	add_child(_room)
	_hud = _room.get_node("GameplayHUD")
	await _settle()

	await _shot(output, "a-fresh-manual")
	FirstShiftManager.activate_next_case()
	await _settle()
	if physical_size.x == 1920:
		await _shot(output, "b-case-0001-manual")
	await _finish_active_case(true)
	for case_id: StringName in [&"CASE_0002", &"CASE_0003", &"CASE_0004", &"CASE_0005", &"CASE_0006"]:
		await _finish_next_case(case_id, true)
	if physical_size.x == 1920:
		await _shot(output, "c-scanner-ready")

	FirstShiftManager.commission_scanner()
	FirstShiftManager.activate_next_case()
	await _settle()
	await _shot(output, "d-scanner-case-0007-inspected")
	await _finish_active_case(true)
	for case_id: StringName in [&"CASE_0008", &"CASE_0009", &"CASE_0011"]:
		await _finish_next_case(case_id, true)
	if physical_size.x == 1920:
		await _shot(output, "e-sorter-ready")

	FirstShiftManager.commission_sorter()
	FirstShiftManager.activate_next_case()
	await _settle()
	await _shot(output, "f-sorter-case-0012-classified")
	await _finish_active_case(true)
	for case_id: StringName in [&"CASE_0013", &"CASE_0014", &"CASE_0015"]:
		await _finish_next_case(case_id, true)
	if physical_size.x == 1920:
		await _shot(output, "g-intake-ready")

	FirstShiftManager.commission_intake()
	await _settle()
	await _shot(output, "h-full-line-online")

	var metadata := {
		"godot": Engine.get_version_info(),
		"adapter": RenderingServer.get_video_adapter_name(),
		"renderer": RenderingServer.get_current_rendering_method(),
		"physical_size": str(get_window().size),
		"logical_size": str(get_window().content_scale_size),
		"capture_source": "Actual Godot ArchiveRoom runtime viewport",
		"captures": _captures,
	}
	var file := FileAccess.open(output.path_join("metadata.json"), FileAccess.WRITE)
	file.store_string(JSON.stringify(metadata, "\t"))
	file.close()
	print("Actual First Shift captures saved: %s (%d states)" % [output, _captures.size()])
	get_tree().quit(0)


func _finish_next_case(expected_id: StringName, correct: bool) -> void:
	var progress := FirstShiftManager.activate_next_case()
	if progress == null or progress.get_case_id() != expected_id:
		push_error("Capture driver lost First Shift FIFO at " + String(expected_id))
		get_tree().quit(1)
		return
	await _settle()
	await _finish_active_case(correct)


func _finish_active_case(correct: bool) -> void:
	var progress := CaseManager.get_active_case()
	if progress == null:
		return
	if progress.get_state() == CaseProgress.State.ACTIVE:
		CaseManager.mark_active_case_inspected()
		progress = CaseManager.get_active_case()
	if progress.get_state() == CaseProgress.State.INSPECTED:
		var definition := CaseManager.get_case_definition(progress.get_case_id())
		var category := definition.expected_category_id
		if not correct:
			category = &"ELEC" if category != &"ELEC" else &"PERS"
		CaseManager.classify_active_case(category)
	CaseManager.archive_active_case()
	await _settle()


func _shot(output: String, name_value: String) -> void:
	await _settle()
	await RenderingServer.frame_post_draw
	var image := get_viewport().get_texture().get_image()
	if image.get_size() != get_window().size:
		push_error("Capture size mismatch for " + name_value)
		get_tree().quit(1)
		return
	if image.save_png(output.path_join(name_value + ".png")) != OK:
		push_error("Could not write " + name_value)
		get_tree().quit(1)
		return
	var active := CaseManager.get_active_case()
	var snapshot: Dictionary = _hud.get_readability_snapshot()
	_captures.append({
		"name": name_value,
		"phase": FirstShiftManager.get_phase_label(),
		"commissioning": CommissioningManager.STAGE_LABELS[CommissioningManager.get_stage()],
		"action": _hud.first_shift_action_button.text,
		"active_case": "" if active == null else String(active.get_case_id()),
		"case_state": "" if active == null else CaseProgress.STATE_LABELS[active.get_state()],
		"credits": GameState.get_money(),
		"aggregate_items": GameState.get_total_processed_items(),
		"throughput": SimulationManager.get_effective_throughput(),
		"hud": snapshot,
		"draw_calls": int(Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)),
		"node_count": int(Performance.get_monitor(Performance.OBJECT_NODE_COUNT)),
		"texture_memory_bytes": int(Performance.get_monitor(Performance.RENDER_TEXTURE_MEM_USED)),
	})
	print("Rendered First Shift %s at %s: phase=%s action=%s" % [name_value, get_window().size, FirstShiftManager.get_phase_label(), _hud.first_shift_action_button.text])


func _settle() -> void:
	for _frame: int in range(4):
		await get_tree().process_frame
