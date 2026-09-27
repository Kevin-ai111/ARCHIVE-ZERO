class_name ConveyorPlaceholderVisual
extends Node2D

signal visuals_changed

const PARCEL_SIZE := Vector2(42.0, 30.0)
const BELT_TOP_OFFSET := 19.0
const BELT_TOP_LINE_WIDTH := 8.0
const BELT_ASSET_TOP_Y := 703.0
const BELT_MODULE_XS := [436.0, 476.0, 604.0, 732.0, 860.0, 988.0, 1116.0, 1244.0, 1372.0, 1500.0, 1628.0]
const BELT_MODULE_WIDTHS := [40.0, 128.0, 128.0, 128.0, 128.0, 128.0, 128.0, 128.0, 128.0, 128.0, 40.0]
const SUPPORT_XS := [468.0, 637.0, 806.0, 976.0, 1145.0, 1314.0, 1483.0, 1644.0]
const SUPPORT_TOP_Y := 770.0
const SLAT_WINDOW := Rect2(476.0, 716.0, 1152.0, 44.0)
const SLAT_SPEED := 90.0

@export var path_start_x := 436.0
@export var path_end_x := 1668.0
@export var item_path_y := 688.0
@export var ground_baseline_y := 920.0

var is_running := true
var displayed_throughput := 0.0
var _visual_time := 0.0

@onready var slat_overlay: ConveyorSlatsVisual = %SlatOverlay


func _ready() -> void:
	set_process(is_running)
	_update_slat_overlay()


func _process(delta: float) -> void:
	advance_visuals(delta)


func set_visual_state(running: bool, throughput: float) -> void:
	is_running = running
	displayed_throughput = maxf(throughput, 0.0)
	set_process(is_running)
	_update_slat_overlay()
	visuals_changed.emit()


func advance_visuals(delta: float) -> void:
	if not is_running or delta <= 0.0:
		return
	_visual_time += delta
	_update_slat_overlay()
	visuals_changed.emit()


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
		"module_xs": BELT_MODULE_XS,
		"module_widths": BELT_MODULE_WIDTHS,
		"support_xs": SUPPORT_XS,
		"support_top_y": SUPPORT_TOP_Y,
		"slat_window": SLAT_WINDOW,
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
		"asset_top_y": BELT_ASSET_TOP_Y,
		"assembled_width": _sum_module_widths(),
		"slat_offset": get_slat_offset(),
	}


func get_slat_offset() -> float:
	return fposmod(_visual_time * SLAT_SPEED, ConveyorSlatsVisual.TILE_DISPLAY_SIZE.x)


func _update_slat_overlay() -> void:
	if is_node_ready() and slat_overlay != null:
		slat_overlay.set_scroll_offset(get_slat_offset())


func _sum_module_widths() -> float:
	var width := 0.0
	for module_width in BELT_MODULE_WIDTHS:
		width += module_width
	return width
