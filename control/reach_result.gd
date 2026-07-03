# To modify the inner arrays' items, copy the array first
class_name ReachResult

var reached: bool
## Size is 1 more than segments count, with the additional first basis as Vector3.FLIP_Z
var bases: Array[Basis]
## Size is 1 more than segments count, with the additional last position as the last segment's tip position
var positions: Array[Vector3]

func _init(
	p_reached: bool,
	p_bases: Array[Basis],
	p_positions: Array[Vector3],
) -> void:
	reached = p_reached
	bases = p_bases
	positions = p_positions