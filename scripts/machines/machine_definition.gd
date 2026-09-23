class_name MachineDefinition
extends Resource

@export var id: StringName
@export var display_name: String
@export_multiline var description: String
@export_range(0.0, 1_000_000.0, 0.01, "or_greater") var base_processing_rate: float = 0.0
@export_range(0, 1_000_000, 1, "or_greater") var purchase_cost: int = 0


func is_valid() -> bool:
	return (
		not id.is_empty()
		and not display_name.is_empty()
		and is_finite(base_processing_rate)
		and base_processing_rate >= 0.0
		and purchase_cost >= 0
	)
