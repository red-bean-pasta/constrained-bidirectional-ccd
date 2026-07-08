@tool
extends EditorScenePostImport

enum Segment {
	COXA,
	TROCHANTER,
	FEMUR,
	PATELLA,
	TIBIA,
	METATARSUS,
	TARSUS
}

class JointSpec:
	var min_flex_degree: float
	var max_flex_degree: float
	var rest_flex_degree: float
	var min_yaw_degree: float
	var max_yaw_degree: float
	var rest_yaw_degree: float
	
	func _init(
		p_min_flex_deg: float,
		p_max_flex_deg: float,
		p_rest_flex_deg: float = NAN,
		p_yaw_deg: float = 0.0,
	) -> void:
		min_flex_degree = p_min_flex_deg
		max_flex_degree = p_max_flex_deg
		rest_flex_degree = (p_min_flex_deg + p_max_flex_deg) * 0.5 if is_nan(p_rest_flex_deg) else p_rest_flex_deg
		assert(min_flex_degree <= rest_flex_degree and rest_flex_degree <= max_flex_degree)
		
		assert(p_yaw_deg >= 0.0)
		min_yaw_degree = -p_yaw_deg
		max_yaw_degree = p_yaw_deg
		rest_yaw_degree = 0.0
		
	static func create_inflexible(
		flex_deg: float,
		yaw_deg: float = 0.0
	) -> JointSpec:
		return JointSpec.new(flex_deg, flex_deg, flex_deg, yaw_deg)
	

static var segment_spec: Dictionary[Segment, JointSpec] = {
	Segment.COXA: JointSpec.new(140, 220, 180, 15),
	Segment.TROCHANTER: JointSpec.create_inflexible(180, 25),
	Segment.FEMUR: JointSpec.new(215, 270, 250),
	Segment.PATELLA: JointSpec.new(30, 160, 50),
	Segment.METATARSUS: JointSpec.new(95, 175, 115),
	Segment.TIBIA: JointSpec.create_inflexible(190),
	Segment.TARSUS: JointSpec.create_inflexible(172, 20)
}


func _post_import(scene: Node) -> Object:
	var root := scene.get_child(0)
	
	for c in root.get_children():
		_mesh_to_segment(c)
		
	_sort_segments(root)
	
	_root_to_chain(root)
	
	_elevate_root(root)
	
	return root

func _mesh_to_segment(node: Node) -> void:
	assert(node is MeshInstance3D)
	
	var key := node.name.to_upper()
	var value: int = Segment[key]
	var spec := segment_spec[value]
	
	node.set_script(BiCcdSegment)
	var seg := node as BiCcdSegment
	
	seg.index = value
	
	seg._min_flex_degree = spec.min_flex_degree
	seg._max_flex_degree = spec.max_flex_degree
	seg._rest_flex_degree = spec.rest_flex_degree
	seg._min_yaw_degree = spec.min_yaw_degree
	seg._max_yaw_degree = spec.max_yaw_degree
	seg._rest_yaw_degree = spec.rest_yaw_degree
	
func _sort_segments(root: Node) -> void:
	var ordered: Array[BiCcdSegment] = []
	ordered.assign(root.get_children())
	ordered.sort_custom(
		func(a: BiCcdSegment, b: BiCcdSegment) -> bool:
			return a.index < b.index
	)
	for i in ordered.size():
		root.move_child(ordered[i], i)
			
func _root_to_chain(root: Node) -> void:
	root.set_script(BiCcdChain)
	var chain := root as BiCcdChain
	assert(chain != null)
	chain.segments.assign(chain.get_children())
	
func _elevate_root(root: Node) -> void:
	for c in root.get_children():
		_change_owner_recursive(c, root)
		
	root.get_parent().remove_child(root)
	root.owner = null

func _change_owner_recursive(node: Node, owner: Node) -> void:
	node.owner = owner
	for c in node.get_children():
		_change_owner_recursive(c, owner)