class_name ArchiveDirectiveDefinition
extends Resource

const VALID_EVIDENCE_FIELDS: Array[StringName] = [
	&"item_id", &"inspection_material", &"inspection_identifier", &"inspection_risk",
]

@export var directive_id: StringName
@export var title: String
@export_multiline var display_text: String
@export var priority: int
@export var target_category_id: StringName
@export var evidence_field: StringName
@export var match_values: PackedStringArray


func is_valid(category_ids: Array[StringName]) -> bool:
	if (
		not String(directive_id).is_valid_identifier()
		or title.strip_edges().is_empty()
		or display_text.strip_edges().is_empty()
		or priority < 0
		or target_category_id not in category_ids
		or evidence_field not in VALID_EVIDENCE_FIELDS
		or match_values.is_empty()
	):
		return false
	var seen := {}
	for value: String in match_values:
		var normalized := value.strip_edges().to_lower()
		if normalized.is_empty() or seen.has(normalized):
			return false
		seen[normalized] = true
	return true


func matches(case_definition: CaseDefinition) -> bool:
	if case_definition == null or evidence_field not in VALID_EVIDENCE_FIELDS:
		return false
	var evidence := String(case_definition.get(String(evidence_field))).strip_edges().to_lower()
	for value: String in match_values:
		if evidence == value.strip_edges().to_lower():
			return true
	return false
