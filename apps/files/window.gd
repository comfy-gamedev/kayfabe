extends AppWindow

const TAG_ICON = preload("tag_icon.png")

@onready var tags: HBoxContainer = %Tags
@onready var item_list: ItemList = %ItemList

func _ready() -> void:
	super()
	
	frame.add_user_button("tags", "Tags", TAG_ICON)
	frame.user_button_pressed.connect(_on_user_button_pressed)
	
	for doc_uuid in Desktop.current.documents:
		var doc: Document = Desktop.current.documents[doc_uuid]
		var item = item_list.add_item(doc.name, doc.get_thumbnail())
		item_list.set_item_metadata(item, doc.uuid)
		print(doc.name)

func _on_user_button_pressed(id: StringName) -> void:
	var voice = DisplayServer.tts_get_voices_for_language("en")[-1]
	DisplayServer.tts_speak("NOT IMPLEMENTED", voice, 50, 1.0, 2.0)


func _on_item_list_item_activated(index: int) -> void:
	var doc_uuid = item_list.get_item_metadata(index)
	var app_ids = Desktop.current.document_get_apps(doc_uuid)
	if app_ids.size() > 0:
		var doc = Desktop.current.documents[doc_uuid]
		Desktop.current.app_get_service(app_ids[0])._open_document(doc)
