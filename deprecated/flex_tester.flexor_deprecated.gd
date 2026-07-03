extends Node


@export var reacher: SpiderLegFlexor


func _ready() -> void:
	assert(reacher)


func _unhandled_input(event: InputEvent) -> void:
	if not Utils.is_left_mouse_button(event, -1):
		return
	
	var point := _get_click_point_on_yz(event)
	if not point.is_finite():
		return
	
	reacher.reach_to_world_point(point)
	
	
func _get_click_point_on_yz(event: InputEventMouseButton) -> Vector3:
	var pos := event.position
	
	var camera := get_viewport().get_camera_3d()
	var ray_org := camera.project_ray_origin(pos)
	var ray_dir := camera.project_ray_normal(pos)
	
	var yz_plane := Plane(Vector3.RIGHT, 0.0)
	var point = yz_plane.intersects_ray(ray_org, ray_dir)
	
	return point if point != null else Vector3.INF
