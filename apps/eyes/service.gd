extends AppService

const EYES = preload("eyes.tscn")

func _icon_activated() -> void:
	var window = EYES.instantiate()
	Desktop.current.window_open(window)
