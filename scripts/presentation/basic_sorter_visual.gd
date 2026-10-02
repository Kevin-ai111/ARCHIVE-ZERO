class_name BasicSorterVisual
extends MachinePlaceholderVisual

const DISPLAY_SIZE := Vector2(480.0, 360.0)
const LAYER_SCALE := Vector2(0.5, 0.5)
const GATE_PIVOT := Vector2(18.0, -266.0)
const GATE_CHILD_OFFSET := Vector2(-42.0, -22.0)
const GATE_MAX_ANGLE := deg_to_rad(16.0)
const GATE_ANGULAR_SPEED := 2.0
const ENABLED_MODULATE := Color.WHITE
const DISABLED_MODULATE := Color(0.42, 0.48, 0.52, 1.0)

var is_active := false
var header_lighting_enabled := true
var bay_lighting_enabled := true
var _animation_time := 0.0

@onready var rear_housing: Sprite2D = %RearHousing
@onready var header_emissive: Sprite2D = %HeaderEmissive
@onready var bay_emissive: Sprite2D = %BayEmissive
@onready var sorting_gate_pivot: Node2D = %SortingGatePivot
@onready var sorting_gate: Sprite2D = %SortingGate
@onready var front_mask: Sprite2D = %FrontMask
@onready var motor_upgrade: Sprite2D = %MotorUpgrade


func _ready() -> void:
	_apply_layer_state()
	_update_animation()
	set_process(is_active)
	queue_redraw()


func _process(delta: float) -> void:
	advance_visual_animation(delta)


func apply_visual_state(enabled: bool, bottleneck: bool, upgraded: bool) -> void:
	apply_sorter_state(enabled, enabled, upgraded, bottleneck)


func apply_sorter_state(enabled: bool, active: bool, upgraded: bool, bottleneck: bool) -> void:
	machine_enabled = enabled
	is_active = active and enabled
	has_upgrade = upgraded
	is_bottleneck = bottleneck
	if is_node_ready():
		_apply_layer_state()
		set_process(is_active)
	queue_redraw()


func advance_visual_animation(delta: float) -> void:
	if not is_active or delta <= 0.0:
		return
	_animation_time = fmod(_animation_time + delta, TAU / GATE_ANGULAR_SPEED)
	_update_animation()


func set_gate_phase_for_preview(phase: float) -> void:
	_animation_time = fposmod(phase, 1.0) * TAU / GATE_ANGULAR_SPEED
	if is_node_ready():
		_update_animation()


func set_header_lighting_enabled(value: bool) -> void:
	header_lighting_enabled = value
	if is_node_ready():
		_apply_layer_state()


func set_bay_lighting_enabled(value: bool) -> void:
	bay_lighting_enabled = value
	if is_node_ready():
		_apply_layer_state()


func set_texture_filter_mode(filter_mode: CanvasItem.TextureFilter) -> void:
	texture_filter = filter_mode


func get_state_snapshot() -> Dictionary:
	return {
		"enabled": machine_enabled,
		"active": is_active,
		"upgraded": has_upgrade,
		"bottleneck": is_bottleneck,
		"header_visible": header_emissive.visible,
		"bays_visible": bay_emissive.visible,
		"gate_visible": sorting_gate.visible,
		"gate_angle": sorting_gate_pivot.rotation,
		"gate_processing": is_processing(),
		"upgrade_visible": motor_upgrade.visible,
		"texture_filter": texture_filter,
	}


func get_asset_geometry_snapshot() -> Dictionary:
	return {
		"display_size": visual_size,
		"back_export_size": rear_housing.texture.get_size(),
		"back_position": rear_housing.position,
		"back_scale": rear_housing.scale,
		"header_export_size": header_emissive.texture.get_size(),
		"header_position": header_emissive.position,
		"header_scale": header_emissive.scale,
		"bays_export_size": bay_emissive.texture.get_size(),
		"bays_position": bay_emissive.position,
		"bays_scale": bay_emissive.scale,
		"gate_export_size": sorting_gate.texture.get_size(),
		"gate_pivot": sorting_gate_pivot.position,
		"gate_child_position": sorting_gate.position,
		"gate_scale": sorting_gate.scale,
		"gate_centered": sorting_gate.centered,
		"front_export_size": front_mask.texture.get_size(),
		"front_position": front_mask.position,
		"front_scale": front_mask.scale,
		"upgrade_export_size": motor_upgrade.texture.get_size(),
		"upgrade_position": motor_upgrade.position,
		"upgrade_scale": motor_upgrade.scale,
		"back_z": rear_housing.z_index,
		"header_z": header_emissive.z_index,
		"bays_z": bay_emissive.z_index,
		"gate_z": sorting_gate_pivot.z_index,
		"front_z": front_mask.z_index,
		"upgrade_z": motor_upgrade.z_index,
		"parcel_center_local_y": -232.0,
		"conveyor_contact_local_y": -217.0,
	}


func _apply_layer_state() -> void:
	var casing_modulate := ENABLED_MODULATE if machine_enabled else DISABLED_MODULATE
	rear_housing.self_modulate = casing_modulate
	front_mask.self_modulate = casing_modulate
	sorting_gate.self_modulate = casing_modulate
	header_emissive.visible = machine_enabled and header_lighting_enabled
	bay_emissive.visible = machine_enabled and bay_lighting_enabled
	motor_upgrade.visible = has_upgrade
	motor_upgrade.self_modulate = casing_modulate


func _update_animation() -> void:
	sorting_gate_pivot.rotation = sin(_animation_time * GATE_ANGULAR_SPEED) * GATE_MAX_ANGLE


func _draw() -> void:
	var rect := get_visual_rect()
	if is_bottleneck:
		draw_rect(rect.grow(5.0), Color(0.89, 0.67, 0.27, 0.92), false, 6.0)
	if not machine_enabled:
		draw_circle(Vector2(rect.end.x - 28.0, rect.position.y + 28.0), 12.0, Color("c85d62"))
		draw_line(rect.position + Vector2(48.0, 48.0), rect.end - Vector2(48.0, 48.0), Color(0.78, 0.25, 0.28, 0.82), 9.0)
