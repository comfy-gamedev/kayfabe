class_name Desktop
extends Control

const WINDOW_CANVAS_LAYER = 1

static var current: Desktop

var metadata: DesktopMetadata
var windows: Array[AppWindow]
var app_services: Dictionary
var documents: Dictionary

var uuid: StringName:
	get: return metadata.uuid

@onready var window_root: Node = %WindowRoot

func _enter_tree() -> void:
	current = self
	get_window().files_dropped.connect(_on_files_dropped)

func _exit_tree() -> void:
	if current == self:
		current = null
	_save_thumbnail()
	get_window().files_dropped.disconnect(_on_files_dropped)

func _ready() -> void:
	for app_key: StringName in AppManager.get_app_keys():
		var manifest := AppManager.get_app_manifest(app_key)
		var service_source = load(manifest.service_node_path)
		var service: AppService
		if service_source is Script:
			service = service_source.new()
		elif service_source is PackedScene:
			service = service_source.instantiate()
		app_services[app_key] = service
		add_child(service)
	
	for doc_uuid in DirAccess.get_directories_at(Framework.get_desktop_documents_dir(uuid)):
		if not UUID.is_valid(doc_uuid):
			push_error("Invalid document directory: ", doc_uuid)
			continue
		var doc = Document.open(metadata.uuid, doc_uuid)
		if not doc:
			push_error("Invalid document: ", doc_uuid)
			continue
		documents[doc_uuid] = doc

func window_open(app_window: AppWindow) -> void:
	if app_window.is_inside_tree():
		push_error("Cannot open window that is inside the tree.")
		return
	assert(app_window not in windows)
	var canvas_layer = CanvasLayer.new()
	canvas_layer.layer = WINDOW_CANVAS_LAYER
	canvas_layer.add_child(app_window)
	window_root.add_child(canvas_layer)
	app_window.position = size / 2.0 - app_window.size / 2.0
	windows.append(app_window)
	_update_windows_z_index()

func window_close(app_window: AppWindow, free: bool = true) -> void:
	if app_window not in windows:
		push_error("Cannot close unknown window.")
		return
	windows.erase(app_window)
	var canvas_layer: CanvasLayer = app_window.get_parent()
	window_root.remove_child(canvas_layer)
	if not free:
		canvas_layer.remove_child(app_window)
	canvas_layer.queue_free()
	_update_windows_z_index()

func window_bring_to_front(app_window: AppWindow) -> void:
	if app_window.is_current: return
	
	var idx := windows.find(app_window)
	if idx == -1:
		push_error("Unknown window.")
		return
	
	for i in range(idx, windows.size() - 1):
		windows[i] = windows[i + 1]
	windows[-1] = app_window
	
	_update_windows_z_index()

func app_get_service(app_id: StringName) -> AppService:
	var app = app_services.get(app_id)
	if not app:
		push_error("Invalid app_id: ", app_id)
		return null
	return app

func app_get_name(app_id: StringName) -> String:
	var app = app_services.get(app_id)
	if not app:
		push_error("Invalid app_id: ", app_id)
		return ""
	return app.name

func document_get_apps(document_uuid: String) -> PackedStringArray:
	var doc = documents.get(document_uuid)
	if not doc:
		push_error("Unknown document: ", document_uuid)
		return PackedStringArray()
	
	var results: PackedStringArray
	for app_id: StringName in app_services:
		if app_services[app_id]._can_open_document(doc):
			results.append(app_id)
	
	return results

func _update_windows_z_index() -> void:
	for i in windows.size():
		var canvas_layer = windows[i].get_parent() as CanvasLayer
		window_root.move_child(canvas_layer, i)
		canvas_layer.child_order_changed.emit() # Needed to update canvas item sorting, possible godot bug?
		windows[i].is_current = i == windows.size() - 1

func _save_thumbnail() -> void:
	if not metadata:
		push_error("Can't save thumbnail: no desktop metadata.")
		return
	var icon_img = get_viewport().get_texture().get_image()
	icon_img.resize(400, 400 * icon_img.get_height() / icon_img.get_width(), Image.INTERPOLATE_LANCZOS)
	icon_img.save_png(Framework.get_desktop_thumbnail_file(uuid))

func _on_files_dropped(files: PackedStringArray) -> void:
	for f in files:
		if DirAccess.dir_exists_absolute(f):
			push_error("Cannot import directory. ", f)
			continue
		_import_file(f)

func _import_file(path: String) -> void:
	var src = FileAccess.get_file_as_bytes(path)
	var err = FileAccess.get_open_error()
	if err != OK:
		push_error("Failed to import %s: %s" % [path, error_string(err)])
		return
	var doc = Document.create(uuid, path.get_file())
	var dest = doc.open_file(FileAccess.ModeFlags.WRITE)
	dest.store_buffer(src)
	dest.close()
	doc.tags.append("_imported")
	doc.commit_version("IMPORT")
