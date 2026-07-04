class_name BiCcdHelper


static func solve_rotation_to_direction(
	start_pos: Vector3,
	end_pos: Vector3,
	target_pos: Vector3,
	rotate_axis: Vector3
) -> float:
	assert(rotate_axis.is_normalized())
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


static func calculate_flex_from_basis(
	basis: Basis,
	target_dir: Vector3
) -> float:
	basis = basis.orthonormalized()
	target_dir = target_dir.normalized()
	
	var initial_forward := -basis.z.normalized()
	var flex_axis := basis.x.normalized()
	var desired_in_flex_plane := target_dir.slide(flex_axis)
	var initial_in_flex_plane := initial_forward
	
	if is_zero_approx(desired_in_flex_plane.length_squared()):
		return NAN
	var flex := initial_in_flex_plane.signed_angle_to(
		desired_in_flex_plane,
		flex_axis
	)
	return flex

static func calculate_yaw_from_basis(
	basis: Basis,
	target_dir: Vector3,
	flex_rad: float
) -> float:
	basis = basis.orthonormalized()
	target_dir = target_dir.normalized()
	
	# Construct the basis after flex but before yaw
	var zero_yaw_basis := (basis * Basis(Vector3.RIGHT, flex_rad)).orthonormalized()
	var zero_yaw_forward := -zero_yaw_basis.z.normalized()
	var yaw_axis := zero_yaw_basis.y.normalized()
	var desired_in_yaw_plane := target_dir.slide(yaw_axis)
	var initial_in_yaw_plane := zero_yaw_forward
	
	if is_zero_approx(desired_in_yaw_plane.length_squared()):
		return NAN
	var yaw := initial_in_yaw_plane.signed_angle_to(
		desired_in_yaw_plane,
		yaw_axis
	)
	return yaw