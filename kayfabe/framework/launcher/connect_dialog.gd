extends ConfirmationDialog

@onready var url_line_edit: LineEdit = %URLLineEdit

func _on_about_to_popup() -> void:
	_validate()

func _on_url_line_edit_text_changed(_new_text: String) -> void:
	_validate()

func _validate() -> void:
	var valid = true
	var uri = URI.parse_uri(url_line_edit.text)
	if uri.protocol not in ["ws", "wss"]:
		valid = false
	if not uri.hostname:
		valid = false
	
	get_ok_button().disabled = not valid
