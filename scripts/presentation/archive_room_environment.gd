class_name ArchiveRoomEnvironmentVisual
extends Node2D

const RUNTIME_TEXTURE_COUNT := 13
const DECODED_TEXTURE_BYTES := 6_985_816

@onready var light_cones: Node2D = %LightCones
@onready var lamp_housings: Node2D = %LampHousings
@onready var wall_sconces: Node2D = %WallSconces
@onready var floor_reflections: Node2D = %FloorReflections


func set_light_housings_visible(value: bool) -> void:
	lamp_housings.visible = value
	wall_sconces.visible = value


func set_light_cones_visible(value: bool) -> void:
	light_cones.visible = value


func set_floor_reflections_visible(value: bool) -> void:
	floor_reflections.visible = value


func get_layout_snapshot() -> Dictionary:
	return {
		"runtime_texture_count": RUNTIME_TEXTURE_COUNT,
		"decoded_texture_bytes": DECODED_TEXTURE_BYTES,
		"distant_z": %DistantArchive.z_index,
		"rear_wall_z": %RearWallTiles.z_index,
		"catwalk_z": %BackCatwalk.z_index,
		"roof_z": %Roof.z_index,
		"pillars_z": %Pillars.z_index,
		"cables_z": %CeilingCables.z_index,
		"decor_z": %BackgroundDecor.z_index,
		"light_cones_z": light_cones.z_index,
		"lamp_housings_z": lamp_housings.z_index,
		"floor_z": %FloorTiles.z_index,
		"floor_reflections_z": floor_reflections.z_index,
		"wall_tile_count": %RearWallTiles.get_child_count(),
		"catwalk_tile_count": %BackCatwalk.get_child_count(),
		"roof_tile_count": %Roof.get_child_count(),
		"floor_tile_count": %FloorTiles.get_child_count(),
		"pillar_positions": _child_positions(%Pillars),
		"lamp_positions": _child_positions(lamp_housings),
		"light_cone_positions": _child_positions(light_cones),
		"floor_reflection_positions": _child_positions(floor_reflections),
	}


func _child_positions(parent: Node2D) -> PackedVector2Array:
	var positions := PackedVector2Array()
	for child in parent.get_children():
		if child is Node2D:
			positions.append((child as Node2D).position)
	return positions
