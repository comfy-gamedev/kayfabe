extends PanelContainer

const LAUNCHER_ROW = preload("launcher_row.tscn")

var desktops: Dictionary
var rows: Dictionary
var new_row_uuid: String

@onready var desktop_scroll_container: ScrollContainer = %DesktopScrollContainer
@onready var desktop_rows: VBoxContainer = %DesktopRows

func _ready() -> void:
	if DirAccess.dir_exists_absolute(Framework.DESKTOPS_PATH):
		for d in DirAccess.get_directories_at(Framework.DESKTOPS_PATH):
			if UUID.is_valid(d):
				var metadata_file = Framework.DESKTOPS_PATH.path_join(d).path_join(Framework.DESKTOP_METADATA_FILE)
				if not FileAccess.file_exists(metadata_file):
					push_error("Desktop directory missing metadata file: ", d)
					continue
				var metadata: DesktopMetadata = JsonResource.load_json(metadata_file, DesktopMetadata)
				if not metadata:
					push_error("Desktop metadata is invalid: ", d)
					continue
				if metadata.uuid != d:
					push_error("Desktop metadata UUID does not match directory name: ", d)
					continue
				_add_row(metadata)

func _add_row(metadata: DesktopMetadata, is_new: bool = false) -> void:
	desktops[metadata.uuid] = metadata
	
	var row = LAUNCHER_ROW.instantiate()
	desktop_rows.add_child(row)
	row.icon_texture_rect.texture = metadata.get_icon()
	row.name_label.text = metadata.friendly_name
	row.activated.connect(_on_row_activated.bind(metadata.uuid))
	row.name_edited.connect(_on_row_name_edited.bind(metadata.uuid))
	rows[metadata.uuid] = row
	
	if is_new:
		new_row_uuid = metadata.uuid
		row.edit_name()

func _on_create_new_desktop_button_pressed() -> void:
	if new_row_uuid != "": return
	_add_row(DesktopMetadata.create(), true)

func _on_row_activated(desktop_uuid: String) -> void:
	get_window().title = desktops[desktop_uuid].friendly_name
	var desktop_scene = load("res://framework/desktop.tscn")
	var desktop = desktop_scene.instantiate()
	desktop.name = "Desktop-" + desktop_uuid
	desktop.metadata = desktops[desktop_uuid]
	var tree = get_tree()
	tree.root.remove_child(self)
	tree.root.add_child(desktop)
	tree.current_scene = desktop
	queue_free()
	

func _on_row_name_edited(new_name: String, desktop_uuid: String) -> void:
	if new_row_uuid == desktop_uuid:
		new_row_uuid = ""
		if new_name == "":
			desktops.erase(desktop_uuid)
			rows[desktop_uuid].queue_free()
			rows.erase(desktop_uuid)
			return
		desktops[desktop_uuid].friendly_name = new_name
		desktops[desktop_uuid].initialize_directory()
	else:
		if new_name == "":
			return
		var metadata: DesktopMetadata = desktops[desktop_uuid]
		if new_name == metadata.friendly_name:
			return
		metadata.friendly_name = new_name
		var metadata_path = Desktop.get_root_dir(metadata.uuid).path_join(Framework.DESKTOP_METADATA_FILE)
		var err = JsonResource.save_json(metadata, metadata_path)
		if err != OK:
			push_error("Failed to save metadata %s: %s" % [metadata_path, error_string(err)])
			return
	rows[desktop_uuid].name_label.text = new_name
