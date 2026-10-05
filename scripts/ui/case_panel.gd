class_name ManualCasePanel
extends CanvasLayer

const ASSET_ROOT := "res://assets/ui/case_panel/"
const TEXT := Color(0.87, 0.91, 0.92)
const CYAN := Color(0.35, 0.82, 0.87)
const MUTED := Color(0.52, 0.63, 0.67)
const AMBER := Color(0.95, 0.72, 0.34)
const CATEGORY_IDS: Array[StringName] = [&"PERS", &"ELEC", &"DOCS", &"BAG"]
const CATEGORY_NAMES := ["Personal Items", "Electronics", "Documents", "Bags / Containers"]

var category_buttons: Dictionary = {}
var inspect_button: Button
var release_button: Button
var close_button: Button
var item_texture: TextureRect
var case_number: Label
var status: Label
var item_name: Label
var found: Label
var time: Label
var condition: Label
var material: Label
var identifier: Label
var risk: Label
var pending: Label
var inspection_check: TextureRect
var manual_review: Control
var _buttons: Array[Button] = []

@onready var panel: Control = $Panel


func _ready() -> void:
	_build_controls()
	CaseManager.active_case_changed.connect(_on_active_case_changed)
	CaseManager.case_progress_changed.connect(_on_case_progress_changed)
	refresh_from_authority()
	# Instantiation after activation reconstructs the existing active case too.
	if CaseManager.has_active_case():
		open_panel()


func _exit_tree() -> void:
	CaseManager.active_case_changed.disconnect(_on_active_case_changed)
	CaseManager.case_progress_changed.disconnect(_on_case_progress_changed)


func open_panel() -> bool:
	refresh_from_authority()
	if not CaseManager.has_active_case():
		return false
	panel.show()
	_focus_first_action()
	return true


func close_panel() -> void:
	var focused := panel.get_viewport().gui_get_focus_owner()
	if focused != null and panel.is_ancestor_of(focused):
		focused.release_focus()
	panel.hide()


func _unhandled_key_input(event: InputEvent) -> void:
	if panel.visible and event.is_action_pressed("ui_cancel"):
		close_panel()
		get_viewport().set_input_as_handled()


func _on_active_case_changed() -> void:
	refresh_from_authority()
	if CaseManager.has_active_case():
		open_panel()


func _on_case_progress_changed(_case_id: StringName) -> void:
	# Refresh is read-only, including when a valid restore emits these signals.
	refresh_from_authority()


func refresh_from_authority() -> void:
	var progress: CaseProgress = CaseManager.get_active_case()
	if progress == null:
		close_panel()
		return
	var definition: CaseDefinition = CaseManager.get_case_definition(progress.get_case_id())
	var item: ArchiveItemDefinition = CaseManager.get_item_definition(definition.item_id)
	var previous_focus := panel.get_viewport().gui_get_focus_owner()
	var state := progress.get_state()
	case_number.text = "CASE #%s" % String(definition.case_id).trim_prefix("CASE_")
	status.text = "ACTIVE RECORD" if state == CaseProgress.State.ACTIVE else CaseProgress.STATE_LABELS[state]
	manual_review.visible = definition.routing_policy == CaseDefinition.MANUAL_REVIEW
	item_name.text = item.display_name
	item_name.tooltip_text = item.display_name
	found.text = definition.found_location
	time.text = definition.found_time_label
	condition.text = definition.condition_text
	item_texture.texture = CaseItemPresentationCatalog.get_texture(definition.item_id)
	var inspected := state >= CaseProgress.State.INSPECTED
	pending.visible = not inspected
	material.visible = inspected
	identifier.visible = inspected
	risk.visible = inspected
	for label_name: String in ["MaterialLabel", "IdentifierLabel", "RiskLabel"]:
		panel.get_node(label_name).visible = inspected
	material.text = definition.inspection_material if inspected else ""
	identifier.text = definition.inspection_identifier if inspected else ""
	risk.text = definition.inspection_risk if inspected else ""
	inspection_check.visible = inspected
	inspect_button.disabled = state != CaseProgress.State.ACTIVE
	release_button.disabled = state != CaseProgress.State.CLASSIFIED
	for category_id: StringName in CATEGORY_IDS:
		var button := category_buttons[category_id] as Button
		var selected := progress.get_selected_category_id() == category_id
		button.disabled = state != CaseProgress.State.INSPECTED
		button.set_meta("selected", selected)
		(button.get_node("Code") as Label).text = ("✓ " if selected else "") + String(category_id)
	_update_focus_chain()
	if panel.visible and previous_focus != null and panel.is_ancestor_of(previous_focus) and previous_focus.focus_mode == Control.FOCUS_NONE:
		_focus_first_action()
	for button: Button in _buttons:
		_update_button_surface(button)


func _inspect() -> void:
	if panel.visible and not inspect_button.disabled:
		CaseManager.mark_active_case_inspected()


func _classify(category_id: StringName) -> void:
	if panel.visible and not (category_buttons[category_id] as Button).disabled:
		CaseManager.classify_active_case(category_id)


func _archive() -> void:
	if panel.visible and not release_button.disabled:
		CaseManager.archive_active_case()


func _build_controls() -> void:
	_surface(panel, "PanelSurface", Rect2(0, 0, 824, 708), "panel", Vector4(18, 18, 18, 18))
	_surface(panel, "HeaderSurface", Rect2(10, 10, 804, 56), "header", Vector4(20, 14, 20, 14))
	case_number = _label(panel, "CaseNumber", Rect2(24, 20, 212, 36), "", 30)
	_surface(panel, "StatusSurface", Rect2(244, 20, 268, 36), "status_badge", Vector4(14, 8, 14, 8))
	status = _label(panel, "Status", Rect2(256, 20, 244, 36), "", 18, AMBER)
	manual_review = Control.new()
	manual_review.name = "ManualReview"
	manual_review.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_child(manual_review)
	_surface(manual_review, "Strip", Rect2(530, 20, 204, 36), "manual_review_strip", Vector4(16, 8, 16, 8))
	_label(manual_review, "Label", Rect2(540, 20, 184, 36), "MANUAL REVIEW", 18, AMBER)
	close_button = _button("Close", Rect2(752, 14, 56, 48), "", false)
	close_button.tooltip_text = "Close case panel (Escape)"
	var close_icon := _texture(close_button, "CloseIcon", Rect2(8, 4, 40, 40), load(ASSET_ROOT + "AZ_CASE_close_button_2x.png"))
	close_icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	close_button.pressed.connect(close_panel)
	_surface(panel, "ItemFrame", Rect2(24, 84, 294, 294), "item_frame", Vector4(18, 18, 18, 18))
	_label(panel, "ItemHeading", Rect2(38, 88, 266, 26), "LOST ITEM", 18, CYAN)
	item_texture = _texture(panel, "ItemTexture", Rect2(43, 114, 256, 256), null)
	_surface(panel, "InformationSurface", Rect2(338, 84, 462, 228), "section", Vector4(16, 16, 16, 16))
	_label(panel, "InformationHeading", Rect2(352, 92, 434, 26), "CASE INFORMATION", 18, CYAN)
	_label(panel, "ItemLabel", Rect2(354, 120, 104, 31), "ITEM", 18, CYAN)
	item_name = _label(panel, "ItemName", Rect2(460, 120, 324, 31), "", 22)
	item_name.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	# Godot's shaped 22px text needs 31 + 3 line spacing + 31 = 65px.
	# Leave 3px safety room; count visible lines in the regression, not just lines.
	_label(panel, "FoundLabel", Rect2(354, 151, 104, 68), "FOUND", 18, CYAN)
	found = _label(panel, "Found", Rect2(460, 151, 324, 68), "", 22)
	found.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	found.max_lines_visible = 2
	_label(panel, "TimeLabel", Rect2(354, 219, 104, 31), "TIME", 18, CYAN)
	time = _label(panel, "Time", Rect2(460, 219, 324, 31), "", 22)
	# The longest authored conditions need the full value width at body size 22.
	# A stacked label/value preserves all text without shrinking typography.
	_label(panel, "ConditionLabel", Rect2(354, 250, 432, 26), "CONDITION", 18, CYAN)
	condition = _label(panel, "Condition", Rect2(354, 276, 432, 32), "", 22)
	_surface(panel, "ScanSurface", Rect2(338, 316, 462, 140), "section", Vector4(16, 16, 16, 16))
	_label(panel, "ScanHeading", Rect2(352, 324, 434, 26), "SCAN DATA", 18, CYAN)
	pending = _label(panel, "Pending", Rect2(354, 360, 424, 48), "PENDING", 22, MUTED)
	_label(panel, "MaterialLabel", Rect2(354, 352, 108, 28), "MATERIAL", 18, CYAN)
	material = _label(panel, "Material", Rect2(468, 352, 312, 28), "", 22)
	_label(panel, "IdentifierLabel", Rect2(354, 384, 108, 28), "IDENTIFIER", 18, CYAN)
	identifier = _label(panel, "Identifier", Rect2(468, 384, 312, 28), "", 22)
	_label(panel, "RiskLabel", Rect2(354, 416, 108, 28), "RISK", 18, CYAN)
	risk = _label(panel, "Risk", Rect2(468, 416, 312, 28), "", 22)
	inspection_check = _texture(panel, "InspectionCheck", Rect2(754, 324, 26, 26), load(ASSET_ROOT + "AZ_CASE_check_indicator_2x.png"))
	inspection_check.tooltip_text = "Inspection complete"
	inspect_button = _button("Inspect", Rect2(24, 396, 294, 60), "INSPECT ITEM", false)
	inspect_button.pressed.connect(_inspect)
	_surface(panel, "ClassificationSurface", Rect2(24, 464, 776, 156), "section", Vector4(16, 16, 16, 16))
	_label(panel, "ClassificationHeading", Rect2(38, 474, 744, 26), "CLASSIFY ITEM", 18, CYAN)
	for index: int in CATEGORY_IDS.size():
		var category_id := CATEGORY_IDS[index]
		var button := _button(String(category_id), Rect2(38 + index * 190, 504, 174, 104), "", true)
		category_buttons[category_id] = button
		button.tooltip_text = CATEGORY_NAMES[index]
		_texture(button, "Icon", Rect2(67, 8, 40, 40), load(ASSET_ROOT + "AZ_CASE_icon_%s_2x.png" % String(category_id).to_lower()))
		var code := _label(button, "Code", Rect2(4, 48, 166, 28), String(category_id), 20)
		code.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		var subtitle := _label(button, "Subtitle", Rect2(4, 76, 166, 26), CATEGORY_NAMES[index], 18)
		subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		button.pressed.connect(_classify.bind(category_id))
	release_button = _button("Release", Rect2(24, 632, 776, 60), "RELEASE TO ARCHIVE", false)
	release_button.pressed.connect(_archive)
	var divider := _texture(panel, "Divider", Rect2(24, 452, 776, 4), load(ASSET_ROOT + "AZ_CASE_divider_h_2x.png"))
	divider.stretch_mode = TextureRect.STRETCH_SCALE


func _label(parent: Node, node_name: String, rect: Rect2, text_value: String, font_size: int, color: Color = TEXT) -> Label:
	var label := Label.new()
	label.name = node_name
	label.position = rect.position
	label.size = rect.size
	label.text = text_value
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.clip_text = true
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(label)
	return label


func _texture(parent: Node, node_name: String, rect: Rect2, texture: Texture2D) -> TextureRect:
	var view := TextureRect.new()
	view.name = node_name
	view.position = rect.position
	view.size = rect.size
	view.texture = texture
	view.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	view.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	view.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(view)
	return view


func _surface(parent: Node, node_name: String, rect: Rect2, asset: String, margins: Vector4) -> NinePatchRect:
	var surface := NinePatchRect.new()
	surface.name = node_name
	surface.position = rect.position
	# Patch margins are texture pixels (2x). Drawing the surface at 0.5 keeps
	# border thickness logical/native while text and hit targets stay unscaled.
	surface.size = rect.size * 2.0
	surface.scale = Vector2(0.5, 0.5)
	surface.texture = load(ASSET_ROOT + "AZ_CASE_%s_9patch_2x.png" % asset)
	surface.patch_margin_left = int(margins.x * 2)
	surface.patch_margin_top = int(margins.y * 2)
	surface.patch_margin_right = int(margins.z * 2)
	surface.patch_margin_bottom = int(margins.w * 2)
	surface.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(surface)
	return surface


func _button(node_name: String, rect: Rect2, caption: String, category: bool) -> Button:
	var button := Button.new()
	button.name = node_name
	button.position = rect.position
	button.size = rect.size
	button.clip_contents = true
	button.set_meta("category", category)
	button.set_meta("selected", false)
	for state: String in ["normal", "hover", "pressed", "disabled", "focus"]:
		button.add_theme_stylebox_override(state, StyleBoxEmpty.new())
	panel.add_child(button)
	_surface(button, "Surface", Rect2(Vector2.ZERO, rect.size), "category_base" if category else "primary_button_base", Vector4(14, 14, 14, 14) if category else Vector4(20, 14, 20, 14))
	if not caption.is_empty():
		var label := _label(button, "Caption", Rect2(8, 4, rect.size.x - 16, rect.size.y - 8), caption, 22)
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var focus := Panel.new()
	focus.name = "FocusOutline"
	focus.size = rect.size
	focus.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var outline := StyleBoxFlat.new()
	outline.bg_color = Color.TRANSPARENT
	outline.border_color = CYAN
	outline.set_border_width_all(3)
	outline.corner_radius_top_left = 8
	outline.corner_radius_bottom_right = 8
	focus.add_theme_stylebox_override("panel", outline)
	button.add_child(focus)
	_buttons.append(button)
	for signal_name: String in ["mouse_entered", "mouse_exited", "button_down", "button_up", "focus_entered", "focus_exited"]:
		button.connect(signal_name, _update_button_surface.bind(button))
	return button


func _update_button_surface(button: Button) -> void:
	var category: bool = button.get_meta("category")
	var selected: bool = button.get_meta("selected")
	var suffix := "base"
	if selected:
		suffix = "selected"
	elif button.disabled:
		suffix = "disabled"
	elif button.is_pressed() and not category:
		suffix = "pressed"
	elif button.is_hovered() or button.has_focus():
		suffix = "hover"
	var surface := button.get_node("Surface") as NinePatchRect
	surface.texture = load(ASSET_ROOT + "AZ_CASE_%s_%s_9patch_2x.png" % ["category" if category else "primary_button", suffix])
	surface.modulate = Color(0.8, 0.8, 0.8) if category and button.is_pressed() and not button.disabled else Color.WHITE
	(button.get_node("FocusOutline") as Panel).visible = button.has_focus() and not button.disabled
	if button.has_node("Caption"):
		(button.get_node("Caption") as Label).add_theme_color_override("font_color", MUTED if button.disabled else TEXT)


func _update_focus_chain() -> void:
	var available: Array[Button] = []
	for button: Button in _buttons:
		button.focus_mode = Control.FOCUS_NONE if button.disabled else Control.FOCUS_ALL
		if not button.disabled:
			available.append(button)
	for index: int in available.size():
		available[index].focus_next = available[index].get_path_to(available[(index + 1) % available.size()])
		available[index].focus_previous = available[index].get_path_to(available[(index - 1 + available.size()) % available.size()])


func _focus_first_action() -> void:
	if not inspect_button.disabled:
		inspect_button.grab_focus()
	elif not release_button.disabled:
		release_button.grab_focus()
	else:
		(category_buttons[&"PERS"] as Button).grab_focus()
