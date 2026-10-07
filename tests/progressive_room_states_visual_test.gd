extends Node

# Explicit QA only. No stage controls or case initialization enter main gameplay.
# -- --capture=true --size=1920x1080 --out=C:/temp/commissioning-proof
const ROOM := preload("res://scenes/world/archive_room.tscn")
const SUPPORT := preload("res://tests/commissioning_test_support.gd")
var _room: Node2D
var _toolbar: CanvasLayer
var _options := {}
var _measurements: Array[Dictionary] = []


func _ready() -> void:
	SimulationManager.set_process(false)
	GameState.set_process(false)
	for argument: String in OS.get_cmdline_user_args():
		var pair := argument.trim_prefix("--").split("=", true, 1)
		if pair.size() == 2:
			_options[pair[0]] = pair[1]
	SimulationManager.restore_production_save_data(SimulationManager.get_default_production_save_data())
	GameState.restore_state(0, 0, 0, 0)
	_room = ROOM.instantiate()
	add_child(_room)
	if _options.has("capture"):
		_freeze_phases()
	_toolbar = CanvasLayer.new()
	_toolbar.layer = 3
	add_child(_toolbar)
	for index: int in range(4):
		var button := Button.new()
		button.position = Vector2(32 + index * 400, 144)
		button.size = Vector2(380, 52)
		button.text = "%d · %s" % [index + 1, CommissioningManager.STAGE_LABELS[index]]
		button.add_theme_font_size_override("font_size", 18)
		button.pressed.connect(_select_stage.bind(index))
		_toolbar.add_child(button)
	var case_button := Button.new()
	case_button.position = Vector2(32, 204)
	case_button.size = Vector2(380, 52)
	case_button.text = "C · QA CASE #0001"
	case_button.pressed.connect(_open_case)
	_toolbar.add_child(case_button)
	if _options.has("capture"):
		call_deferred("_capture")


func _unhandled_key_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode >= KEY_1 and event.keycode <= KEY_4:
			_select_stage(event.keycode - KEY_1)
		elif event.keycode == KEY_C:
			_open_case()


func _select_stage(stage: int) -> void:
	SUPPORT.restore_stage(stage)


func _open_case() -> void:
	CaseManager.reset_cases()
	CaseManager.enqueue_case(&"CASE_0001")
	CaseManager.activate_next_case()


func _freeze_phases() -> void:
	for node_name: String in ["Conveyor", "ReceivingDesk", "BasicScanner", "BasicSorter", "ArchiveIntake"]:
		_room.get_node("%" + node_name).set_process(false)
	(_room.get_node("%ReceivingDesk") as ReceivingDeskVisual).set_wheel_angle_for_preview(0)
	(_room.get_node("%BasicScanner") as BasicScannerVisual).set_scan_phase_for_preview(0)
	(_room.get_node("%BasicSorter") as BasicSorterVisual).set_gate_phase_for_preview(0)
	(_room.get_node("%ArchiveIntake") as ArchiveIntakeVisual).set_carrier_phase_for_preview(0)


func _capture() -> void:
	if DisplayServer.get_name() == "headless":
		push_error("Actual commissioning captures require the graphical renderer.")
		get_tree().quit(1)
		return
	var size_parts := String(_options.get("size", "1920x1080")).split("x")
	get_window().borderless = true
	get_window().position = Vector2i.ZERO
	get_window().size = Vector2i(int(size_parts[0]), int(size_parts[1]))
	_toolbar.hide()
	for _index: int in range(20):
		await get_tree().process_frame
	var output := String(_options.get("out", "user://progressive-room-proof"))
	DirAccess.make_dir_recursive_absolute(output)
	CaseManager.reset_cases()
	var authority := SUPPORT.authority_snapshot()
	for stage: int in range(4):
		SUPPORT.restore_stage(stage)
		_freeze_phases()
		if not await _shot(output, CommissioningManager.STAGE_LABELS[stage].to_lower()):
			return
		if SUPPORT.authority_snapshot() != authority:
			push_error("Capture stage selection changed production or cases.")
			get_tree().quit(1)
			return
	for stage: int in [0, 1]:
		_open_case()
		var case_authority := SUPPORT.authority_snapshot()
		SUPPORT.restore_stage(stage)
		_freeze_phases()
		if not await _shot(output, CommissioningManager.STAGE_LABELS[stage].to_lower() + "-case-panel"):
			return
		if SUPPORT.authority_snapshot() != case_authority:
			push_error("Stage switch with open Case Panel mutated authority.")
			get_tree().quit(1)
			return
	CaseManager.reset_cases()
	if get_window().size == Vector2i(1920, 1080):
		SimulationManager.set_machine_enabled(&"basic_scanner", false)
		for stage: int in [0, 3]:
			SUPPORT.restore_stage(stage)
			_freeze_phases()
			if not await _shot(output, "runtime-disabled-scanner-" + CommissioningManager.STAGE_LABELS[stage].to_lower()):
				return
		SimulationManager.set_machine_enabled(&"basic_scanner", true)
	var metadata := {"godot": Engine.get_version_info(), "adapter": RenderingServer.get_video_adapter_name(), "renderer": RenderingServer.get_current_rendering_method(), "physical_size": str(get_window().size), "logical_size": str(get_window().content_scale_size), "animation_phase": "all machine phases and conveyor time zero; presentation frozen for deterministic proof", "captures": _measurements}
	var file := FileAccess.open(output.path_join("metadata.json"), FileAccess.WRITE)
	file.store_string(JSON.stringify(metadata, "\t"))
	print("Actual progressive room captures saved: " + output)
	get_tree().quit(0)


func _shot(output: String, name_value: String) -> bool:
	await get_tree().process_frame
	await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var image := get_viewport().get_texture().get_image()
	if image.get_size() != get_window().size or image.save_png(output.path_join(name_value + ".png")) != OK:
		push_error("Capture dimensions/write failed.")
		get_tree().quit(1)
		return false
	var parity := "not applicable"
	if name_value == "full_line_online" and get_window().size == Vector2i(1920, 1080):
		var baseline := Image.load_from_file("res://docs/screenshots/progressive-room-states/base-full-line.png")
		if baseline.get_size() != image.get_size() or baseline.get_data() != image.get_data():
			push_error("Full-line render differs from exact pre-PR baseline.")
			get_tree().quit(1)
			return false
		parity = "pixel-identical to exact base 4714f71f912e718818b5db4871bfe2eee18d05fb"
	_measurements.append({"capture": name_value, "stage": CommissioningManager.get_stage(), "baseline_parity": parity, "draw_calls": int(Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)), "primitives": int(Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME)), "texture_memory_bytes": int(Performance.get_monitor(Performance.RENDER_TEXTURE_MEM_USED)), "environment": _room.get_node("%EnvironmentArt").get_commissioning_snapshot(), "scanner": _room.get_node("%BasicScanner").get_state_snapshot(), "sorter": _room.get_node("%BasicSorter").get_state_snapshot(), "intake": _room.get_node("%ArchiveIntake").get_state_snapshot()})
	print("Rendered %s %s: full-line parity=%s" % [name_value, get_window().size, parity])
	return true
