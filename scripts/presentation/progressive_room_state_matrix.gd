class_name ProgressiveRoomStateMatrix
extends RefCounted

# Exact Phase 5D-B matrix, translated once; no runtime JSON parsing.
# Rows: [visible, modulation RGBA, alpha multiplier] in Stage enum order.
const TARGETS := {
	"distant_background": ["DistantArchive/Backdrop"],
	"shelving": ["ArchiveShelving"],
	"haze": ["Haze"],
	"recess_lighting": ["BayRecessA","BayRecessB"],
	"service_door": ["ServiceDoor"],
	"cable_runs": ["PolishCables"],
	"signage": ["Signage"],
	"floor_wear": ["FloorWear"],
	"service_markings": ["ServiceMarkings"],
	"scanner_cyan_bounce": ["CyanBounce/Art_14_0"],
	"intake_cyan_bounce": ["CyanBounce/Art_14_1"],
	"optional_sconces": ["WallSconces"],
	"foreground_rails": ["ForegroundRails"],
	"pendant_housing_1": ["LampHousings/Art_7_0"],
	"light_cone_1": ["LightCones/Art_8_0"],
	"machine_shadow_1": ["MachineShadows/Art_11_0"],
	"floor_light_pool_1": ["FloorReflections/Art_13_0"],
	"pendant_housing_2": ["LampHousings/Art_7_1"],
	"light_cone_2": ["LightCones/Art_8_1"],
	"machine_shadow_2": ["MachineShadows/Art_11_1"],
	"floor_light_pool_2": ["FloorReflections/Art_13_1"],
	"pendant_housing_3": ["LampHousings/Art_7_2"],
	"light_cone_3": ["LightCones/Art_8_2"],
	"machine_shadow_3": ["MachineShadows/Art_11_2"],
	"floor_light_pool_3": ["FloorReflections/Art_13_2"],
	"pendant_housing_4": ["LampHousings/Art_7_3"],
	"light_cone_4": ["LightCones/Art_8_3"],
	"machine_shadow_4": ["MachineShadows/Art_11_3"],
	"floor_light_pool_4": ["FloorReflections/Art_13_3"],
}

const VALUES := {
	"distant_background": [
		[true, Color(0.82, 0.88, 0.94, 1), 0.86],
		[true, Color(0.88, 0.92, 0.96, 1), 0.9],
		[true, Color(0.94, 0.96, 0.98, 1), 0.96],
		[true, Color(1, 1, 1, 1), 1],
	],
	"shelving": [
		[true, Color(0.82, 0.88, 0.94, 1), 0.72],
		[true, Color(0.88, 0.92, 0.96, 1), 0.8],
		[true, Color(0.94, 0.96, 0.98, 1), 0.9],
		[true, Color(1, 1, 1, 1), 1],
	],
	"haze": [
		[true, Color(0.82, 0.88, 0.94, 1), 0.22],
		[true, Color(0.88, 0.92, 0.96, 1), 0.38],
		[true, Color(0.94, 0.96, 0.98, 1), 0.68],
		[true, Color(1, 1, 1, 1), 1],
	],
	"recess_lighting": [
		[true, Color(0.82, 0.88, 0.94, 1), 0.38],
		[true, Color(0.88, 0.92, 0.96, 1), 0.55],
		[true, Color(0.94, 0.96, 0.98, 1), 0.78],
		[true, Color(1, 1, 1, 1), 1],
	],
	"service_door": [
		[true, Color(0.62, 0.68, 0.72, 1), 0.58],
		[true, Color(0.62, 0.68, 0.72, 1), 0.62],
		[true, Color(0.88, 0.92, 0.96, 1), 0.76],
		[true, Color(1, 1, 1, 1), 1],
	],
	"cable_runs": [
		[true, Color(0.82, 0.88, 0.94, 1), 0.72],
		[true, Color(0.88, 0.92, 0.96, 1), 0.8],
		[true, Color(0.94, 0.96, 0.98, 1), 0.9],
		[true, Color(1, 1, 1, 1), 1],
	],
	"signage": [
		[true, Color(0.82, 0.88, 0.94, 1), 0.74],
		[true, Color(0.88, 0.92, 0.96, 1), 0.82],
		[true, Color(0.94, 0.96, 0.98, 1), 0.9],
		[true, Color(1, 1, 1, 1), 1],
	],
	"pendant_housing_1": [
		[true, Color(1, 1, 1, 1), 1],
		[true, Color(1, 1, 1, 1), 1],
		[true, Color(1, 1, 1, 1), 1],
		[true, Color(1, 1, 1, 1), 1],
	],
	"light_cone_1": [
		[true, Color(1, 1, 1, 1), 0.82],
		[true, Color(1, 1, 1, 1), 0.82],
		[true, Color(1, 1, 1, 1), 0.82],
		[true, Color(1, 1, 1, 1), 1],
	],
	"machine_shadow_1": [
		[true, Color(1, 1, 1, 1), 1],
		[true, Color(1, 1, 1, 1), 1],
		[true, Color(1, 1, 1, 1), 1],
		[true, Color(1, 1, 1, 1), 1],
	],
	"floor_light_pool_1": [
		[true, Color(1, 1, 1, 1), 0.78],
		[true, Color(1, 1, 1, 1), 0.78],
		[true, Color(1, 1, 1, 1), 0.78],
		[true, Color(1, 1, 1, 1), 1],
	],
	"pendant_housing_2": [
		[true, Color(0.62, 0.68, 0.72, 1), 0.62],
		[true, Color(1, 1, 1, 1), 1],
		[true, Color(1, 1, 1, 1), 1],
		[true, Color(1, 1, 1, 1), 1],
	],
	"light_cone_2": [
		[false, Color(1, 1, 1, 1), 0],
		[true, Color(1, 1, 1, 1), 0.82],
		[true, Color(1, 1, 1, 1), 0.82],
		[true, Color(1, 1, 1, 1), 1],
	],
	"machine_shadow_2": [
		[true, Color(0.82, 0.88, 0.94, 1), 0.82],
		[true, Color(1, 1, 1, 1), 1],
		[true, Color(1, 1, 1, 1), 1],
		[true, Color(1, 1, 1, 1), 1],
	],
	"floor_light_pool_2": [
		[false, Color(1, 1, 1, 1), 0],
		[true, Color(1, 1, 1, 1), 0.78],
		[true, Color(1, 1, 1, 1), 0.78],
		[true, Color(1, 1, 1, 1), 1],
	],
	"pendant_housing_3": [
		[true, Color(0.62, 0.68, 0.72, 1), 0.62],
		[true, Color(0.62, 0.68, 0.72, 1), 0.62],
		[true, Color(1, 1, 1, 1), 1],
		[true, Color(1, 1, 1, 1), 1],
	],
	"light_cone_3": [
		[false, Color(1, 1, 1, 1), 0],
		[false, Color(1, 1, 1, 1), 0],
		[true, Color(1, 1, 1, 1), 0.82],
		[true, Color(1, 1, 1, 1), 1],
	],
	"machine_shadow_3": [
		[true, Color(0.82, 0.88, 0.94, 1), 0.82],
		[true, Color(0.82, 0.88, 0.94, 1), 0.82],
		[true, Color(1, 1, 1, 1), 1],
		[true, Color(1, 1, 1, 1), 1],
	],
	"floor_light_pool_3": [
		[false, Color(1, 1, 1, 1), 0],
		[false, Color(1, 1, 1, 1), 0],
		[true, Color(1, 1, 1, 1), 0.78],
		[true, Color(1, 1, 1, 1), 1],
	],
	"pendant_housing_4": [
		[true, Color(0.62, 0.68, 0.72, 1), 0.62],
		[true, Color(0.62, 0.68, 0.72, 1), 0.62],
		[true, Color(0.62, 0.68, 0.72, 1), 0.62],
		[true, Color(1, 1, 1, 1), 1],
	],
	"light_cone_4": [
		[false, Color(1, 1, 1, 1), 0],
		[false, Color(1, 1, 1, 1), 0],
		[false, Color(1, 1, 1, 1), 0],
		[true, Color(1, 1, 1, 1), 1],
	],
	"machine_shadow_4": [
		[true, Color(0.82, 0.88, 0.94, 1), 0.82],
		[true, Color(0.82, 0.88, 0.94, 1), 0.82],
		[true, Color(0.82, 0.88, 0.94, 1), 0.82],
		[true, Color(1, 1, 1, 1), 1],
	],
	"floor_light_pool_4": [
		[false, Color(1, 1, 1, 1), 0],
		[false, Color(1, 1, 1, 1), 0],
		[false, Color(1, 1, 1, 1), 0],
		[true, Color(1, 1, 1, 1), 1],
	],
	"floor_wear": [
		[true, Color(0.82, 0.88, 0.94, 1), 0.74],
		[true, Color(0.88, 0.92, 0.96, 1), 0.82],
		[true, Color(0.94, 0.96, 0.98, 1), 0.92],
		[true, Color(1, 1, 1, 1), 1],
	],
	"service_markings": [
		[true, Color(0.82, 0.88, 0.94, 1), 0.55],
		[true, Color(0.88, 0.92, 0.96, 1), 0.68],
		[true, Color(0.94, 0.96, 0.98, 1), 0.84],
		[true, Color(1, 1, 1, 1), 1],
	],
	"scanner_cyan_bounce": [
		[false, Color(1, 1, 1, 1), 0],
		[true, Color(0.82, 0.95, 1, 1), 0.52],
		[true, Color(0.88, 0.97, 1, 1), 0.68],
		[true, Color(1, 1, 1, 1), 1],
	],
	"intake_cyan_bounce": [
		[false, Color(1, 1, 1, 1), 0],
		[false, Color(1, 1, 1, 1), 0],
		[false, Color(1, 1, 1, 1), 0],
		[true, Color(1, 1, 1, 1), 1],
	],
	"optional_sconces": [
		[false, Color(1, 1, 1, 1), 0],
		[false, Color(1, 1, 1, 1), 0],
		[false, Color(1, 1, 1, 1), 0],
		[false, Color(1, 1, 1, 1), 0],
	],
	"foreground_rails": [
		[true, Color(0.82, 0.88, 0.94, 1), 0.82],
		[true, Color(0.88, 0.92, 0.96, 1), 0.88],
		[true, Color(0.94, 0.96, 0.98, 1), 0.94],
		[true, Color(1, 1, 1, 1), 1],
	],
}


static func get_value(element: String, stage: int) -> Dictionary:
	if not VALUES.has(element) or stage < 0 or stage >= 4:
		return {}
	var row: Array = VALUES[element][stage]
	var tint: Color = row[1]
	var effective := Color(tint.r, tint.g, tint.b, tint.a * float(row[2]))
	return {"visible": row[0], "modulate": effective, "alpha_multiplier": row[2]}
