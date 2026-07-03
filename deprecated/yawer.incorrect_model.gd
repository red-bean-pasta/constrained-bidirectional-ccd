extends Node

# Deprecated: Incorrect math and model
# This class naively accumulates each segment's yaw and hopes it to euqal the total needed yaw between target position and starting direction.
# But the accumulated result actually only means the rotation of last segment, not the position, and doesn't apply to the rotation between starting direction and target position.


var _parent: SpiderLeg

## How much segment's antecedent contribute to yaw attempt
## The more contribution the end
@export var _damp: float = 0.1

var _segments: SpiderLegSegments
var yawables: Array[SpiderLegSegment]

var _effort_graph: EffortGraph


func _ready() -> void:
	_parent = get_parent()
	assert(_parent is SpiderLeg)
	
	assert(0 <= _damp and _damp < 1)
	
	SpiderLegUnitRegister.register_segments(self)
	_update_segments(_segments)

func _update_segments(segs: SpiderLegSegments):
	_segments = segs
	
	yawables.clear()
	for s: SpiderLegSegment in _segments.items:
		if not is_zero_approx(s.allowed_yaw_rad):
			yawables.append(s)
	
	_effort_graph = EffortGraph.new(yawables, _damp)


func yaw_to_local_point(
	at: Vector3
) -> void:
	var target := Vector2(at.x, at.z)
	
	var needed := Vector2.UP.angle_to(target)
	if is_zero_approx(needed):
		return
	
	var yaws := _effort_graph.resolve_yaws(needed)
	_yaw_segments(yaws)

func yaw_to_world_point(
	at: Vector3
) -> void:
	assert(get_parent() == _parent) # Ensure that it's not reparented
	var local := _parent.to_local(at)
	yaw_to_local_point(local)

## [param signed]: If rads is already 
func _yaw_segments(rads: Array[float]) -> void:
	assert(rads.size() == yawables.size())
	for i in rads.size():
		yaw_segment_by(rads[i], yawables[i])


func yaw_segment_by(
	rad: float, 
	segment: SpiderLegSegment
) -> void:
	segment.yaw_by_rad(rad)

func yaw_indexed_segment_by(
	rad: float, 
	segment: SpiderLegSpec.Segment = SpiderLegSpec.Segment.COXA
) -> void:
	var target := _segments.get_indexed_at(segment)
	target.yaw_by_rad(rad)
	

class EffortGraph:
	var _yaws: Array[float]
	
	## On a scale of 0 to 1, how much effort will max out a yaw
	var _thresholds: Array[float]
	## The total yaw at each threshold,  
	var _stages: Array[float]
	
	var max_yaw: float:
		get: return _stages[-1]
	
	
	func _init(
		yawable_segments: Array[SpiderLegSegment],
		yaw_damp: float
	) -> void:
		assert(0 <= yaw_damp and yaw_damp < 1)
		
		var count := 0
		var slope := 0.0
		for s in yawable_segments:
			var yaw := s.allowed_yaw_rad
			assert(not is_zero_approx(yaw) and yaw > 0)
			_yaws.append(yaw)
			var threshold := 1.0 * (1.0 - yaw_damp) ** count # max_effort * (relative_sensitivity) ** segment_number
			_thresholds.append(threshold)
			slope += yaw / threshold
			count += 1
		
		var prev_point := 0.0
		var prev_stage := 0.0
		for i in count:
			var idx := count - 1 - i
			var current_point := _thresholds[idx]
			var current_stage := prev_stage + slope * (current_point - prev_point)
			_stages.append(current_stage)
			
			slope -= _yaws[idx] / _thresholds[idx]
			prev_point = current_point
			prev_stage = current_stage
	
	static func build_from(
		segments: Array[SpiderLegSegment],
		yaw_damp: float
	) -> EffortGraph:
		var yawable := segments.filter(_check_if_yawable)
		return EffortGraph.new(yawable, yaw_damp)
	
	static func _check_if_yawable(seg: SpiderLegSegment) -> bool:
		return not is_zero_approx(seg.allowed_yaw_rad)
		
		
	func resolve_yaws(total: float) -> Array[float]:
		var result: Array[float]
		if is_zero_approx(total):
			result = []
			result.resize(_yaws.size())
			return result
		var to := absf(total)
		if to >= max_yaw:
			result = Array(_yaws)
		else:
			var effort := _resolve_effort(total)
			result = _get_yaws_at_effort(effort)
		if total < 0:
			_flip_array(result)
		return result
		
	func _resolve_effort(total: float) -> float:
		total = clamp(total, 0.0, max_yaw)
		var start_e := 0.0 
		var start_y := 0.0
		for i in _stages.size():
			var end_pair := _get_staged_threshold_pair(i)
			var end_e := end_pair[0]
			var end_y := end_pair[0]
			if end_y < total:
				start_e = end_e
				start_y = end_y
				continue
			var weight := inverse_lerp(start_y, end_y, total)
			return lerpf(start_e, end_e, weight)
		push_error("Failed to resolve effort to reach total yaw of %s" % total)
		return 1.0
	
	func _get_yaws_at_effort(x: float) -> Array[float]:
		assert(0 <= x and x <= 1)
		var result: Array[float] = []
		result.resize(_yaws.size())
		for i in _yaws.size():
			result[i] = _yaws[i] * clamp(x / _thresholds[i], 0.0, 1.0)
		return result
		

	func _get_staged_threshold_pair(idx: int) -> Vector2:
		assert(_thresholds.size() == _stages.size())
		return Vector2(
			_thresholds[_thresholds.size() - 1 - idx],
			_stages[idx]
		)
		
	func _get_thresholded_stage_pair(idx: int) -> Vector2:
		return _get_staged_threshold_pair(_stages.size() - 1 - idx)
		
	static func _flip_array(arr: Array[float]) -> Array[float]:
		for i in arr.size():
			arr[i] *= -1
		return arr