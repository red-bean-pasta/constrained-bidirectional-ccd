@abstract
extends EditorPlugin
class_name BiCcdEditorClickNotifier


signal ray_clicked(origin: Vector3, direction: Vector3)
signal point_clicked(point: Vector3)

var _button: Button
var enabled := false

var label: String:
	get: return _get_label()


### Override required
func _get_label() -> String:
	assert(false, "Override needed")
	return ""
	
func _get_tooltip() -> String:
	return ""
	
func _on_toggled(pressed: bool) -> void:
	push_warning("Override needed")
	
func _on_tree_entered() -> void:
	return
	
func _on_tree_exited() -> void:
	return
###


func _enter_tree() -> void:
	set_input_event_forwarding_always_enabled()
	
	_create_button()
	add_control_to_container(
		EditorPlugin.CONTAINER_SPATIAL_EDITOR_MENU,
		_button
	)
	
	_on_tree_entered()
	
func _create_button() -> void:
	_button = Button.new()
	_button.text = label
	_button.tooltip_text = _get_tooltip()
	_button.add_theme_stylebox_override("normal", StyleBoxEmpty.new())
	_button.toggle_mode = true
	_button.toggled.connect(_on_toggled_inner)

func _on_toggled_inner(pressed: bool) -> void:
	print(label, " enabled" if pressed else " disabled")
	enabled = pressed
	_on_toggled(pressed)
	

func _exit_tree() -> void:
	remove_control_from_container(
		EditorPlugin.CONTAINER_SPATIAL_EDITOR_MENU,
		_button
	)
	_button.queue_free()


func _forward_3d_gui_input(
	camera: Camera3D,
	event: InputEvent
) -> EditorPlugin.AfterGUIInput:
	if not enabled:
		return EditorPlugin.AFTER_GUI_INPUT_PASS
	
	if event is not InputEventMouseButton or event.button_index != MOUSE_BUTTON_LEFT or not event.pressed:
		return EditorPlugin.AFTER_GUI_INPUT_PASS
	
	_notify_ray(camera, event.position)
	_notify_point(camera, event.position)
	
	return EditorPlugin.AFTER_GUI_INPUT_PASS
		

func _notify_ray(
	camera: Camera3D, 
	mouse_position: Vector2
) -> void:
	var ray_origin := camera.project_ray_origin(mouse_position)
	var ray_direction := camera.project_ray_normal(mouse_position)
	print(label, ": Received click of ray from ", ray_origin, " to ", ray_direction)
	ray_clicked.emit(ray_origin, ray_direction)


func _notify_point(
	camera: Camera3D, 
	mouse_position: Vector2
) -> void:
	var point := _get_clicked_position(camera, mouse_position)
	if point == null:
		print(label, ": Skipped raising point signal")
		return
	
	var vector := point as Vector3
	assert(point != null)
	print(label, ": Received click at point ", vector)
	point_clicked.emit(point)

func _get_clicked_position(
	camera: Camera3D,
	mouse_position: Vector2
) -> Variant:
	var selected := EditorInterface.get_selection().get_selected_nodes()
	if selected.is_empty():
		print(label, ": No editor node selected")
		return null

	var center := Vector3.ZERO
	for n in selected:
		center += n.global_position
	center /= selected.size()

	var ray_origin := camera.project_ray_origin(mouse_position)
	var ray_direction := camera.project_ray_normal(mouse_position)
	
	var plane_forward := -camera.global_transform.basis.z.normalized()
	var plane := Plane(plane_forward, center)
	var hit := plane.intersects_ray(
		ray_origin,
		ray_direction.normalized()
	)
	if hit == null:
		print(label, ": Plane not intersected")
	return hit
