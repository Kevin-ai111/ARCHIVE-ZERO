class_name ArchiveRoomEnvironmentVisual
extends Node2D

const POLISH_TEXTURE_COUNT := 19
const POLISH_DECODED_TEXTURE_BYTES := 9_894_208
# Nine retained Phase 4E textures plus the nineteen Phase 4I textures.
const DECODED_TEXTURE_BYTES := 11_397_016

@onready var light_cones: Node2D = %LightCones
@onready var lamp_housings: Node2D = %LampHousings
@onready var wall_sconces: Node2D = %WallSconces
@onready var floor_reflections: Node2D = %FloorReflections


func set_light_housings_visible(value: bool) -> void:
	lamp_housings.visible = value


func set_light_cones_visible(value: bool) -> void:
	light_cones.visible = value


func set_floor_reflections_visible(value: bool) -> void:
	floor_reflections.visible = value
	%CyanBounce.visible = value


func set_wall_sconces_visible(value: bool) -> void:
	wall_sconces.visible = value


func set_haze_visible(value: bool) -> void:
	%Haze.visible = value


func get_layout_snapshot() -> Dictionary:
	var sprites: Array[Dictionary] = []
	_collect_sprites(self, sprites)
	var textures := {}
	for sprite in sprites:
		textures[sprite["texture"]] = true
	return {
		"runtime_texture_count": textures.size(),
		"polish_texture_count": POLISH_TEXTURE_COUNT,
		"polish_decoded_texture_bytes": POLISH_DECODED_TEXTURE_BYTES,
		"decoded_texture_bytes": DECODED_TEXTURE_BYTES,
		"sprites": sprites,
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
		"signage_positions": _child_positions(%Signage),
		"foreground_positions": _child_positions(%ForegroundRails),
		"shadow_positions": _child_positions(%MachineShadows),
	}


func _collect_sprites(parent: Node, result: Array[Dictionary]) -> void:
	for child in parent.get_children():
		if child is Sprite2D:
			var sprite := child as Sprite2D
			var effective_z := sprite.z_index
			var ancestor := sprite.get_parent() as CanvasItem
			var relative := sprite.z_as_relative
			while relative and ancestor != null:
				effective_z += ancestor.z_index
				relative = ancestor.z_as_relative
				ancestor = ancestor.get_parent() as CanvasItem
			result.append({
				"texture": sprite.texture.resource_path,
				"position": sprite.global_position,
				"scale": sprite.global_scale,
				"z": effective_z,
				"centered": sprite.centered,
				"absolute_z": not sprite.z_as_relative,
			})
		_collect_sprites(child, result)


func _child_positions(parent: Node2D) -> PackedVector2Array:
	var positions := PackedVector2Array()
	for child in parent.get_children():
		if child is Node2D:
			positions.append((child as Node2D).position)
	return positions
