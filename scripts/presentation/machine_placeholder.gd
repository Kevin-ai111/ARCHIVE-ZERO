class_name MachinePlaceholderVisual
extends Node2D

@export var machine_id: StringName
@export var display_name := "MACHINE"
@export var visual_size := Vector2(320.0, 360.0)
@export var body_color := Color("485363")
@export var accent_color := Color("7f93a8")

var machine_enabled := true
var is_bottleneck := false
var has_upgrade := false


func _ready() -> void:
	queue_redraw()


func apply_visual_state(enabled: bool, bottleneck: bool, upgraded: bool) -> void:
	machine_enabled = enabled
	is_bottleneck = bottleneck
	has_upgrade = upgraded
	queue_redraw()


func get_visual_rect() -> Rect2:
	return Rect2(Vector2(-visual_size.x * 0.5, -visual_size.y), visual_size)


func _draw() -> void:
	var rect := get_visual_rect()
	var visible_body_color := body_color if machine_enabled else body_color.darkened(0.55)
	var visible_accent_color := accent_color if machine_enabled else Color("59616b")

	draw_rect(rect, Color("151b23"), true)
	draw_rect(rect.grow(-8.0), visible_body_color, true)
	draw_rect(Rect2(rect.position + Vector2(8.0, 8.0), Vector2(rect.size.x - 16.0, 52.0)), visible_accent_color, true)
	draw_rect(Rect2(rect.position + Vector2(28.0, 88.0), Vector2(rect.size.x - 56.0, rect.size.y - 134.0)), Color("252f3a"), true)

	var port_y := -232.0
	draw_circle(Vector2(-visual_size.x * 0.5, port_y), 13.0, Color("d3a94b"))
	draw_circle(Vector2(visual_size.x * 0.5, port_y), 13.0, Color("d3a94b"))

	if has_upgrade:
		draw_rect(Rect2(Vector2(rect.end.x - 70.0, rect.position.y + 76.0), Vector2(48.0, 92.0)), Color("42c9a1"), true)
		draw_circle(Vector2(rect.end.x - 46.0, rect.position.y + 100.0), 8.0, Color("bfffe8"))

	if is_bottleneck:
		draw_rect(rect.grow(5.0), Color("e3aa45"), false, 6.0)

	if not machine_enabled:
		draw_rect(rect.grow(-10.0), Color(0.05, 0.06, 0.08, 0.60), true)
		draw_line(rect.position + Vector2(24.0, 24.0), rect.end - Vector2(24.0, 24.0), Color("c96868"), 10.0)

	var font := ThemeDB.fallback_font
	var title_position := Vector2(rect.position.x + 18.0, rect.position.y + 43.0)
	draw_string(font, title_position, display_name, HORIZONTAL_ALIGNMENT_LEFT, rect.size.x - 36.0, 28, Color("f1f4f7"))
	var state_text := "ONLINE" if machine_enabled else "OFFLINE"
	draw_string(font, Vector2(rect.position.x + 30.0, rect.end.y - 24.0), state_text, HORIZONTAL_ALIGNMENT_LEFT, rect.size.x - 60.0, 22, Color("cbd5df"))
