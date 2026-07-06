@tool
extends BiCcdEditorChainAdjuster
## It will add a node to the scene for line visualization. The node's name follows format: [code]"VisualizedAdjust" + source_chain.name + target_position_x_mm + y_mm + z_mm[/code]
class_name BiCcdEditorChainAdjustVisualizer


const group_name := "VisualizedAdjust"

var _pin_button: CheckButton
var _x_input: SpinBox
var _y_input: SpinBox
var _z_input: SpinBox

var _pinned: bool:
	get: return _pin_button.button_pressed
var _pinned_position: Vector3:
	get: return Vector3(
		_x_input.value,
		_y_input.value,
		_z_input.value
	)


func _get_label() -> String:
	return "Visualize chain adjust"
	
func _get_tooltip() -> String:
	return "Activate to visualize the adjustments that will happen to the selected BiCcdChains to a clicked or provided position in the editor viewport"


func _set_setting_panel() -> void:
	_panel = PopupPanel.new()
	add_child(_panel)
	
	var stack := _create_container_stack()
	_panel.add_child(stack)
	
func _create_container_stack() -> VBoxContainer:
	var stack := VBoxContainer.new()
	
	var parent_container := _create_grid_container()
	stack.add_child(parent_container)
	
	var toggle_container := _create_pin_toggle_container()
	stack.add_child(toggle_container)
	
	var position_container := _create_pin_position_container()
	stack.add_child(position_container)
	
	return stack

func _create_pin_toggle_container() -> GridContainer:
	var container := GridContainer.new()
	container.columns = 2
	
	var pin_label := Label.new()
	pin_label.text = "Pin down target position"
	pin_label.tooltip_text = "Enable to pin down the target position. If enabled, the click in the viewport will only act as activation."
	container.add_child(pin_label)
	
	_pin_button = CheckButton.new()
	_pin_button.button_pressed = false
	container.add_child(_pin_button)
	
	return container

func _create_pin_position_container() -> GridContainer:
	var container := GridContainer.new()
	container.columns = 4
	
	var position_label := Label.new()
	position_label.text = "Target Position"
	container.add_child(position_label)
	
	var input: Array[String] = ["_x_input", "_y_input", "_z_input"]
	for i in input:
		var box := SpinBox.new()
		var prefix := i.substr(1, 1) + ": "
		box.prefix = prefix
		box.min_value = -INF
		box.max_value = +INF
		box.step = 0
		box.value = 0
		container.add_child(box)
		set(i, box)
		
	return container


func _chain_on_click(chain: BiCcdChain, point: Vector3) -> void:
	if _pinned:
		point = _pinned_position
		print(label, ": Target position pinned: ", point)
		
	_draw_chain_adjustment_path(chain, point)

func _draw_chain_adjustment_path(chain: BiCcdChain, point: Vector3) -> void:
	if not _ensure_environment():
		return

	print(label, ": Visualizing for chain ", chain.name)
	var adjusts := _get_adjusts(chain, point)
	assert(adjusts.size() > 0)
	if adjusts[-1].positions.size() < 1:
		push_error(label, ": Adjustments returned empty positions: Is the chain empty?")
		return
	
	var lines := _create_graident_line_meshes(adjusts)
	
	var group := _ensure_group_in_scene()
	var parent := _add_lines_to_group(lines, group)
	parent.name = _get_vision_name(chain, point)
	parent.global_transform = chain.global_transform
	parent.init_data(
		adjusts[-1].reached,
		adjusts.size(),
		point, 
		chain.to_global(adjusts[-1].positions[-1]),
	)
	
	_log_result(adjusts[-1].reached, point, adjusts[-1].positions[-1])

func _ensure_environment() -> bool:
	if EditorInterface.get_edited_scene_root() == null:
		push_error(label, ": No active scene open")
		return false
	if _max_attempts < 1:
		push_error(label, ": Max attempts must be greater than 0")
		return false
	return true

func _get_adjusts(
	chain: BiCcdChain, 
	point: Vector3,
) -> Array[BiCcdReachResult]:
	var cache: Array[BiCcdReachResult] = []
	var adjuster := chain.adjuster
	var max_attempts := _max_attempts
	
	adjuster._placements.refresh()
	
	if _align_segment_first:
		var result := adjuster.get_segments_forward_adjust_step(point, _tolerance, false)
		cache.append(result.duplicate())
		max_attempts -= 1
		if result.reached:
			return cache
	
	for i in max_attempts:
		var backward := (
			true 
			if _mode == Mode.BACKWARD else 
			false 
			if _mode == Mode.FORWARD else 
			(i + 1) % 2 == 1
		) 
		var result := (
			adjuster.get_backward_adjust_step(point, _tolerance, false)
			if backward else 
			adjuster.get_forward_adjust_step(point, _tolerance, false)
		)
		cache.append(result.duplicate())
		if result.reached:
			break
	
	return cache
	

func _create_graident_line_meshes(
	adjusts: Array[BiCcdReachResult]
) -> Array[MeshInstance3D]:
	var start_color := Color.GREEN
	var end_color := Color.RED
	
	var meshes: Array[MeshInstance3D] = []
	var size := adjusts.size()
	for i in size:
		var linear_t := float(i) / float(size - 1) if size >= 1 else 1.0
		var pow_t := pow(linear_t, 0.6)
		var color := start_color.lerp(end_color, pow_t)
		var mesh := _create_line_mesh(adjusts[i].positions, color)
		meshes.append(mesh)
	
	return meshes

func _create_line_mesh(
	positions: Array[Vector3],
	color: Color = Color.RED,
) -> MeshInstance3D:
	var mesh := MeshInstance3D.new()
	
	var immediate := ImmediateMesh.new()
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.albedo_color = color
	immediate.surface_begin(Mesh.PRIMITIVE_LINES, material)

	for i in range(positions.size() - 1):
		immediate.surface_add_vertex(positions[i])
		immediate.surface_add_vertex(positions[i + 1])
	immediate.surface_end()

	mesh.mesh = immediate

	return mesh
	
	
func _ensure_group_in_scene() -> Node:
	var scene := EditorInterface.get_edited_scene_root()
	var group := scene.find_child(group_name, false, true)
	if group:
		return group
		
	group = Node.new()
	group.name = group_name
	scene.add_child(group)
	group.owner = scene
	return group

func _add_lines_to_group(lines: Array[MeshInstance3D], group: Node) -> BiCcdAdjustVision:
	var parent := BiCcdAdjustVision.new()
	group.add_child(parent)
	parent.owner = group.owner
	for l in lines:
		parent.add_child(l)
		l.owner = group.owner
	return parent


func _get_vision_name(chain: BiCcdChain, point: Vector3) -> String:
	var mode_affix := "%s_%s" % [_mode, _align_segment_first]
	var point_mm := point * 1000
	var point_affix := "%s_%s_%s" % [int(point_mm.x), int(point_mm.y), int(point_mm.z)]
	return "%s_%s_%s" % [chain.name, mode_affix, point_affix]