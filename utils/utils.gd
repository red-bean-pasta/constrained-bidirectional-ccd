class_name BiCcdUtils


static func throw_not_implemented() -> void:
	assert(false, "Not implemented")

static func assert_range(
	p_x: float, 
	p_min: float,
	p_max: float, 
	p_inclusive: bool = true
) -> void:
	assert(p_min <= p_x and p_x <= p_max)
	if not p_inclusive:
		assert(p_min != p_x and p_x != p_max)

static func get_previous_sibling(node: Node, type: Variant = Node) -> Node:
	var parent := node.get_parent()
	var index := node.get_index()
	for i in range(index - 1, -1, -1):
		var sibling := parent.get_child(i)
		if is_instance_of(sibling, type):
			return sibling
	return null
	
static func get_next_sibling(node: Node, type: Variant = Node) -> Node:
	var parent := node.get_parent()
	var count := parent.get_child_count()
	var index := node.get_index()
	for i in range(index + 1, count, 1):
		var sibling := parent.get_child(i)
		if is_instance_of(sibling, type):
			return sibling
	return null

static func is_tau(rad: float) -> bool:
	return is_zero_approx(fmod(rad, TAU))

static func wrap_rad(p_v: float, p_min: float, p_max: float) -> float:
	if p_min <= p_v and p_v <= p_max:
		return p_v
	return fposmod(p_v - p_min, TAU) + p_min

static func wrap_clamp_rad(p_v: float, p_min: float, p_max: float) -> float:
	var wrapped := wrap_rad(p_v, p_min, p_max)
	if wrapped <= p_max:
		return wrapped
	var d_to_max := wrapped - p_max
	var d_to_min := TAU - (wrapped - p_min)
	return p_max if d_to_max <= d_to_min else p_min