extends Node

const CHARS = ["-", "\\", "|", "/"]

var i: int

func _ready() -> void:
	TitlebarManager.render_tracker = CHARS[0]
	RenderingServer.frame_pre_draw.connect(_on_frame_pre_draw)

func _on_frame_pre_draw() -> void:
	i += 1
	TitlebarManager.render_tracker = CHARS[i % CHARS.size()]
