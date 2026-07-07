@tool
extends BiCcdEditorPanelClickNotifier
class_name BiCcdEditorChainAdjuster


var _tolerance_input: SpinBox
var _mode_input: OptionButton
var _backward_first_check: CheckBox
var _forward_first_check: CheckBox
var _align_segment_first_check: CheckBox

var _max_attempt_input: SpinBox

var _tolerance: float: 
	get: return _tolerance_input.value
var _mode: BiCcdAdjuster.CompleteFullAdjustMode:
	get: return _mode_input.selected
var _backward_first: bool:
	get: return _backward_first_check.button_pressed
var _forward_first: bool:
	get: return _forward_first_check.button_pressed
var _align_segment_first: bool:
	get: return _align_segment_first_check.button_pressed
var _max_attempts: int:
	get: return int(_max_attempt_input.value)


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

	_tolerance_input = _add_spinbox(
		container,
		"Tolerance",
		"Bearable distance before consider reached. Setting this to 0 may result in always unreachable returns.",
		0,
		INF,
		0,
		0.01,
	)

	_mode_input = _add_enumed_option_button(
		"Mode",
		"Iteration mode",
		BiCcdAdjuster.CompleteFullAdjustMode,
		container
	)
	
	_backward_first_check = _add_checkbox(
		"Backwards adjustment first",
		"If checked, a backward adjustment to the target position will be performed first. This consumes 1 attempt from max attempts. If both Align segments alignment are enabled as well, segments are be aligned first.",
		false,
		container
	)
	_forward_first_check = _add_checkbox(
		"Forwards adjustment first",
		"If checked, a forward adjustment to the target position will be performed first. This consumes 1 attempt from max attempts. If both Align segments alignment are enabled as well, segments are be aligned first.",
		false,
		container
	)
	_align_segment_first_check = _add_checkbox(
		"Align segments first",
		"If checked, it will align segments to the target position from proximal to the distal first. Note that it aligns segments instead of joint-effector. This may or may not result in more natural and determined pose. This consumes 1 attempt from max attempts.",
		false,
		container
	)
	
	_max_attempt_input = _add_spinbox(
		container,
		"Max Attempts",
		"Maximum adjust attempts",
		0,
		INF,
		1,
		10,
		true
	)
	
	return container

func _add_enumed_option_button(
	label: String,
	tooltip: String,
	type: Variant, 
	container: Container
) ->  OptionButton:
	var l := Label.new()
	l.text = label
	l.tooltip_text = tooltip
	container.add_child(l)

	var b := OptionButton.new()
	for k: String in type:
		b.add_item(k.capitalize(), type[k])
	container.add_child(b)
	
	return b

func _add_checkbox(
	label: String,
	tooltip: String,
	default: bool,
	container: Container
) -> CheckBox:
	var l := Label.new()
	l.text = label
	l.tooltip_text = tooltip
	container.add_child(l)

	var b := CheckBox.new()
	b.button_pressed = default
	container.add_child(b)
	
	return b

func _add_spinbox(
	container: Container,
	label: String,
	tooptip: String,
	min_value: float,
	max_value: float,
	step: float,
	default: float,
	rounded: bool = false
) -> SpinBox:
	var l := Label.new()
	l.text = label
	l.tooltip_text = tooptip
	container.add_child(l)
	
	var b := SpinBox.new()
	b.min_value = min_value
	b.max_value = max_value
	b.step = step
	b.rounded = rounded
	b.set_value_no_signal(default)
	container.add_child(b)
	
	return b


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
	print("%s: Applying settings: tolerance: %s; mode: %s; backward first: %s; forward first: %s; align segments first: %s" % [label, _tolerance, _mode, _backward_first, _forward_first, _align_segment_first])
		
func _chain_on_click(chain: BiCcdChain, point: Vector3) -> void:
	_adjust_chain(chain, point)
	
func _adjust_chain(chain: BiCcdChain, point: Vector3) -> void:
	var result := chain.adjuster._get_full_adjust_inner(point, _tolerance, _mode, _max_attempts, _backward_first, _forward_first, _align_segment_first)
	chain.adjuster.apply(chain.segments, result.bases, result.positions)
	_log_result(result.reached, point, result.positions[-1])

func _log_result(reached: bool, target: Vector3, result: Vector3) -> void:
	if reached:
		print(label, ": Successfully converged to position ", target)
	else:
		print(label, ": Failed to fully converge to position ", target, " with difference ", target.distance_to(result))
