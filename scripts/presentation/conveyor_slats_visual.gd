class_name ConveyorSlatsVisual
extends Node2D

const TILE_DISPLAY_SIZE := Vector2(64.0, 44.0)

@export var slat_texture: Texture2D
@export var window_rect := Rect2(476.0, 716.0, 1152.0, 44.0)

var scroll_offset := 0.0
var redraw_count := 0


func _ready() -> void:
	queue_redraw()


func set_scroll_offset(value: float) -> void:
	var wrapped := fposmod(value, TILE_DISPLAY_SIZE.x)
	if is_equal_approx(scroll_offset, wrapped):
		return
	scroll_offset = wrapped
	queue_redraw()


func get_geometry_snapshot() -> Dictionary:
	return {
		"window": window_rect,
		"tile_display_size": TILE_DISPLAY_SIZE,
		"texture_size": Vector2.ZERO if slat_texture == null else slat_texture.get_size(),
		"scroll_offset": scroll_offset,
		"redraw_count": redraw_count,
	}


func _draw() -> void:
	redraw_count += 1
	if slat_texture == null:
		return

	var tile_x := window_rect.position.x - scroll_offset
	while tile_x < window_rect.end.x:
		var tile_rect := Rect2(Vector2(tile_x, window_rect.position.y), TILE_DISPLAY_SIZE)
		var visible_rect := tile_rect.intersection(window_rect)
		if visible_rect.has_area():
			var source_rect := Rect2(
				(visible_rect.position - tile_rect.position) * 2.0,
				visible_rect.size * 2.0
			)
			draw_texture_rect_region(slat_texture, visible_rect, source_rect)
		tile_x += TILE_DISPLAY_SIZE.x
