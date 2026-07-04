class_name BiCcdJoint

var flex: BiCcdHingeLimits
var yaw: BiCcdHingeLimits

var flexible: bool:
	get: return flex.rotatable
var yawable: bool:
	get: return yaw.rotatable

func _init(
	flex_spec: BiCcdHingeLimits,
	yaw_spec: BiCcdHingeLimits
) -> void:
	flex = flex_spec
	yaw = yaw_spec