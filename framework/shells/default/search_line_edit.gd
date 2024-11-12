extends LineEdit

signal up_pressed()
signal down_pressed()

func _gui_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_up"):
		up_pressed.emit()
	elif event.is_action_pressed("ui_down"):
		down_pressed.emit()
