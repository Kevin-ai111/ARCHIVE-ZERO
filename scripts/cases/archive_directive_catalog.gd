class_name ArchiveDirectiveCatalog
extends RefCounted

const DEFAULT_DIRECTIVES: Array[Resource] = [
	preload("res://data/cases/directives/personal_items.tres"),
	preload("res://data/cases/directives/electronics.tres"),
	preload("res://data/cases/directives/documents.tres"),
	preload("res://data/cases/directives/bags_containers.tres"),
]

var _directives: Array[ArchiveDirectiveDefinition] = []
var _valid := false


func _init(
	directives: Array = DEFAULT_DIRECTIVES,
	category_ids: Array[StringName] = [&"PERS", &"ELEC", &"DOCS", &"BAG"]
) -> void:
	if not is_valid_catalog_data(directives, category_ids):
		return
	for value: ArchiveDirectiveDefinition in directives:
		_directives.append(value.duplicate(true) as ArchiveDirectiveDefinition)
	_directives.sort_custom(ArchiveDirectiveEvaluator._higher_priority_first)
	_valid = true


static func is_valid_catalog_data(directives: Array, category_ids: Array[StringName]) -> bool:
	if directives.is_empty() or category_ids.is_empty():
		return false
	var ids := {}
	var priorities := {}
	for value: Variant in directives:
		if not value is ArchiveDirectiveDefinition:
			return false
		var directive := value as ArchiveDirectiveDefinition
		if (
			not directive.is_valid(category_ids)
			or ids.has(directive.directive_id)
			or priorities.has(directive.priority)
		):
			return false
		ids[directive.directive_id] = true
		priorities[directive.priority] = true
	return true


func is_valid() -> bool:
	return _valid


func get_directives() -> Array[ArchiveDirectiveDefinition]:
	var result: Array[ArchiveDirectiveDefinition] = []
	for directive: ArchiveDirectiveDefinition in _directives:
		result.append(directive.duplicate(true) as ArchiveDirectiveDefinition)
	return result


func evaluate(case_definition: CaseDefinition) -> StringName:
	return ArchiveDirectiveEvaluator.evaluate(case_definition, _directives)
