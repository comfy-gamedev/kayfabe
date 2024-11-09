extends AppService

const CHAT_PANEL = preload("chat_panel.tscn")

func _icon_activated() -> void:
	var window = CHAT_PANEL.instantiate()
	WindowManager.app_window_open(window)
