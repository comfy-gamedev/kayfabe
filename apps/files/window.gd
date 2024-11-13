extends AppWindow

const TAG_ICON = preload("tag_icon.png")

@onready var tags: HBoxContainer = %Tags
@onready var files: VBoxContainer = %Files

func _ready() -> void:
	super()
	
	frame.add_user_button("tags", "Tags", TAG_ICON)
	frame.user_button_pressed.connect(_on_user_button_pressed)
	
	for doc_uuid in Desktop.current.documents:
		var doc: Document = Desktop.current.documents[doc_uuid]
		var lbl = Label.new()
		lbl.text = doc.name
		files.add_child(lbl)

func _on_user_button_pressed(id: StringName) -> void:
	var voice = DisplayServer.tts_get_voices_for_language("en")[-1]
	DisplayServer.tts_speak("NOT IMPLEMENTED", voice, 50, 1.0, 2.0)
