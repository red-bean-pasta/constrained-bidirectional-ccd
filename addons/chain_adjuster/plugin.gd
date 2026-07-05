@tool
extends EditorClickNotifier
class_name EditorChainAdjuster


var _panel: PopupPanel
var _tolerance_input: SpinBox
var _mode_input: OptionButton
var _max_attempt_input: SpinBox

var tolerance: float: 
	get: return _tolerance_input.value
var mode: Mode:
	get: return _mode_input.selected
var max_attempts: int:
	get: return int(_max_attempt_input.value)
	
enum Mode {
	BACKWARD,
	FORWARD,
	BACKWARD_FORWARD,
	BACKWARD_SEGMENT_FORWARD,
}


func _get_label() -> String:
	return "Adjust CCD chain"
	
func _get_tooltip() -> String:
	return "Activate to adjust selected BiCcdChains to clicked positions in the editor viewport"
	
	
func _on_toggled(pressed: bool) -> void:
	if pressed:
		_popup_setting_panel()
	else:
		_panel.hide()
		
func _popup_setting_panel() -> void:
	var popup_position := Vector2i(
		_button.global_position.x,
		_button.global_position.y + _button.size.y
	)
	_panel.popup(
		Rect2i(popup_position, Vector2i(350, 100))
	)


func _on_tree_entered() -> void:
	_create_setting_panel()
	point_clicked.connect(_on_click)

func _create_setting_panel() -> void:
	_panel = PopupPanel.new()
	add_child(_panel)

	var fields := GridContainer.new()
	fields.columns = 2
	_panel.add_child(fields)

	var tolerance_label := Label.new()
	tolerance_label.text = "Tolerance"
	fields.add_child(tolerance_label)

	_tolerance_input = SpinBox.new()
	_tolerance_input.min_value = 0
	_tolerance_input.max_value = INF
	_tolerance_input.step = 0
	_tolerance_input.set_value_no_signal(0.001)
	fields.add_child(_tolerance_input)

	var mode_label := Label.new()
	mode_label.text = "Mode"
	fields.add_child(mode_label)

	_mode_input = OptionButton.new()
	_mode_input.add_item("Backward", Mode.BACKWARD)
	_mode_input.add_item("Forward", Mode.FORWARD)
	_mode_input.add_item("Backward + Forward", Mode.BACKWARD_FORWARD)
	_mode_input.add_item("Backward + Segment Forward", Mode.BACKWARD_SEGMENT_FORWARD)
	fields.add_child(_mode_input)
	
	var max_attempt_label := Label.new()
	max_attempt_label.text = "Max Attempts"
	fields.add_child(max_attempt_label)
	
	_max_attempt_input = SpinBox.new()
	_max_attempt_input.min_value = 0
	_max_attempt_input.max_value = INF
	_max_attempt_input.step = 1
	_max_attempt_input.rounded = true
	_max_attempt_input.set_value_no_signal(10)
	_max_attempt_input.tooltip_text = "Maximum adjust attempts"
	fields.add_child(_max_attempt_input)
	

func _on_click(point: Vector3) -> void:
	var chains := _get_selected_chain()
	if chains.is_empty():
		print(label, ": No chain selected. Skiping...")
		return
		
	print(label, ": Adjust with tolerance ", tolerance, ", mode ", mode)
	for c in chains:
		_adjust_chain(c, point)

func _get_selected_chain() -> Array[BiCcdChain]:
	var selected: Array[BiCcdChain] = []
	selected.assign(
		EditorInterface.get_selection().get_selected_nodes().filter(
			func(n): return n is BiCcdChain
		)
	)
	return selected
	
func _adjust_chain(chain: BiCcdChain, point: Vector3) -> void:
	var result := chain.adjuster.get_full_adjust(point, tolerance, mode, max_attempts)
	chain.adjuster.apply(chain.segments, result.bases, result.positions)
	print(label, ": ", "Successfully" if result.reached else "Failed to fully" ," converged to position ", point)
	