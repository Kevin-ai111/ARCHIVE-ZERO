extends RefCounted

# Measure the live, shaped Godot Label, not a guessed rectangle or source string.
# Calling get_line_count first ensures shaping before get_visible_line_count.
static func measure(label: Label) -> Dictionary:
	var total := label.get_line_count()
	var visible := label.get_visible_line_count()
	var required_height := 0.0
	for line: int in range(total):
		required_height += label.get_line_height(line)
	if total > 1:
		required_height += (total - 1) * label.get_theme_constant("line_spacing")
	required_height += label.get_theme_stylebox("normal").get_minimum_size().y
	var width := label.get_theme_font("font").get_string_size(label.text, HORIZONTAL_ALIGNMENT_LEFT, -1, label.get_theme_font_size("font_size")).x
	var fits_width := label.autowrap_mode != TextServer.AUTOWRAP_OFF or width <= label.size.x
	var complete := label.is_visible_in_tree() and total > 0 and visible == total and label.lines_skipped == 0 and label.visible_ratio == 1.0 and required_height <= label.size.y and fits_width
	return {"total_lines": total, "visible_lines": visible, "required_height": required_height, "available_height": label.size.y, "unwrapped_width": width, "available_width": label.size.x, "font_size": label.get_theme_font_size("font_size"), "complete": complete}


static func dynamic_labels(panel: ManualCasePanel) -> Array[Label]:
	return [panel.found, panel.time, panel.condition, panel.item_name, panel.material, panel.identifier, panel.risk]


static func secondary_labels(panel: ManualCasePanel) -> Array[Label]:
	var labels: Array[Label] = []
	for node_name: String in ["ItemHeading", "InformationHeading", "ItemLabel", "FoundLabel", "TimeLabel", "ConditionLabel", "ScanHeading", "MaterialLabel", "IdentifierLabel", "RiskLabel", "ClassificationHeading"]:
		labels.append(panel.panel.get_node(node_name) as Label)
	for category_id: StringName in ManualCasePanel.CATEGORY_IDS:
		labels.append(panel.category_buttons[category_id].get_node("Subtitle") as Label)
	return labels
