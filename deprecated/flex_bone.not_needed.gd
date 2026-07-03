## Bone is a higher level unit of a continous chain of unflexable SegmentLegSegment
# class_name JointedLegFlexBone

# Deprecated: Migrated to basis propagation. No need for higher level grouping to find the end tip position


var segments: Array[Segment]

var antecedent: JointedLegFlexBone
var subsequent: JointedLegFlexBone

var count: int:
	get: return segments.size()
var first: Segment:
	get: return segments[0]
var end: Segment:
	get: return segments[-1]
	
var min_flex_rad: float:
	get: return first.joint.flex.min_rad
var max_flex_rad: float:
	get: return first.joint.flex.max_rad
var current_flex_rad: float:
	get: return first.current_flex_rad

var position: Vector3:
	get: return first.position
var end_position: Vector3:
	get: return end.end_position
var span: float:
	get: return first.length if count < 1 else position.distance_to(end_position)


func _init(p_segments: Array[Segment]) -> void:
	_validate(p_segments)
	segments = p_segments
	
func _validate(segs: Array[Segment]) -> void:
	if not OS.is_debug_build():
		return
	assert(segs.size() > 0)
	var parent: Leg = null
	for i in segs.size():
		var s := segs[i]
		assert(s != null)
		assert(s.joint.flexible if i == 0 else not s.join.flexible)
		var p := s.get_parent() as Leg
		assert(p != null)
		if parent != null:
			assert(p == parent)
		else:
			parent = p
		if i > 0:
			assert(s.antecedent == segs[i - 1])
		if i < segs.size() - 1:
			assert(s.subsequent == segs[i + 1])

