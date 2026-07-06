@abstract
extends BiCcdEditorClickNotifier
## Opens up a panel when button is clicked
class_name BiCcdEditorPanelClickNotifier

var _panel: PopupPanel

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
