@tool
extends AppWindow

var thread_scene = preload("chat_thread.tscn")
@onready var threads = $VBoxContainer/ThreadContainer

func _on_new_chat_button_pressed() -> void:
	var new_thread = thread_scene.instantiate()
	new_thread.name = "New Chat"
	threads.add_child(new_thread, true)
