# class_name SpiderLegReachProjector

# Deprecated: Legacy model
# Didn't take the complexity of 3D into account. Wishfully hoping to separate 3D space into two 2D dimensions cleanly.


static func project_yaw(v: Vector3) -> Vector2:
	return Vector2(v.x, v.z)
	
static func project_flex(v: Vector3) -> Vector2:
	return Vector2(v.z, v.y)
	
static func elevate_yaw(v: Vector2, original: Vector3) -> Vector3:
	return Vector3(v.x, original.y, v.y)

static func elevate_flex(v: Vector2, original: Vector3) -> Vector3:
	return Vector3(original.x, v.y, v.x)