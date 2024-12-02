extends Node

const CHARS = ["| ", "/ ", "- ", "\\ "]

var i: int

func _ready() -> void:
	RenderingServer.frame_pre_draw.connect(_on_frame_pre_draw)

func _on_frame_pre_draw() -> void:
	var window = get_window()
	if not window: return
	var title = window.title
	for c in CHARS:
		if title.begins_with(c):
			title = title.trim_prefix(c)
			break
	get_window().title = CHARS[i % CHARS.size()] + title
	i += 1
