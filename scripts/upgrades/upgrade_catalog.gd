class_name UpgradeCatalog
extends RefCounted

const SORTER_MOTOR_I_ID: String = "sorter_motor_1"
const SCANNER_MOTOR_I_ID: String = "scanner_motor_1"

const SORTER_MOTOR_I: UpgradeDefinition = preload("res://data/upgrades/sorter_motor_1.tres")
const SCANNER_MOTOR_I: UpgradeDefinition = preload("res://data/upgrades/scanner_motor_1.tres")
const DEFINITIONS: Array[UpgradeDefinition] = [SORTER_MOTOR_I, SCANNER_MOTOR_I]


static func get_definitions() -> Array[UpgradeDefinition]:
	var definitions: Array[UpgradeDefinition] = []
	definitions.assign(DEFINITIONS)
	return definitions


static func get_definition(upgrade_id: String) -> UpgradeDefinition:
	for definition: UpgradeDefinition in DEFINITIONS:
		if String(definition.id) == upgrade_id:
			return definition
	return null


static func has_upgrade_for_machine(machine_id: StringName) -> bool:
	for definition: UpgradeDefinition in DEFINITIONS:
		if definition.target_machine_id == machine_id:
			return true
	return false


static func get_capacity_multiplier(machine_id: StringName, owned_upgrade_ids: Array[String]) -> float:
	var multiplier: float = 1.0
	for upgrade_id: String in owned_upgrade_ids:
		var definition: UpgradeDefinition = get_definition(upgrade_id)
		if definition != null and definition.target_machine_id == machine_id:
			multiplier *= definition.capacity_multiplier
	return multiplier


static func are_valid_owned_upgrade_ids(value: Variant) -> bool:
	if typeof(value) != TYPE_ARRAY:
		return false

	var seen_ids: Dictionary = {}
	for upgrade_id: Variant in value:
		if typeof(upgrade_id) != TYPE_STRING or get_definition(upgrade_id) == null:
			return false
		if seen_ids.has(upgrade_id):
			return false
		seen_ids[upgrade_id] = true
	return true
