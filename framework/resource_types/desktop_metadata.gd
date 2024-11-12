class_name DesktopMetadata
extends RefCounted

signal changed()

const SUBDIRS = ["documents"]

@export var uuid: String = UUID.ZERO: set = set_uuid
@export var friendly_name: String = "": set = set_friendly_name
@export var installed_apps: Array = []

static func create() -> DesktopMetadata:
	var d = DesktopMetadata.new()
	d.uuid = UUID.v7()
	return d

func initialize_directory() -> void:
	if not UUID.is_valid(uuid):
		push_error("Invalid UUID.")
		return
	var dir = Framework.get_desktop_root(uuid)
	if DirAccess.dir_exists_absolute(dir):
		push_error("Directory already exists: ", dir)
		return
	var err = DirAccess.make_dir_recursive_absolute(dir)
	if err != OK:
		push_error("Failed to create directory %s: %s" % [dir, error_string(err)])
		return
	var metadata_path = dir.path_join(Framework.DESKTOP_METADATA_FILE)
	err = ObjectJSON.stringify_to_file(self, metadata_path)
	if err != OK:
		push_error("Failed to save metadata %s: %s" % [metadata_path, error_string(err)])
		return
	
	for s in SUBDIRS:
		var d = dir.path_join(s)
		err = DirAccess.make_dir_absolute(d)
		if err != OK:
			push_error("Failed to create subdirectory %s: %s" % [d, error_string(err)])

func set_uuid(v: String) -> void:
	if uuid == v: return
	if v != "" and not UUID.is_valid(v):
		push_warning("Invalid UUID.")
		breakpoint
	uuid = v
	changed.emit()

func set_friendly_name(v: String) -> void:
	if friendly_name == v: return
	friendly_name = v
	changed.emit()

func get_icon_path() -> String:
	return Framework.get_desktop_root(uuid).path_join("thumbnail.png")

func get_icon() -> Texture2D:
	var icon_path = get_icon_path()
	if not FileAccess.file_exists(icon_path):
		push_warning("No icon found: ", icon_path)
		return null
	return ImageTexture.create_from_image(Image.load_from_file(icon_path))
