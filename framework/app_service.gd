class_name AppService
extends Node

var app_id: StringName
var app_manifest: AppManifest

func _icon_activated() -> void: # VIRTUAL
	push_error("_icon_activated not implemented for app %s" % app_manifest.name)

@warning_ignore("unused_parameter")
func _can_open_document(document: Document) -> bool: # VIRTUAL
	return false

@warning_ignore("unused_parameter")
func _open_document(document: Document) -> void: # VIRTUAL
	push_error("_open_document not implemented for app %s" % app_manifest.name)

func window_open(window: AppWindow) -> void:
	window.service = self
	Desktop.current.window_open(window)
