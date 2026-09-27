class_name ScannerPlaceholderVisual
extends Node2D

@export var machine_id: StringName = &"basic_scanner"
@export var display_name := "BASIC SCANNER"
@export var visual_size := Vector2(384.0, 416.0)

var machine_enabled := true
var is_active := false
var has_motor_upgrade := false
var is_bottleneck := false
var _pulse_time := 0.0


func _ready() -> void:
	queue_redraw()


func _process(delta: float) -> void:
	if is_active:
		_pulse_time = fmod(_pulse_time + delta, TAU)
		queue_redraw()


func apply_visual_state(enabled: bool, active: bool, upgraded: bool, bottleneck: bool) -> void:
	machine_enabled = enabled
	is_active = active and enabled
	has_motor_upgrade = upgraded
	is_bottleneck = bottleneck
	queue_redraw()


func get_visual_rect() -> Rect2:
	return Rect2(Vector2(-visual_size.x * 0.5, -visual_size.y), visual_size)


func get_state_snapshot() -> Dictionary:
	return {
		"enabled": machine_enabled,
		"active": is_active,
		"upgraded": has_motor_upgrade,
		"bottleneck": is_bottleneck,
	}


func _draw() -> void:
	var rect := get_visual_rect()
	var body := Color("394b5d") if machine_enabled else Color("20262e")
	var trim := Color("53b8cf") if machine_enabled else Color("555d66")
	var pulse := 0.55 + sin(_pulse_time * 3.0) * 0.20 if is_active else 0.18

	draw_rect(rect, Color("121820"), true)
	draw_rect(rect.grow(-8.0), body, true)
	draw_rect(Rect2(rect.position + Vector2(8.0, 8.0), Vector2(rect.size.x - 16.0, 54.0)), trim, true)
	draw_rect(Rect2(rect.position + Vector2(46.0, 92.0), Vector2(rect.size.x - 92.0, 194.0)), Color("111820"), true)
	draw_rect(Rect2(rect.position + Vector2(63.0, 111.0), Vector2(rect.size.x - 126.0, 155.0)), Color(0.20, 0.82, 0.93, pulse), true)
	draw_line(Vector2(rect.position.x + 78.0, rect.position.y + 126.0), Vector2(rect.end.x - 78.0, rect.position.y + 250.0), Color(0.75, 0.97, 1.0, pulse), 9.0)

	var port_y := -232.0
	draw_circle(Vector2(-visual_size.x * 0.5, port_y), 13.0, Color("d3a94b"))
	draw_circle(Vector2(visual_size.x * 0.5, port_y), 13.0, Color("d3a94b"))

	var light_color := Color("65e49f") if is_active else (Color("e6bd57") if machine_enabled else Color("c85d62"))
	draw_circle(Vector2(rect.end.x - 42.0, rect.position.y + 35.0), 11.0, light_color)

	if has_motor_upgrade:
		draw_rect(Rect2(Vector2(rect.end.x - 82.0, rect.position.y + 308.0), Vector2(58.0, 78.0)), Color("42c9a1"), true)
		draw_circle(Vector2(rect.end.x - 53.0, rect.position.y + 330.0), 10.0, Color("c9ffee"))
		draw_string(ThemeDB.fallback_font, Vector2(rect.end.x - 74.0, rect.position.y + 375.0), "M1", HORIZONTAL_ALIGNMENT_CENTER, 42.0, 20, Color("11251f"))

	if is_bottleneck:
		draw_rect(rect.grow(5.0), Color("e3aa45"), false, 6.0)

	if not machine_enabled:
		draw_rect(rect.grow(-10.0), Color(0.04, 0.05, 0.07, 0.68), true)
		draw_line(rect.position + Vector2(26.0, 26.0), rect.end - Vector2(26.0, 26.0), Color("c96868"), 10.0)

	draw_string(ThemeDB.fallback_font, Vector2(rect.position.x + 18.0, rect.position.y + 44.0), display_name, HORIZONTAL_ALIGNMENT_LEFT, rect.size.x - 70.0, 28, Color("f3f7fa"))
	var state_text := "SCANNING" if is_active else ("READY" if machine_enabled else "DISABLED")
	draw_string(ThemeDB.fallback_font, Vector2(rect.position.x + 30.0, rect.end.y - 25.0), state_text, HORIZONTAL_ALIGNMENT_LEFT, rect.size.x - 60.0, 22, Color("cbd5df"))
