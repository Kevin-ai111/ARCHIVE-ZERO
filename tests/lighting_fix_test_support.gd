extends RefCounted

# Test-only independent approved delta. Historical ART/matrix fixtures stay intact.
const CONTRACT_PATH := "res://tests/fixtures/lighting_fix_contract.json"


static func contract() -> Dictionary:
	return JSON.parse_string(FileAccess.get_file_as_string(CONTRACT_PATH))


static func expected_asset_hash(path: String, historical: String) -> String:
	var data := contract()
	return data.assets[path.trim_prefix("res://")].sha256 if data.assets.has(path.trim_prefix("res://")) else historical


static func is_lighting_entry(element: String) -> bool:
	return element == "service_markings" or element.begins_with("light_cone_") or element.begins_with("floor_light_pool_")


static func expected_alpha(element: String, stage: int, historical: float) -> float:
	if not is_lighting_entry(element) or historical == 0.0:
		return historical
	var key := "service_markings" if element == "service_markings" else ("light_cone" if element.begins_with("light_cone_") else "floor_light_pool")
	return float(contract().alpha[key][stage])


static func affected_screen_regions(environment: Node) -> Array[Rect2]:
	var regions: Array[Rect2] = []
	_collect_regions(environment, contract().assets.keys(), regions)
	return regions


static func _collect_regions(node: Node, corrected_paths: Array, regions: Array[Rect2]) -> void:
	if node is Sprite2D:
		var sprite := node as Sprite2D
		var path := sprite.texture.resource_path.trim_prefix("res://")
		if sprite.is_visible_in_tree() and (path in corrected_paths or path == contract().locked_service_marking.path):
			# Readback pixels require the engine stretch AND actual canvas transform.
			# One physical pixel guards fractional/bilinear edge support.
			var local := Rect2(sprite.offset, sprite.texture.get_size())
			if sprite.centered:
				local.position -= local.size * 0.5
			var to_pixels := sprite.get_viewport().get_stretch_transform() * sprite.get_global_transform_with_canvas()
			regions.append((to_pixels * local).grow(1.0))
	for child: Node in node.get_children():
		_collect_regions(child, corrected_paths, regions)


static func compare_outside_regions(before: Image, after: Image, regions: Array[Rect2]) -> Dictionary:
	if before == null or after == null or before.get_size() != after.get_size():
		return {"valid": false, "outside_changed_pixels": -1}
	# Normalize only in-memory readback copies; evidence PNGs are never edited.
	var old_image := before.duplicate() as Image
	var new_image := after.duplicate() as Image
	old_image.convert(Image.FORMAT_RGBA8)
	new_image.convert(Image.FORMAT_RGBA8)
	var old_bytes := old_image.get_data()
	var new_bytes := new_image.get_data()
	var width := after.get_width()
	var outside_count := 0
	var changed := 0
	var changed_outside := 0
	for y: int in range(after.get_height()):
		var intervals: Array[Vector2i] = []
		for rect: Rect2 in regions:
			if y + 0.5 >= rect.position.y and y + 0.5 < rect.end.y:
				intervals.append(Vector2i(clampi(int(floor(rect.position.x)), 0, width), clampi(int(ceil(rect.end.x)), 0, width)))
		intervals.sort_custom(func(a: Vector2i, b: Vector2i) -> bool: return a.x < b.x)
		var cursor := 0
		for interval: Vector2i in intervals:
			if interval.x > cursor:
				outside_count += interval.x - cursor
				changed_outside += _changed_pixels(old_bytes, new_bytes, (y * width + cursor) * 4, (y * width + interval.x) * 4)
			cursor = maxi(cursor, interval.y)
		if cursor < width:
			outside_count += width - cursor
			changed_outside += _changed_pixels(old_bytes, new_bytes, (y * width + cursor) * 4, (y * width + width) * 4)
		changed += _changed_pixels(old_bytes, new_bytes, y * width * 4, (y + 1) * width * 4)
	return {"valid": true, "outside_checked_pixels": outside_count, "outside_changed_pixels": changed_outside, "all_changed_pixels": changed, "allowed_regions": regions}


static func _changed_pixels(before: PackedByteArray, after: PackedByteArray, first: int, end: int) -> int:
	if before.slice(first, end) == after.slice(first, end):
		return 0
	var count := 0
	for offset: int in range(first, end, 4):
		if before[offset] != after[offset] or before[offset + 1] != after[offset + 1] or before[offset + 2] != after[offset + 2] or before[offset + 3] != after[offset + 3]:
			count += 1
	return count
