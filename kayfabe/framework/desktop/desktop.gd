class_name Desktop
extends Control

signal message(message: TaggedMessage)

const WINDOW_CANVAS_LAYER = 1

static var current: Desktop

var uuid: StringName
var remote_url: String

var filesystem: DesktopFilesystem
var windows: Array[AppWindow]
var app_services: Dictionary
var desktop_multiplayer: DesktopMultiplayer

@onready var window_root: Node = %WindowRoot
@onready var network_plumber: NetworkPlumber = $NetworkPlumber
@onready var network_transfer_handler: NetworkTransferHandler = $NetworkTransferHandler

func _enter_tree() -> void:
	current = self
	desktop_multiplayer = DesktopMultiplayer.new()
	get_tree().set_multiplayer(desktop_multiplayer, get_path())
	assert(multiplayer == desktop_multiplayer)
	get_window().files_dropped.connect(_on_files_dropped)

func _exit_tree() -> void:
	if current == self:
		current = null
	_save_thumbnail()
	get_window().files_dropped.disconnect(_on_files_dropped)

func _ready() -> void:
	print_verbose("DESKTOP READY")
	if remote_url:
		print_verbose("CONNECTING TO REMOTE")
		desktop_multiplayer.start_client(remote_url)
		await desktop_multiplayer.connected_to_server
		print_verbose("CONNECTED TO SERVER")
		var server_desktop_metadata: DesktopMetadata = JsonResource.unpack(
			desktop_multiplayer.get_server_info().packed_desktop_metadata, DesktopMetadata)
		
		print_verbose("INIT REMOTE FILESYSTEM")
		filesystem = RemoteDesktopFilesystem.create(server_desktop_metadata)
		if not filesystem:
			push_error("Failed to initialize filesystem.")
			queue_free()
			return
		
		uuid = filesystem.desktop_uuid
	
	assert(UUID.is_valid(uuid))
	
	if not filesystem:
		filesystem = LocalDesktopFilesystem.create(uuid)
	
	filesystem.name = "DesktopFilesystem"
	add_child(filesystem)
	
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

func message_push(msg: TaggedMessage) -> void:
	message.emit(msg)

func window_open(app_window: AppWindow) -> void:
	if app_window.is_inside_tree():
		push_error("Cannot open window that is inside the tree.")
		return
	if app_window.service == null:
		push_error("Cannot open window that does not have an assigned service.")
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
	
	if idx == windows.size() - 1:
		return
	
	for i in range(idx, windows.size() - 1):
		windows[i] = windows[i + 1]
	windows[-1] = app_window
	
	_update_windows_z_index()
	
	if windows.size() > 1:
		windows[-2].unfocused.emit()
	windows[-1].focused.emit()

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
	var doc = filesystem.open(document_uuid)
	if not doc:
		return []
	
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
	if not filesystem:
		push_error("Can't save thumbnail: no desktop filesystem.")
		return
	var icon_img := get_viewport().get_texture().get_image()
	icon_img.resize(400, roundi(400 * icon_img.get_size().aspect()), Image.INTERPOLATE_LANCZOS)
	icon_img.save_png(filesystem.get_thumbnail_file_path())

func _on_files_dropped(files: PackedStringArray) -> void:
	for f in files:
		if DirAccess.dir_exists_absolute(f):
			push_error("Cannot import directory. ", f)
			continue
		_import_file(f)

func _import_file(path: String) -> void:
	filesystem.import(path)


func _on_shell_start_server() -> void:
	if desktop_multiplayer.is_server() and desktop_multiplayer.multiplayer_peer is not OfflineMultiplayerPeer:
		return
	desktop_multiplayer.start_server()


func _on_shell_stop_server() -> void:
	if not desktop_multiplayer.is_server():
		return
	desktop_multiplayer.shutdown()
