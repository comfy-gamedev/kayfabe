class_name DesktopMetadata
extends Resource

const DESKTOPS_DIR = "user://desktops"
const DESKTOP_METADATA_FILE = "desktop_metadata.tres"

const SUBDIRS = ["documents"]

@export var uuid: String = "": set = set_uuid
@export var friendly_name: String = "": set = set_friendly_name
@export var installed_apps: Array[StringName] = []

static func create() -> DesktopMetadata:
	var d = DesktopMetadata.new()
	d.uuid = UUID.v7()
	return d

func initialize_directory() -> void:
	if resource_path != "":
		push_error("Already initialized: ", resource_path)
		return
	if not UUID.is_valid(uuid):
		push_error("Invalid UUID.")
		return
	var dir = DESKTOPS_DIR.path_join(uuid)
	if DirAccess.dir_exists_absolute(dir):
		push_error("Directory already exists: ", dir)
		return
	var err = DirAccess.make_dir_recursive_absolute(dir)
	if err != OK:
		push_error("Failed to create directory %s: %s" % [dir, error_string(err)])
		return
	resource_path = dir.path_join(DESKTOP_METADATA_FILE)
	ResourceSaver.save(self, resource_path)
	
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
	if resource_path != "":
		push_error("Cannot change UUID of existing desktop.")
		return
	uuid = v
	emit_changed()

func set_friendly_name(v: String) -> void:
	if friendly_name == v: return
	friendly_name = v
	emit_changed()

func get_icon_path() -> String:
	return resource_path.get_base_dir().path_join("thumbnail.png")

func get_icon() -> Texture2D:
	var icon_path = get_icon_path()
	if not FileAccess.file_exists(icon_path):
		push_warning("No icon found: ", icon_path)
		return null
	return ImageTexture.create_from_image(Image.load_from_file(icon_path))
