extends AppService

const SUPPORTED_EXTS = [
	"txt",
]

const NOTEPAD = preload("notepad.tscn")

func _icon_activated() -> void:
	var window = NOTEPAD.instantiate()
	window_open(window)

func _can_open_document(document: Document) -> bool:
	return document.get_file_name().get_extension() in SUPPORTED_EXTS

func _open_document(document: Document) -> void:
	var window = NOTEPAD.instantiate()
	window.document = document
	window_open(window)
