class_name Joint

var flex: HingeLimits
var yaw: HingeLimits

var flexible: bool:
	get: return flex.rotatable
var yawable: bool:
	get: return yaw.rotatable

func _init(
	flex_spec: HingeLimits,
	yaw_spec: HingeLimits
) -> void:
	flex = flex_spec
	yaw = yaw_spec