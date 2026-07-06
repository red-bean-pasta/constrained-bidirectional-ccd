@tool
extends BiCcdEditorChainAdjustVisualizer
class_name BiCcdEditorChainAdjustTool


var _path_mode_button: CheckButton

var _path_mode: bool:
	get: return _path_mode_button.button_pressed


func _get_label() -> String:
	return "Adjust Chain"
	
func _get_tooltip() -> String:
	return "Activate to adjust CCD chains or visualize the adjustment path toward clicked or pinned positions in the editor viewport"
	

func _create_container_stack() -> VBoxContainer:
	var stack := super._create_container_stack()
	
	var container := _create_path_mode_container()
	stack.add_child(container)
	stack.move_child(container, 0)
	
	return stack
	
func _create_path_mode_container() -> GridContainer:
	var container := GridContainer.new()
	container.columns = 2

	var mode_label := Label.new()
	mode_label.text = "Path Mode"
	mode_label.tooltip_text = "Enable to visualize adjustment paths instead of transform selected chains"
	container.add_child(mode_label)
	
	_path_mode_button = CheckButton.new()
	_path_mode_button.button_pressed = true
	container.add_child(_path_mode_button)
	
	return container


func _chain_on_click(chain: BiCcdChain, point: Vector3) -> void:
	if _pinned:
		point = _pinned_position
		print(label, ": Target position pinned: ", point)
		
	if _path_mode:
		_draw_chain_adjustment_path(chain, point)
	else:
		_adjust_chain(chain, point)