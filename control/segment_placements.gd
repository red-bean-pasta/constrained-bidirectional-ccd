class_name SegmentPlacements


var _segments: Array[Segment]

var _basis_buffer: Array[Basis] = []
var _position_buffer: Array[Vector3] = []

var _yaw_buffer: Array[float] = []
var _flex_buffer: Array[float] = []

var count: int:
	get: return _segments.size()
var end_position: Vector3:
	get: return _position_buffer[-1]
	
var bases: Array[Basis]:
	get: return _basis_buffer
var positions: Array[Vector3]:
	get: return _position_buffer

## [param p_basis_buffer]: Optional reusable basis buffer to avoid allocation. Micro-optiomization
func _init(
	p_segments: Array[Segment]
) -> void:
	_segments = p_segments
	refresh()

func refresh() -> void:
	_basis_buffer.resize(count + 1)
	_position_buffer.resize(count + 1)
	_flex_buffer.resize(count)
	_yaw_buffer.resize(count)
	
	_basis_buffer[0] = _segments[0].prev_basis
	_position_buffer[-1] = _segments[-1].end_position
	
	for i in count:
		var seg := _segments[i]
		_basis_buffer[i + 1] = seg.basis
		_position_buffer[i] = seg.position
		_flex_buffer[i] = seg.current_flex_rad
		_yaw_buffer[i] = seg.current_yaw_rad

func rotate_seg_from_current(seg: Segment, flex_delta: float, yaw_delta: float) -> void:
	if Utils.is_tau(flex_delta) and Utils.is_tau(yaw_delta):
		return
		
	var clamped_flex_delta := _clamp_flex_delta(seg, flex_delta)
	var clamped_yaw_delta := _clamp_yaw_delta(seg, yaw_delta)
	
	var flex := Basis(_get_seg_flex_axis(seg), clamped_flex_delta)
	var yaw := Basis(_get_seg_yaw_axis(seg), clamped_yaw_delta)
	var rotation := yaw * flex
	
	_rotate_and_ripple(seg, rotation)
	
	var idx := seg.index
	_flex_buffer[idx] += clamped_flex_delta
	_yaw_buffer[idx] += clamped_yaw_delta

func check_reached(pos: Vector3, tolerance: float) -> bool:
	return end_position.distance_squared_to(pos) <= tolerance ** 2

func _rotate_and_ripple(
	seg: Segment, 
	rotation: Basis
) -> void:
	assert(seg.movable)
	
	var idx := seg.index
	
	for i in range(idx, count):
		_basis_buffer[i + 1] = rotation * _basis_buffer[i + 1]
		
	var pivot := _get_seg_pos(seg)
	for i in range(idx + 1, count + 1):
		var offset := _position_buffer[i] - pivot
		_position_buffer[i] = pivot + rotation * offset


## [returns]: May return NaN if the flex is unsolvable when `target_pos` or `end_pos` is just to the RIGHT of the joint
func _solve_relative_flex_delta(
	seg: Segment,
	end_pos: Vector3,
	target_pos: Vector3,
) -> float:
	return Helper.solve_flex_delta(
		_get_seg_pos(seg),
		end_pos,
		target_pos,
		_get_seg_flex_axis(seg)
	)

## [returns]: May return NaN if the flex is unsolvable when `target_pos` or `end_pos` is just to the UP of the joint
func solve_relative_yaw_delta(
	seg: Segment,
	end_pos: Vector3,
	target_pos: Vector3,
	flex_delta: float,
) -> float:
	return Helper.solve_yaw_delta(
		_get_seg_pos(seg),
		end_pos,
		target_pos,
		_get_seg_yaw_axis(seg),
		_get_seg_flex_axis(seg),
		flex_delta
	)


func solve_joint_effector_flex_delta(
	seg: Segment,
	target_pos: Vector3,
) -> float:
	return _solve_relative_flex_delta(seg, end_position, target_pos)

func solve_joint_effector_yaw_delta(
	seg: Segment,
	target_pos: Vector3,
	flex_delta: float,
) -> float:
	return solve_relative_yaw_delta(seg, end_position, target_pos, flex_delta)


func solve_segment_flex_delta(
	seg: Segment,
	target_pos: Vector3,
) -> float:
	return _solve_relative_flex_delta(seg, _get_seg_end(seg), target_pos)

func solve_segment_yaw_delta(
	seg: Segment,
	target_pos: Vector3,
	flex_delta: float,
) -> float:
	return solve_relative_yaw_delta(seg, _get_seg_end(seg), target_pos, flex_delta)


func _clamp_flex_delta(
	seg: Segment,
	delta: float,
) -> float:
	var i := seg.index
	var current := _flex_buffer[i]
	var clamped := seg.joint.flex.clamp(current + delta)
	return clamped - current

func _clamp_yaw_delta(
	seg: Segment,
	delta: float,
) -> float:
	var i := seg.index
	var current := _yaw_buffer[i]
	var clamped := seg.joint.yaw.clamp(current + delta)
	return clamped - current


func _get_seg_basis(seg: Segment) -> Basis:
	return _basis_buffer[seg.index + 1]
	
func _get_seg_prev_basis(seg: Segment) -> Basis:
	return _basis_buffer[seg.index]

func _get_seg_pos(seg: Segment) -> Vector3:
	return _position_buffer[seg.index]

func _get_seg_end(seg: Segment) -> Vector3:
	return _position_buffer[seg.index + 1]

func _get_seg_flex_axis(seg: Segment) -> Vector3:
	return _get_seg_prev_basis(seg).y
	
func _get_seg_yaw_axis(seg: Segment) -> Vector3:
	return _get_seg_basis(seg).x