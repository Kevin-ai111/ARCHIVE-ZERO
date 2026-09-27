class_name ReceivingDeskVisual
extends MachinePlaceholderVisual

const DISPLAY_SIZE := Vector2(336.0, 352.0)
const LAYER_SCALE := Vector2(0.5, 0.5)
const WHEEL_PIVOT := Vector2(116.0, -173.0)
const WHEEL_ANGULAR_SPEED := 1.8
const ENABLED_MODULATE := Color.WHITE
const DISABLED_MODULATE := Color(0.42, 0.48, 0.52, 1.0)

var is_active := false
var idle_lighting_enabled := true
var _wheel_angle := 0.0

@onready var rear_casing: Sprite2D = %RearCasing
@onready var static_paperwork: Sprite2D = %StaticPaperwork
@onready var idle_emissive: Sprite2D = %IdleEmissive
@onready var feed_wheel_pivot: Node2D = %FeedWheelPivot
@onready var feed_wheel: Sprite2D = %FeedWheel
@onready var front_mask: Sprite2D = %FrontMask


func _ready() -> void:
	_apply_layer_state()
	set_process(is_active)
	queue_redraw()


func _process(delta: float) -> void:
	advance_visual_animation(delta)


func apply_visual_state(enabled: bool, bottleneck: bool, _upgraded: bool) -> void:
	apply_receiving_state(enabled, enabled, bottleneck)


func apply_receiving_state(enabled: bool, active: bool, bottleneck: bool) -> void:
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
	_wheel_angle = fmod(_wheel_angle + delta * WHEEL_ANGULAR_SPEED, TAU)
	feed_wheel_pivot.rotation = _wheel_angle


func set_wheel_angle_for_preview(angle: float) -> void:
	_wheel_angle = fposmod(angle, TAU)
	if is_node_ready():
		feed_wheel_pivot.rotation = _wheel_angle


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
		"wheel_visible": feed_wheel.visible,
		"wheel_angle": feed_wheel_pivot.rotation,
		"wheel_processing": is_processing(),
		"texture_filter": texture_filter,
	}


func get_asset_geometry_snapshot() -> Dictionary:
	return {
		"display_size": visual_size,
		"back_export_size": rear_casing.texture.get_size(),
		"back_position": rear_casing.position,
		"back_scale": rear_casing.scale,
		"paper_export_size": static_paperwork.texture.get_size(),
		"paper_position": static_paperwork.position,
		"paper_scale": static_paperwork.scale,
		"emissive_export_size": idle_emissive.texture.get_size(),
		"emissive_position": idle_emissive.position,
		"emissive_scale": idle_emissive.scale,
		"wheel_export_size": feed_wheel.texture.get_size(),
		"wheel_pivot": feed_wheel_pivot.position,
		"wheel_scale": feed_wheel.scale,
		"wheel_centered": feed_wheel.centered,
		"front_export_size": front_mask.texture.get_size(),
		"front_position": front_mask.position,
		"front_scale": front_mask.scale,
		"back_z": rear_casing.z_index,
		"paper_z": static_paperwork.z_index,
		"emissive_z": idle_emissive.z_index,
		"wheel_z": feed_wheel_pivot.z_index,
		"front_z": front_mask.z_index,
		"parcel_center_local_y": -232.0,
		"conveyor_contact_local_y": -217.0,
		"conveyor_handoff_local_x": 168.0,
	}


func _apply_layer_state() -> void:
	var casing_modulate := ENABLED_MODULATE if machine_enabled else DISABLED_MODULATE
	rear_casing.self_modulate = casing_modulate
	static_paperwork.self_modulate = casing_modulate
	front_mask.self_modulate = casing_modulate
	feed_wheel.self_modulate = casing_modulate
	idle_emissive.visible = machine_enabled and idle_lighting_enabled


func _draw() -> void:
	var rect := get_visual_rect()
	if is_bottleneck:
		draw_rect(rect.grow(5.0), Color(0.89, 0.67, 0.27, 0.92), false, 6.0)
	if not machine_enabled:
		draw_circle(Vector2(rect.end.x - 28.0, rect.position.y + 28.0), 12.0, Color("c85d62"))
		draw_line(rect.position + Vector2(38.0, 48.0), rect.end - Vector2(38.0, 48.0), Color(0.78, 0.25, 0.28, 0.82), 9.0)
