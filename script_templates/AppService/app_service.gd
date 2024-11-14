extends AppService

func _ready() -> void:
	pass

func _icon_activated() -> void:
	push_error("_icon_activated not implemented for app %s" % app_manifest.name)

func _can_open_document(document: Document) -> bool:
	return false

func _open_document(document: Document) -> void:
	push_error("_open_document not implemented for app %s" % app_manifest.name)
