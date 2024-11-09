class_name Desktop
extends Control

const WINDOW_FIRST_CANVAS_LAYER = 10

static var current: Desktop

var metadata: DesktopMetadata
var windows: Array[AppWindow]
var app_services: Dictionary

var _i: int = 0
var _title: String

@onready var app_item_list: ItemList = %AppItemList
@onready var window_root: Node = %WindowRoot

func _enter_tree() -> void:
	current = self

func _exit_tree() -> void:
	if current == self:
		current = null

func _ready() -> void:
	_title = get_window().title
	RenderingServer.frame_pre_draw.connect(_on_frame_pre_draw)
	
	for app_key: StringName in AppManager.get_app_keys():
		var manifest := AppManager.get_app_manifest(app_key)
		var idx := app_item_list.add_item(manifest.name, manifest.icon)
		app_item_list.set_item_metadata(idx, app_key)
		
		var service_source = load(manifest.service_node_path)
		var service: AppService
		if service_source is Script:
			service = service_source.new()
		elif service_source is PackedScene:
			service = service_source.instantiate()
		app_services[app_key] = service
		add_child(service)
		

func window_open(app_window: AppWindow) -> void:
	if app_window.is_inside_tree():
		push_error("Cannot open window that is inside the tree.")
		return
	assert(app_window not in windows)
	var canvas_layer = CanvasLayer.new()
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
		(windows[i].get_parent() as CanvasLayer).layer = WINDOW_FIRST_CANVAS_LAYER + i
		windows[i].is_current = i == windows.size() - 1

func _on_frame_pre_draw() -> void:
	_i = (_i + 1) % 10
	get_window().title = "%s - %s" % [_title, _i]

func _on_app_item_list_item_activated(index: int) -> void:
	var app_key: StringName = app_item_list.get_item_metadata(index)
	app_services[app_key]._icon_activated()
