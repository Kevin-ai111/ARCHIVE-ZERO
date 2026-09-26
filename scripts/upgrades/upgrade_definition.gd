class_name UpgradeDefinition
extends Resource

@export var id: StringName
@export var display_name: String
@export var target_machine_id: StringName
@export_range(1, 1_000_000, 1, "or_greater") var cost: int = 1
@export_range(0.01, 1_000_000.0, 0.01, "or_greater") var capacity_multiplier: float = 1.0
@export_multiline var description: String


func is_valid() -> bool:
	return (
		not id.is_empty()
		and not display_name.is_empty()
		and not target_machine_id.is_empty()
		and cost > 0
		and is_finite(capacity_multiplier)
		and capacity_multiplier > 0.0
		and not description.is_empty()
	)
