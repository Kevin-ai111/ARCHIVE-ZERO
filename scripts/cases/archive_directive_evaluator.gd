class_name ArchiveDirectiveEvaluator
extends RefCounted


static func evaluate(case_definition: CaseDefinition, directives: Array[ArchiveDirectiveDefinition]) -> StringName:
	if case_definition == null:
		return &""
	var ordered := directives.duplicate()
	ordered.sort_custom(_higher_priority_first)
	for directive: ArchiveDirectiveDefinition in ordered:
		if directive.matches(case_definition):
			return directive.target_category_id
	return &""


static func _higher_priority_first(left: ArchiveDirectiveDefinition, right: ArchiveDirectiveDefinition) -> bool:
	if left.priority == right.priority:
		return String(left.directive_id) < String(right.directive_id)
	return left.priority > right.priority
