class_name ScannerUpgrades
extends RefCounted

const MOTOR_I_ID: String = "scanner_motor_1"
const DEFINITIONS: Dictionary = {
	MOTOR_I_ID: {
		"name": "Scanner Motor I",
		"cost": 50,
		"throughput_multiplier": 1.25,
	},
}


static func get_definition(upgrade_id: String) -> Dictionary:
	return DEFINITIONS.get(upgrade_id, {}).duplicate(true)


static func get_scanner_multiplier(owned_upgrades: Array[String]) -> float:
	var multiplier: float = 1.0
	for upgrade_id: String in owned_upgrades:
		var definition: Dictionary = DEFINITIONS.get(upgrade_id, {})
		multiplier *= float(definition.get("throughput_multiplier", 1.0))
	return multiplier
