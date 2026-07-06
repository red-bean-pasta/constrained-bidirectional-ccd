@tool
extends Node3D
class_name BiCcdChain

@export var segments: Array[BiCcdSegment]

var adjuster: BiCcdAdjuster

func _ready() -> void:
	if segments.is_empty():
		for c in get_children():
			if c is BiCcdSegment:
				segments.append(c)
	assert(segments.all(func(s): return s != null))
	assert(_check_segment_ordered())
	adjuster = BiCcdAdjuster.new(self)
	
func _check_segment_ordered() -> bool:
	var size := segments.size()
	for i in range(1, size - 1 if size > 2 else 2):
		var before := segments[i - 1]
		var current := segments[i]
		var after := segments[i + 1]
		if (
			current.index != before.index + 1
			or current.index != after.index - 1
			or current.antecedent != before
			or before.subsequent != current
			or current.subsequent != after
			or after.antecedent != current
		):
			return false
	return true