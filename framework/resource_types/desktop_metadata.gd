class_name DesktopMetadata
extends JsonResource

signal changed()

@export var uuid: String = UUID.ZERO: set = set_uuid
@export var friendly_name: String = "": set = set_friendly_name
@export var installed_apps: PackedStringArray = []

static func create() -> DesktopMetadata:
	var d = DesktopMetadata.new()
	d.uuid = UUID.v7()
	return d

func initialize_directory() -> void:
	if not UUID.is_valid(uuid):
		push_error("Invalid UUID.")
		return
	var dir = Framework.get_desktop_dir(uuid)
	if DirAccess.dir_exists_absolute(dir):
		push_error("Directory already exists: ", dir)
		return
	var err = DirAccess.make_dir_recursive_absolute(dir)
	if err != OK:
		push_error("Failed to create directory %s: %s" % [dir, error_string(err)])
		return
	
	var metadata_path = Framework.get_desktop_metadata_file(uuid)
	err = JsonResource.save_json(self, metadata_path)
	if err != OK:
		push_error("Failed to save metadata %s: %s" % [metadata_path, error_string(err)])
		return
	
	for s in [Framework.DESKTOP_ARCHIVE_DIR, Framework.DESKTOP_DOCUMENTS_DIR]:
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
