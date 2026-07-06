@tool
extends BiCcdEditorPanelClickNotifier
class_name BiCcdEditorChainAdjuster


var _tolerance_input: SpinBox
var _mode_input: OptionButton
var _align_segment_first_check: CheckBox
var _max_attempt_input: SpinBox

var _tolerance: float: 
	get: return _tolerance_input.value
var _mode: Mode:
	get: return _mode_input.selected
var _align_segment_first: bool:
	get: return _align_segment_first_check.button_pressed
var _max_attempts: int:
	get: return int(_max_attempt_input.value)
	
enum Mode {
	BACKWARD,
	FORWARD,
	BACKWARD_FORWARD,
}


func _get_label() -> String:
	return "Adjust CCD chain"
	
func _get_tooltip() -> String:
	return "Activate to adjust selected BiCcdChains to clicked positions in the editor viewport"
	

func _on_tree_entered() -> void:
	_set_setting_panel()
	point_clicked.connect(_on_click)

func _set_setting_panel() -> void:
	_panel = PopupPanel.new()
	add_child(_panel)
	
	var container := _create_grid_container()
	_panel.add_child(container)

func _create_grid_container() -> GridContainer:
	var container := GridContainer.new()
	container.columns = 2

	var tolerance_label := Label.new()
	tolerance_label.text = "Tolerance"
	container.add_child(tolerance_label)

	_tolerance_input = SpinBox.new()
	_tolerance_input.min_value = 0
	_tolerance_input.max_value = INF
	_tolerance_input.step = 0
	_tolerance_input.set_value_no_signal(0.001)
	container.add_child(_tolerance_input)

	var mode_label := Label.new()
	mode_label.text = "Mode"
	container.add_child(mode_label)

	_mode_input = OptionButton.new()
	_mode_input.add_item("Backward", Mode.BACKWARD)
	_mode_input.add_item("Forward", Mode.FORWARD)
	_mode_input.add_item("Cyclic", Mode.BACKWARD_FORWARD)
	container.add_child(_mode_input)
	
	var align_segment_label := Label.new()
	align_segment_label.text = "Align segment first"
	align_segment_label.tooltip_text = "If checked, a forward adjustment will be performed first to align segments to the target position. Note that it aligns segments instead of joint-effector. This may or may not result in more natural and determined pose. This consumes 1 attempt from max attempts."
	container.add_child(align_segment_label)

	_align_segment_first_check = CheckBox.new()
	_align_segment_first_check.button_pressed = false
	container.add_child(_align_segment_first_check)
	
	var max_attempt_label := Label.new()
	max_attempt_label.text = "Max Attempts"
	container.add_child(max_attempt_label)
	
	_max_attempt_input = SpinBox.new()
	_max_attempt_input.min_value = 0
	_max_attempt_input.max_value = INF
	_max_attempt_input.step = 1
	_max_attempt_input.rounded = true
	_max_attempt_input.set_value_no_signal(10)
	_max_attempt_input.tooltip_text = "Maximum adjust attempts"
	container.add_child(_max_attempt_input)
	
	return container


func _on_click(point: Vector3) -> void:
	var chains := _get_selected_chain()
	if chains.is_empty():
		print(label, ": No chain selected. Skiping...")
		return
	
	_log_settings()
	for c in chains:
		_chain_on_click(c, point)

func _get_selected_chain() -> Array[BiCcdChain]:
	var selected: Array[BiCcdChain] = []
	selected.assign(
		EditorInterface.get_selection().get_selected_nodes().filter(
			func(n): return n is BiCcdChain
		)
	)
	return selected
	
func _log_settings() -> void:
	print("%s: Applying settings: tolerance: %s; mode: %s; align segments first: %s" % [label, _tolerance, _mode, _align_segment_first])
		
func _chain_on_click(chain: BiCcdChain, point: Vector3) -> void:
	_adjust_chain(chain, point)
	
func _adjust_chain(chain: BiCcdChain, point: Vector3) -> void:
	var result := chain.adjuster.get_full_adjust(point, _tolerance, _mode, _max_attempts, _align_segment_first)
	chain.adjuster.apply(chain.segments, result.bases, result.positions)
	_log_result(result.reached, point, result.positions[-1])

func _log_result(reached: bool, target: Vector3, result: Vector3) -> void:
	if reached:
		print(label, ": Successfully converged to position ", target)
	else:
		print(label, ": Failed to fully converge to position ", target, " with difference ", target.distance_to(result))
