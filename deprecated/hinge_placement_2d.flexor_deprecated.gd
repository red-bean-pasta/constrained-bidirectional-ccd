class_name HingePlacement2D

var _start_rad: float
var start_dir: Vector2
var points: Array[Vector2] = []

var start_rad: float:
	get: 
		return _start_rad
	set(value): 
		_start_rad = value
		start_dir = Vector2(cos(start_rad), sin(start_rad))

var current_dir: Vector2:
	get:
		if len(points) < 2:
			return start_dir
		return (points[-1] - points[-2]).normalized()

var _from_dir: Vector2:
	get:
		if len(points) < 2:
			return -start_dir
		return -(points[-1] - points[-2]).normalized()
		
var end: Vector2:
	get: return points[-1]


func _init(p_start_rad: float) -> void:
	start_rad = p_start_rad
	refresh()

func clear(p_start_rad: float) -> void:
	start_rad = p_start_rad
	refresh()

func refresh() -> void:
	points.clear()
	points.append(Vector2.ZERO)


## Removement includes item at passed index
func remove_from(index: int) -> void:
	if index < 0:
		index = points.size() + index
	index = clampi(index, 1, points.size())
	points.resize(index)


## Follow last segement's direction
func add_segment(seg: Node, clamp_overrides: Vector2 = Vector2.INF) -> void:
	add_scene_directed_segment(seg, current_dir, clamp_overrides)

func add_scene_directed_segment(seg: Node, to_dir: Vector2, clamp_overrides: Vector2 = Vector2.INF) -> void:
	var normalized_dir := _clamp_segment_dir(seg, _from_dir, to_dir, clamp_overrides)
	_add_segment_in_scene_dir(seg, normalized_dir)

## Expects same rotation direction of passed rad, segment and clamp override
func add_relative_opened_segment(seg: Node, rad: float, clamp_overrides: Vector2 = Vector2.INF) -> void:
	var dir := _get_scene_dir_of_opened_segment(seg, rad, _from_dir, clamp_overrides)
	_add_segment_in_scene_dir(seg, dir)

func _get_scene_dir_of_opened_segment(
	seg: Node,
	rad: float,
	from_dir: Vector2,
	clamp_overrides: Vector2 = Vector2.INF
) -> Vector2:
	var normalized := _clock_and_clamp_segment_openness(seg, rad, clamp_overrides)
	var to_dir := from_dir.rotated(normalized)
	return to_dir
	
func _add_segment_in_scene_dir(seg: Node, dir: Vector2) -> void:
	var pos := end + dir.normalized() * _get_length(seg)
	points.append(pos)


## Expects same rotation direction of passed rad, bone and clamp override
## [Return] counterclockwise clamped rad
func _clock_and_clamp_segment_openness(
	seg: Node,
	rad: float,
	clamp_overrides: Vector2 = Vector2.INF
) -> float:
	var clamped := _clamp_segment_openness(rad, seg, clamp_overrides)
	var clocked := clamped * (1.0 if _is_counterclockwise(seg) else -1.0)
	return clocked

## Expects passed direction arguments in scene level
## [param from_dir] Note the direction of from_dir. It should be <-·-> not ·->->
## [Return] Direction in scene level
func _clamp_segment_dir(
	seg: Node,
	from_dir: Vector2,
	to_dir: Vector2, 
	clamp_overrides: Vector2 = Vector2.INF
) -> Vector2:
	var rad := from_dir.angle_to(to_dir)
	var normalized := _clamp_counterclockwise_segment_openness(rad, seg, clamp_overrides)
	return from_dir.rotated(normalized)

## Expects same rotation direction of passed rad, bone and clamp override
func _clamp_segment_openness(
	rad: float, 
	seg: Node,
	clamp_overrides: Vector2 = Vector2.INF
) -> float:
	var limits := _resolve_rad_limit(seg, clamp_overrides)
	var clamped := MiscUtils.wrap_clamp_rad(rad, limits.x, limits.y)
	return clamped

## [Return] Counterclockwise rad 
func _clamp_counterclockwise_segment_openness(
	rad: float,
	seg: Node,
	clamp_overrides: Vector2 = Vector2.INF
) -> float:
	var limits := _resolve_rad_limit(seg, clamp_overrides)
	if not _is_counterclockwise(seg):
		limits = Vector2(-limits.y, -limits.x)
	var clamped := MiscUtils.wrap_clamp_rad(rad, limits.x, limits.y)
	return clamped
	
func _resolve_rad_limit(seg: Node, clamp_overrides: Vector2) -> Vector2:
	return clamp_overrides if clamp_overrides.is_finite() else _get_segment_clamp(seg)


###### Override may be needed

func _is_counterclockwise(seg: Node) -> bool:
	const f1 := "counterclockwise"
	var is_counterclockwise = seg.get(f1)
	if is_counterclockwise != null:
		return is_counterclockwise
	
	const f2 := "clockwise"
	var is_clockwise = seg.get(f2)
	if is_clockwise != null:
		return not is_clockwise
	
	push_warning("Unable to determine the rotation direction of '%s'. Default to counterclockwise" % seg.get_path())
	return true

### [return] In rad
func _get_segment_clamp(seg: Node) -> Vector2:
	const method := "get_clamp"
	if seg.has_method(method):
		return seg.get_clamp()
	return Vector2.INF
	
func _get_length(node: Node) -> float:
	const param := "length"
	var length = node.get(param)
	if length != null:
		return length
		
	const method := "get_length"
	if node.has_method(method):
		return node.get_length()
		
	const fallback := "get_aabb"
	assert(node.has_method(fallback), "Failed to determine the length of '%s': No '%s', '%s' or '%s' found" % [node.get_path(), param, method, fallback])
	return node.get_aabb().size.z