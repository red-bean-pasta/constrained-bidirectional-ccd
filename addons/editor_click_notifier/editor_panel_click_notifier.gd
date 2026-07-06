@abstract
extends BiCcdEditorClickNotifier
## Opens up a panel when button is clicked
class_name BiCcdEditorPanelClickNotifier

var _panel: PopupPanel

func _ready() -> void:
	_panel.popup_hide.connect(_on_panel_hidden)

func _on_toggled_inner(on: bool) -> void:
	if on:
		_on_toggled(true)
		return
	
	if not _panel.visible: 
		_button.set_pressed_no_signal(true) 
		_popup_setting_panel() 
		return
	
	_on_toggled(false)

func _on_toggled(on: bool) -> void:
	print(label, " enabled" if on else " disabled")
	if on:
		_popup_setting_panel()
	elif _panel.visible:
		_panel.hide()
		
func _popup_setting_panel() -> void:
	var popup_position := Vector2i(
		_button.global_position.x,
		_button.global_position.y + _button.size.y
	)
	_panel.popup(
		Rect2i(popup_position, Vector2i(350, 100))
	)

func _on_panel_hidden() -> void:
	if _button.get_global_rect().has_point(_button.get_global_mouse_position()):
		_button.set_pressed_no_signal(false)
		_on_toggled(false)