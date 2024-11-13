extends AppService

const WINDOW = preload("window.tscn")

var window: AppWindow

func _icon_activated() -> void:
	if not is_instance_valid(window):
		window = WINDOW.instantiate()
		Desktop.current.window_open(window)
	else:
		Desktop.current.window_bring_to_front(window)
