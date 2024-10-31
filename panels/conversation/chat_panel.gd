extends Node2D

var thread_scene = preload("res://panels/conversation/chat_thread.tscn")
@onready var threads = $Window/VBoxContainer/ThreadContainer

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	pass # Replace with function body.


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass


func _on_new_chat_button_pressed() -> void:
	var new_thread = thread_scene.instantiate()
	new_thread.name = "New Chat"
	threads.add_child(new_thread)
