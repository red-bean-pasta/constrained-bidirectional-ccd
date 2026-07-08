## This class provides two interface styles:
## 1. Single-step methods, whose names end in `step`. The caller performs one iteration, evaluates convergence, interpolates the result, and applies it manually.
## 2. Fully converged methods, which behave like traditional CCD solvers.
## WARNING: Flex is applied before yaw: [code]yaw_rotation * flex_rotation * previous_basis[/code]
## WARNING: Returned [BiCcdReachResult] instances are cached and reused. Call [BiCcdReachResult.duplicate()] before storing a result.
@tool
class_name BiCcdAdjuster


var _chain: BiCcdChain
var _segments: Array[BiCcdSegment]:
	get: return _chain.segments

## Reusable placement to reduce allocations
var _placements: AdjustablePlacements
## Reusable result to reduce allocations
var _result: BiCcdReachResult


static func apply(
	p_segments: Array[BiCcdSegment],
	p_bases: Array[Basis],
	p_positions: Array[Vector3],
) -> void:
	assert(p_bases.size() == p_segments.size() + 1)
	assert(p_positions.size() == p_segments.size() + 1)
	for i in p_segments.size():
		p_segments[i].transform = Transform3D(
			p_bases[i + 1],
			p_positions[i]
		)


func _init(p_chain: BiCcdChain) -> void:
	_chain = p_chain
	_placements = AdjustablePlacements.new(_segments)
	_result = BiCcdReachResult.empty


func get_backward_adjust_step(
	global_position: Vector3,
	tolerance: float,
	refresh: bool = true,
) -> BiCcdReachResult:
	var local_position := _chain.to_local(global_position)
	return get_backward_adjust_step_local(local_position, tolerance, refresh)
	
func get_backward_adjust_step_local(
	local_position: Vector3,
	tolerance: float,
	refresh: bool = true,
) -> BiCcdReachResult:
	var reached := _placements.adjust_by_joint_effector(local_position, tolerance, true, refresh)
	return _placement_to_result(reached, _placements, _result)
	

func get_forward_adjust_step(
	global_position: Vector3, 
	tolerance: float,
	refresh: bool = true,
) -> BiCcdReachResult:
	var local_position := _chain.to_local(global_position)
	return get_forward_adjust_step_local(local_position, tolerance, refresh)

func get_forward_adjust_step_local(
	local_position: Vector3, 
	tolerance: float,
	refresh: bool = true,
) -> BiCcdReachResult:
	var reached := _placements.adjust_by_joint_effector(local_position, tolerance, false, refresh)
	return _placement_to_result(reached, _placements, _result)


func get_segments_forward_adjust_step(
	global_position: Vector3, 
	tolerance: float,
	refresh: bool = true,
) -> BiCcdReachResult:
	var local_position := _chain.to_local(global_position)
	return get_segments_forward_adjust_step_local(local_position, tolerance, refresh)

func get_segments_forward_adjust_step_local(
	local_position: Vector3, 
	tolerance: float,
	refresh: bool = true,
) -> BiCcdReachResult:
	var reached := _placements.adjust_by_segment(local_position, tolerance, false, refresh)
	return _placement_to_result(reached, _placements, _result)


## WARNING: Low level method that directly adjust a joint aligned to a target position
## [param joint_to_effector]: If true, align the joint-to-effector direction to the target position, else align the joint's segment
func get_joint_adjust_step(
	joint_index: int,
	global_position: Vector3, 
	tolerance: float,
	joint_to_effector: bool = true,
	refresh: bool = false,
) -> BiCcdReachResult:
	var local_position := _chain.to_local(global_position)
	return get_joint_adjust_step_local(joint_index, local_position, tolerance, joint_to_effector, refresh)

## WARNING: Low level method that directly adjust a joint aligned to a target position
## [param joint_to_effector]: If true, align the joint-to-effector direction to the target position, else align the joint's segment
func get_joint_adjust_step_local(
	joint_index: int,
	local_position: Vector3, 
	tolerance: float,
	joint_to_effector: bool = true,
	refresh: bool = false,
) -> BiCcdReachResult:
	if refresh:
		_placements.refresh()
		
	var reached := _placements._adjust_segment_and_check(joint_index, local_position, tolerance, joint_to_effector)
	return _placement_to_result(
		reached,
		_placements,
		_result
	)


enum FullAdjustMode {
	BACKWARD_ONLY,
	FORWARD_ONLY,
	ALIGN_SEGMENT_FIRST_BACKWARD,
	FORWARD_ALIGNED_CYCLIC,
	BACKWARD_FIRST_FORWARD
}

static var mode_map: Dictionary[FullAdjustMode, ExperimentFullAdjustMode] = {
	FullAdjustMode.BACKWARD_ONLY : ExperimentFullAdjustMode.BACKWARD_ONLY,
	FullAdjustMode.FORWARD_ONLY : ExperimentFullAdjustMode.FORWARD_ONLY,
	FullAdjustMode.ALIGN_SEGMENT_FIRST_BACKWARD : ExperimentFullAdjustMode.BACKWARD_ONLY,
	FullAdjustMode.FORWARD_ALIGNED_CYCLIC : ExperimentFullAdjustMode.FORWARD_ALIGNED_CYCLIC,
	FullAdjustMode.BACKWARD_FIRST_FORWARD : ExperimentFullAdjustMode.FORWARD_ONLY,
}

func get_full_adjust(
	global_position: Vector3, 
	tolerance: float,
	mode: FullAdjustMode,
	max_attempts: int = 10,
) -> BiCcdReachResult:
	return get_full_adjust_local(global_position, tolerance, mode, max_attempts)

func get_full_adjust_local(
	local_position: Vector3, 
	tolerance: float,
	mode: FullAdjustMode,
	max_attempts: int = 10,
) -> BiCcdReachResult:
	var mapped := mode_map[mode]
	var backward_first := mode == FullAdjustMode.BACKWARD_FIRST_FORWARD
	var forward_first := false
	var align_segments_first := mode == FullAdjustMode.ALIGN_SEGMENT_FIRST_BACKWARD
	return _get_full_adjust_local_inner(
		local_position,
		tolerance,
		mapped,
		max_attempts,
		backward_first,
		forward_first,
		align_segments_first
	)


enum ExperimentFullAdjustMode{
	BACKWARD_ONLY,
	FORWARD_ONLY,
	SIMPLE_CYCLIC,
	BACKWARD_ALIGNED_CYCLIC,
	FORWARD_ALIGNED_CYCLIC,
	BOTH_ALIGNED_CYCLIC,
}

func _get_full_adjust_inner(
	global_position: Vector3, 
	tolerance: float,
	mode: ExperimentFullAdjustMode,
	max_attempts: int = 10,
	backward_first: bool = false,
	forward_first: bool = false,
	align_segments_first: bool = false
) -> BiCcdReachResult:
	var local_position := _chain.to_local(global_position)
	return _get_full_adjust_local_inner(local_position, tolerance, mode, max_attempts, backward_first, forward_first, align_segments_first)

func _get_full_adjust_local_inner(
	local_position: Vector3, 
	tolerance: float,
	mode: ExperimentFullAdjustMode,
	max_attempts: int = 10,
	backward_first: bool = false,
	forward_first: bool = false,
	align_segments_first: bool = false
) -> BiCcdReachResult:
	return _get_full_adjust_local_base(local_position, tolerance, mode, max_attempts, backward_first, forward_first, align_segments_first, false)
	

func _get_full_adjust_steps_inner(
	global_position: Vector3, 
	tolerance: float,
	mode: ExperimentFullAdjustMode,
	max_attempts: int = 10,
	backward_first: bool = false,
	forward_first: bool = false,
	align_segments_first: bool = false
) -> Array[BiCcdReachResult]:
	var local_position := _chain.to_local(global_position)
	return _get_full_adjust_steps_local_inner(local_position, tolerance, mode, max_attempts, backward_first, forward_first, align_segments_first)

func _get_full_adjust_steps_local_inner(
	local_position: Vector3, 
	tolerance: float,
	mode: ExperimentFullAdjustMode,
	max_attempts: int = 10,
	backward_first: bool = false,
	forward_first: bool = false,
	align_segments_first: bool = false
) -> Array[BiCcdReachResult]:
	return _get_full_adjust_local_base(local_position, tolerance, mode, max_attempts, backward_first, forward_first, align_segments_first, true)


var _full_adjust_steps_cache: Array[BiCcdReachResult] = []

func _get_full_adjust_local_base(
	local_position: Vector3, 
	tolerance: float,
	mode: ExperimentFullAdjustMode,
	max_attempts: int = 10,
	backward_first: bool = false,
	forward_first: bool = false,
	align_segments_first: bool = false,
	steps: bool = false,
) -> Variant:
	assert(max_attempts > 0)
	
	_full_adjust_steps_cache.clear()
	_placements.refresh()
	var reached: bool = false
	
	var initial_attempt := 0
	while initial_attempt < 3 and max_attempts > 0:
		initial_attempt += 1
		if initial_attempt == 1:
			if not align_segments_first:
				continue
			reached = _placements.adjust_by_segment(local_position, tolerance, false, false)
		elif initial_attempt == 2:
			if not backward_first:
				continue
			reached = _placements.adjust_by_joint_effector(local_position, tolerance, true, false)
		else:
			if not forward_first:
				continue
			reached = _placements.adjust_by_joint_effector(local_position, tolerance, false, false )
		
		max_attempts -= 1
		if steps:
			_append_full_adjust_step(reached)
		if reached:
			return _full_adjust_steps_cache.duplicate() if steps else _get_result(true)
	
	var backward_only := mode == ExperimentFullAdjustMode.BACKWARD_ONLY
	var forward_only := mode == ExperimentFullAdjustMode.FORWARD_ONLY
	var align_forward := (
		mode == ExperimentFullAdjustMode.FORWARD_ALIGNED_CYCLIC
		or mode == ExperimentFullAdjustMode.BOTH_ALIGNED_CYCLIC
	)
	var align_backward := (
		mode == ExperimentFullAdjustMode.BACKWARD_ALIGNED_CYCLIC
		or mode == ExperimentFullAdjustMode.BOTH_ALIGNED_CYCLIC
	)
	for i in max_attempts:
		var backward := (
			true 
			if backward_only else 
			false 
			if forward_only else 
			(i & 1) == 0
		)
		reached = _placements.adjust_by_joint_effector(
			local_position, 
			tolerance,
			backward, 
			false
		)
		
		if not reached:
			if not backward and align_forward:
				reached = _placements._adjust_segment_and_check(0, local_position, tolerance, true)
			elif backward and align_backward:
				reached = _placements._adjust_segment_and_check(-1, local_position, tolerance, true)
		
		if steps:
			_append_full_adjust_step(reached)
		if reached:
			break
	
	if steps:
		return _full_adjust_steps_cache.duplicate()
	return _get_result(reached)

func _append_full_adjust_step(reached: bool) -> void:
	var result := _get_result(reached)
	_full_adjust_steps_cache.append(result.duplicate())


func _get_result(reached: bool) -> BiCcdReachResult:
	return _placement_to_result(reached, _placements, _result)
		
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
	var _placements: BiCcdPlacements
	
	var _count: int:
		get: return _placements.count
	var _segments: Array[BiCcdSegment]:
		get: return _placements._segments
		
	var bases: Array[Basis]:
		get: return _placements.bases
	var positions: Array[Vector3]:
		get: return _placements.positions
	
	func _init(p_segments: Array[BiCcdSegment]) -> void:
		assert(p_segments.size() > 0)
		_placements = BiCcdPlacements.new(p_segments)
	
	func refresh() -> void:
		_placements.refresh()
	
	## [param p_refresh]: If false, process will happen on whatever was left since the last adjustment, which may not correctly reflect the current layout of segments
	func adjust_by_joint_effector(
		p_position: Vector3,
		p_tolerance: float,
		p_backward: bool,
		p_refresh: bool = true,
	) -> bool:
		return _adjust(p_position, p_tolerance, p_backward, true, p_refresh)
	
	## Align the joint's segment to the target position rather than the joint-effector
	## [param p_refresh]: If false, process will happen on whatever was left since the last adjustment, which may not correctly reflect the current layout of segments
	func adjust_by_segment(
		p_position: Vector3,
		p_tolerance: float,
		p_backward: bool = false,
		p_refresh: bool = true,
	) -> bool:
		return _adjust(p_position, p_tolerance, p_backward, false, p_refresh)
		
	func _adjust(
		p_position: Vector3,
		p_tolerance: float,
		p_backward: bool,
		p_joint_to_effector: bool,
		p_refresh: bool = true,
	) -> bool:
		if _count < 1:
			return false
		if p_refresh:
			refresh()
		if p_backward: # To avoid the range()
			for i in range(_count - 1, -1, -1):
				if _adjust_segment_and_check(i, p_position, p_tolerance, p_joint_to_effector):
					return true
		else:
			for i in _count:
				if _adjust_segment_and_check(i, p_position, p_tolerance, p_joint_to_effector):
					return true
		return false
	
	func _adjust_segment_and_check(
		seg_idx: int, 
		pos: Vector3,
		tolerance: float,
		joint_to_effector: bool
	) -> bool:
		var seg := _segments[seg_idx]
		if joint_to_effector:
			_adjust_segment_by_joint_effector(seg, pos)
		else:
			_adjust_segment_by_segment(seg, pos)
		return _placements.check_reached(pos, tolerance)
	
	func _adjust_segment_by_segment(
		seg: BiCcdSegment, 
		pos: Vector3,
	) -> void:
		_adjust_segment_relative_to(seg, _placements._get_seg_end(seg), pos)

	func _adjust_segment_by_joint_effector(
		seg: BiCcdSegment, 
		pos: Vector3,
	) -> void:
		_adjust_segment_relative_to(seg, _placements.end_position, pos)
		
	func _adjust_segment_relative_to(
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
				_placements.clamp_flex_delta(seg, flex_delta_needed)
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
				_placements.clamp_yaw_delta(seg, yaw_delta_needed)
				if not is_nan(yaw_delta_needed) else 
				0.0
			)
		
		_placements.rotate_seg_from_current(seg, flex_delta, yaw_delta)
	