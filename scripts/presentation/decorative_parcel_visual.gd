class_name DecorativeParcelVisual
extends Node2D

@export var conveyor_path: NodePath

@onready var conveyor: ConveyorPlaceholderVisual = get_node(conveyor_path) as ConveyorPlaceholderVisual


func _ready() -> void:
	if conveyor == null:
		push_error("DecorativeParcelVisual requires a ConveyorPlaceholderVisual source.")
	else:
		conveyor.visuals_changed.connect(queue_redraw)
	set_process(false)
	queue_redraw()


func _exit_tree() -> void:
	if conveyor != null and conveyor.visuals_changed.is_connected(queue_redraw):
		conveyor.visuals_changed.disconnect(queue_redraw)


func get_item_positions() -> PackedVector2Array:
	return PackedVector2Array() if conveyor == null else conveyor.get_item_positions()


func _draw() -> void:
	if conveyor == null:
		return
	for item_position in conveyor.get_item_positions():
		var parcel_rect := Rect2(
			item_position - ConveyorPlaceholderVisual.PARCEL_SIZE * 0.5,
			ConveyorPlaceholderVisual.PARCEL_SIZE
		)
		draw_rect(parcel_rect, Color("d2c39d"), true)
		draw_rect(parcel_rect, Color("5b4934"), false, 3.0)
		draw_line(
			item_position - Vector2(10.0, 2.0),
			item_position + Vector2(11.0, -2.0),
			Color("896c43"),
			3.0
		)
