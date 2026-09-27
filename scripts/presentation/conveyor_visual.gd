class_name ConveyorPlaceholderVisual
extends Node2D

const PARCEL_SIZE := Vector2(42.0, 30.0)
const BELT_TOP_OFFSET := 19.0
const BELT_TOP_LINE_WIDTH := 8.0

@export var path_start_x := 436.0
@export var path_end_x := 1668.0
@export var item_path_y := 688.0
@export var ground_baseline_y := 920.0

var is_running := true
var displayed_throughput := 0.0
var _visual_time := 0.0


func _ready() -> void:
	queue_redraw()


func _process(delta: float) -> void:
	advance_visuals(delta)


func set_visual_state(running: bool, throughput: float) -> void:
	is_running = running
	displayed_throughput = maxf(throughput, 0.0)
	queue_redraw()


func advance_visuals(delta: float) -> void:
	if is_running:
		_visual_time += delta
	queue_redraw()


func get_item_positions() -> PackedVector2Array:
	var positions := PackedVector2Array()
	var path_length := path_end_x - path_start_x
	var speed := clampf(70.0 + displayed_throughput * 30.0, 70.0, 210.0)
	for index in range(5):
		var distance := fposmod(_visual_time * speed + float(index) * path_length / 5.0, path_length)
		positions.append(Vector2(path_start_x + distance, item_path_y))
	return positions


func get_layout_snapshot() -> Dictionary:
	return {
		"path_start_x": path_start_x,
		"path_end_x": path_end_x,
		"item_path_y": item_path_y,
		"ground_baseline_y": ground_baseline_y,
	}


func get_draw_geometry_snapshot() -> Dictionary:
	var parcel_bottom_y := item_path_y + PARCEL_SIZE.y * 0.5
	var belt_top_line_y := item_path_y + BELT_TOP_OFFSET
	var visible_belt_surface_y := belt_top_line_y - BELT_TOP_LINE_WIDTH * 0.5
	return {
		"parcel_size": PARCEL_SIZE,
		"parcel_bottom_y": parcel_bottom_y,
		"belt_top_line_y": belt_top_line_y,
		"belt_top_line_width": BELT_TOP_LINE_WIDTH,
		"visible_belt_surface_y": visible_belt_surface_y,
		"contact_gap": visible_belt_surface_y - parcel_bottom_y,
	}


func _draw() -> void:
	var geometry := get_draw_geometry_snapshot()
	var belt_top := float(geometry["belt_top_line_y"])
	var belt_height := 62.0
	draw_rect(Rect2(Vector2(path_start_x, belt_top), Vector2(path_end_x - path_start_x, belt_height)), Color("1a222c"), true)
	draw_line(Vector2(path_start_x, belt_top), Vector2(path_end_x, belt_top), Color("b4873e"), BELT_TOP_LINE_WIDTH)
	draw_line(Vector2(path_start_x, belt_top + belt_height), Vector2(path_end_x, belt_top + belt_height), Color("56616d"), 8.0)

	var slat_offset := fposmod(_visual_time * 90.0, 52.0) if is_running else 0.0
	var slat_x := path_start_x - 52.0 + slat_offset
	while slat_x <= path_end_x:
		draw_line(Vector2(slat_x, belt_top + 8.0), Vector2(slat_x + 26.0, belt_top + belt_height - 8.0), Color("6a7682"), 5.0)
		slat_x += 52.0

	for support_x in range(int(path_start_x) + 80, int(path_end_x), 180):
		draw_line(Vector2(support_x, belt_top + belt_height), Vector2(support_x, ground_baseline_y), Color("3d4853"), 15.0)
		draw_line(Vector2(support_x - 34.0, ground_baseline_y), Vector2(support_x + 34.0, ground_baseline_y), Color("3d4853"), 11.0)
