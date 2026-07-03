# class_name SpiderLegYawer

# Deprecated: Incorrect model
# This class resolves yaw after flex. The flex after rotation will always fall short. It cannot retry flexing as Vector3.y is pinned down. 
# Such design effectively demolish most of the yaw attempts and relies solely on fallback.


var _tolerance: float

var _segments: SpiderLegSegments
var _yawables: Array[SpiderLegSegment]

var _end_segment: SpiderLegSegment: 
	get: return _segments.items[-1]
var _end_pos: Vector2:
	get: return _solve_segment_end(_end_segment)


func _init(
	segments: SpiderLegSegments,
	tolerance: float
) -> void:
	_tolerance = tolerance
	_update_segments(segments)
	
func _update_segments(segments: SpiderLegSegments):
	_segments = segments
	_yawables.assign(segments.items.filter(_is_yawable))

static func _is_yawable(segment: SpiderLegSegment) -> bool:
	return not is_zero_approx(segment.allowed_yaw_rad)
	

func yaw_to(
	target: Vector3
) -> bool:
	assert(_ensure_hierarchy())
	
	var projected := SpiderLegReachProjector.project_yaw(target)
	if _check_tip_reached(projected):
		return true
		
	for i in range(_yawables.size() - 1, -1, -1):
		if _try_yaw_segment(i, projected):
			return true
	
	_try_yaw_segment(0, projected, false)
	return false
	

## [param idx]: The index of the segment in _yawables to yaw
func _try_yaw_segment(
	idx: int,
	pos: Vector2,
	reset_on_failure: bool = true
) -> bool:
	assert(not _check_tip_reached(pos))

	var seg := _yawables[idx]
	assert(is_zero_approx(seg.current_yaw_rad)) # The model explicitly assumes a fresh state
	var needed := Helper2D.get_rad_between_vertices(
		_solve_segment_end(seg),
		_solve_segment_pos(seg),
		pos
	)
	var allowed := _clamp_yaw(needed, seg)
	
	if is_zero_approx(allowed):
		return false
	seg.yaw_to(allowed)
	if _check_tip_reached(pos):
		return true
	
	if idx != _yawables.size() - 1:
		_try_yaw_segment(idx + 1, pos, reset_on_failure)
	if _check_tip_reached(pos):
		return true
	if reset_on_failure:
		seg.reset_yaw()
	return false

	
func _clamp_yaw(rad: float, seg: SpiderLegSegment) -> float:
	var allowed := seg.allowed_yaw_rad
	assert(allowed >= 0)
	return MiscUtils.wrap_clamp_rad(rad, -allowed, allowed)

func _check_tip_reached(target: Vector2) -> bool:
	return _consider_reached(_end_pos, target)


static func _solve_segment_pos(seg: SpiderLegSegment) -> Vector2:
		return _from_segment_to_leg_space(seg.position, seg, true)
		
static func _solve_segment_end(seg: SpiderLegSegment) -> Vector2:
	return _from_segment_to_leg_space(seg.end, seg, false)

static func _from_segment_to_leg_space(
	target: Vector3,
	segment: SpiderLegSegment, 
	local_to_bone: bool
) -> Vector2:
	var bone := segment.get_parent() as SpiderLegBone
	var boned := target if local_to_bone else segment.transform * target
	var legged := bone.transform * boned
	var projected := SpiderLegReachProjector.project_yaw(legged)
	return projected


func _consider_reached(a: Vector2, b: Vector2) -> bool:
	return a.distance_squared_to(b) <= _tolerance ** 2
	
func _ensure_hierarchy() -> bool:
	for s in _segments.items:
		var bone := s.get_parent() as SpiderLegBone
		if not bone:
			return false
		var leg := bone.get_parent() as SpiderLeg
		if not leg:
			return false
	return true
	
