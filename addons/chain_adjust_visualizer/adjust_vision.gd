@tool
extends Node3D
class_name BiCcdAdjustVision


var _reached: bool
## If reached target after adjustment
@export var reached: bool:
	get: return _reached
	set(value): pass

var _destination: Vector3
## The initial target point in global space before adjustments
@export var destination: Vector3:
	get: return _destination
	set(value): pass

var _result: Vector3
## The best-effort reached point in global space after adjustments
@export var result: Vector3:
	get: return _result
	set(value): pass
	
var _iteration: int
## The total iteration count. Can be smaller than max attempts when reached early
@export var iteration: int:
	get: return _iteration
	set(value): pass
	
	
func init_data(
	reached: bool,
	dest: Vector3, 
	result: Vector3,
	iteration: int,
) -> void:
	_reached = reached
	_destination = dest
	_result = result
	_iteration = iteration