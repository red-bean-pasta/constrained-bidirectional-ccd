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

static var segment_spec: Dictionary[Segment, BiCcdJointSpec] = {
	Segment.COXA: BiCcdJointSpec.create_symmetrical_yawable(15, 140, 220, 180),
	Segment.TROCHANTER: BiCcdJointSpec.create_symmetrical_yawable_inflexible(25, 180),
	Segment.FEMUR: BiCcdJointSpec.create_unyawable(0, 215, 270, 250),
	Segment.PATELLA: BiCcdJointSpec.create_unyawable(0, 30, 160, 50),
	Segment.METATARSUS: BiCcdJointSpec.create_unyawable(0, 95, 175, 115),
	Segment.TIBIA: BiCcdJointSpec.create_inflexible_unyawable(190, 0),
	Segment.TARSUS: BiCcdJointSpec.create_symmetrical_yawable_inflexible(20, 172)
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
	spec.apply_to_segment(seg)
	
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