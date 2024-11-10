extends TabContainer

var thread_scene = preload("chat_thread.tscn")

func _ready() -> void:
	await get_parent().ready
	get_parent().frame.add_user_button("new_chat", "Start New Chat", preload("res://apps/eyes/smile_icon.tres"))
	get_parent().frame.user_button_pressed.connect(_on_user_button_pressed)


func _on_user_button_pressed(id: StringName) -> void:
	if id == "new_chat":
		var new_thread = thread_scene.instantiate()
		new_thread.name = "New Chat"
		add_child(new_thread, true)
