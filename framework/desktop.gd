class_name Desktop
extends Control

const WINDOW_CANVAS_LAYER = 1

static var current: Desktop

var metadata: DesktopMetadata
var windows: Array[AppWindow]
var app_services: Dictionary
var documents: Dictionary

var _i: int = 0
var _title: String

@onready var window_root: Node = %WindowRoot

func _enter_tree() -> void:
	current = self

func _exit_tree() -> void:
	if current == self:
		current = null
	_save_thumbnail()

func _ready() -> void:
	_title = get_window().title
	RenderingServer.frame_pre_draw.connect(_on_frame_pre_draw)
	
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
	
	for doc_uuid in DirAccess.get_directories_at(get_documents_dir()):
		if not UUID.is_valid(doc_uuid):
			push_error("Invalid document directory: ", doc_uuid)
			continue
		var doc = Document.open(metadata.uuid, doc_uuid)
		if not doc:
			push_error("Invalid document: ", doc_uuid)
			continue
		documents[doc_uuid] = doc

func get_documents_dir() -> String:
	return Framework.get_desktop_root(metadata.uuid).path_join("documents")

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
	icon_img.save_png(metadata.get_icon_path())

func _on_frame_pre_draw() -> void:
	_i = (_i + 1) % 10
	get_window().title = "%s - %s" % [_title, _i]
