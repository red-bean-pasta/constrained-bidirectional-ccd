## Note that flex happens before yaw, following the formula `yaw_rotation * flex_rotation * prev_basis`
class_name BiCcdAdjuster

var _tolerance: float
var _segments: Array[BiCcdSegment]

## Reusable placement to avoid allocations
var _placements: AdjustablePlacements

func _init(
	p_tolerance: float,
	p_segments: Array[BiCcdSegment],
) -> void:
	_tolerance = p_tolerance
	_segments = p_segments
	_placements = AdjustablePlacements.new(
		_tolerance, 
		_segments
	)


## This method does not perform iteration and convergence. It simply process one pass.
## [param pos]: Local to SegmentLeg space
## [param out]: Optional argument to reuse reach result to reduce allocations
func get_backward_adjust_step(
	position: Vector3, 
	output: BiCcdReachResult = null,
) -> BiCcdReachResult:
	var reached := _placements.adjust_to(position, true, true, true)
	return _placement_to_result(reached, _placements, output)
	
## This method does not perform iteration and convergence. It simply process one pass.
## [param pos]: Local to SegmentLeg space
## [param joint_to_effector]: If true, align joint-effector to `pos`, else align the joint's segment to `pos`
## [param out]: Optional argument to reuse reach result to reduce allocations
## [param refresh]: 
func get_forward_adjust_step(
	position: Vector3, 
	joint_to_effector: bool = true,
	output: BiCcdReachResult = null,
) -> BiCcdReachResult:
	var reached := _placements.adjust_to(position, false, joint_to_effector, true)
	return _placement_to_result(reached, _placements, output)


## Performs iteration until converged or capped, like traditional CCD
## [param mode]: Some common use cases:
## 	0: backward adjust only;
## 	1: forward adjust only;
##	2: loop between backward and forward adjust, each account for one attempt;
## 	3: same as 1, but with the forward pass aligning segment instead of joint-effector
func get_full_adjust(
	mode: int,
	position: Vector3, 
	max_attempts: int = 10,
	output: BiCcdReachResult = null
) -> BiCcdReachResult:
	assert(max_attempts > 0)
	BiCcdUtils.assert_range(mode, 0, 2)
	
	_placements.refresh()
	
	var reached: bool = false
	for i in max_attempts:
		var backward := true if mode == 0 else false if mode == 1 else (i + 1) % 2 == 1
		var joint_to_effector := true if mode != 3 or backward else false 
		if _placements.adjust_to(
			position, 
			backward, 
			joint_to_effector,
			false
		):
			reached = true
			break
			
	return _placement_to_result(reached, _placements, output)
		
static func _placement_to_result(
	reached: bool,
	placements: AdjustablePlacements,
	output: BiCcdReachResult
) -> BiCcdReachResult:
	if output:
		output.reached = reached
		output.bases = placements.bases
		output.positions = placements.positions
		return output
	return BiCcdReachResult.new(
		reached,
		placements.bases,
		placements.positions
	)
	

class AdjustablePlacements:
	var _tolerance: float
	var _placements: BiCcdPlacements
	
	var _count: int:
		get: return _placements.count
	var _segments: Array[BiCcdSegment]:
		get: return _placements._segments
		
	var bases: Array[Basis]:
		get: return _placements.bases
	var positions: Array[Vector3]:
		get: return _placements.positions
	
	## [param p_basis_buffer]: Optional reusable basis buffer to avoid allocation. Micro-optiomization
	func _init(
		p_tolerance: float,
		p_segments: Array[BiCcdSegment],
	) -> void:
		_tolerance = p_tolerance
		_placements = BiCcdPlacements.new(p_segments)
	
	func refresh() -> void:
		_placements.refresh()
	
	## [param p_from_terminal]: If true, adjust from the terminal to the target pos then propagate to the proximal, vice versa
	## [param p_joint_to_effector]: Cautious: If false, it will align the joint's segment to the target position rather than the joint-effector
	## [param p_refresh]: Cautious: If false, process will happen on whatever was left since the last adjustment, which may not correctly reflect the current layout of segments
	func adjust_to(
		p_position: Vector3,
		p_backward: bool,
		p_joint_to_effector: bool = true,
		p_refresh: bool = true,
	) -> bool:
		if p_refresh:
			refresh()
		if p_backward: # To avoid the range()
			for i in range(_count - 1, -1, -1):
				if _adjust_and_check(i, p_position, p_joint_to_effector):
					return true
		else:
			for i in _count:
				if _adjust_and_check(i, p_position, p_joint_to_effector):
					return true
		return false
	
	func _adjust_and_check(
		seg_idx: int, 
		pos: Vector3,
		joint_to_effector: bool
	) -> bool:
		var seg := _segments[seg_idx]
		if joint_to_effector:
			_adjust_joint_effector_to(seg, pos)
		else:
			_adjust_segment_to(seg, pos)
		return _placements.check_reached(pos, _tolerance)
	
	func _adjust_segment_to(
		seg: BiCcdSegment, 
		pos: Vector3,
	) -> void:
		_adjust_seg_relative_to(seg, _placements._get_seg_end(seg), pos)

	func _adjust_joint_effector_to(
		seg: BiCcdSegment, 
		pos: Vector3,
	) -> void:
		_adjust_seg_relative_to(seg, _placements.end_position, pos)
		
	func _adjust_seg_relative_to(
		seg: BiCcdSegment, 
		end_pos: Vector3,
		target_pos: Vector3,
	) -> void:
		if not seg.movable:
			return
		
		var flex_delta := 0.0
		if seg.flexible:
			var flex_delta_needed := _placements._solve_relative_flex_delta(
				seg, 
				end_pos,
				target_pos
			)
			flex_delta = (
				seg._clamp_flex_delta(flex_delta_needed)
				if not is_nan(flex_delta_needed) else 
				0.0 # Skip adjusting instead of fallback as the next frame may change the situation
			)
		
		var yaw_delta := 0.0
		if seg.yawable:
			var yaw_delta_needed := _placements.solve_relative_yaw_delta(
				seg,
				end_pos, 
				target_pos,
				flex_delta
			)
			yaw_delta = (
				seg._clamp_yaw_delta(yaw_delta_needed)
				if not is_nan(yaw_delta_needed) else 
				0.0
			)
		
		_placements.rotate_seg_from_current(seg, flex_delta, yaw_delta)
	