extends AppService

const EYES = preload("eyes.tscn")

func _icon_activated() -> void:
	var window = EYES.instantiate()
	WindowManager.app_window_open(window)
