@tool
extends AppWindow

const NEW_ICON = preload("res://apps/notepad/new_icon.png")
const SAVE_ICON = preload("res://apps/notepad/save_icon.png")

const BTN_NEW = &"new"
const BTN_SAVE = &"save"

var document: Document: set = set_document

@onready var text_edit: TextEdit = $PanelContainer/TextEdit

func _ready() -> void:
	super()
	frame.add_user_button(BTN_NEW, "New", NEW_ICON)
	frame.add_user_button(BTN_SAVE, "Save", SAVE_ICON)
	frame.user_button_pressed.connect(_on_user_button_pressed)
	_reload()

func set_document(d: Document) -> void:
	if document == d: return
	if document:
		document.changed.disconnect(_on_document_changed)
	document = d
	if document:
		document.changed.connect(_on_document_changed)
	_reload()

func _reload() -> void:
	if not is_inside_tree(): return
	
	if not document:
		text_edit.text = ""
	else:
		var content: PackedByteArray = await document.get_content_async() as PackedByteArray
		text_edit.text = content.get_string_from_utf8()

func _on_document_changed() -> void:
	_reload()

func _on_user_button_pressed(id: StringName) -> void:
	match id:
		BTN_NEW:
			document = null
		BTN_SAVE:
			if document is LocalDocument:
				document.put_content_async(text_edit.text.to_utf8_buffer())
