extends AppService

const CHAT_PANEL = preload("chat_panel.tscn")

func _icon_activated() -> void:
	var window = CHAT_PANEL.instantiate()
	Desktop.current.window_open(window)
