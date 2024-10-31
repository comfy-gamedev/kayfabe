class_name ChatMessage
extends MarginContainer


# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	pass # Replace with function body.


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass


func get_portrait() -> Texture2D:
	return $HBoxContainer/Portrait.texture

func set_portrait(texture: Texture2D):
	return $HBoxContainer/Portrait.texture


func get_display_name() -> String:
	return $HBoxContainer/VBoxContainer/DisplayName.text

func set_display_name(name: String):
	$HBoxContainer/VBoxContainer/DisplayName.text = name


func get_message() -> String:
	return $HBoxContainer/VBoxContainer/Message.text

func set_message(message: String):
	$HBoxContainer/VBoxContainer/Message.text = message
