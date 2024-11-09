class_name AppService
extends Node

var app_manifest: AppManifest

func _icon_activated() -> void:
	push_error("_icon_activated not implemented for app %s" % app_manifest.name)

func _can_open_document(document: Document) -> bool:
	return false
