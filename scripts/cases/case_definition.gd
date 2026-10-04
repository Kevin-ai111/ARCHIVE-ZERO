class_name CaseDefinition
extends Resource

const NORMAL: StringName = &"NORMAL"
const MANUAL_REVIEW: StringName = &"MANUAL_REVIEW"

@export var case_id: StringName
@export var item_id: StringName
@export var found_location: String
@export var found_time_label: String
@export_multiline var condition_text: String
@export var expected_category_id: StringName
@export var routing_policy: StringName = NORMAL


func is_valid() -> bool:
	return (
		String(case_id).is_valid_identifier()
		and String(item_id).is_valid_identifier()
		and String(expected_category_id).is_valid_identifier()
		and not found_location.strip_edges().is_empty()
		and not found_time_label.strip_edges().is_empty()
		and not condition_text.strip_edges().is_empty()
		and routing_policy in [NORMAL, MANUAL_REVIEW]
	)
