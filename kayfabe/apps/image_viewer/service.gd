extends AppService

const SUPPORTED_EXTS = [
	"bmp",
	"dds",
	"ktx",
	"exr",
	"hdr",
	"jpg",
	"jpeg",
	"png",
	"tga",
	"svg",
	"webp",
]

const VIEWER = preload("res://apps/image_viewer/viewer.tscn")

func _icon_activated() -> void:
	push_error("_icon_activated not implemented for app %s" % manifest.name)

func _can_open_document(document: Document) -> bool:
	return document.get_file_name().get_extension() in SUPPORTED_EXTS

func _open_document(document: Document) -> void:
	var window = VIEWER.instantiate()
	window.document = document
	window_open(window)

enum {
	NOTIFICATION_LAUNCH_DOCUMENT,
}

func _app_notification(what: int, data: Variant) -> void:
	match what:
		NOTIFICATION_LAUNCH_DOCUMENT:
			var window = VIEWER.instantiate()
			window.document = data as Document
			window_open(window)
