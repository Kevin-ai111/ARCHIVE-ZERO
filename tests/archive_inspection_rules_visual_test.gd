extends Node

const ROOM := preload("res://scenes/world/archive_room.tscn")

var _options := {}
var _room: Node2D
var _panel: ManualCasePanel
var _captures: Array[Dictionary] = []


func _ready() -> void:
	SimulationManager.set_process(false)
	GameState.set_process(false)
	for argument: String in OS.get_cmdline_user_args():
		var pair := argument.trim_prefix("--").split("=", true, 1)
		if pair.size() == 2:
			_options[pair[0]] = pair[1]
	call_deferred("_capture")


func _capture() -> void:
	if DisplayServer.get_name() == "headless":
		push_error("Archive inspection evidence requires a graphical renderer.")
		get_tree().quit(1)
		return
	var parts := String(_options.get("size", "1920x1080")).split("x")
	var size := Vector2i(int(parts[0]), int(parts[1]))
	var output := String(_options.get("out", "user://archive-inspection-rules"))
	DirAccess.make_dir_recursive_absolute(output)
	get_window().borderless = true
	get_window().position = Vector2i.ZERO
	get_window().size = size
	FirstShiftManager.start_new_game()
	_room = ROOM.instantiate()
	add_child(_room)
	_panel = _room.get_node("CasePanel") as ManualCasePanel
	await _settle()

	FirstShiftManager.activate_next_case()
	CaseManager.mark_active_case_inspected()
	await _settle()
	_panel.directives_button.pressed.emit()
	await _shot(output, "a-inspected-directives")
	_panel.directives_button.pressed.emit()
	CaseManager.set_active_case_classification(&"PERS")
	await _shot(output, "b-category-pers-selected")
	CaseManager.set_active_case_classification(&"ELEC")
	await _shot(output, "c-category-changed-elec")
	CaseManager.set_active_case_classification(&"PERS")
	CaseManager.archive_active_case()
	await _shot(output, "d-correct-result")

	FirstShiftManager.activate_next_case()
	CaseManager.mark_active_case_inspected()
	CaseManager.set_active_case_classification(&"PERS")
	CaseManager.archive_active_case()
	await _shot(output, "e-misrouted-result")

	# Start a separate all-wrong proof path so the commissioning gate is
	# genuinely reachable with zero Credits rather than merely zero cost.
	FirstShiftManager.start_new_game()
	for case_id: StringName in FirstShiftManager.MANUAL_CASE_IDS:
		await _finish_next(case_id, false)
	_panel.close_panel()
	await _shot(output, "f-zero-credit-scanner-gate")

	FirstShiftManager.commission_scanner()
	for case_id: StringName in FirstShiftManager.SCANNER_CASE_IDS:
		await _finish_next(case_id, false)
	FirstShiftManager.commission_sorter()
	FirstShiftManager.activate_next_case()
	await _settle()
	await _shot(output, "g-sorter-awaiting-player-classification")

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
	print("Archive inspection/rules captures saved: %s (%d states)" % [output, _captures.size()])
	get_tree().quit(0)


func _finish_next(case_id: StringName, correct: bool) -> void:
	var progress := FirstShiftManager.activate_next_case()
	if progress == null or progress.get_case_id() != case_id:
		push_error("Capture FIFO mismatch at " + String(case_id))
		get_tree().quit(1)
		return
	await _settle()
	progress = CaseManager.get_active_case()
	if progress.get_state() == CaseProgress.State.ACTIVE:
		CaseManager.mark_active_case_inspected()
		progress = CaseManager.get_active_case()
	var expected := CaseManager.get_case_definition(case_id).expected_category_id
	var selected := expected if correct else _wrong_category(expected)
	CaseManager.set_active_case_classification(selected)
	CaseManager.archive_active_case()
	await _settle()


func _wrong_category(expected: StringName) -> StringName:
	for candidate: StringName in [&"PERS", &"ELEC", &"DOCS", &"BAG"]:
		if candidate != expected:
			return candidate
	return &""


func _shot(output: String, capture_name: String) -> void:
	await _settle()
	await RenderingServer.frame_post_draw
	var image := get_viewport().get_texture().get_image()
	if image.get_size() != get_window().size or image.save_png(output.path_join(capture_name + ".png")) != OK:
		push_error("Could not capture " + capture_name)
		get_tree().quit(1)
		return
	var active := CaseManager.get_active_case()
	_captures.append({
		"name": capture_name,
		"phase": FirstShiftManager.get_phase_label(),
		"credits": GameState.get_money(),
		"active_case": "" if active == null else String(active.get_case_id()),
		"case_state": "" if active == null else CaseProgress.STATE_LABELS[active.get_state()],
		"selected": "" if active == null else String(active.get_selected_category_id()),
		"result": FirstShiftManager.get_last_committed_case_result(),
		"directives_open": _panel.directives_drawer.visible,
		"draw_calls": int(Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)),
		"texture_memory_bytes": int(Performance.get_monitor(Performance.RENDER_TEXTURE_MEM_USED)),
	})
	print("Rendered %s at %s" % [capture_name, get_window().size])


func _settle() -> void:
	for _frame: int in range(4):
		await get_tree().process_frame
