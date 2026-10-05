class_name BasicScannerVisual
extends Node2D

const LAYER_CENTER := Vector2(0.0, -208.0)
const DISPLAY_SIZE := Vector2(384.0, 416.0)
const EXPORT_SIZE := Vector2(768.0, 832.0)
const LAYER_SCALE := Vector2(0.5, 0.5)
const SCAN_TRAVEL := 47.0
const SCAN_ANGULAR_SPEED := 2.4
const ENABLED_MODULATE := Color.WHITE
const DISABLED_MODULATE := Color(0.42, 0.48, 0.52, 1.0)
const DORMANT_MODULATE := Color(0.62, 0.68, 0.72, 1.0)

@export var machine_id: StringName = &"basic_scanner"
@export var display_name := "BASIC SCANNER"
@export var visual_size := DISPLAY_SIZE

var machine_enabled := true
var commissioned_for_presentation := true
var is_active := false
var has_motor_upgrade := false
var is_bottleneck := false
var _animation_time := 0.0

@onready var scanner_back: Sprite2D = %ScannerBack
@onready var idle_emissive: Sprite2D = %IdleEmissive
@onready var scan_beam: Sprite2D = %ScanBeam
@onready var scanner_front: Sprite2D = %ScannerFront
@onready var motor_upgrade: Sprite2D = %MotorUpgrade


func _ready() -> void:
	_apply_layer_state()
	_update_animation()
	queue_redraw()


func _process(delta: float) -> void:
	advance_visual_animation(delta)


func advance_visual_animation(delta: float) -> void:
	if not is_active or delta <= 0.0:
		return
	_animation_time = fmod(_animation_time + delta, TAU / SCAN_ANGULAR_SPEED)
	_update_animation()
	queue_redraw()


func set_scan_phase_for_preview(phase: float) -> void:
	_animation_time = clampf(phase, 0.0, 1.0) * TAU / SCAN_ANGULAR_SPEED
	_update_animation()


func set_texture_filter_mode(filter_mode: CanvasItem.TextureFilter) -> void:
	texture_filter = filter_mode


func apply_visual_state(enabled: bool, active: bool, upgraded: bool, bottleneck: bool, commissioned: bool = true) -> void:
	machine_enabled = enabled
	commissioned_for_presentation = commissioned
	is_active = active and enabled and commissioned
	has_motor_upgrade = upgraded
	is_bottleneck = bottleneck and commissioned
	if is_node_ready():
		_apply_layer_state()
		_update_animation()
		set_process(is_active)
	queue_redraw()


func get_visual_rect() -> Rect2:
	return Rect2(Vector2(-visual_size.x * 0.5, -visual_size.y), visual_size)


func get_state_snapshot() -> Dictionary:
	return {
		"commissioned": commissioned_for_presentation,
		"casing_modulate": scanner_back.self_modulate,
		"fault_visible": commissioned_for_presentation and not machine_enabled,
		"enabled": machine_enabled,
		"active": is_active,
		"upgraded": has_motor_upgrade,
		"bottleneck": is_bottleneck,
		"idle_visible": idle_emissive.visible,
		"scan_visible": scan_beam.visible,
		"upgrade_visible": motor_upgrade.visible,
		"scan_offset_y": scan_beam.position.y - LAYER_CENTER.y,
		"texture_filter": texture_filter,
	}


func get_asset_geometry_snapshot() -> Dictionary:
	return {
		"export_size": scanner_back.texture.get_size(),
		"display_size": visual_size,
		"layer_center": scanner_back.position,
		"layer_scale": scanner_back.scale,
		"pivot_local": Vector2.ZERO,
		"parcel_center_local_y": -232.0,
		"conveyor_contact_local_y": -217.0,
		"back_z": scanner_back.z_index,
		"idle_z": idle_emissive.z_index,
		"scan_z": scan_beam.z_index,
		"front_z": scanner_front.z_index,
		"upgrade_z": motor_upgrade.z_index,
	}


func _apply_layer_state() -> void:
	var casing_modulate := (ENABLED_MODULATE if machine_enabled else DISABLED_MODULATE) if commissioned_for_presentation else DORMANT_MODULATE
	scanner_back.self_modulate = casing_modulate
	scanner_front.self_modulate = casing_modulate
	idle_emissive.visible = machine_enabled and commissioned_for_presentation
	scan_beam.visible = is_active
	motor_upgrade.visible = has_motor_upgrade and commissioned_for_presentation
	motor_upgrade.self_modulate = ENABLED_MODULATE if machine_enabled else DISABLED_MODULATE


func _update_animation() -> void:
	var wave := sin(_animation_time * SCAN_ANGULAR_SPEED)
	scan_beam.position = LAYER_CENTER + Vector2(0.0, wave * SCAN_TRAVEL)
	if is_active:
		idle_emissive.self_modulate = Color(1.0, 1.0, 1.0, 0.82 + wave * 0.10)
		scan_beam.self_modulate = Color(1.0, 1.0, 1.0, 0.72 + wave * 0.16)
	else:
		idle_emissive.self_modulate = Color(1.0, 1.0, 1.0, 0.52)


func _draw() -> void:
	if not commissioned_for_presentation:
		return
	var rect := get_visual_rect()
	if is_bottleneck:
		draw_rect(rect.grow(5.0), Color(0.89, 0.67, 0.27, 0.92), false, 6.0)
	if not machine_enabled:
		draw_circle(Vector2(rect.end.x - 28.0, rect.position.y + 28.0), 12.0, Color("c85d62"))
		draw_line(rect.position + Vector2(42.0, 54.0), rect.end - Vector2(42.0, 54.0), Color(0.78, 0.25, 0.28, 0.82), 9.0)
