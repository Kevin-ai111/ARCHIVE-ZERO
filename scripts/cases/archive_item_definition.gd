class_name ArchiveItemDefinition
extends Resource

@export var item_id: StringName
@export var display_name: String
@export var category_id: StringName
@export_multiline var description: String


func is_valid() -> bool:
	return (
		String(item_id).is_valid_identifier()
		and String(category_id).is_valid_identifier()
		and not display_name.strip_edges().is_empty()
		and not description.strip_edges().is_empty()
	)
