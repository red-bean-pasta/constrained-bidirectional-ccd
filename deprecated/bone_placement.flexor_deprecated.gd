extends HingePlacement2D
class_name SpiderLegBonePlacement


func add_pressured_segment(
	seg: Node, 
	pressure: float, 
	clamp_overrides: Vector2 = Vector2.INF
) -> void:
	var dir := _get_scene_dir_of_pressured_segment(seg, _from_dir, pressure, clamp_overrides)
	_add_segment_in_scene_dir(seg, dir)

func _get_scene_dir_of_pressured_segment(
	seg: Node, 
	from_dir: Vector2,
	pressure: float,
	clamp_overrides: Vector2 = Vector2.INF
) -> Vector2:
	var limits := _resolve_rad_limit(seg, clamp_overrides)
	var opened := pressure_to_rad(pressure, limits.x, limits.y)
	return _get_scene_dir_of_opened_segment(seg, opened, from_dir, clamp_overrides)
	

static func pressure_to_rad(pressure: float, p_min: float, p_max: float) -> float:
	return lerpf(p_min, p_max, pressure)
	
static func rad_to_pressure(rad: float, p_min: float, p_max: float) -> float:
	return inverse_lerp(p_min, p_max, rad)


func _is_counterclockwise(node: Node) -> bool:
	return _cast_to_bone(node).counterclockwise

func _get_segment_clamp(node: Node) -> Vector2:
	var bone := _cast_to_bone(node)
	return Vector2(bone.min_rad, bone.max_rad)
	
func _get_length(node: Node) -> float:
	return _cast_to_bone(node).get_start_end_distance()
	
static func _cast_to_bone(node: Node) -> SpiderLegBone:
	var bone := node as SpiderLegBone
	assert(bone != null)
	return bone