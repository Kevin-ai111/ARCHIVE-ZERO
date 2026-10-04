extends Node

# Explicit developer-only fixture. No automatic case creation in either scene.
# Graphical evidence: -- --capture=true --size=1280x720 --out=C:/temp/case-proof
const ROOM := preload("res://scenes/world/archive_room.tscn")
var _room: Node2D
var _panel: ManualCasePanel
var _toolbar: CanvasLayer
var _options := {}


func _ready() -> void:
	SimulationManager.set_process(false)
	GameState.set_process(false)
	for argument: String in OS.get_cmdline_user_args():
		var pair := argument.trim_prefix("--").split("=", true, 1)
		if pair.size() == 2:
			_options[pair[0]] = pair[1]
	_room = ROOM.instantiate()
	add_child(_room)
	_panel = _room.get_node("CasePanel") as ManualCasePanel
	_toolbar = CanvasLayer.new()
	_toolbar.layer = 3
	add_child(_toolbar)
	var labels := ["QA: CASE #0001", "QA: CASE #0010", "REOPEN CASE"]
	for index: int in range(3):
		var button := Button.new()
		button.position = Vector2(32 + index * 310, 144)
		button.size = Vector2(292, 52)
		button.text = labels[index]
		button.add_theme_font_size_override("font_size", 22)
		_toolbar.add_child(button)
		if index < 2:
			button.pressed.connect(_activate.bind(&"CASE_0001" if index == 0 else &"CASE_0010"))
		else:
			button.pressed.connect(_panel.open_panel)
	var label := Label.new()
	label.position = Vector2(32, 204)
	label.text = "DEVELOPMENT QA ONLY · production clock frozen · no live-save writes"
	label.add_theme_font_size_override("font_size", 18)
	_toolbar.add_child(label)
	if _options.has("capture"):
		call_deferred("_capture")


func _activate(case_id: StringName) -> void:
	CaseManager.reset_cases()
	CaseManager.enqueue_case(case_id)
	CaseManager.activate_next_case()


func _capture() -> void:
	if DisplayServer.get_name() == "headless":
		push_error("Graphical proof requires a real Godot renderer.")
		get_tree().quit(1)
		return
	var dimensions := String(_options.get("size", "1920x1080")).split("x")
	get_window().borderless = true
	get_window().position = Vector2i.ZERO
	get_window().size = Vector2i(int(dimensions[0]), int(dimensions[1]))
	for _frame: int in range(20):
		await get_tree().process_frame
	_toolbar.hide()
	var output := String(_options.get("out", "user://manual-case-proof"))
	DirAccess.make_dir_recursive_absolute(output)
	_activate(&"CASE_0001")
	await _shot(output, "active")
	await _click(_panel.inspect_button)
	if CaseManager.get_active_case().get_state() != CaseProgress.State.INSPECTED:
		push_error("Graphical Inspect click failed.")
		get_tree().quit(1)
		return
	await _shot(output, "inspected")
	await _click(_panel.category_buttons[&"ELEC"] as Button)
	if CaseManager.get_active_case().get_selected_category_id() != &"ELEC":
		push_error("Graphical category click failed.")
		get_tree().quit(1)
		return
	await _shot(output, "classified-wrong-elec")
	_panel.close_panel()
	_panel.open_panel()
	await _shot(output, "reopened-classified")
	await _click(_panel.release_button)
	if CaseManager.has_active_case() or _panel.panel.visible:
		push_error("Graphical Release click failed.")
		get_tree().quit(1)
		return
	await _shot(output, "archived-closed")
	_activate(&"CASE_0010")
	await _shot(output, "manual-review-active")
	await _click(_panel.inspect_button)
	await _shot(output, "manual-review-inspected")
	if CaseManager.get_active_case().get_state() != CaseProgress.State.INSPECTED or CaseManager.get_case_progress(&"CASE_0001") != null:
		push_error("Graphical mouse fixture did not reach expected final authority.")
		get_tree().quit(1)
		return
	var metadata := {"godot": Engine.get_version_info(), "adapter": RenderingServer.get_video_adapter_name(), "renderer": RenderingServer.get_current_rendering_method(), "physical_size": str(get_window().size), "logical_size": str(get_window().content_scale_size), "input_source": "Native Godot Viewport mouse events", "case_save_version": CaseManager.CASE_SAVE_VERSION, "global_save_version": SaveManager.SAVE_VERSION, "draw_calls": Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME), "texture_memory_bytes": Performance.get_monitor(Performance.RENDER_TEXTURE_MEM_USED)}
	var file := FileAccess.open(output.path_join("runtime-metadata.json"), FileAccess.WRITE)
	file.store_string(JSON.stringify(metadata, "\t"))
	print("Actual Godot case-panel captures saved: " + output)
	get_tree().quit(0)


func _click(button: Button) -> void:
	var point := button.get_global_transform_with_canvas() * (button.size * 0.5)
	var motion := InputEventMouseMotion.new()
	motion.position = point
	motion.global_position = point
	get_viewport().push_input(motion, true)
	var event := InputEventMouseButton.new()
	event.button_index = MOUSE_BUTTON_LEFT
	event.position = point
	event.global_position = point
	event.pressed = true
	get_viewport().push_input(event, true)
	event = InputEventMouseButton.new()
	event.button_index = MOUSE_BUTTON_LEFT
	event.position = point
	event.global_position = point
	event.pressed = false
	get_viewport().push_input(event, true)
	await get_tree().process_frame


func _shot(output: String, state_name: String) -> void:
	await get_tree().process_frame
	await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var frame := get_viewport().get_texture().get_image()
	var expected := get_window().size
	if frame.get_size() != expected or frame.save_png(output.path_join(state_name + ".png")) != OK:
		push_error("Runtime capture size/write mismatch.")
		get_tree().quit(1)
