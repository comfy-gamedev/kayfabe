class_name DesktopFilesystem
extends Node

@warning_ignore("unused_signal") # Emitted by implementations.
signal document_added(doc: Document)

enum CompressionMode {
	NONE,
	GZIP,
}

var metadata: DesktopMetadata

var desktop_uuid: StringName:
	get: return metadata.uuid

func get_thumbnail_file_path() -> String:
	push_error("Not implemented.")
	return ""

@warning_ignore("unused_parameter")
func list(tags: Array[StringName] = []) -> PackedStringArray:
	push_error("Not implemented.")
	return []

@warning_ignore("unused_parameter")
func create_empty(file_name: String) -> Document:
	push_error("Not implemented.")
	return null

@warning_ignore("unused_parameter")
func open(document_uuid: StringName) -> Document:
	push_error("Not implemented.")
	return null

@warning_ignore("unused_parameter")
func import(path: String) -> Document:
	push_error("Not implemented.")
	return null

func get_archive_file_path(sha256: String) -> String:
	return Framework.get_desktop_archive_dir(desktop_uuid).path_join(sha256)

func archive_file_exists(sha256: String) -> bool:
	return FileAccess.file_exists(get_archive_file_path(sha256))

func write_archive_file(sha256: String, content: PackedByteArray, compression: CompressionMode) -> Error:
	var archive_dir = Framework.get_desktop_archive_dir(desktop_uuid)
	if not DirAccess.dir_exists_absolute(archive_dir):
		push_warning("Archive dir not found, repairing: ", archive_dir)
		var err = DirAccess.make_dir_recursive_absolute(archive_dir)
		if err != OK:
			push_error("Failed to repair archive_dir %s: %s" % [archive_dir, error_string(err)])
			return err
	
	var path = get_archive_file_path(sha256)
	if FileAccess.file_exists(path):
		push_error("File already exists: ", path)
		return ERR_ALREADY_EXISTS
	var uncompressed_size = content.size()
	match compression:
		CompressionMode.NONE: pass
		CompressionMode.GZIP: content = content.compress(FileAccess.COMPRESSION_GZIP)
		_: breakpoint
	var file = FileAccess.open(path, FileAccess.WRITE)
	if not file:
		var err = FileAccess.get_open_error()
		push_error("Failed to open archive file for writing %s: %s" % [path, error_string(err)])
		return err
	file.store_8(1) # format version
	file.store_8(compression) # compression
	file.store_8(0) # reserved
	file.store_8(0) # reserved
	file.store_64(uncompressed_size)
	file.store_buffer(content)
	file.close()
	return file.get_error()

func read_archive_file(sha256: String) -> Variant: # null | PackedByteArray
	var path = get_archive_file_path(sha256)
	var file = FileAccess.open(path, FileAccess.READ)
	if not file:
		var err = FileAccess.get_open_error()
		push_error("Failed to open archive file for reading %s: %s" % [path, error_string(err)])
		return null
	var version = file.get_8()
	if version != 1:
		push_error("Invalid format version: ", path)
		return null
	var compression = file.get_8()
	file.get_8() # reserved
	file.get_8() # reserved
	var uncompressed_size = file.get_64()
	var content = file.get_buffer(file.get_length() - file.get_position())
	file.close()
	match compression:
		CompressionMode.NONE: pass
		CompressionMode.GZIP: content = content.decompress(uncompressed_size, FileAccess.COMPRESSION_GZIP)
		_: breakpoint
	return content

func archive_file_unpack(sha256: String, dest_file: String) -> void:
	var content = read_archive_file(sha256)
	if content == null:
		return
	var f := FileAccess.open(dest_file, FileAccess.WRITE)
	if not f:
		var err = FileAccess.get_open_error()
		push_error("Failed to open dest_file %s: %s" % [dest_file, error_string(err)])
		return
	f.store_buffer(content)
	f.close()
	assert(FileAccess.get_sha256(dest_file) == sha256)

func _open_archive_file(sha256: String, mode: FileAccess.ModeFlags) -> FileAccess:
	var path = get_archive_file_path(sha256)
	match mode:
		FileAccess.READ:
			return FileAccess.open(path, FileAccess.READ)
		FileAccess.WRITE:
			if FileAccess.file_exists(path):
				push_error("File already exists: ", path)
				return null
			return FileAccess.open(path, FileAccess.WRITE)
		_:
			push_error("Unsupported operation.")
			return null

func _open_archive_file_tmp(sha256: String) -> FileAccess:
	var path = get_archive_file_path(sha256)
	var i = 1
	var tmp = path + ".tmp" + str(i)
	while FileAccess.file_exists(tmp):
		i += 1
		tmp = path + ".tmp" + str(i)
	return FileAccess.open(tmp, FileAccess.WRITE)

static func _initialize_directory(p_metadata: DesktopMetadata) -> Error:
	if not UUID.is_valid(p_metadata.uuid):
		push_error("Invalid UUID.")
		return ERR_INVALID_PARAMETER
	var dir = Framework.get_desktop_dir(p_metadata.uuid)
	if DirAccess.dir_exists_absolute(dir):
		push_error("Directory already exists: ", dir)
		return ERR_ALREADY_EXISTS
	var err = DirAccess.make_dir_recursive_absolute(dir)
	if err != OK:
		push_error("Failed to create directory %s: %s" % [dir, error_string(err)])
		return err
	
	var metadata_path = Framework.get_desktop_metadata_file(p_metadata.uuid)
	err = JsonResource.save_json(p_metadata, metadata_path)
	if err != OK:
		push_error("Failed to save metadata %s: %s" % [metadata_path, error_string(err)])
		return err
	
	for s in [Framework.DESKTOP_ARCHIVE_DIR, Framework.DESKTOP_DOCUMENTS_DIR]:
		var d = dir.path_join(s)
		err = DirAccess.make_dir_absolute(d)
		if err != OK:
			push_error("Failed to create subdirectory %s: %s" % [d, error_string(err)])
			return err
	
	return OK

@warning_ignore("unused_parameter")
@rpc("authority", "call_remote", "reliable")
func _update_head_rpc(document_uuid: StringName, metadata_pack: Dictionary, head_pack: Dictionary, version_pack: Dictionary) -> void:
	push_error("Not implemented.")

@warning_ignore("unused_parameter")
@rpc("any_peer", "call_remote", "reliable")
func _commit_rpc(document_uuid: StringName, new_sha256: String, comment: String) -> void:
	push_error("Not implemented.")

@rpc("any_peer", "call_remote", "reliable")
func _request_refresh_rpc() -> void:
	push_error("Not implemented.")
