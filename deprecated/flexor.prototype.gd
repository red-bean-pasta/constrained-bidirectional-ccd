# class_name SpiderLegFlexor2D

# Deprecated: Legacy model that didn't take yaw and its complexity on yaw into account


## The distance allowed between metatarsus tip and target position when resolving leg segments placements
var _tolerance: float
## The allowed number of resolving attempts before considering a target position unreachable and quitting
var _max_attempts: int

## How "damp" femur should be comparing to tibia in extending and folding
var _femur_damp: float


var _bones: SpiderLegBones


func _init(
	p_bones: SpiderLegBones,
	p_tolerance: float = 1e-6,
	p_max_attempt: int = 12,
	p_femur_damp: float = 0.8
) -> void:
	_bones = p_bones
	_tolerance = p_tolerance
	_max_attempts = p_max_attempt
	_femur_damp = p_femur_damp
	

## [param point]: The local point of leg bones' parent space
## [returns]: If target reached
func flex_to(target: Vector3) -> bool:
	var projected := SpiderLegReachProjector.project_flex(target)
	var flex := _get_flex_for_pos(projected)
	_place_bones(flex.points)
	return flex.reached
	
	
func _place_bones(points: Array[Vector2]):
	assert(_bones.count == points.size() - 1) # points include an additional starting point, (0,0)
	for i in range(_bones.count):
		var bone := _bones.get_indexed_at(i)
		var start2 := points[i]
		var start3 := SpiderLegReachProjector.elevate_flex(start2, bone.position)
		var end2 := points[i+1]
		var end3 := SpiderLegReachProjector.elevate_flex(end2, bone.end_position)
		bone.position = start3
		bone.basis = Basis.looking_at(end3 - start3)
	
	
func _get_flex_for_pos(pos: Vector2) -> Flex:
	var placement := HingePlacement2D.new(0)
	var flex := _build_flex_for_pos(pos, placement)
	
	if not flex.reached: # coxa-trochanter bone are lazy and only rotates when absolutely necessary
		var coxa_dir := _resolve_coxa_rotation(placement, pos)
		var coxa_rad := coxa_dir.angle()
		placement.clear(coxa_rad)
		flex = _build_flex_for_pos(pos, placement)
	
	return flex

func _build_flex_for_pos(pos: Vector2, placement: HingePlacement2D) -> Flex:
	var attempt := 0
	var l := 0.0
	var h := 1.0
	while true:
		var m := (l + h) * 0.5
		var r := _check_position_reachable_at_pressure(m, pos, placement)
		match r:
			Utils.BinarySearchResult.LEFT:
				h = m
			Utils.BinarySearchResult.RIGHT:
				l = m
			Utils.BinarySearchResult.MIDDLE:
				break
		attempt += 1
		if attempt >= _max_attempts:
			print_debug("Failed to resolve leg placements for %s after %s iterations" % [pos, attempt])
			break
	
	var reached := _check_if_reached(placement.end, pos)
	var pressure := (l + h) * 0.5
	var result := Flex.new(reached, pressure, placement.points.duplicate())
	return result
	
func _resolve_coxa_rotation(placement: HingePlacement2D, pos: Vector2) -> Vector2:
	assert(not _check_if_reached(placement.end, pos))
	assert(is_zero_approx(placement.start_rad))
	
	# This method simply assumes that spider leg has best reachability when coxa is pointing directly at the target position
	# This assumption is inspired assuming spider's anatomy is mostly accustomed and adjusted to walking on flat surface
	var dir := placement._clamp_segment_dir(
		_bones.coxa_trochanter,
		placement.start_dir,
		pos - placement.points[0],
	)
	return dir


func _check_position_reachable_at_pressure(
	pressure: float, 
	pos: Vector2,
	placement: HingePlacement2D,
) -> Utils.BinarySearchResult:
	_build_coxa_femur_placement_at_pressure(pressure, placement)
	_resolve_tibia_metatarsus_placement(pos, placement, pressure)
	if _check_if_reached(placement.end, pos):
		return Utils.BinarySearchResult.MIDDLE
	return _find_pressure_direction(placement.end, pos, placement.start_dir)
	
func _build_coxa_femur_placement_at_pressure(pressure: float, placement: HingePlacement2D):
	placement.refresh()
	placement.add_bone(_bones.coxa_trochanter)
	placement.add_pressured_bone(_bones.femur, _damp_pressure(pressure, _femur_damp))

func _resolve_tibia_metatarsus_placement(
	pos: Vector2,
	placement: HingePlacement2D,
	pressure: float
):
	assert(placement.points.size() == 3)
	
	var tibia := _bones.patella_tibia
	var mtts := _bones.metatarsus_tarsus
	
	var tibia_start := placement.end
	var femur_tibia_dir := pos - tibia_start
	var v = Helper2D.find_triangle_vertex(tibia_start, pos, tibia.length, mtts.length, 1)
	if v != null: 
		femur_tibia_dir = (v as Vector2) - tibia_start
	
	var femur_tibia_clamp := _get_pressured_joint_range(tibia, pressure, tibia.rest_rad)
	placement.add_scene_directed_bone(tibia, femur_tibia_dir, femur_tibia_clamp)
	
	var tibia_mtts_dir := pos - placement.end
	placement.add_scene_directed_bone(mtts, tibia_mtts_dir)


func _check_if_reached(from: Vector2, to: Vector2) -> bool:
	return (to - from).length_squared() <= _tolerance ** 2

static func _find_pressure_direction(
	current_pos: Vector2,
	target_pos: Vector2,
	start_dir: Vector2,
	perpendicular_result: Utils.BinarySearchResult = Utils.BinarySearchResult.MIDDLE
) -> Utils.BinarySearchResult:
	var dot := (target_pos - current_pos).dot(start_dir)
	if dot > 0:
		return Utils.BinarySearchResult.RIGHT
	if dot == 0:
		return perpendicular_result
	return Utils.BinarySearchResult.LEFT

static func _damp_pressure(pressure: float, damp: float) -> float:
	return pow(pressure, 1.0 / damp)
	
	
## Useful to apply pressure constraints when a bone's placement is determined by geometry.
## [param resting_angle] If null, will be default to (p_min + p_max) / 2
static func _get_pressured_joint_range(
	bone: SpiderLegBone,
	pressure: float,
	rest_rad: float
) -> Vector2:
	assert(0.0 <= pressure and pressure <= 1.0)
	assert(rest_rad is float and bone.min_rad <= rest_rad and rest_rad <= bone.max_rad)
	
	var min_rad := bone.min_rad
	var max_rad := bone.max_rad
	var rest_pres := SpiderLegBonePlacement.rad_to_pressure(rest_rad, min_rad, max_rad)
	
	var min_prog := _evaluate_pressure_progress(pressure, rest_pres, 0.0)
	var max_prog := _evaluate_pressure_progress(pressure, rest_pres, 1.0)
	var min_push := _progress_to_push(min_prog)
	var max_push := _progress_to_push(max_prog)
	
	var pushed_min := lerpf(rest_rad, min_rad, min_push)
	var pushed_max := lerpf(rest_rad, max_rad, max_push)
	assert(pushed_max > pushed_min)
	return Vector2(pushed_min, pushed_max)

static func _evaluate_pressure_progress(
	pressure: float,
	rest_pressure: float,
	border_pressure: float
) -> float:
	# sliding pressure from border to rest to the other side,
	# result will change from 1 to 0 to -INF.
	var off := pressure - rest_pressure
	var base := border_pressure - rest_pressure
	if is_zero_approx(base):
		return -INF if off <= 0 else 1.0
	return clampf(off / base, -INF, 1.0)

static func _progress_to_push(
	progress: float
) -> float:
	const stable_push := 0.5
	
	if progress <= 0.0:
		const min_push := -0.2
		const neg_k := 1.5
		return min_push + (stable_push - min_push) * exp(neg_k * progress)
	
	assert(progress <= 1.0)
	const pos_k := 2.0
	return 1.0 - (1.0 - stable_push) * pow(1.0 - progress, pos_k)
	

class Flex:
	## False if placements exited after exceeding max attempts rather than actually reaching the target position
	var reached: bool
	var pressure: float
	## With origin (0,0) included
	var points: Array[Vector2]
	
	func _init(
		p_reached: bool,
		p_pressure: float, 
		p_points: Array[Vector2]
	) -> void:
		reached = p_reached
		pressure = p_pressure
		points = p_points
