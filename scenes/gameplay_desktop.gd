extends Node2D

@onready var chat_panel_scene = preload("res://panels/conversation/chat_panel.tscn")

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	pass # Replace with function body.


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass



func _on_new_panel_button_pressed() -> void:
	var new_panel = chat_panel_scene.instantiate()
	add_child(new_panel)
