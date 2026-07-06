class_name BiCcdHelper


static func solve_rotation_to_direction(
	start_pos: Vector3,
	end_pos: Vector3,
	target_pos: Vector3,
	rotate_axis: Vector3
) -> float:
	if rotate_axis.is_zero_approx():
		return NAN
	rotate_axis = rotate_axis.normalized()
	var to_end := end_pos - start_pos
	var to_target := target_pos - start_pos
	var end_on_plane := to_end.slide(rotate_axis)
	var target_on_plane := to_target.slide(rotate_axis)
	if target_on_plane.is_zero_approx(): 
		return NAN
	if end_on_plane.is_zero_approx():
		return NAN
	return end_on_plane.signed_angle_to(
		target_on_plane,
		rotate_axis
	)

## [returns]: May return NaN if the flex is unsolvable when the target or the effector is just to the RIGHT of the joint
static func solve_flex_delta(
	start_pos: Vector3,
	end_pos: Vector3,
	target_pos: Vector3,
	flex_axis: Vector3
) -> float:
	return solve_rotation_to_direction(start_pos, end_pos, target_pos, flex_axis)

## Flex related arguments are required as the model assumes flex happens before yaw
## [returns]: May return NaN if the yaw is unsolvable when the target or the effector is just to the UP of the joint
static func solve_yaw_delta(
	start_pos: Vector3,
	end_pos: Vector3,
	target_pos: Vector3,
	current_yaw_axis: Vector3,
	flex_axis: Vector3,
	flex_delta: float
) -> float:
	var flex_rotation := Basis(
		flex_axis.normalized(),
		flex_delta
	)
	var flexed_effector_pos := start_pos + flex_rotation * (end_pos - start_pos)
	var flexed_yaw_axis := (flex_rotation * current_yaw_axis).normalized()
	return solve_rotation_to_direction(
		start_pos,
		flexed_effector_pos,
		target_pos,
		flexed_yaw_axis
	)
