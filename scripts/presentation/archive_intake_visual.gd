class_name ArchiveIntakeVisual
extends MachinePlaceholderVisual

const DISPLAY_SIZE := Vector2(304.0, 464.0)
const LAYER_SCALE := Vector2(0.5, 0.5)
const CARRIER_PIVOT := Vector2(74.0, -294.0)
const CARRIER_CHILD_OFFSET := Vector2(-35.0, -54.0)
const CARRIER_TRAVEL := 24.0
const CARRIER_ANGULAR_SPEED := 1.6
const ENABLED_MODULATE := Color.WHITE
const DISABLED_MODULATE := Color(0.42, 0.48, 0.52, 1.0)

var is_active := false
var idle_lighting_enabled := true
var _animation_time := 0.0

@onready var rear_housing: Sprite2D = %RearHousing
@onready var idle_emissive: Sprite2D = %IdleEmissive
@onready var lift_carrier_pivot: Node2D = %LiftCarrierPivot
@onready var lift_carrier: Sprite2D = %LiftCarrier
@onready var front_mask: Sprite2D = %FrontMask


func _ready() -> void:
	_apply_layer_state()
	_update_animation()
	set_process(is_active)
	queue_redraw()


func _process(delta: float) -> void:
	advance_visual_animation(delta)


func apply_visual_state(enabled: bool, bottleneck: bool, _upgraded: bool) -> void:
	apply_intake_state(enabled, enabled, bottleneck)


func apply_intake_state(enabled: bool, active: bool, bottleneck: bool) -> void:
	machine_enabled = enabled
	is_active = active and enabled
	is_bottleneck = bottleneck
	has_upgrade = false
	if is_node_ready():
		_apply_layer_state()
		set_process(is_active)
	queue_redraw()


func advance_visual_animation(delta: float) -> void:
	if not is_active or delta <= 0.0:
		return
	_animation_time = fmod(_animation_time + delta, TAU / CARRIER_ANGULAR_SPEED)
	_update_animation()


func set_carrier_phase_for_preview(phase: float) -> void:
	_animation_time = fposmod(phase, 1.0) * TAU / CARRIER_ANGULAR_SPEED
	if is_node_ready():
		_update_animation()


func set_idle_lighting_enabled(value: bool) -> void:
	idle_lighting_enabled = value
	if is_node_ready():
		_apply_layer_state()


func set_texture_filter_mode(filter_mode: CanvasItem.TextureFilter) -> void:
	texture_filter = filter_mode


func get_state_snapshot() -> Dictionary:
	return {
		"enabled": machine_enabled,
		"active": is_active,
		"bottleneck": is_bottleneck,
		"idle_visible": idle_emissive.visible,
		"carrier_visible": lift_carrier.visible,
		"carrier_offset_y": lift_carrier_pivot.position.y - CARRIER_PIVOT.y,
		"carrier_processing": is_processing(),
		"has_upgrade": has_upgrade,
		"texture_filter": texture_filter,
	}


func get_asset_geometry_snapshot() -> Dictionary:
	return {
		"display_size": visual_size,
		"back_export_size": rear_housing.texture.get_size(),
		"back_position": rear_housing.position,
		"back_scale": rear_housing.scale,
		"emissive_export_size": idle_emissive.texture.get_size(),
		"emissive_position": idle_emissive.position,
		"emissive_scale": idle_emissive.scale,
		"carrier_export_size": lift_carrier.texture.get_size(),
		"carrier_pivot": CARRIER_PIVOT,
		"carrier_child_position": lift_carrier.position,
		"carrier_scale": lift_carrier.scale,
		"carrier_centered": lift_carrier.centered,
		"carrier_travel": CARRIER_TRAVEL,
		"front_export_size": front_mask.texture.get_size(),
		"front_position": front_mask.position,
		"front_scale": front_mask.scale,
		"back_z": rear_housing.z_index,
		"emissive_z": idle_emissive.z_index,
		"carrier_z": lift_carrier_pivot.z_index,
		"front_z": front_mask.z_index,
		"parcel_center_local_y": -232.0,
		"conveyor_contact_local_y": -217.0,
		"conveyor_endpoint_local_x": 0.0,
	}


func _apply_layer_state() -> void:
	var casing_modulate := ENABLED_MODULATE if machine_enabled else DISABLED_MODULATE
	rear_housing.self_modulate = casing_modulate
	front_mask.self_modulate = casing_modulate
	lift_carrier.self_modulate = casing_modulate
	idle_emissive.visible = machine_enabled and idle_lighting_enabled


func _update_animation() -> void:
	var carrier_offset := sin(_animation_time * CARRIER_ANGULAR_SPEED) * CARRIER_TRAVEL
	lift_carrier_pivot.position = CARRIER_PIVOT + Vector2(0.0, carrier_offset)


func _draw() -> void:
	var rect := get_visual_rect()
	if is_bottleneck:
		draw_rect(rect.grow(5.0), Color(0.89, 0.67, 0.27, 0.92), false, 6.0)
	if not machine_enabled:
		draw_circle(Vector2(rect.end.x - 28.0, rect.position.y + 28.0), 12.0, Color("c85d62"))
		draw_line(rect.position + Vector2(42.0, 54.0), rect.end - Vector2(42.0, 54.0), Color(0.78, 0.25, 0.28, 0.82), 9.0)
