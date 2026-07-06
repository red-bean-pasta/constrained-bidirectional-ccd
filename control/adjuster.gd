## Note that flex happens before yaw, following the formula [code]yaw_rotation * flex_rotation * prev_basis[/code].
## Note that returned [BiCcdReachResult] is cached and reused. Callers should clone it if storage is needed.
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
	
## Must be called when the chain is updated to refresh placements cache
func update() -> void:
	_placements = AdjustablePlacements.new(_segments)


## This method does not perform iteration and convergence. It simply process one pass.
func get_backward_adjust_step(
	global_position: Vector3,
	tolerance: float,
	refresh: bool = true,
) -> BiCcdReachResult:
	var local_position := _chain.to_local(global_position)
	return get_backward_adjust_step_local(local_position, tolerance, refresh)
	
## This method does not perform iteration and convergence. It simply process one pass.
## [param pos]: Local to the [BiCcdChain] space
func get_backward_adjust_step_local(
	local_position: Vector3,
	tolerance: float,
	refresh: bool = true,
) -> BiCcdReachResult:
	var reached := _placements.adjust_to(local_position, tolerance, true, refresh)
	return _placement_to_result(reached, _placements, _result)
	

## This method does not perform iteration and convergence. It simply process one pass.
func get_forward_adjust_step(
	global_position: Vector3, 
	tolerance: float,
	refresh: bool = true,
) -> BiCcdReachResult:
	var local_position := _chain.to_local(global_position)
	return get_forward_adjust_step_local(local_position, tolerance, refresh)

## This method does not perform iteration and convergence. It simply process one pass.
## [param pos]: Local to the [BiCcdChain] space
func get_forward_adjust_step_local(
	local_position: Vector3, 
	tolerance: float,
	refresh: bool = true,
) -> BiCcdReachResult:
	var reached := _placements.adjust_to(local_position, tolerance, false, refresh)
	return _placement_to_result(reached, _placements, _result)


## This method does not perform iteration and convergence. It simply process one pass.
func get_segment_forward_adjust_step(
	global_position: Vector3, 
	tolerance: float,
	refresh: bool = true,
) -> BiCcdReachResult:
	var local_position := _chain.to_local(global_position)
	return get_segment_forward_adjust_step_local(local_position, tolerance, refresh)

## This method does not perform iteration and convergence. It simply process one pass.
## [param pos]: Local to the [BiCcdChain] space
func get_segment_forward_adjust_step_local(
	local_position: Vector3, 
	tolerance: float,
	refresh: bool = true,
) -> BiCcdReachResult:
	var reached := _placements.adjust_segment_to(local_position, tolerance, false, refresh)
	return _placement_to_result(reached, _placements, _result)


## Performs iteration until converged or capped, like traditional CCD
## [param mode]: Some common use cases:
## 	0: backward adjust only;
## 	1: forward adjust only;
##	2: loop between backward and forward adjust, each account for one attempt;
func get_full_adjust(
	global_position: Vector3, 
	tolerance: float,
	mode: int,
	max_attempts: int = 10,
	align_segment_first: bool = false
) -> BiCcdReachResult:
	var local_position := _chain.to_local(global_position)
	return get_full_adjust_local(local_position, tolerance, mode, max_attempts)

## Performs iteration until converged or capped, like traditional CCD
## [param pos]: Local to the [BiCcdChain] space
## [param mode]: Some convenient common use cases:
## 	0: backward adjust only;
## 	1: forward adjust only;
##	2: loop between backward and forward adjust, each accounting for one attempt;
## [param align_segment_first]: Forward align segment instead of joint-effector to the target position first before performing adjustments. Account as one attempt
func get_full_adjust_local(
	local_position: Vector3, 
	tolerance: float,
	mode: int,
	max_attempts: int = 10,
	align_segment_first: bool = false
) -> BiCcdReachResult:
	assert(max_attempts > 0)
	BiCcdUtils.assert_range(mode, 0, 2)
	
	_placements.refresh()
	
	var reached: bool = false
	
	if align_segment_first:
		reached = _placements.adjust_segment_to(
			local_position, 
			tolerance,
			true, 
			false
		)
		max_attempts -= 1
	if reached:
		return _placement_to_result(reached, _placements, _result)
	
	for i in max_attempts:
		var backward := (
			true 
			if mode == 0 else 
			false 
			if mode == 1 else 
			(i + 1) % 2 == 1
		)
		if _placements.adjust_to(
			local_position, 
			tolerance,
			backward, 
			false
		):
			reached = true
			break
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
	
	## [param p_basis_buffer]: Optional reusable basis buffer to avoid allocation. Micro-optiomization
	func _init(p_segments: Array[BiCcdSegment]) -> void:
		if p_segments.size() < 1:
			push_warning("Initliazed with empty segments")
		_placements = BiCcdPlacements.new(p_segments)
	
	func refresh() -> void:
		_placements.refresh()
	
	## [param p_from_terminal]: If true, adjust from the terminal to the target pos then propagate to the proximal, vice versa
	## [param p_joint_to_effector]: 
	## [param p_refresh]: If false, process will happen on whatever was left since the last adjustment, which may not correctly reflect the current layout of segments
	func adjust_to(
		p_position: Vector3,
		p_tolerance: float,
		p_backward: bool,
		p_refresh: bool = true,
	) -> bool:
		return _adjust_to(p_position, p_tolerance, p_backward, true, p_refresh)
	
	## Align the joint's segment to the target position rather than the joint-effector
	## [param p_refresh]: If false, process will happen on whatever was left since the last adjustment, which may not correctly reflect the current layout of segments
	func adjust_segment_to(
		p_position: Vector3,
		p_tolerance: float,
		p_backward: bool = true,
		p_refresh: bool = true,
	) -> bool:
		return _adjust_to(p_position, p_tolerance, p_backward, false, p_refresh)
		
	func _adjust_to(
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
				if _adjust_and_check(i, p_position, p_tolerance, p_joint_to_effector):
					return true
		else:
			for i in _count:
				if _adjust_and_check(i, p_position, p_tolerance, p_joint_to_effector):
					return true
		return false
	
	func _adjust_and_check(
		seg_idx: int, 
		pos: Vector3,
		tolerance: float,
		joint_to_effector: bool
	) -> bool:
		var seg := _segments[seg_idx]
		if joint_to_effector:
			_adjust_joint_effector_to(seg, pos)
		else:
			_adjust_segment_to(seg, pos)
		return _placements.check_reached(pos, tolerance)
	
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
	