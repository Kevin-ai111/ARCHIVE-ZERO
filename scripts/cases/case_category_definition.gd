class_name CaseCategoryDefinition
extends Resource

@export var category_id: StringName
@export var display_name: String


func is_valid() -> bool:
	return String(category_id).is_valid_identifier() and not display_name.strip_edges().is_empty()
